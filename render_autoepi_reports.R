#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(rmarkdown)
  library(glue)
  library(purrr)
  library(stringr)
  library(fs)
  # minimal add-ons for logs update:
  library(readr)
  library(dplyr)
})

# -----------------------
# Inputs / defaults
# -----------------------
args <- commandArgs(trailingOnly = TRUE)

# 1) Settings (to discover default Reports_Dir)
settings_path <- if (length(args) >= 1) args[[1]] else "AutoEpi_Settings.RData"
if (!file.exists(settings_path)) stop("Settings file not found: ", settings_path)
load(settings_path)  # -> autoepi_settings

# Normalize IO paths from settings (Windows/UNC safe)
normp <- function(p) {
  if (is.null(p) || !nzchar(p)) return(NA_character_)
  tryCatch(normalizePath(p, winslash = "/", mustWork = FALSE), error = function(e) p)
}

reports_dir_setting <- normp(autoepi_settings$IO$Reports_Dir)
logs_dir_setting    <- normp(autoepi_settings$IO$Logs_Dir)

if (!nzchar(reports_dir_setting)) stop("Reports_Dir missing in settings.")

if (!dir_exists(reports_dir_setting)) {
  dir_create(reports_dir_setting, recurse = TRUE)
}

# 2) AutoEpi report RData or directory containing it (arg #2 is flexible):
#    - If a FILE path is given and exists, use it.
#    - If a DIR path is given, search within that dir.
#    - If omitted, search Reports_Dir from settings, then CWD.
resolve_report_path <- function(arg2, reports_dir_setting) {
  is_rdata <- function(x) grepl("\\.RData$", x, ignore.case = TRUE)
  pick_latest <- function(paths) {
    if (!length(paths)) return(NA_character_)
    info <- file_info(paths)
    paths[which.max(info$modification_time)]
  }
  
  pattern <- "AutoEpi_Report_\\d{4}-\\d{2}-\\d{2}\\.RData$"
  
  if (!is.null(arg2) && nzchar(arg2)) {
    p <- normp(arg2)
    if (file_exists(p) && is_rdata(p)) return(p)
    if (dir_exists(p)) {
      cand <- dir_ls(p, regexp = pattern, type = "file", recurse = FALSE)
      if (length(cand)) return(pick_latest(cand))
      stop("No AutoEpi_Report_*.RData found in provided directory: ", p)
    }
    stop("Second argument is neither an existing .RData nor a directory: ", arg2)
  }
  
  # No arg2 provided: search reports_dir_setting first, then working dir
  search_dirs <- unique(c(reports_dir_setting, path_abs(".")))
  for (d in search_dirs) {
    if (!dir_exists(d)) next
    cand <- dir_ls(d, regexp = pattern, type = "file", recurse = FALSE)
    if (length(cand)) return(pick_latest(cand))
  }
  NA_character_
}

report_rdata_path <- resolve_report_path(if (length(args) >= 2) args[[2]] else NULL, reports_dir_setting)
if (!nzchar(report_rdata_path) || !file_exists(report_rdata_path)) {
  stop("Could not locate an AutoEpi report .RData. Checked: argument #2, Reports_Dir from settings, and working directory.")
}

# 3) Rmd template path (can be overridden as 3rd arg)
template_path <- if (length(args) >= 3) args[[3]] else "autoepi_report_template.Rmd"
if (!file.exists(template_path)) stop("Rmd template not found: ", template_path)

message("Using settings:  ", settings_path)
message("Using report:    ", report_rdata_path)
message("Using template:  ", template_path)

# -----------------------
# Load report object
# -----------------------
load(report_rdata_path)  # expects object: autoepi_report
if (!exists("autoepi_report")) stop("Object 'autoepi_report' not found in ", report_rdata_path)
stopifnot(is.list(autoepi_report), length(autoepi_report) > 0)

# -----------------------
# Output directory
# -----------------------
# Default output under <directory_of_RData>/Rendered/<YYYY-MM-DD>/
rd_base <- path_dir(report_rdata_path)
rd_name <- path_file(report_rdata_path)
rd_date <- stringr::str_match(rd_name, "AutoEpi_Report_(\\d{4}-\\d{2}-\\d{2})\\.RData$")[,2]
rd_date <- rd_date %||% format(Sys.Date(), "%Y-%m-%d")

out_root <- path(rd_base, "Rendered", rd_date)
dir_create(out_root, recurse = TRUE)
message("Output directory: ", out_root)

# -----------------------
# Helpers
# -----------------------
`%||%` <- function(a, b) if (!is.null(a) && length(a)) a else b

sanitize_filename <- function(x) {
  x <- stringr::str_replace_all(x, "[/\\?*:\"<>|]+", "_")
  x <- stringr::str_squish(x)
  x <- ifelse(nchar(x) == 0, "unnamed", x)
  x
}

# minimal date parser used only at join time
to_Date <- function(x) {
  suppressWarnings(as.Date(as.character(x),
                           tryFormats = c("%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y")))
}

date_keys <- names(autoepi_report)

# -----------------------
# Iterate Date × Syndrome
# -----------------------
rendered <- 0L
failed   <- 0L

# collect created files for logs update (minimal change)
created <- list()  # list of list(date=dk, syndrome=sk, path=full_html_path)

for (dk in date_keys) {
  node <- autoepi_report[[dk]]
  if (!is.list(node)) next
  
  meta <- node$meta %||% list()
  
  # Syndromes are all top-level keys except "meta"
  syn_keys <- setdiff(names(node), "meta")
  if (!length(syn_keys)) next
  
  # Subfolder per date to keep things tidy
  out_dir <- path(out_root, sanitize_filename(dk))
  dir_create(out_dir)
  
  for (sk in syn_keys) {
    rpt <- node[[sk]]
    if (!is.list(rpt)) next
    
    # Build output filename
    fname <- glue("{sanitize_filename(dk)}__{sanitize_filename(sk)}__AutoEpi.html")
    full_out <- path(out_dir, fname)
    
    message(glue("Rendering: Date='{dk}'  Syndrome='{sk}'"))
    
    # Render with parameters (syndrome_key optional; template infers too)
    ok <- tryCatch({
      rmarkdown::render(
        input        = template_path,
        output_dir   = out_dir,
        output_file  = fname,
        params       = list(
          date_key     = dk,
          syndrome_key = sk,    # kept for filename clarity; template can infer if absent
          report       = rpt,   # list: $count, $per10k, $maps
          meta         = meta   # list: climate_table, climate_stats, aqi_stations, aqi_summary, aqi_plot
        ),
        quiet        = TRUE,
        envir        = new.env(parent = globalenv())
      )
      TRUE
    }, error = function(e) {
      message("  ✖ Failed: ", conditionMessage(e))
      FALSE
    })
    
    if (ok) {
      rendered <- rendered + 1L
      message("  ✓ Wrote: ", full_out)
      created[[length(created) + 1L]] <- list(date = dk, syndrome = sk, path = full_out)
    } else {
      failed <- failed + 1L
    }
  }
}

message("\n=== Done ===")
message("Rendered: ", rendered)
message("Failed:   ", failed)
message("Output:   ", out_root)

# -----------------------
# AFTER: bolt-on logs update (minimal)
# -----------------------
if (file.exists("LogsFileLoc.RData")) {
  load("LogsFileLoc.RData")  # -> LogsFileLoc
}

if (exists("LogsFileLoc") && is.character(LogsFileLoc) && nzchar(LogsFileLoc) && file.exists(LogsFileLoc)) {
  logs_path <- normalizePath(LogsFileLoc, winslash = "/", mustWork = FALSE)
  
  if (!length(created)) {
    message("\n=== Logs Update ===")
    message("No HTML files created; nothing to update in logs.")
    quit(status = 0)
  }
  
  # minimal deps already loaded above: readr, dplyr
  logs_raw <- readr::read_csv(logs_path, 
                             col_types = readr::cols(
                               ObvsDate       = readr::col_date(),
                               presented_name = readr::col_character(),
                               AlertLevel     = readr::col_factor(levels = c("Normal","Warning","Alert","False Positive")),
                               ReportCreated  = readr::col_factor(levels = c("no","yes")),
                               ReportLocation = readr::col_character(),
                               EmailSent      = readr::col_factor(levels = c("no","yes"))
                             ))
  needed <- c("ObvsDate","presented_name","AlertLevel","ReportCreated","ReportLocation","EmailSent")
  if (!all(needed %in% names(logs_raw))) {
    warning("Logs CSV missing required columns; skipping update: ", logs_path)
    quit(status = 0)
  }
  
  to_Date <- function(x) suppressWarnings(as.Date(as.character(x),
                                                  tryFormats = c("%Y-%m-%d", "%m/%d/%Y", "%m/%d/%y")))
  
  logs_df <- logs_raw %>%
    mutate(
      .idx = dplyr::row_number(),
      ObvsDate_parsed = to_Date(ObvsDate),
      presented_name  = as.character(presented_name)
    )
  
  created_df <- dplyr::bind_rows(lapply(created, as.data.frame)) %>%
    dplyr::transmute(
      presented_name = as.character(syndrome),
      html_path      = path
    )
  
  # Match by syndrome name only (not by date, since we want to update the correct observation dates)
  map_df <- logs_df %>%
    dplyr::select(.idx, presented_name, AlertLevel, ObvsDate_parsed) %>%
    dplyr::inner_join(created_df, by = "presented_name")
  
  if (nrow(map_df) > 0) {
    logs_df$ReportCreated[map_df$.idx]  <- "yes"
    logs_df$ReportLocation[map_df$.idx] <- map_df$html_path
    
    # Update False Positives: any entries that had Warning/Alert but no report generated
    logs_df <- logs_df %>%
      mutate(
        AlertLevel = factor(case_when(
          AlertLevel %in% c("Warning", "Alert") & ReportCreated == "no" ~ "False Positive",
          TRUE ~ as.character(AlertLevel)
        ), levels = c("Normal","Warning","Alert","False Positive"))
      )
    
    aw_count <- sum(as.character(map_df$AlertLevel) %in% c("Warning","Alert"), na.rm = TRUE)
    
    logs_out <- logs_df %>% dplyr::select(-.idx, -ObvsDate_parsed)
    readr::write_csv(logs_out, logs_path)
    
    message("\n=== Logs Update ===")
    message("Updated rows:               ", nrow(map_df))
    message("Alerts/Warnings in updates: ", aw_count)
    message("CSV written:                ", logs_path)
  } else {
    message("\n=== Logs Update ===")
    message("No matching rows found to update in logs (date = ",
            ifelse(is.na(target_date), "ANY", as.character(target_date)), ").")
  }
  
} else {
  message("\n=== Logs Update ===")
  message("LogsFileLoc.RData not found OR LogsFileLoc missing/invalid; skipping log updates.")
}