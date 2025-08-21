############################################################
##  AutoEpi – DataDetails Drill-down & Triage
##  --------------------------------------------------------
##  Prereqs:  • AutoEpi_Settings.RData         (from GUI.R)
##            • LogsFileLoc.RData              (from LogsCreate.R)
##            • InvestigateTSRecords.RData     (from Time-Series script)
##
##  1.  Load settings, log, and investigate_df
##  2.  For every (syndrome, ObvsDate) flagged:
##        a.  Query ESSENCE /dataDetails, dedup on C_BioSense_ID
##        b.  Count visits (n_visits)
##        c.  Pull historical TimeSeries for [ObvsDate-lookback, ObvsDate]
##           – compute mean & sd
##        d.  If n_visits > mean + sd  ➜ keep (possible true signal)
##             else                    ➜ mark False Positive in log
##  3.  Write:
##        • reportsData.RData        (all “kept” visit-level rows)
##        • updated autoepi_logs.csv (via LogsFileLoc)
############################################################

## --- 0.  Packages ----------------------------------------------------------
suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(dplyr)
  library(readr)
})

## --- 1.  Load core artefacts ----------------------------------------------
load("AutoEpi_Settings.RData")          # -> autoepi_settings
load("LogsFileLoc.RData")               # -> LogsFileLoc
load("InvestigateTSRecords.RData")      # -> investigate_df

if (!exists("autoepi_settings") || !exists("LogsFileLoc") ||
    !exists("investigate_df"))
  stop("Required .RData objects missing – aborting.")

log_levels <- c("Normal", "Warning", "Alert", "False Positive")

logs_df <- read_csv(LogsFileLoc,
                    col_types = cols(
                      ObvsDate       = col_date(),
                      presented_name = col_character(),
                      AlertLevel     = col_factor(levels = log_levels),
                      ReportCreated  = col_factor(levels = c("no", "yes")),
                      ReportLocation = col_character(),
                      EmailSent      = col_factor(levels = c("no", "yes"))
                    ))

## --- 2.  Helpers -----------------------------------------------------------
fmt_api_date <- function(x) format(as.Date(x), "%d%b%Y")   # e.g. 13Aug2025

api_base_dd <- "https://essence.syndromicsurveillance.org/nssp_essence/api/dataDetails"
api_base_ts <- "https://essence.syndromicsurveillance.org/nssp_essence/api/timeSeries"

build_dd_url <- function(ccdd, d_str) {
  paste0(
    api_base_dd,
    "?datasource=va_er",
    "&startDate=", d_str,
    "&endDate=",   d_str,
    "&medicalGroupingSystem=essencesyndromes",
    "&userId=5629",
    "&percentParam=noPercent",
    "&aqtTarget=DataDetails",
    "&ccddCategory=", URLencode(ccdd, reserved = TRUE),
    "&geographySystem=region",
    "&detector=probrepswitch",
    "&timeResolution=daily",
    "&refValues=true"
  )
}

build_ts_url <- function(ccdd, start_str, end_str) {
  paste0(
    api_base_ts,
    "?datasource=va_er",
    "&startDate=", start_str,
    "&endDate=",   end_str,
    "&medicalGroupingSystem=essencesyndromes",
    "&userId=5629",
    "&percentParam=noPercent",
    "&aqtTarget=TimeSeries",
    "&ccddCategory=", URLencode(ccdd, reserved = TRUE),
    "&geographySystem=region",
    "&detector=probrepswitch",
    "&timeResolution=daily"
  )
}

## --- 3.  Main loop ---------------------------------------------------------
lookback <- autoepi_settings$Dates$Lookback_Days
auth_usr <- autoepi_settings$Credentials$ESSENCE_Username
auth_pwd <- autoepi_settings$Credentials$ESSENCE_Password

kept_list <- list()        # rows that pass the check

for (j in seq_len(nrow(investigate_df))) {
  row      <- investigate_df[j, ]
  ccdd     <- row$Syndrome_Snippet
  syn_name <- row$presented_name
  d_obs    <- as.Date(row$ObvsDate)
  d_str    <- fmt_api_date(d_obs)
  
  ## 3a.  DataDetails call ---------------------------------------------------
  url_dd <- build_dd_url(ccdd, d_str)
  resp_dd <- GET(url_dd, authenticate(auth_usr, auth_pwd))
  if (http_error(resp_dd)) {
    warning("DataDetails call failed (", status_code(resp_dd), ") for ", syn_name,
            " @ ", d_str)
    next
  }
  
  dd_json <- content(resp_dd, as = "text", encoding = "UTF-8")
  dd_dat  <- fromJSON(dd_json, flatten = TRUE)$dataDetails
  if (is.null(dd_dat) || nrow(dd_dat) == 0) next
  
  ## 3b.  Dedup + visit count ------------------------------------------------
  n_visits <- dd_dat |>
    distinct(C_BioSense_ID) |>
    tally() |>
    pull(n)
  
  ## 3c.  Historical TS for mean & sd ---------------------------------------
  start_hist <- d_obs - lookback
  url_ts <- build_ts_url(ccdd, fmt_api_date(start_hist), d_str)
  resp_ts <- GET(url_ts, authenticate(auth_usr, auth_pwd))
  if (http_error(resp_ts)) {
    warning("TimeSeries call failed (", status_code(resp_ts), ") for ", syn_name,
            " @ ", d_str)
    next
  }
  
  ts_json <- content(resp_ts, as = "text", encoding = "UTF-8")
  ts_df   <- fromJSON(ts_json, simplifyDataFrame = TRUE)$timeSeriesData
  if (is.null(ts_df) || nrow(ts_df) == 0) next
  
  stats <- summarise(ts_df, m = mean(count, na.rm = TRUE),
                     s = sd(count,   na.rm = TRUE))
  
  threshold <- stats$m + stats$s
  
  ## 3d.  Decision -----------------------------------------------------------
  if (n_visits > threshold) {
    kept_list[[length(kept_list) + 1]] <-
      mutate(dd_dat,
             presented_name = syn_name,
             ObvsDate       = d_obs,
             visit_count    = n_visits,
             mean_lookback  = stats$m,
             sd_lookback    = stats$s)
    
  } else {
    logs_df <- logs_df |>
      mutate(AlertLevel = ifelse(presented_name == syn_name &
                                   ObvsDate == d_obs,
                                 factor("False Positive", levels = log_levels),
                                 AlertLevel))
  }
}

## --- 4.  Persist results ---------------------------------------------------
if (length(kept_list)) {
  reports_df <- bind_rows(kept_list)
  save(reports_df, file = "reportsData.RData")
  message("Saved ", nrow(reports_df), " rows to reportsData.RData")
} else {
  message("No rows exceeded threshold – nothing written to reportsData.RData")
}

# Ensure AlertLevel remains a factor with correct levels before writing
logs_df <- logs_df %>%
  mutate(AlertLevel = factor(as.character(AlertLevel), levels = log_levels))
write_csv(logs_df, LogsFileLoc)
message("autoepi_logs.csv updated (False Positives flagged where applicable).")
