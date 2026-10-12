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

args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 4L)
library(gcamreport)
library(rgcam)
task <- read_configuration(args[[1]], args[[2]])
conn <- rgcam::localDBConn(task$db_path, task$db_name, migabble = FALSE)
scenarios <- rgcam::listScenariosInDB(conn)
selected <- scenarios[scenarios$name == task$scenario, , drop = FALSE]
if (nrow(selected) != 1L) stop("Expected one database entry for scenario ", task$scenario)
mapping <- select_mapping(as.character(selected$version[[1]]),
                          gcamreport::available_GCAM_versions, args[[3]])
message("Scenario: ", task$scenario, "; GCAM mapping: ", mapping)
gcamreport::generate_report(
  db_path = task$db_path, db_name = task$db_name, prj_name = "gcamreport.dat",
  scenarios = task$scenario, GCAM_version = mapping,
  save_output = "CSV", output_file = file.path(getwd(), "iamc"),
  launch_ui = FALSE, interactive = FALSE
)
if (grepl("china", basename(args[[4]]), ignore.case = TRUE)) {
  report <- read.csv("iamc.csv", check.names = FALSE, stringsAsFactors = FALSE)
  report$Model <- "GCAM-China"
  write.csv(report, "iamc.csv", row.names = FALSE, na = "")
}
unlink(file.path(task$db_path, paste0(task$db_name, "_gcamreport.dat")))
