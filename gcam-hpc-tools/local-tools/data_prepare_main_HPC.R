library(tools)
source("./diag_parser_HPC.r")
source("./diag_header_HPC.r")

data_folder <- file.path("PTAH-TO-LOCAL-CSV")

# Set the import scenarios -------------------
#source(file.path(base_viewer_folder,"data_prepare.R")) # tools for prepare the .dat files
fn <- c(paste0(data_folder,"/######.csv"))
tables_saved <- list()
tables_saved <- parse_mi_output_pic_progress( fn )
print(names(tables_saved))
timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
rds_filename <- paste0(file_path_sans_ext(basename(fn)), "_", timestamp, ".rds")
saveRDS(tables_saved, file = file.path(data_folder, rds_filename))
