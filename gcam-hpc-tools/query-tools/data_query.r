# Import libraries
library(dplyr)
library(rgcam)

data_timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
Query_path <- file.path(".", "gcam-hpc-tools", "query-tools", "i_queries_xml", "steel-tech-protofolio-query.xml")
data_folder <- file.path(".", "gcam-hpc-tools", "query-tools", "i_data")


#==== Define the scenario group and scenarios to be used ====
output_path_ssd <- "/Volumes/JERRYSONG_SSD_2T/GCAM_Workspace/gcam-v8.2-Mac-Release-Package/output"
# Create a list of all scenario configurations
all_scenarios_ssd <- list(
  list(group = "0720_gcam_mfa_tech_0720", scenarios = c("GCAM_steel_mfa_SSP2",                    "GCAM_steel_mfa_ctax_SSP2",
                                                        "GCAM_steel_mfa_SSP2_hEE",                "GCAM_steel_mfa_ctax_SSP2_hEE",
                                                        "GCAM_steel_mfa_SSP2_tech_ref",           "GCAM_steel_mfa_ctax_SSP2_tech_ref",
                                                        "GCAM_steel_mfa_SSP2_tech_adv",           "GCAM_steel_mfa_ctax_SSP2_tech_adv",
                                                        "GCAM_steel_mfa_SSP2_tech_adv_noCCS",     "GCAM_steel_mfa_ctax_SSP2_tech_adv_noCCS",
                                                        "GCAM_steel_mfa_SSP2_tech_ref_lowCCS",    "GCAM_steel_mfa_SSP2_retirement"
                                                        )),
  list(group = "0723_gcam_mfa_tech_0723", scenarios = c("GCAM_steel_mfa_ctax_SSP2_retirement",    "GCAM_steel_mfa_ctax_SSP2_tech_ref_lowCCS",
                                                        "GCAM_steel_mfa_SSP2_tech_ref_noCCS",     "GCAM_steel_mfa_ctax_SSP2_tech_ref_noCCS"
                                                        ))
)

#==== Initialize the project object map ====

# Run addScenario and build the project object map
for (config in all_scenarios_ssd) {
  message("Processing scenario .dat file: ", config$group)
  assign(paste0("PJ", config$group, ".proj"),
         addScenario(
           conn = localDBConn(output_path_ssd, config$group),
           proj = paste0(data_folder, "/PJ", config$group, ".dat"),
           scenario = config$scenarios,
           queryFile = Query_path,
           clobber = FALSE,
           saveProj = TRUE
         )
  )
}
