############################################################
##  AutoEpi – Report Creator (Enhanced Demographics & Mapping)
##  --------------------------------------------------------
##  - Age+Gender stacked bars
##  - Race/Ethnicity graphs
##  - Zipcode-based Leaflet mapping (sf + geojsonsf, ZIP→ZCTA aware)
##  - Climate (Max/Min/Avg Temp, Water, Snow) tables + stats (NO plot)
##  - AQI meta (PM2.5 24h) with table (+ optional small plot)
############################################################
##  OUTPUT: <Reports_Dir>/AutoEpi_Report_<YYYY-MM-DD>.RData
##          object: autoepi_report[date][syndrome][section][plot/map]
############################################################

suppressPackageStartupMessages({
  library(httr);      library(jsonlite);   library(dplyr);    library(readr)
  library(purrr);     library(plotly);     library(glue);     library(leaflet)
  library(tidyr);     library(stringr);    library(sf);       library(geojsonsf)
})

# ------------------------------------------------------------------
# 1) Load settings & data
# ------------------------------------------------------------------
load("AutoEpi_Settings.RData")   # -> autoepi_settings
load("reportsData.RData")        # -> reports_df
stopifnot(nrow(reports_df) > 0)

rep_set <- autoepi_settings$Report_Settings
usr     <- autoepi_settings$Credentials$ESSENCE_Username
pwd     <- autoepi_settings$Credentials$ESSENCE_Password

reports_dir <- normalizePath(autoepi_settings$IO$Reports_Dir, winslash = "/", mustWork = FALSE)
if (!dir.exists(reports_dir)) dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)

# ------------------------------------------------------------------
# 2) Helpers
# ------------------------------------------------------------------
fmt_api    <- function(x) format(as.Date(x), "%d%b%Y")               # for ESSENCE API
pad_zip    <- function(z) stringr::str_pad(as.character(z), 5, pad = "0")
clean_hosp <- function(x) sub("^.*?_", "", x)
dedupe     <- function(df) dplyr::distinct(df, .data$C_BioSense_ID, .keep_all = TRUE)
`%||%`     <- function(a, b) if (!is.null(a)) a else b

# Pretty date labels for titles/popups (MM-DD-YYYY)
mk_date_label <- function(d, rep_s = NULL) {
  if (inherits(d, "Date")) return(format(d, "%m-%d-%Y"))
  if (!is.null(rep_s) && "ObvsDate" %in% names(rep_s) && inherits(rep_s$ObvsDate, "Date"))
    return(format(rep_s$ObvsDate[1], "%m-%d-%Y"))
  ds <- as.character(d)
  if (grepl("^\\d{4}-\\d{2}-\\d{2}$", ds)) return(format(as.Date(ds), "%m-%d-%Y"))
  if (grepl("^\\d{8}$", ds)) return(format(as.Date(ds, "%Y%m%d"), "%m-%d-%Y"))
  ds
}

# tolerant numeric
safe_num <- function(x) {
  if (is.character(x)) {
    y <- ifelse(tolower(x) %in% c("none","na",""), NA, x)
    suppressWarnings(as.numeric(y))
  } else {
    suppressWarnings(as.numeric(x))
  }
}

# Denominator API (all visits)
all_url <- function(d) glue(
  "https://essence.syndromicsurveillance.org/nssp_essence/api/dataDetails",
  "?datasource=va_er&startDate={fmt_api(d)}&endDate={fmt_api(d)}",
  "&medicalGroupingSystem=essencesyndromes&userId=5629",
  "&percentParam=noPercent&aqtTarget=DataDetails",
  "&geographySystem=region&detector=probrepswitch",
  "&timeResolution=daily&refValues=true"
)
ess_txt <- function(u) httr::content(httr::GET(u, authenticate(usr, pwd)), as = "text", encoding = "UTF-8")

# External data helpers (optional pretty names; not required for matching)
CLIMATE_STATIONS <- c(
  "pdt-eln"="Ellensburg, Washington","otx-lws"="Lewiston, Idaho",
  "pdt-dls"="Dallesport, Washington","pdt-psc"="Pasco, Washington",
  "sew-sew"="Seattle, Washington","otx-geg"="Spokane, Washington",
  "pqr-vuo"="Vancouver, Washington","pdt-alw"="Walla Walla, Washington",
  "otx-eat"="Wenatchee, Washington","pdt-ykm"="Yakima, Washington",
  "sew-olm"="Olympia, Washington","otx-omk"="Omak, Washington",
  "sew-bli"="Bellingham, Washington","otx-dew"="Deer Park, Washington"
)

# -------- Climate fetcher (single call; schema proven by smoke test) ----------
# Weather table already includes MaxTemp/MinTemp/AvgTemp/Water/Snow columns.
fetch_climate_data <- function(date, station_ids, verbose = FALSE) {
  if (length(station_ids) == 0) return(NULL)
  st_param <- paste0("&stationID=", station_ids, collapse = "")
  url <- glue(
    "https://essence.syndromicsurveillance.org/nssp_essence/api/dataDetails",
    "?percentParam=noPercent&endDate={fmt_api(date)}&userId=5629",
    "&weatherFactor=avgtemp&datasource=va_weather_aggr&stationAggregateFunc=max",
    "&timeResolution=daily&aqtTarget=DataDetails&detector=probrepswitch",
    "&timeAggregateFunc=max&startDate={fmt_api(date)}&refValues=true{st_param}"
  )
  txt <- ess_txt(url)
  js  <- tryCatch(fromJSON(txt, flatten = TRUE), error = function(e) NULL)
  if (is.null(js) || is.null(js$dataDetails) || nrow(js$dataDetails) == 0) return(NULL)
  
  dd <- js$dataDetails
  out <- dd %>%
    transmute(
      StationRaw = as.character(.data[["Location"]] %||% NA_character_),
      Station    = tolower(StationRaw),
      DateStr    = .data[["Date"]] %||% NA_character_,
      MaxTemp    = safe_num(.data[["MaxTemp"]]),
      MinTemp    = safe_num(.data[["MinTemp"]]),
      AvgTemp    = safe_num(.data[["AvgTemp"]]),
      Water      = safe_num(.data[["Water"]]),
      Snow       = safe_num(.data[["Snow"]])
    ) %>%
    filter(Station %in% tolower(station_ids)) %>%
    arrange(Station)
  
  if (!nrow(out)) return(NULL)
  
  list(
    wide = out,
    long = out %>% pivot_longer(cols = c(MaxTemp, MinTemp, AvgTemp, Water, Snow),
                                names_to = "Metric", values_to = "Value")
  )
}

# -------- AQI (PM2.5 24-hr) fetcher + EPA category (schema proven) -----------
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
  txt <- ess_txt(url)
  js  <- tryCatch(fromJSON(txt, flatten = TRUE), error = function(e) NULL)
  if (is.null(js) || is.null(js$dataDetails) || nrow(js$dataDetails) == 0) return(NULL)
  
  dd <- js$dataDetails
  val_col <- if ("Value" %in% names(dd)) "Value" else
    if ("value" %in% names(dd)) "value" else
      if ("valueDouble" %in% names(dd)) "valueDouble" else
        if ("dataValue" %in% names(dd)) "dataValue" else NA_character_
  if (is.na(val_col)) return(NULL)
  
  n <- nrow(dd)
  AQSID_vec   <- if ("AQSID" %in% names(dd)) as.character(dd$AQSID) else rep(NA_character_, n)
  Station_vec <- if ("Station" %in% names(dd)) as.character(dd$Station)
  else if ("SiteName" %in% names(dd)) as.character(dd$SiteName)
  else rep(NA_character_, n)
  
  stations_tbl <- tibble(
    Date       = as.Date(date),
    County     = stringr::str_to_title(county),
    AQSID      = AQSID_vec,
    Station    = Station_vec,
    PM25_24hr  = safe_num(dd[[val_col]])
  ) %>%
    mutate(
      Category = dplyr::case_when(
        is.na(PM25_24hr)   ~ NA_character_,
        PM25_24hr <= 12.0  ~ "Good",
        PM25_24hr <= 35.4  ~ "Moderate",
        PM25_24hr <= 55.4  ~ "Unhealthy for Sensitive Groups",
        PM25_24hr <= 150.4 ~ "Unhealthy",
        PM25_24hr <= 250.4 ~ "Very Unhealthy",
        TRUE               ~ "Hazardous"
      )
    )
  
  county_agg <- stations_tbl %>%
    summarize(
      Date       = first(Date),
      County     = first(County),
      mean_PM25  = round(mean(PM25_24hr, na.rm = TRUE), 2),
      max_PM25   = round(max(PM25_24hr, na.rm = TRUE), 2),
      cat_at_max = (stations_tbl %>% filter(PM25_24hr == max(PM25_24hr, na.rm = TRUE)) %>% slice(1) %>% pull(Category))
    )
  
  list(stations = stations_tbl, county_agg = county_agg)
}

# -------- Age bins (from settings) -------------------------------------------
age_binner <- (function() {
  s <- rep_set$Age_Group_Stratification
  if (s$type == "named") {
    cuts <- c(0,6,19,26,35,55,65,Inf); labs <- s$groups
  } else if (s$type == "decade") {
    cuts <- seq(0,120,10); labs <- glue("{head(cuts,-1)}-{head(cuts,-1)+9}")
  } else {
    cuts <- c(s$cuts, s$final_upper + 1, Inf)
    labs <- glue("{head(cuts,-1)}-{tail(cuts,-1)-1}")
  }
  force(cuts); force(labs)
  function(x) {
    x_num <- suppressWarnings(as.numeric(x))
    cut(x_num, breaks = cuts, labels = labs, right = FALSE, ordered_result = TRUE)
  }
})()

# ------------------------------------------------------------------
# 3) Load zipcode GeoJSON AS SF (not list)
# ------------------------------------------------------------------
zip_geo_path <- file.path("ZipLayer", "wa_washington_zip_codes_geo.min.json")
zip_sf <- NULL
if (!file.exists(zip_geo_path)) {
  cat("WARNING: Zipcode geojson not found at", zip_geo_path, "- maps will be skipped.\n")
} else {
  zip_sf <- tryCatch(sf::st_read(zip_geo_path, quiet = TRUE), error = function(e) NULL)
  if (is.null(zip_sf)) {
    zip_sf <- tryCatch(geojsonsf::geojson_sf(readr::read_file(zip_geo_path)), error = function(e) NULL)
  }
  if (inherits(zip_sf, "sf")) {
    zip_col <- intersect(names(zip_sf), c("ZCTA5CE10","GEOID10","ZCTA5","ZIP","ZIPCODE","ZIP_CODE","GEOID"))
    if (length(zip_col) == 0) {
      cat("ERROR: No ZIP column found in geojson; maps will be skipped.\n")
      zip_sf <- NULL
    } else {
      zip_col <- zip_col[1]
      zip_sf <- zip_sf %>%
        mutate(
          Zipcode = pad_zip(.data[[zip_col]]),
          geo_key = Zipcode   # explicit geometry join key
        )
      cat("SUCCESS: Loaded zip geojson as sf (ZIP column:", zip_col, ")\n")
    }
  } else {
    cat("ERROR: Failed to load zipcode geojson as sf; maps will be skipped.\n")
  }
}

# ------------------------------------------------------------------
# 4) Optional ZIP→ZCTA crosswalk (to handle PO Box/Unique ZIPs)
# ------------------------------------------------------------------
zip_xwalk <- NULL
xwalk_path <- autoepi_settings$IO$Zip_to_ZCTA_Crosswalk %||% NA
if (!is.na(xwalk_path) && file.exists(xwalk_path)) {
  x <- readr::read_csv(xwalk_path, col_types = cols(.default = col_character()))
  zip_col_x  <- intersect(names(x), c("zip","ZIP","zipcode","Zip","ZIPCODE"))
  zcta_col_x <- intersect(names(x), c("zcta","ZCTA","ZCTA5","zcta5","ZCTA5CE10"))
  if (length(zip_col_x) && length(zcta_col_x)) {
    zip_xwalk <- x %>%
      transmute(Zip = pad_zip(.data[[zip_col_x[1]]]),
                ZCTA = pad_zip(.data[[zcta_col_x[1]]])) %>%
      filter(!is.na(Zip), !is.na(ZCTA), Zip != "", ZCTA != "") %>%
      distinct(Zip, .keep_all = TRUE)
    cat("ZIP→ZCTA crosswalk loaded with", nrow(zip_xwalk), "rows\n")
  } else {
    cat("WARNING: Crosswalk present but missing expected columns; ignoring.\n")
  }
} else {
  cat("INFO: No ZIP→ZCTA crosswalk configured; PO-Box/Unique ZIPs will be dropped from maps.\n")
}

# ------------------------------------------------------------------
# 5) Compute denominators (enhanced demographics)
# ------------------------------------------------------------------
cat("Computing denominators for each report date...\n")
all_visits <- map_dfr(unique(reports_df$ObvsDate), function(d) {
  cat("Pulling all visits for", as.character(d), "...\n")
  js <- fromJSON(ess_txt(all_url(d)), flatten = TRUE)$dataDetails
  if (is.null(js) || nrow(js) == 0) return(tibble())
  js %>%
    dedupe() %>%
    mutate(
      ObvsDate  = d,
      age_grp   = age_binner(Age),
      Sex       = Sex,
      Hospital  = clean_hosp(HospitalName),
      Zipcode   = as.character(ZipCode),
      Race      = c_race,
      Ethnicity = c_ethnicity
    ) %>%
    select(ObvsDate, age_grp, Sex, Hospital, Zipcode, Race, Ethnicity) %>%
    pivot_longer(cols = c(age_grp, Sex, Hospital, Zipcode, Race, Ethnicity),
                 names_to = "demo", values_to = "level") %>%
    count(ObvsDate, demo, level, name = "denom") %>%
    filter(!is.na(level), level != "", level != "Unknown")
})

# ------------------------------------------------------------------
# 6) Prepare report data (enhanced demographics)
# ------------------------------------------------------------------
reports_df <- reports_df %>%
  mutate(
    HospitalClean = clean_hosp(HospitalName),
    age_grp       = age_binner(Age),
    Zipcode       = as.character(ZipCode),
    Race          = c_race,
    Ethnicity     = c_ethnicity
  )

# ------------------------------------------------------------------
# 7) Build report structure Date → Syndrome (with maps)
# ------------------------------------------------------------------
cat("Building reports and visualizations...\n")

reports <- list()
store <- function(dk, sk, sect, nm, obj) {
  reports[[dk]][[sk]][[sect]][[nm]] <<- obj
}

# helper: bins that separate 0 vs 1 so singles are visible
make_count_bins <- function(vals) {
  vals <- vals[is.finite(vals)]
  if (!length(vals)) return(c(-0.1, 0.5, 1.5, 2.5, 3.5, Inf))
  maxc <- max(vals, na.rm = TRUE)
  if (maxc <= 1)      c(-0.1, 0.5, 1.5, Inf)
  else if (maxc <= 5) c(-0.1, 0.5, 1.5, 2.5, 3.5, Inf)
  else {
    nz <- vals[vals > 1]
    q  <- if (length(nz) >= 3) quantile(nz, probs = c(0.33, 0.66), na.rm = TRUE) else c(2, 3)
    unique(c(-0.1, 0.5, 1.5, q[1], q[2], Inf))
  }
}

for (d in sort(unique(reports_df$ObvsDate))) {
  dk      <- as.character(d)
  reports[[dk]] <- list(meta = list())
  rep_d   <- dplyr::filter(reports_df, ObvsDate == d)
  denom_d <- dplyr::filter(all_visits, ObvsDate == d)
  
  for (syn in sort(unique(rep_d$presented_name))) {
    sk    <- syn
    rep_s <- dplyr::filter(rep_d, presented_name == syn)
    d_lbl <- mk_date_label(d, rep_s)
    
    reports[[dk]][[sk]] <- list(count = list(), per10k = list(), maps = list())
    cat("Processing", syn, "for", dk, "(", nrow(rep_s), "records)\n")
    
    # Age group ordering function
    order_age_groups <- function(age_groups) {
      # Define the correct order for age groups (standard epidemiological age groups)
      age_order <- c("0-5", "6-18", "19-25", "25-34", "35-54", "55-64", "65+", "Unknown")
      # Filter to only include age groups that exist in the data
      existing_ages <- intersect(age_order, age_groups)
      # Add any remaining age groups that weren't in our predefined order
      remaining_ages <- setdiff(age_groups, age_order)
      c(existing_ages, remaining_ages)
    }

# ----- COUNT GRAPHS -----
    if (isTRUE(rep_set$Age_Group_Bar)) {
      # Order age groups properly
      age_levels <- order_age_groups(unique(rep_s$age_grp))
      rep_s_ordered <- rep_s %>% 
        mutate(age_grp = factor(age_grp, levels = age_levels))
      
      p <- plot_ly(rep_s_ordered, x = ~age_grp, type = "histogram") %>%
        layout(title = glue("Age Group Distribution - {syn} ({d_lbl})"),
               xaxis = list(title = "Age Group"), yaxis = list(title = "Count"))
      store(dk, sk, "count", "age", p)
    }
    if (isTRUE(rep_set$Age_Gender_Stacked_Bar)) {
      # Order age groups properly
      age_levels <- order_age_groups(unique(rep_s$age_grp))
      age_sex_data <- rep_s %>% 
        count(age_grp, Sex, .drop = FALSE) %>% 
        filter(!is.na(age_grp), !is.na(Sex)) %>%
        mutate(age_grp = factor(age_grp, levels = age_levels))
      
      p <- plot_ly(age_sex_data, x = ~age_grp, y = ~n, color = ~Sex, type = "bar") %>%
        layout(title = glue("Age Group + Gender - {syn} ({d_lbl})"),
               xaxis = list(title = "Age Group"), yaxis = list(title = "Count"), barmode = "stack")
      store(dk, sk, "count", "age_gender", p)
    }
    if (isTRUE(rep_set$Sex_Only_Graph)) {
      p <- plot_ly(rep_s, x = ~Sex, type = "histogram") %>%
        layout(title = glue("Sex Distribution - {syn} ({d_lbl})"),
               xaxis = list(title = "Sex"), yaxis = list(title = "Count"))
      store(dk, sk, "count", "sex", p)
    }
    if (isTRUE(rep_set$Race_Ethnicity_Graph)) {
      race_data <- rep_s %>% filter(!is.na(Race), Race != "", Race != "Unknown") %>% count(Race, sort = TRUE)
      if (nrow(race_data) > 0) {
        p <- plot_ly(race_data, x = ~reorder(Race, n), y = ~n, type = "bar") %>%
          layout(title = glue("Race Distribution - {syn} ({d_lbl})"),
                 xaxis = list(title = "Race"), yaxis = list(title = "Count"))
        store(dk, sk, "count", "race", p)
      }
      eth_data <- rep_s %>% filter(!is.na(Ethnicity), Ethnicity != "", Ethnicity != "Unknown") %>% count(Ethnicity, sort = TRUE)
      if (nrow(eth_data) > 0) {
        p <- plot_ly(eth_data, x = ~reorder(Ethnicity, n), y = ~n, type = "bar") %>%
          layout(title = glue("Ethnicity Distribution - {syn} ({d_lbl})"),
                 xaxis = list(title = "Ethnicity"), yaxis = list(title = "Count"))
        store(dk, sk, "count", "ethnicity", p)
      }
    }
    
    # ----- PER-10K GRAPHS -----
    if (isTRUE(rep_set$Age_Per_10k_Graph)) {
      num <- rep_s %>% count(age_grp, name = "num", .drop = FALSE)
      den <- dplyr::filter(denom_d, demo == "age_grp") %>% select(level, denom)
      df  <- left_join(num, den, by = c("age_grp" = "level")) %>%
        mutate(rate = round(num / pmax(denom, 1) * 1e4, 1))
      
      # Order age groups properly
      age_levels <- order_age_groups(unique(df$age_grp))
      df_ordered <- df %>% mutate(age_grp = factor(age_grp, levels = age_levels))
      
      p <- plot_ly(df_ordered, x = ~age_grp, y = ~rate, type = "bar") %>%
        layout(title = glue("Age Group per 10k - {syn} ({d_lbl})"),
               xaxis = list(title = "Age Group"), yaxis = list(title = "Rate per 10k"))
      store(dk, sk, "per10k", "age", p)
    }
    if (isTRUE(rep_set$Sex_Per_10k_Graph)) {
      num <- rep_s %>% count(Sex, name = "num", .drop = FALSE)
      den <- dplyr::filter(denom_d, demo == "Sex") %>% select(level, denom)
      df  <- left_join(num, den, by = c("Sex" = "level")) %>%
        mutate(rate = round(num / pmax(denom, 1) * 1e4, 1))
      p <- plot_ly(df, x = ~Sex, y = ~rate, type = "bar") %>%
        layout(title = glue("Sex per 10k - {syn} ({d_lbl})"),
               xaxis = list(title = "Sex"), yaxis = list(title = "Rate per 10k"))
      store(dk, sk, "per10k", "sex", p)
    }
    if (isTRUE(rep_set$Hospital_Per_10k_Graph)) {
      num <- rep_s %>% count(HospitalClean, name = "num", .drop = FALSE)
      den <- dplyr::filter(denom_d, demo == "Hospital") %>% select(level, denom)
      df  <- left_join(num, den, by = c("HospitalClean" = "level")) %>%
        mutate(rate = round(num / pmax(denom, 1) * 1e4, 1))
      p <- plot_ly(df, x = ~HospitalClean, y = ~rate, type = "bar") %>%
        layout(title = glue("Hospital per 10k - {syn} ({d_lbl})"),
               xaxis = list(title = "Hospital"), yaxis = list(title = "Rate per 10k"))
      store(dk, sk, "per10k", "hospital", p)
    }
    
    # ----- CHOROPLETH MAP (ZIP→ZCTA aware; all polygons visible) -----
    if (isTRUE(rep_set$Choropleth_Map) && inherits(zip_sf, "sf")) {
      # Numerators (raw USPS ZIPs)
      zip_data_raw <- rep_s %>%
        filter(!is.na(Zipcode), Zipcode != "", Zipcode != "00000") %>%
        transmute(Zip = pad_zip(Zipcode)) %>%
        count(Zip, name = "num_count")
      
      # Denominators (raw USPS ZIPs)
      zip_denom_raw <- denom_d %>%
        filter(demo == "Zipcode") %>%
        transmute(Zip = pad_zip(level), den_count = as.numeric(denom))
      
      # Map USPS ZIP -> ZCTA when crosswalk is available
      if (!is.null(zip_xwalk)) {
        num_map <- zip_data_raw %>% left_join(zip_xwalk, by = "Zip")
        den_map <- zip_denom_raw %>% left_join(zip_xwalk, by = "Zip")
        
        zip_num <- num_map %>%
          filter(!is.na(ZCTA)) %>%
          transmute(Zipcode = pad_zip(ZCTA), num_count) %>%
          group_by(Zipcode) %>% summarize(num_count = sum(num_count), .groups = "drop")
        
        zip_den <- den_map %>%
          filter(!is.na(ZCTA)) %>%
          transmute(Zipcode = pad_zip(ZCTA), den_count) %>%
          group_by(Zipcode) %>% summarize(den_count = sum(den_count, na.rm = TRUE), .groups = "drop")
        
        dropped_num <- num_map %>% filter(is.na(ZCTA)) %>% distinct(Zip) %>% pull(Zip)
        if (length(dropped_num)) {
          cat("XWALK drop (", syn, " ", d, "): ", length(dropped_num),
              " ZIPs had no ZCTA (e.g. ", paste(head(dropped_num, 5), collapse = ", "),
              "). Counts for these are excluded from map.\n", sep = "")
        }
      } else {
        zip_num <- zip_data_raw %>% rename(Zipcode = Zip)
        zip_den <- zip_denom_raw %>% rename(Zipcode = Zip)
      }
      
      # Combine and compute rates
      zip_summary <- full_join(zip_num, zip_den, by = "Zipcode") %>%
        mutate(
          num_count    = coalesce(as.numeric(num_count), 0),
          den_count    = coalesce(as.numeric(den_count), 0),
          rate_per_10k = if_else(den_count > 0, round(num_count / den_count * 1e4, 1), 0)
        )
      
      # Keep only codes present in geometry (join via explicit geo_key)
      missing_in_geo <- setdiff(zip_summary$Zipcode, zip_sf$geo_key)
      if (length(missing_in_geo)) {
        cat("WARN (", syn, " ", d, "): ", length(missing_in_geo),
            " ZIP/ZCTA(s) not in geometry, e.g.: ",
            paste(head(missing_in_geo, 5), collapse = ", "), "\n", sep = "")
      }
      zip_summary <- semi_join(zip_summary, zip_sf, by = c("Zipcode" = "geo_key"))
      
      if (nrow(zip_summary) > 0) {
        # Avoid name collisions
        zip_summary <- zip_summary %>%
          rename(stat_count = num_count, stat_denom = den_count, stat_rate = rate_per_10k)
        
        # Join stats to geometry
        zip_join <- zip_sf %>%
          left_join(zip_summary, by = c("geo_key" = "Zipcode")) %>%
          mutate(
            count_filled = coalesce(stat_count, 0),
            rate_filled  = coalesce(stat_rate, 0)
          )
        
        vals <- zip_join$count_filled
        bins <- make_count_bins(vals)
        pal  <- colorBin(
          palette  = c("#f2f0f7", "#cbc9e2", "#9e9ac8", "#756bb1", "#54278f"),
          domain   = vals, bins = bins, na.color = "transparent"
        )
        
        zip_join <- zip_join %>%
          mutate(
            fill_opacity = if_else(count_filled > 0, 0.9, 0.15),
            popup_text   = glue(
              "ZCTA/ZIP: {geo_key}<br/>",
              "Syndrome: {syn}<br/>",
              "Date: {d_lbl}<br/>",
              "Count: {count_filled}<br/>",
              "Rate per 10k: {rate_filled}"
            )
          )
        
        m <- leaflet(zip_join) %>%
          addTiles() %>%
          addPolygons(
            weight = 1.2, color = "#ffffff",
            fillColor   = ~pal(count_filled),
            fillOpacity = ~fill_opacity,
            popup       = ~popup_text,
            label       = ~paste0(geo_key, ": ", count_filled),
            highlightOptions = highlightOptions(weight = 2, color = "#000", bringToFront = TRUE)
          ) %>%
          addLegend(
            pal    = pal,
            values = vals,
            title  = glue("{syn}<br/>{d_lbl}<br/>Count"),
            position = "bottomright"
          )
        
        store(dk, sk, "maps", "choropleth", m)
        
        cat("MAP DIAG (", syn, " ", d, "): ",
            "ZCTAs in layer=", nrow(zip_join),
            ", nonzero=", sum(zip_join$count_filled > 0, na.rm = TRUE),
            ", zeros=", sum(zip_join$count_filled == 0, na.rm = TRUE), "\n", sep = "")
      } else {
        cat("INFO (", syn, " ", d, "): no ZIPs/ZCTAs to map after joining.\n", sep = "")
      }
    }
  } # end syndrome loop
  
  # ----- Per-date META: Climate (tables only) & AQI -----
  d_lbl <- mk_date_label(d)
  if (isTRUE(rep_set$Climate$Include)) {
    wx <- tryCatch(
      fetch_climate_data(d, rep_set$Climate$Station_IDs),
      error = function(e) { message("Climate fetch failed: ", conditionMessage(e)); NULL }
    )
    if (!is.null(wx)) {
      reports[[dk]]$meta$climate_table <- wx$wide
      # quick stats row
      num_cols <- intersect(names(wx$wide), c("MaxTemp","MinTemp","AvgTemp","Water","Snow"))
      if (length(num_cols)) {
        reports[[dk]]$meta$climate_stats <- wx$wide %>%
          summarize(across(all_of(num_cols), ~ round(mean(., na.rm = TRUE), 2)), .groups = "drop") %>%
          mutate(Date = d_lbl, .before = 1)
      }
      # NOTE: no climate plot (per your request)
    }
  }
  if (isTRUE(rep_set$Air_Quality$enabled)) {
    aq <- tryCatch(
      fetch_air_quality_data(d, rep_set$Air_Quality$county),
      error = function(e) { message("AQI fetch failed: ", conditionMessage(e)); NULL }
    )
    if (!is.null(aq)) {
      reports[[dk]]$meta$aqi_stations <- aq$stations
      reports[[dk]]$meta$aqi_summary  <- aq$county_agg
      # small per-date AQI plot is kept; delete this block if you want table-only:
      if (nrow(aq$stations)) {
        p_aqi <- plot_ly(aq$stations, x = ~Station, y = ~PM25_24hr, type = "bar") %>%
          layout(title = glue("PM2.5 (24h) — {stringr::str_to_title(rep_set$Air_Quality$county)}, WA ({d_lbl})"),
                 xaxis = list(title = "Station"), yaxis = list(title = "µg/m³ (24h)"))
        reports[[dk]]$meta$aqi_plot <- p_aqi
      }
    }
  }
}

# ------------------------------------------------------------------
# 8) Save comprehensive report (includes meta tables/stats)
# ------------------------------------------------------------------
autoepi_report <- reports
out_file <- file.path(reports_dir, glue("AutoEpi_Report_{format(Sys.Date(), '%Y-%m-%d')}.RData"))
save(autoepi_report, file = out_file)

# ------------------------------------------------------------------
# 9) Update autoepi_logs.csv with report completion status
# ------------------------------------------------------------------
cat("Updating logs with report completion status...\n")
if (file.exists("LogsFileLoc.RData")) {
  load("LogsFileLoc.RData")  # -> LogsFileLoc
  if (file.exists(LogsFileLoc)) {
    log_levels <- c("Normal","Warning","Alert","False Positive")
    logs_df <- read_csv(LogsFileLoc,
                        col_types = cols(
                          ObvsDate       = col_date(),
                          presented_name = col_character(),
                                                     AlertLevel     = col_character(),  # Read as character first
                          ReportCreated  = col_factor(levels = c("no","yes")),
                          ReportLocation = col_character(),
                          EmailSent      = col_factor(levels = c("no","yes"))
                        ))
    # Debug: check what dates are in reports_df
    message("Debug - reports_df ObvsDate values: ", paste(unique(reports_df$ObvsDate), collapse=", "))
    message("Debug - reports_df ObvsDate class: ", class(reports_df$ObvsDate))
    
    report_combinations <- expand_grid(
      ObvsDate = unique(reports_df$ObvsDate),
      presented_name = unique(reports_df$presented_name)
    )
    
    # Debug: check what combinations are being created
    message("Debug - report_combinations:")
    print(report_combinations)
    
    logs_df <- logs_df %>%
      mutate(
        ReportCreated = if_else(
          paste(ObvsDate, presented_name) %in% paste(report_combinations$ObvsDate, report_combinations$presented_name),
          factor("yes", levels = c("no","yes")),
          ReportCreated
        )
      )

    write_csv(logs_df, LogsFileLoc)
    updated_count <- logs_df %>%
      filter(paste(ObvsDate, presented_name) %in% paste(report_combinations$ObvsDate, report_combinations$presented_name)) %>%
      nrow()
    cat("Updated", updated_count, "log entries with report completion status\n")
  } else {
    warning("Log file not found at ", LogsFileLoc)
  }
} else {
  warning("LogsFileLoc.RData not found - logs not updated")
}

# ------------------------------------------------------------------
# 10) Accurate visualization count (only htmlwidgets)
# ------------------------------------------------------------------
count_htmlwidgets <- function(x) {
  if (inherits(x, "htmlwidget")) return(1L)
  if (is.list(x)) return(sum(vapply(x, count_htmlwidgets, integer(1))))
  0L
}
total_viz <- count_htmlwidgets(reports)

cat("\n=== AutoEpi Report Creator Complete ===\n")
cat("Report saved to:", out_file, "\n")
cat("Structure: autoepi_report[date][syndrome][section][plot/map]\n")
cat("Sections: count, per10k, maps, and date-level meta (climate tables/stats; aqi tables+optional plot)\n")
cat("Dates processed:", length(unique(reports_df$ObvsDate)), "\n")
cat("Syndromes processed:", length(unique(reports_df$presented_name)), "\n")
cat("Total visualizations created:", total_viz, "\n")
