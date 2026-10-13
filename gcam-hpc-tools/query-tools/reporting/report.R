#!/usr/bin/env Rscript
# Read the existing scenario configuration, detect its version, and export CSV.
read_configuration <- function(config, exe) {
  root <- xml2::read_xml(config)
  scenario <- trimws(xml2::xml_text(xml2::xml_find_first(
    root, "(./Strings/Value[@name='scenarioName'])[last()]")))
  value <- xml2::xml_find_first(root, "(./Files/Value[@name='xmldb-location'])[last()]")
  location <- trimws(xml2::xml_text(value))
  if (is.na(scenario) || !nzchar(scenario)) stop("Missing scenarioName: ", config)
  if (is.na(location) || !nzchar(location)) stop("Missing xmldb-location: ", config)
  if (identical(xml2::xml_attr(value, "write-output"), "0")) stop("Database output must be enabled")
  if (identical(xml2::xml_attr(value, "append-scenario-name"), "1")) location <- paste0(location, scenario)
  database <- normalizePath(if (startsWith(location, "/")) location else file.path(exe, location), mustWork = TRUE)
  list(scenario = scenario, db_path = dirname(database), db_name = basename(database))
}

select_mapping <- function(version, supported, override = "") {
  if (nzchar(override)) {
    if (!override %in% supported) stop("Mapping unavailable in this image: ", override)
    return(override)
  }
  match <- regmatches(version, regexpr("[0-9]+\\.[0-9]+", version))
  if (!length(match) || !nzchar(match)) stop("Cannot detect GCAM version: ", version)
  mapping <- paste0("v", match)
  if (!mapping %in% supported) {
    stop("No mapping for GCAM ", version, ". Available: ", paste(supported, collapse = ", "))
  }
  if (grepl("europe|scenariomip|cmip", version, ignore.case = TRUE)) {
    stop("Specify GCAMREPORT_VERSION for model variant: ", version)
  }
  mapping
}

read_report_options <- function(config, mapping) {
  settings <- new.env(parent = baseenv())
  sys.source(config, envir = settings)
  if (!exists("report_options", envir = settings, inherits = FALSE)) {
    stop("Report config must define report_options: ", config)
  }
  options <- settings$report_options
  if (!is.list(options) || !length(options) || is.null(names(options)) ||
      anyNA(names(options)) || any(!nzchar(names(options))) || anyDuplicated(names(options))) {
    stop("report_options must be a named list with unique parameter names: ", config)
  }
  task_parameters <- c("db_path", "db_name", "prj_name", "scenarios", "GCAM_version", "output_file")
  allowed <- c(setdiff(names(formals(gcamreport::generate_report)), task_parameters), "excluded_regions")
  unknown <- setdiff(names(options), allowed)
  if (length(unknown)) stop("Unsupported or task-managed report parameters: ", paste(unknown, collapse = ", "))
  # Reports run unattended on HPC; retain these defaults in custom configs too.
  if (is.null(options$launch_ui)) options$launch_ui <- FALSE
  if (is.null(options$interactive)) options$interactive <- FALSE
  excluded <- options$excluded_regions
  options$excluded_regions <- NULL
  if (length(excluded)) {
    if (!is.character(excluded) || anyNA(excluded)) stop("excluded_regions must be a character vector")
    available <- if (is.null(mapping)) "China" else gcamreport::available_regions(print = FALSE, GCAM_version = mapping)
    unknown_regions <- setdiff(excluded, available)
    if (length(unknown_regions)) stop("Unknown excluded regions: ", paste(unknown_regions, collapse = ", "))
    regions <- options$desired_regions
    if (is.null(regions) || identical(regions, "All")) regions <- available
    options$desired_regions <- setdiff(regions, excluded)
    if (!length(options$desired_regions)) stop("Region selection is empty after exclusions")
  }
  options
}

run_china_report <- function(conn, scenario, config) {
  source_dir <- Sys.getenv("GCAMCHINA_REPORT_SOURCE")
  if (!file.exists(file.path(source_dir, "Reporting.R"))) {
    stop("GCAM-China reporting submodule is missing: ", source_dir)
  }
  options <- read_report_options(config, NULL)
  for (package in c("dplyr", "tidyr", "readr", "stringr")) library(package, character.only = TRUE)
  reporting <- new.env(parent = globalenv())
  reporting$home_dir <- source_dir
  reporting$src_dir <- file.path(source_dir, "src")
  reporting$map_dir <- file.path(source_dir, "mappings")
  reporting$Scenarios <- scenario
  sys.source(file.path(reporting$src_dir, "constants.R"), envir = reporting)
  # Load upstream functions without initializing its plotting-only objects.
  for (expr in parse(file.path(reporting$src_dir, "functions.R"))) {
    if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
        is.call(expr[[3]]) && identical(expr[[3]][[1]], as.name("function"))) eval(expr, envir = reporting)
  }
  sys.source(file.path(reporting$src_dir, "mapping.R"), envir = reporting)
  reporting$prj <- rgcam::addScenario(conn, file.path(getwd(), "gcamchina-report.dat"),
    scenario, file.path(source_dir, "src/query_use.xml"), clobber = TRUE, saveProj = FALSE)
  # Keep upstream calculations; the wrapper supplies inputs and exports CSV.
  # GDP is not exported by upstream and its query is absent in macro databases.
  script <- parse(file.path(source_dir, "Reporting.R"))
  setup <- vapply(script, function(expr) is.call(expr) &&
    (as.character(expr[[1]]) %in% c("source", "write.csv") ||
      (identical(expr[[1]], as.name("<-")) && is.symbol(expr[[2]]) &&
        as.character(expr[[2]]) %in% c("Scenarios", "prj", "GDP_PPP_clean"))), logical(1))
  for (expr in script[!setup]) eval(expr, envir = reporting)
  report <- reporting$IAMC_format_china
  names(report)[1:5] <- c("Model", "Scenario", "Region", "Variable", "Unit")
  report$Model <- "GCAM-China"
  if (!is.null(options$desired_regions) && !identical(options$desired_regions, "All")) {
    report <- report[report$Region %in% options$desired_regions, , drop = FALSE]
  }
  if (!is.null(options$desired_variables) && !identical(options$desired_variables, "All")) {
    selected <- Reduce(`|`, lapply(options$desired_variables, function(pattern) grepl(glob2rx(pattern), report$Variable)))
    report <- report[if (isTRUE(options$inverse_desired_variables)) !selected else selected, , drop = FALSE]
  }
  if (!is.null(options$final_year)) {
    years <- grep("^[0-9]{4}$", names(report), value = TRUE)
    report <- report[, c(names(report)[1:5], years[as.integer(years) <= options$final_year]), drop = FALSE]
  }
  report
}

run_report <- function(args) {
  if (length(args) != 5L) stop("Expected scenario XML, executable directory, mapping, model directory, and report config")
  library(gcamreport)
  library(rgcam)
  task <- read_configuration(args[[1]], args[[2]])
  conn <- rgcam::localDBConn(task$db_path, task$db_name, migabble = FALSE)
  scenarios <- rgcam::listScenariosInDB(conn)
  selected <- scenarios[scenarios$name == task$scenario, , drop = FALSE]
  if (nrow(selected) != 1L) stop("Expected one database entry for scenario ", task$scenario)
  version <- as.character(selected$version[[1]])
  if (grepl("china", paste(basename(args[[4]]), version), ignore.case = TRUE)) {
    message("Scenario: ", task$scenario, "; reporting: GCAM-China; report config: ", args[[5]])
    report <- run_china_report(conn, task$scenario, args[[5]])
    if (!is.data.frame(report) || !nrow(report)) stop("GCAM-China reporting produced an empty report")
    write.csv(report, "iamc.csv", row.names = FALSE, na = "")
    return(invisible(NULL))
  }
  mapping <- select_mapping(as.character(selected$version[[1]]),
                            gcamreport::available_GCAM_versions, args[[3]])
  options <- read_report_options(args[[5]], mapping)
  message("Scenario: ", task$scenario, "; GCAM mapping: ", mapping, "; report config: ", args[[5]])
  output_file <- file.path(getwd(), "iamc")
  do.call(gcamreport::generate_report, c(list(
    db_path = task$db_path, db_name = task$db_name, prj_name = "gcamreport.dat",
    scenarios = task$scenario, GCAM_version = mapping, output_file = output_file
  ), options))
  # Upstream always saves report to RData, including when save_output=FALSE.
  # Export the pipeline CSV explicitly so downstream shell merging still works.
  result <- new.env(parent = emptyenv())
  load(paste0(output_file, ".RData"), envir = result)
  report <- result$report
  required <- c("Model", "Scenario", "Region", "Variable", "Unit")
  if (!is.data.frame(report) || !nrow(report) || !all(required %in% names(report))) {
    stop("gcamreport produced an empty or invalid IAMC report")
  }
  write.csv(report, paste0(output_file, ".csv"), row.names = FALSE, na = "")
  unlink(file.path(task$db_path, paste0(task$db_name, "_gcamreport.dat")))
}

if (sys.nframe() == 0L) run_report(commandArgs(trailingOnly = TRUE))
