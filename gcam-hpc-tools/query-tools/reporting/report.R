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
    available <- gcamreport::available_regions(print = FALSE, GCAM_version = mapping)
    unknown_regions <- setdiff(excluded, available)
    if (length(unknown_regions)) stop("Unknown excluded regions: ", paste(unknown_regions, collapse = ", "))
    regions <- options$desired_regions
    if (is.null(regions) || identical(regions, "All")) regions <- available
    options$desired_regions <- setdiff(regions, excluded)
    if (!length(options$desired_regions)) stop("Region selection is empty after exclusions")
  }
  options
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
  if (grepl("china", basename(args[[4]]), ignore.case = TRUE)) report$Model <- "GCAM-China"
  write.csv(report, paste0(output_file, ".csv"), row.names = FALSE, na = "")
  unlink(file.path(task$db_path, paste0(task$db_name, "_gcamreport.dat")))
}

if (sys.nframe() == 0L) run_report(commandArgs(trailingOnly = TRUE))
