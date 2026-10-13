# Independent gcamreport settings; edits take effect without rebuilding the container.
# Each task supplies its database, project name, scenario, version mapping, and output path.
report_options <- list(
  final_year = 2100,

  # Regions to include: "All" or c("China", "USA").
  desired_regions = "All",
  # Regions to remove from the selection above; character() excludes none.
  excluded_regions = character(),

  # Standard variables to include: "All" or c("Population", "Emissions|CO2").
  desired_variables = "All",
  # TRUE excludes desired_variables and retains all other variables.
  # In exclusion mode, list specific variables or patterns, e.g. c("Emissions|CH4*").
  inverse_desired_variables = FALSE,

  # Scrap constraints are internal model markets, not standard reporting variables.
  # Pattern matching also covers region-prefixed names such as Ukrainescrap-constraint.
  # Ignore policy markets absent from the standard energy price mapping.
  ignore = c("scrap-constraint", "CO2_NearTerm", "globalCO2_LTG"),

  # Keep FALSE; the pipeline converts gcamreport's RData output to iamc.csv for merging.
  save_output = FALSE,
  launch_ui = FALSE,
  interactive = FALSE
)
