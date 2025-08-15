############################################################
##  AutoEpi – Report Creator (Enhanced Demographics & Mapping)
##  --------------------------------------------------------
##  Based on Count10k_Graphs.R with additional features:
##  - Age+Gender stacked bars
##  - Race/Ethnicity graphs  
##  - Zipcode-based Leaflet mapping
##  - Enhanced demographic analysis
############################################################
##  OUTPUT: <Reports_Dir>/AutoEpi_Report_<YYYY-MM-DD>.RData
##          object: autoepi_report[date][syndrome][section][plot/map]
############################################################

suppressPackageStartupMessages({
  library(httr);    library(jsonlite); library(dplyr);   library(readr)
  library(purrr);   library(plotly);   library(glue);    library(leaflet)
  library(tidyr);   library(stringr)
})

# ------------------------------------------------------------------
# 1.  Load settings & data
# ------------------------------------------------------------------
load("AutoEpi_Settings.RData")   # autoepi_settings
load("reportsData.RData")        # reports_df
stopifnot(nrow(reports_df) > 0)

rep_set <- autoepi_settings$Report_Settings
usr     <- autoepi_settings$Credentials$ESSENCE_Username
pwd     <- autoepi_settings$Credentials$ESSENCE_Password

reports_dir <- normalizePath(
  autoepi_settings$IO$Reports_Dir, winslash = "/", mustWork = FALSE)
if (!dir.exists(reports_dir))
  dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------
# 2.  Helpers
# ------------------------------------------------------------------
fmt_api <- function(x) format(as.Date(x), "%d%b%Y")
clean_hosp <- function(x) sub("^.*?_", "", x)         # remove prefix_

dedupe <- function(df) distinct(df, .data$C_BioSense_ID, .keep_all = TRUE)

# All visits URL for denominator calculation
all_url <- function(d) glue(
  "https://essence.syndromicsurveillance.org/nssp_essence/api/dataDetails",
  "?datasource=va_er&startDate={fmt_api(d)}&endDate={fmt_api(d)}",
  "&medicalGroupingSystem=essencesyndromes&userId=5629",
  "&percentParam=noPercent&aqtTarget=DataDetails",
  "&geographySystem=region&detector=probrepswitch",
  "&timeResolution=daily&refValues=true")

ess_txt <- function(u)
  httr::content(httr::GET(u, authenticate(usr, pwd)),
                as = "text", encoding = "UTF-8")

# --- External data helpers --------------------------------------------------
# Mapping of station IDs to human-readable names
CLIMATE_STATIONS <- c(
  "pdt-eln" = "Ellensburg, Washington",
  "otx-lws" = "Lewiston, Idaho",
  "pdt-dls" = "Dallesport, Washington",
  "pdt-psc" = "Pasco, Washington",
  "sew-sew" = "Seattle, Washington",
  "otx-geg" = "Spokane, Washington",
  "pqr-vuo" = "Vancouver, Washington",
  "pdt-alw" = "Walla Walla, Washington",
  "otx-eat" = "Wenatchee, Washington",
  "pdt-ykm" = "Yakima, Washington",
  "sew-olm" = "Olympia, Washington",
  "otx-omk" = "Omak, Washington",
  "sew-bli" = "Bellingham, Washington",
  "otx-dew" = "Deer Park, Washington"
)

fetch_climate_data <- function(date, station_ids) {
  if (length(station_ids) == 0) return(NULL)
  factors <- c("maxtemp", "mintemp", "avgtemp", "precip", "snow")
  names_map <- c(maxtemp = "MaxTemp", mintemp = "MinTemp",
                 avgtemp = "AvgTemp", precip = "Water", snow = "Snow")
  station_param <- paste0("&stationID=", station_ids, collapse = "")

  data_list <- lapply(factors, function(fct) {
    url <- glue(
      "https://essence.syndromicsurveillance.org/nssp_essence/api/dataDetails",
      "?percentParam=noPercent&endDate={fmt_api(date)}&userId=5629",
      "&weatherFactor={fct}&datasource=va_weather_aggr&stationAggregateFunc=max",
      "&timeResolution=daily&aqtTarget=DataDetails&detector=probrepswitch",
      "&timeAggregateFunc=max&startDate={fmt_api(date)}&refValues=true{station_param}"
    )
    js <- fromJSON(ess_txt(url), flatten = TRUE)$dataDetails
    if (is.null(js)) return(tibble())
    tibble(Station = js$stationID, value = js$value) %>%
      mutate(variable = names_map[[fct]])
  })

  df <- bind_rows(data_list) %>%
    tidyr::pivot_wider(names_from = variable, values_from = value) %>%
    mutate(Station = CLIMATE_STATIONS[Station])

  df
}

fetch_air_quality_data <- function(date, county) {
  if (!nzchar(county)) return(NULL)
  county_param <- paste0(tolower(county), ",%20wa")
  url <- glue(
    "https://essence.syndromicsurveillance.org/nssp_essence/api/dataDetails",
    "?percentParam=noPercent&endDate={fmt_api(date)}&airQualityParameterName=pm2.5-24hr",
    "&County={county_param}&userId=5629&datasource=airquality",
    "&stationAggregateFunc=max&timeResolution=daily&aqtTarget=DataDetails",
    "&detector=probrepswitch&timeAggregateFunc=max&startDate={fmt_api(date)}&refValues=true"
  )
  js <- fromJSON(ess_txt(url), flatten = TRUE)$dataDetails
  if (is.null(js)) return(NULL)
  tibble(Date = as.character(date), Value = js$value)
}

# --- Age bins (from settings) -----------------------------------------------
age_binner <- (function() {
  s <- rep_set$Age_Group_Stratification
  if (s$type == "named") {
    cuts <- c(0,6,19,26,35,55,65,Inf); labs <- s$groups
  } else if (s$type == "decade") {
    cuts <- seq(0,120,10); labs <- glue("{head(cuts,-1)}-{head(cuts,-1)+9}")
  } else {
    cuts <- c(s$cuts, s$final_upper+1, Inf)
    labs <- glue("{head(cuts,-1)}-{tail(cuts,-1)-1}")
  }
  force(cuts); force(labs)
  function(x) {
    x_num <- suppressWarnings(as.numeric(x))
    cut(x_num, breaks = cuts, labels = labs,
        right = FALSE, ordered_result = TRUE)
  }
})()

# --- Load zipcode geojson for mapping ---------------------------------------
zip_geo_path <- file.path("ZipLayer", "wa_washington_zip_codes_geo.min.json")
if (!file.exists(zip_geo_path)) {
  cat("WARNING: Zipcode geojson not found at ", zip_geo_path, ". Choropleth maps will be skipped.\n")
  zip_geo <- NULL
} else {
  tryCatch({
    zip_geo <- jsonlite::fromJSON(zip_geo_path)
    cat("SUCCESS: Loaded zipcode geojson data for choropleth maps\n")
  }, error = function(e) {
    cat("ERROR: Failed to load zipcode geojson:", conditionMessage(e), "\n")
    cat("Choropleth maps will be skipped.\n")
    zip_geo <<- NULL
  })
}

# ------------------------------------------------------------------
# 3.  Compute denominators (enhanced demographics)
# ------------------------------------------------------------------
cat("Computing denominators for each report date...\n")

all_visits <- map_dfr(unique(reports_df$ObvsDate), function(d) {
  cat("Pulling all visits for", as.character(d), "...\n")
  js <- fromJSON(ess_txt(all_url(d)), flatten = TRUE)$dataDetails
  if (is.null(js) || nrow(js) == 0) return(tibble())
  
  # Enhanced field mapping per requirements
  js %>% 
    dedupe() %>% 
    mutate(
      ObvsDate = d,
      age_grp  = age_binner(Age),
      Sex      = Sex,
      Hospital = clean_hosp(HospitalName),
      Zipcode  = as.character(ZipCode),      # Ensure character for mapping
      Race     = c_race,
      Ethnicity = c_ethnicity
    ) %>%
    select(ObvsDate, age_grp, Sex, Hospital, Zipcode, Race, Ethnicity) %>%
    pivot_longer(cols = c(age_grp, Sex, Hospital, Zipcode, Race, Ethnicity),
                 names_to = "demo", values_to = "level") %>%
    count(ObvsDate, demo, level, name = "denom") %>%
    filter(!is.na(level), level != "", level != "Unknown")  # Clean up missing values
})

# ------------------------------------------------------------------
# 4.  Prepare report data (enhanced demographics)
# ------------------------------------------------------------------
reports_df <- reports_df %>%
  mutate(
    HospitalClean = clean_hosp(HospitalName),
    age_grp = age_binner(Age),
    Zipcode = as.character(ZipCode),
    Race = c_race,
    Ethnicity = c_ethnicity
  )

# ------------------------------------------------------------------
# 5.  Build comprehensive report structure Date → Syndrome
# ------------------------------------------------------------------
cat("Building reports and visualizations...\n")

reports <- list()

store <- function(dk, sk, sect, nm, obj) {
  reports[[dk]][[sk]][[sect]][[nm]] <<- obj
}

for (d in sort(unique(reports_df$ObvsDate))) {
  dk   <- as.character(d)
  reports[[dk]] <- list(meta = list())
  rep_d  <- filter(reports_df, ObvsDate == d)
  denom_d <- filter(all_visits, ObvsDate == d)
  
  for (syn in sort(unique(rep_d$presented_name))) {
    sk    <- syn
    rep_s <- filter(rep_d, presented_name == syn)
    reports[[dk]][[sk]] <- list(count = list(), per10k = list(), maps = list())
    
    cat("Processing", syn, "for", dk, "(", nrow(rep_s), "records)\n")
    
    # ---------- COUNT GRAPHS ----------
    if (rep_set$Age_Group_Bar) {
      p <- plot_ly(rep_s, x = ~age_grp, type = "histogram") %>%
        layout(title = glue("Age Group Distribution - {syn} ({d})"),
               xaxis = list(title = "Age Group"),
               yaxis = list(title = "Count"))
      store(dk, sk, "count", "age", p)
    }
    
    if (rep_set$Age_Gender_Stacked_Bar) {
      age_sex_data <- rep_s %>%
        count(age_grp, Sex, .drop = FALSE) %>%
        filter(!is.na(age_grp), !is.na(Sex))
      
      p <- plot_ly(age_sex_data, x = ~age_grp, y = ~n, color = ~Sex, 
                   type = "bar") %>%
        layout(title = glue("Age Group + Gender - {syn} ({d})"),
               xaxis = list(title = "Age Group"),
               yaxis = list(title = "Count"),
               barmode = "stack")
      store(dk, sk, "count", "age_gender", p)
    }
    
    if (rep_set$Sex_Only_Graph) {
      p <- plot_ly(rep_s, x = ~Sex, type = "histogram") %>%
        layout(title = glue("Sex Distribution - {syn} ({d})"),
               xaxis = list(title = "Sex"),
               yaxis = list(title = "Count"))
      store(dk, sk, "count", "sex", p)
    }
    
    if (rep_set$Race_Ethnicity_Graph) {
      # Race graph
      race_data <- rep_s %>%
        filter(!is.na(Race), Race != "", Race != "Unknown") %>%
        count(Race, sort = TRUE)
      
      if (nrow(race_data) > 0) {
        p <- plot_ly(race_data, x = ~reorder(Race, n), y = ~n, type = "bar") %>%
          layout(title = glue("Race Distribution - {syn} ({d})"),
                 xaxis = list(title = "Race"),
                 yaxis = list(title = "Count"))
        store(dk, sk, "count", "race", p)
      }
      
      # Ethnicity graph
      eth_data <- rep_s %>%
        filter(!is.na(Ethnicity), Ethnicity != "", Ethnicity != "Unknown") %>%
        count(Ethnicity, sort = TRUE)
      
      if (nrow(eth_data) > 0) {
        p <- plot_ly(eth_data, x = ~reorder(Ethnicity, n), y = ~n, type = "bar") %>%
          layout(title = glue("Ethnicity Distribution - {syn} ({d})"),
                 xaxis = list(title = "Ethnicity"),
                 yaxis = list(title = "Count"))
        store(dk, sk, "count", "ethnicity", p)
      }
    }
    
    if (rep_set$Hospital_Bar_Graph) {
      p <- plot_ly(rep_s, x = ~HospitalClean, type = "histogram") %>%
        layout(title = glue("Hospital Distribution - {syn} ({d})"),
               xaxis = list(title = "Hospital"),
               yaxis = list(title = "Count"))
      store(dk, sk, "count", "hospital", p)
    }
    
    # ---------- PER-10K GRAPHS ----------
    if (rep_set$Age_Per_10k_Graph) {
      num <- rep_s %>% count(age_grp, name = "num", .drop = FALSE)
      den <- filter(denom_d, demo == "age_grp") %>% select(level, denom)
      df  <- left_join(num, den, by = c("age_grp" = "level")) %>%
        mutate(rate = round(num/pmax(denom, 1)*1e4, 1))  # Avoid division by zero
      
      p <- plot_ly(df, x = ~age_grp, y = ~rate, type = "bar") %>%
        layout(title = glue("Age Group per 10k - {syn} ({d})"),
               xaxis = list(title = "Age Group"),
               yaxis = list(title = "Rate per 10k"))
      store(dk, sk, "per10k", "age", p)
    }
    
    if (rep_set$Sex_Per_10k_Graph) {
      num <- rep_s %>% count(Sex, name = "num", .drop = FALSE)
      den <- filter(denom_d, demo == "Sex") %>% select(level, denom)
      df  <- left_join(num, den, by = c("Sex" = "level")) %>%
        mutate(rate = round(num/pmax(denom, 1)*1e4, 1))
      
      p <- plot_ly(df, x = ~Sex, y = ~rate, type = "bar") %>%
        layout(title = glue("Sex per 10k - {syn} ({d})"),
               xaxis = list(title = "Sex"),
               yaxis = list(title = "Rate per 10k"))
      store(dk, sk, "per10k", "sex", p)
    }
    
    if (rep_set$Hospital_Per_10k_Graph) {
      num <- rep_s %>% count(HospitalClean, name = "num", .drop = FALSE)
      den <- filter(denom_d, demo == "Hospital") %>% select(level, denom)
      df  <- left_join(num, den, by = c("HospitalClean" = "level")) %>%
        mutate(rate = round(num/pmax(denom, 1)*1e4, 1))
      
      p <- plot_ly(df, x = ~HospitalClean, y = ~rate, type = "bar") %>%
        layout(title = glue("Hospital per 10k - {syn} ({d})"),
               xaxis = list(title = "Hospital"),
               yaxis = list(title = "Rate per 10k"))
      store(dk, sk, "per10k", "hospital", p)
    }
    
    # ---------- CHOROPLETH MAP ----------
    if (rep_set$Choropleth_Map && !is.null(zip_geo)) {
      # Aggregate by zipcode
      zip_data <- rep_s %>%
        filter(!is.na(Zipcode), Zipcode != "", Zipcode != "00000") %>%
        count(Zipcode, name = "count")
      
      # Get denominators for rate calculation
      zip_denom <- filter(denom_d, demo == "Zipcode") %>%
        select(level, denom) %>%
        rename(Zipcode = level)
      
      # Combine and calculate rates
      zip_summary <- left_join(zip_data, zip_denom, by = "Zipcode") %>%
        mutate(
          rate_per_10k = round(count/pmax(denom, 1)*1e4, 1),
          popup_text = glue("Zipcode: {Zipcode}<br/>",
                           "Syndrome: {syn}<br/>",
                           "Date: {d}<br/>",
                           "Count: {count}<br/>",
                           "Rate per 10k: {rate_per_10k}")
        )
      
      if (nrow(zip_summary) > 0) {
        # Create color palette (purples with 0.7 opacity)
        pal <- colorNumeric(
          palette = c("#f2f0f7", "#cbc9e2", "#9e9ac8", "#756bb1", "#54278f"),
          domain = zip_summary$count,
          na.color = "transparent"
        )
        
        # Create Leaflet map
        m <- leaflet() %>%
          addTiles() %>%
          addPolygons(
            data = zip_geo,
            fillColor = ~pal(zip_summary$count[match(zip_geo$features$properties$ZCTA5CE10, 
                                                    zip_summary$Zipcode)]),
            fillOpacity = 0.7,
            color = "white",
            weight = 1,
            popup = ~zip_summary$popup_text[match(zip_geo$features$properties$ZCTA5CE10, 
                                                 zip_summary$Zipcode)]
          ) %>%
          addLegend(
            pal = pal,
            values = zip_summary$count,
            title = glue("{syn}<br/>{d}<br/>Count"),
            position = "bottomright"
          )
        
        store(dk, sk, "maps", "choropleth", m)
      }
    }
  }

  if (rep_set$Climate$Include) {
    reports[[dk]]$meta$climate <- fetch_climate_data(d, rep_set$Climate$Station_IDs)
  }
  if (rep_set$Air_Quality$enabled) {
    reports[[dk]]$meta$air_quality <- fetch_air_quality_data(d, rep_set$Air_Quality$county)
  }
}

# ------------------------------------------------------------------
# 6.  Save comprehensive report
# ------------------------------------------------------------------
autoepi_report <- reports
out_file <- file.path(
  reports_dir,
  glue("AutoEpi_Report_{format(Sys.Date(), '%Y-%m-%d')}.RData")
)
save(autoepi_report, file = out_file)

# ------------------------------------------------------------------
# 7.  Update autoepi_logs.csv with report completion status
# ------------------------------------------------------------------
cat("Updating logs with report completion status...\n")

# Load log file location and current logs
if (file.exists("LogsFileLoc.RData")) {
  load("LogsFileLoc.RData")  # -> LogsFileLoc
  
  if (file.exists(LogsFileLoc)) {
    # Read current logs
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
    
    # Create a lookup of syndrome+date combinations that had reports generated
    report_combinations <- expand_grid(
      ObvsDate = unique(reports_df$ObvsDate),
      presented_name = unique(reports_df$presented_name)
    )
    
    # Update logs for syndrome+date combinations that had reports created
    logs_df <- logs_df %>%
      mutate(
        ReportCreated = case_when(
          paste(ObvsDate, presented_name) %in% 
            paste(report_combinations$ObvsDate, report_combinations$presented_name) ~ 
            factor("yes", levels = c("no", "yes")),
          TRUE ~ ReportCreated
        ),
        ReportLocation = case_when(
          paste(ObvsDate, presented_name) %in% 
            paste(report_combinations$ObvsDate, report_combinations$presented_name) ~ 
            out_file,
          TRUE ~ ReportLocation
        )
      )
    
    # Write updated logs back to CSV
    write_csv(logs_df, LogsFileLoc)
    
    # Count how many records were updated
    updated_count <- logs_df %>%
      filter(paste(ObvsDate, presented_name) %in% 
               paste(report_combinations$ObvsDate, report_combinations$presented_name)) %>%
      nrow()
    
    cat("Updated", updated_count, "log entries with report completion status\n")
    
  } else {
    warning("Log file not found at ", LogsFileLoc)
  }
} else {
  warning("LogsFileLoc.RData not found - logs not updated")
}

cat("\n=== AutoEpi Report Creator Complete ===\n")
cat("Report saved to:", out_file, "\n")
cat("Structure: autoepi_report[date][syndrome][section][plot/map]\n")
cat("Sections: count, per10k, maps\n")
cat("Dates processed:", length(unique(reports_df$ObvsDate)), "\n")
cat("Syndromes processed:", length(unique(reports_df$presented_name)), "\n")
cat("Total visualizations created:", 
    sum(sapply(reports, function(d) sapply(d, function(s) length(unlist(s, recursive = FALSE))))), "\n")
