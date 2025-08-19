#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(glue)
  library(stringr)
  library(fs)
  library(readr)
  library(dplyr)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  stop("Usage: Rscript autoepi_email_links_only_lower.R <settings_path> <logs_csv_path>")
}

settings_path <- args[[1]]
logs_path <- args[[2]]

if (!file.exists(settings_path)) stop("Settings file not found: ", settings_path)
if (!file.exists(logs_path)) stop("Logs file not found: ", logs_path)

load(settings_path)  # loads autoepi_settings
reports_dir <- normalizePath(autoepi_settings$io$reports_dir, winslash = "/", mustWork = FALSE)

# Find Rendered reports
rendered_root <- path(reports_dir, "Rendered")
if (!dir_exists(rendered_root)) stop("No Rendered dir found under: ", reports_dir)

html_files <- dir_ls(rendered_root, regexp = "\\_AutoEpi.html$", recurse = TRUE, type = "file")

# Index reports
report_index <- tibble::tibble(
  path = html_files,
  file = path_file(html_files),
  date_key = str_match(file, "^(.*?)__")[,2],
  syndrome_key = str_match(file, "__(.*?)__AutoEpi.html$")[,2]
)

# Load logs
logs <- read_csv(logs_path, show_col_types = FALSE)

# Normalize
logs <- logs %>%
  mutate(
    obvsdate_chr = as.character(obvsdate),
    presented_name_norm = str_to_lower(str_squish(presented_name))
  )

report_index <- report_index %>%
  mutate(
    obvsdate_chr = date_key,
    presented_name_norm = str_to_lower(str_squish(syndrome_key))
  )

# Match and update
logs_updated <- logs %>% left_join(report_index,
                                   by = c("obvsdate_chr", "presented_name_norm")) %>%
  mutate(
    reportcreated = if_else(!is.na(path), "yes", reportcreated),
    reportlocation = if_else(!is.na(path), path, reportlocation),
    emailsent = if_else(!is.na(path), "yes", emailsent)
  ) %>%
  select(-file, -date_key, -syndrome_key)

# Save updated logs
backup_path <- paste0(logs_path, ".bak")
file.copy(logs_path, backup_path, overwrite = TRUE)
write_csv(logs_updated, logs_path)

message("Logs updated. Backup saved at: ", backup_path)

# Prepare email body (links only)
if (nrow(report_index)) {
  cat("Prepared links to reports:\n")
  for (rp in report_index$path) {
    cat(" - file:///", rp, "\n", sep = "")
  }
} else {
  cat("No reports found to include.\n")
}
