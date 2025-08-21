############################################################
##  AutoEpi – Time-Series Pull + Log Update
##  --------------------------------------------------------
##  1.  Loads saved settings and current log.
##  2.  Determines start-/end-dates for every syndrome.
##  3.  Calls the ESSENCE TimeSeries API for each syndrome.
##  4.  Appends new observations to autoepi_logs.csv.
##  5.  Saves:
##        • InvestigateTSRecords.RData   (rows needing review)
##        • EmailStarterInfo.RData      (who/when was queried)
############################################################

## --- 0.  Packages ----------------------------------------------------------
suppressPackageStartupMessages({
  library(httr)
  library(jsonlite)
  library(dplyr)     # + tidyr/stringr via tidyverse if you like
  library(readr)     # write_csv / read_csv convenience
})

## --- 1.  Load settings + current log --------------------------------------
load("AutoEpi_Settings.RData")            # gives autoepi_settings
if (!exists("autoepi_settings"))
  stop("autoepi_settings object not found – run GUI.R first and save settings.")

load("LogsFileLoc.RData")                 # gives LogsFileLoc
if (!exists("LogsFileLoc"))
  stop("LogsFileLoc not found – run LogsCreate.R first.")

log_levels <- c("Normal", "Warning", "Alert", "False Positive")

logs_df <- if (file.exists(LogsFileLoc)) {
  read_csv(LogsFileLoc,
           col_types = cols(
             ObvsDate       = col_date(),
             presented_name = col_character(),
             AlertLevel     = col_factor(levels = log_levels),
             ReportCreated  = col_factor(levels = c("no", "yes")),
             ReportLocation = col_character(),
             EmailSent      = col_factor(levels = c("no", "yes"))
           ))
} else {
  stop("Log CSV missing at ", LogsFileLoc)
}

## --- 2.  Read syndrome list ------------------------------------------------
syn_path <- autoepi_settings$IO$Syndrome_List_Path
if (!file.exists(syn_path))
  stop("Syndrome list not found at ", syn_path)

syndromes <- read_csv(syn_path, col_types = cols()) |>
  select(presented_name, Syndrome_Snippet) |>
  distinct() |>
  mutate(across(everything(), ~trimws(.)))

if (nrow(syndromes) == 0)
  stop("Syndrome list is empty – nothing to do.")

## --- 3.  Helpers -----------------------------------------------------------
api_base <- "https://essence.syndromicsurveillance.org/nssp_essence/api/timeSeries"

fmt_api_date <- function(x) format(as.Date(x), "%d%b%Y")   # 16May2025

build_url <- function(ccdd, start_str, end_str) {
  paste0(
    api_base,
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

## --- 4.  Loop through syndromes -------------------------------------------
ts_list   <- list()
email_log <- list()
today_str <- fmt_api_date(Sys.Date())

for (i in seq_len(nrow(syndromes))) {
  s_name <- syndromes$presented_name[i]
  s_ccdd <- syndromes$Syndrome_Snippet[i]
  
  ## 4a.  Pick sensible start-date
  last_sig_df <- logs_df |>
    filter(presented_name == s_name,
           AlertLevel %in% c("Warning", "Alert", "False Positive"))
  
  last_sig <- if (nrow(last_sig_df) > 0) {
    last_sig_df |>
      summarise(lat = max(ObvsDate, na.rm = TRUE)) |>
      pull(lat)
  } else {
    NA
  }
  
  start_date <- if (is.finite(last_sig) && !is.na(last_sig)) last_sig
  else as.Date(autoepi_settings$Dates$StartDate_Display)
  
  start_str  <- fmt_api_date(start_date)
  
  ## 4b.  API call
  url <- build_url(s_ccdd, start_str, today_str)
  resp <- GET(url,
              authenticate(autoepi_settings$Credentials$ESSENCE_Username,
                           autoepi_settings$Credentials$ESSENCE_Password))
  
  if (http_error(resp)) {
    warning("ESSENCE query failed for ", s_name,
            " (HTTP ", status_code(resp), "). Skipping.")
    next
  }
  
  ts_json <- content(resp, as = "text", encoding = "UTF-8")
  ts_data <- fromJSON(ts_json, simplifyDataFrame = TRUE)$timeSeriesData
  
  if (is.null(ts_data) || nrow(ts_data) == 0) next
  
  ## 4c.  Normalise and stash
  # Debug: check if colorID exists and what values it has
  if (!"colorID" %in% names(ts_data)) {
    warning("colorID column not found in API response for ", s_name)
    # If colorID doesn't exist, create a default based on count vs expected
    ts_data$colorID <- ifelse(ts_data$count > ts_data$expected * 1.5, 2, 1)
  }
  
  # Debug: print colorID values to understand what we're working with
  message("Debug - ", s_name, ": colorID values = ", paste(ts_data$colorID, collapse=", "))
  message("Debug - ", s_name, ": colorID class = ", class(ts_data$colorID))
  
  ts_df <- ts_data |>
    transmute(
      ObvsDate       = as.Date(date),
      presented_name = s_name,
      AlertLevel     = factor(case_when(
        as.numeric(colorID) >= 3 ~ "Alert",
        as.numeric(colorID) == 2 ~ "Warning",
        as.numeric(colorID) <= 1 ~ "Normal",
        TRUE                     ~ "Normal"
      ), levels = log_levels),
      count,
      expected,
      Syndrome_Snippet = s_ccdd
    )
  
  # Debug: print AlertLevel values to see if they're being assigned correctly
  message("Debug - ", s_name, ": AlertLevel values = ", paste(ts_df$AlertLevel, collapse=", "))
  message("Debug - ", s_name, ": AlertLevel class = ", class(ts_df$AlertLevel))
  
  ts_list[[length(ts_list) + 1]] <- ts_df
  email_log[[length(email_log) + 1]] <-
    tibble(presented_name = s_name,
           Syndrome_Snippet = s_ccdd,
           StartDate = start_date,
           EndDate   = Sys.Date())
}

## --- 5.  Collapse results --------------------------------------------------
if (length(ts_list) == 0)
  stop("No time-series returned for any syndrome – nothing written.")

ts_all   <- bind_rows(ts_list)
email_df <- bind_rows(email_log)

## --- 6.  Update log CSV ----------------------------------------------------
new_entries <- ts_all |>
  anti_join(logs_df, by = c("ObvsDate", "presented_name")) |>
  mutate(ReportCreated  = factor("no", levels = c("no", "yes")),
         ReportLocation = "",
         EmailSent      = factor("no", levels = c("no", "yes"))) |>
  select(names(logs_df))

# Debug: check new entries before writing
if (nrow(new_entries) > 0) {
  message("Debug - New entries AlertLevel values: ", paste(new_entries$AlertLevel, collapse=", "))
  message("Debug - New entries AlertLevel class: ", class(new_entries$AlertLevel))
  message("Debug - New entries AlertLevel levels: ", paste(levels(new_entries$AlertLevel), collapse=", "))
  message("Debug - New entries count: ", nrow(new_entries))
}

logs_df <- bind_rows(logs_df, new_entries) |>
  arrange(ObvsDate, presented_name)

write_csv(logs_df, LogsFileLoc)

## --- 7.  Save investigation + email artefacts ------------------------------
investigate_df <- ts_all |>
  filter(AlertLevel %in% c("Warning", "Alert"))

save(investigate_df, file = "InvestigateTSRecords.RData")
save(email_df,       file = "EmailStarterInfo.RData")

cat("Finished – log updated,",
    nrow(investigate_df), "records flagged,",
    nrow(email_df), "API pulls recorded.\n")
