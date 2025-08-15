############################################################
##  AutoEpi – Counts & /10 k Plot Builder
##             (Date × Syndrome, hospital prefixes removed)
############################################################
##  OUTPUT: <Reports_Dir>/Counts10k_Plots_<YYYY-MM-DD>.RData
##          object: counts10k_plots[date][syndrome][section][plot]
############################################################

suppressPackageStartupMessages({
  library(httr);  library(jsonlite); library(dplyr);  library(readr)
  library(purrr); library(plotly);   library(glue)
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

dedupe <- function(df) distinct(df, C_BioSense_ID, .keep_all = TRUE)

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

# --- age bins ---------------------------------------------------------------
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

# ------------------------------------------------------------------
# 3.  Compute denominators (split by demographic, hospital cleaned)
# ------------------------------------------------------------------
all_visits <- map_dfr(unique(reports_df$ObvsDate), function(d) {
  js <- fromJSON(ess_txt(all_url(d)), flatten = TRUE)$dataDetails
  if (is.null(js)) return(tibble())
  js %>% dedupe() %>% mutate(
    ObvsDate = d,
    age_grp  = age_binner(Age),
    Sex      = Sex,
    Hospital = clean_hosp(HospitalName)
  ) %>%
    pivot_longer(cols = c(age_grp, Sex, Hospital),
                 names_to = "demo", values_to = "level") %>%
    count(ObvsDate, demo, level, name = "denom")
})

# ------------------------------------------------------------------
# 4.  Prepare numerator data (hospital cleaned)
# ------------------------------------------------------------------
reports_df <- reports_df %>%
  mutate(HospitalClean = clean_hosp(HospitalName))

# ------------------------------------------------------------------
# 5.  Build Plotly list Date → Syndrome
# ------------------------------------------------------------------
plots <- list()

store <- function(dk, sk, sect, nm, p) {
  plots[[dk]][[sk]][[sect]][[nm]] <<- p
}

for (d in sort(unique(reports_df$ObvsDate))) {
  dk   <- as.character(d)
  plots[[dk]] <- list()
  rep_d  <- filter(reports_df, ObvsDate == d)
  denom_d <- filter(all_visits, ObvsDate == d)
  
  for (syn in sort(unique(rep_d$presented_name))) {
    sk    <- syn
    rep_s <- filter(rep_d, presented_name == syn)
    plots[[dk]][[sk]] <- list(count = list(), per10k = list())
    
    # ---------- COUNT BARS ----------
    if (rep_set$Age_Group_Bar) {
      p <- plot_ly(rep_s %>% mutate(age_grp = age_binner(Age)),
                   x = ~age_grp, type = "histogram") %>%
        layout(title = "Age Group (count)")
      store(dk, sk, "count", "age", p)
    }
    if (rep_set$Sex_Only_Graph) {
      p <- plot_ly(rep_s, x = ~Sex, type = "histogram") %>%
        layout(title = "Sex (count)")
      store(dk, sk, "count", "sex", p)
    }
    if (rep_set$Hospital_Bar_Graph) {
      p <- plot_ly(rep_s, x = ~HospitalClean, type = "histogram") %>%
        layout(title = "Hospital (count)")
      store(dk, sk, "count", "hospital", p)
    }
    
    # ---------- per-10k (matched denom) ----------
    if (rep_set$Age_Per_10k_Graph) {
      num <- rep_s %>% mutate(age_grp = age_binner(Age)) %>%
        count(age_grp, name = "num", .drop = FALSE)
      den <- filter(denom_d, demo == "age_grp") %>%
        select(level, denom)
      df  <- left_join(num, den, by = c("age_grp" = "level")) %>%
        mutate(rate = round(num/denom*1e4,1))
      p   <- plot_ly(df, x = ~age_grp, y = ~rate, type = "bar") %>%
        layout(title = "Age Group per 10k")
      store(dk, sk, "per10k", "age", p)
    }
    if (rep_set$Sex_Per_10k_Graph) {
      num <- rep_s %>% count(Sex, name = "num", .drop = FALSE)
      den <- filter(denom_d, demo == "Sex") %>% select(level, denom)
      df  <- left_join(num, den, by = c("Sex" = "level")) %>%
        mutate(rate = round(num/denom*1e4,1))
      p <- plot_ly(df, x = ~Sex, y = ~rate, type = "bar") %>%
        layout(title = "Sex per 10k")
      store(dk, sk, "per10k", "sex", p)
    }
    if (rep_set$Hospital_Per_10k_Graph) {
      num <- rep_s %>% count(HospitalClean, name = "num", .drop = FALSE)
      den <- filter(denom_d, demo == "Hospital") %>% select(level, denom)
      df  <- left_join(num, den, by = c("HospitalClean" = "level")) %>%
        mutate(rate = round(num/denom*1e4,1))
      p <- plot_ly(df, x = ~HospitalClean, y = ~rate, type = "bar") %>%
        layout(title = "Hospital per 10k")
      store(dk, sk, "per10k", "hospital", p)
    }
  }
}

# ------------------------------------------------------------------
# 6.  Save RData
# ------------------------------------------------------------------
counts10k_plots <- plots
out_file <- file.path(
  reports_dir,
  glue("Counts10k_Plots_{format(Sys.Date(), '%Y-%m-%d')}.RData")
)
save(counts10k_plots, file = out_file)
message("Saved Plotly list → ", out_file)
