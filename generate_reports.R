# generate_reports.R
# One HTML per (date_id, syndrome). Handles 5-digit date_id keys that vary.
# Usage: adjust the two paths below if needed, then run:
#   Rscript generate_reports.R

suppressPackageStartupMessages({
  library(rmarkdown)
  library(tools)
})

# ---- user-adjustable (or infer from settings) ----
settings_rdata_path <- "AutoEpi_Settings.RData"  # or absolute path
if (!file.exists(settings_rdata_path)) stop("Cannot find: ", settings_rdata_path)

load(settings_rdata_path)  # -> autoepi_settings
S <- autoepi_settings

reports_dir <- S$IO$Reports_Dir
if (!dir.exists(reports_dir)) stop("Reports dir does not exist: ", reports_dir)

# Find all AutoEpi report files (AutoEpi_Report_YYYY-MM-DD.RData)
rdata_files <- list.files(
  reports_dir,
  pattern = "^AutoEpi_Report_\\d{4}-\\d{2}-\\d{2}\\.RData$",
  full.names = TRUE
)
if (length(rdata_files) == 0) stop("No files matching AutoEpi_Report_YYYY-MM-DD.RData in ", reports_dir)

# Template path (this file should sit next to this script)
template_path <- file.path(getwd(), "report_template.Rmd")
if (!file.exists(template_path)) stop("Missing report_template.Rmd in working directory.")

# Output folder for HTML (organized by calendar date)
out_root <- file.path(reports_dir, "html")
if (!dir.exists(out_root)) dir.create(out_root, recursive = TRUE, showWarnings = FALSE)

render_one_rdata <- function(rdata_path) {
  f <- basename(rdata_path)
  date_str <- sub("^AutoEpi_Report_(\\d{4}-\\d{2}-\\d{2})\\.RData$", "\\1", f)
  report_date <- as.Date(date_str)

  e <- new.env(parent = emptyenv())
  load(rdata_path, envir = e)  # -> e$autoepi_report
  RPT <- e$autoepi_report

  # date_id keys are whatever is at top level of RPT; skip non-lists
  date_ids <- names(RPT)
  for (date_id in date_ids) {
    node <- RPT[[date_id]]
    if (!is.list(node)) next

    # syndromes are all names under this node except 'meta'
    syns <- setdiff(names(node), "meta")
    if (length(syns) == 0) next

    out_dir <- file.path(out_root, date_str, date_id)
    if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

    for (syn in syns) {
      safe_syn <- gsub("[^A-Za-z0-9_\\-]+", "_", syn)
      out_file <- sprintf("%s_%s_%s.html", safe_syn, date_id, date_str)
      message("Rendering: ", out_file)

      rmarkdown::render(
        input       = template_path,
        output_file = out_file,
        output_dir  = out_dir,
        params = list(
          autoepi_rdata_path  = rdata_path,
          settings_rdata_path = settings_rdata_path,
          report_date         = report_date,
          date_id             = date_id,
          syndrome_name       = syn
        ),
        envir = new.env(parent = globalenv()),
        quiet = TRUE
      )
    }
  }
}

for (r in rdata_files) render_one_rdata(r)
message("Done.")
