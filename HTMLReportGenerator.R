############################################################
##  AutoEpi – Individual HTML Report Generator
##  --------------------------------------------------------
##  Creates individual HTML reports for each syndrome+date
##  combination that had alerts/reports generated
##  
##  Prerequisites: • reportsData.RData
##                 • AutoEpi_Settings.RData
##                 • autoepi_report (from ReportCreator.R)
############################################################

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(glue)
  library(plotly)
  library(htmlwidgets)
})

# ------------------------------------------------------------------
# 1.  Load required data
# ------------------------------------------------------------------
cat("AutoEpi HTML Report Generator\n")
cat("================================\n")

load("AutoEpi_Settings.RData")   # autoepi_settings
load("reportsData.RData")        # reports_df

# Try to load the comprehensive report from ReportCreator
report_file <- list.files(
  path = autoepi_settings$IO$Reports_Dir,
  pattern = "^AutoEpi_Report_.*\\.RData$",
  full.names = TRUE
)

if (length(report_file) > 0) {
  # Use the most recent report
  latest_report <- report_file[order(file.info(report_file)$mtime, decreasing = TRUE)][1]
  load(latest_report)  # autoepi_report
  cat("Loaded report data from:", latest_report, "\n")
} else {
  cat("No AutoEpi_Report found. Run ReportCreator.R first.\n")
  autoepi_report <- NULL
}

reports_dir <- normalizePath(
  autoepi_settings$IO$Reports_Dir, winslash = "/", mustWork = FALSE)

# ------------------------------------------------------------------
# 2.  HTML Template Functions
# ------------------------------------------------------------------

html_header <- function(syndrome, date, alert_level) {
  glue('
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>AutoEpiBot Alert Report - {syndrome}</title>
    <style>
        body {{
            font-family: Arial, sans-serif;
            margin: 20px;
            line-height: 1.6;
            color: #333;
        }}
        .header {{
            background-color: #f8f9fa;
            padding: 20px;
            border-left: 5px solid #007bff;
            margin-bottom: 20px;
        }}
        .alert-high {{ border-left-color: #dc3545; }}
        .alert-medium {{ border-left-color: #ffc107; }}
        .alert-low {{ border-left-color: #28a745; }}
        
        .summary-table {{
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }}
        .summary-table th, .summary-table td {{
            border: 1px solid #dee2e6;
            padding: 8px 12px;
            text-align: left;
        }}
        .summary-table th {{
            background-color: #e9ecef;
            font-weight: bold;
        }}
        
        .section {{
            margin: 30px 0;
            padding: 20px;
            border: 1px solid #dee2e6;
            border-radius: 5px;
        }}
        
        .section h3 {{
            margin-top: 0;
            color: #495057;
            border-bottom: 2px solid #007bff;
            padding-bottom: 10px;
        }}
        
        .plot-container {{
            margin: 20px 0;
            text-align: center;
        }}
        
        .footer {{
            margin-top: 40px;
            padding: 20px;
            background-color: #f8f9fa;
            border-top: 1px solid #dee2e6;
            font-size: 0.9em;
            color: #6c757d;
        }}
        
        .data-table {{
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
            font-size: 0.9em;
        }}
        .data-table th, .data-table td {{
            border: 1px solid #dee2e6;
            padding: 6px 10px;
            text-align: left;
        }}
        .data-table th {{
            background-color: #f8f9fa;
        }}
    </style>
</head>
<body>
    <div class="header alert-{tolower(alert_level)}">
        <h1>AutoEpiBot Alert Report</h1>
        <h2>{syndrome}</h2>
        <p><strong>Date:</strong> {date} | <strong>Alert Level:</strong> {alert_level}</p>
        <p><strong>Generated:</strong> {Sys.time()}</p>
    </div>
')
}

html_footer <- function() {
  '
    <div class="footer">
        <p><strong>AutoEpiBot</strong> - Automated Epidemiological Surveillance System</p>
        <p>For assistance after November 1, 2025, contact Cody Carmichael, MPH, CPH at codymicah.carmichael@gmail.com</p>
    </div>
</body>
</html>'
}

create_summary_section <- function(syndrome_data, date) {
  visit_count <- nrow(syndrome_data)
  
  # Age summary
  age_summary <- syndrome_data %>%
    summarise(
      mean_age = round(mean(as.numeric(.data$Age), na.rm = TRUE), 1),
      median_age = round(median(as.numeric(.data$Age), na.rm = TRUE), 1),
      min_age = min(as.numeric(.data$Age), na.rm = TRUE),
      max_age = max(as.numeric(.data$Age), na.rm = TRUE)
    )
  
  # Top hospitals
  top_hospitals <- syndrome_data %>%
    count(.data$HospitalName, sort = TRUE) %>%
    head(5)
  
  # Sex distribution
  sex_dist <- syndrome_data %>%
    count(.data$Sex, sort = TRUE)
  
  glue('
    <div class="section">
        <h3>Summary Statistics</h3>
        <table class="summary-table">
            <tr><th>Metric</th><th>Value</th></tr>
            <tr><td>Total Visits</td><td>{visit_count}</td></tr>
            <tr><td>Mean Age</td><td>{age_summary$mean_age} years</td></tr>
            <tr><td>Age Range</td><td>{age_summary$min_age} - {age_summary$max_age} years</td></tr>
            <tr><td>Date</td><td>{date}</td></tr>
        </table>
        
        <h4>Top Hospitals</h4>
        <table class="data-table">
            <tr><th>Hospital</th><th>Count</th></tr>
            {paste(apply(top_hospitals, 1, function(row) glue("<tr><td>{row[1]}</td><td>{row[2]}</td></tr>")), collapse = "")}
        </table>
        
        <h4>Sex Distribution</h4>
        <table class="data-table">
            <tr><th>Sex</th><th>Count</th></tr>
            {paste(apply(sex_dist, 1, function(row) glue("<tr><td>{row[1]}</td><td>{row[2]}</td></tr>")), collapse = "")}
        </table>
    </div>
  ')
}

create_visualization_section <- function(syndrome, date, autoepi_report) {
  if (is.null(autoepi_report)) {
    return('<div class="section"><h3>Visualizations</h3><p>No visualization data available. Run ReportCreator.R first.</p></div>')
  }
  
  date_key <- as.character(date)
  syndrome_key <- syndrome
  
  if (!date_key %in% names(autoepi_report) || 
      !syndrome_key %in% names(autoepi_report[[date_key]])) {
    return('<div class="section"><h3>Visualizations</h3><p>No visualizations found for this syndrome and date.</p></div>')
  }
  
  plots <- autoepi_report[[date_key]][[syndrome_key]]
  
  html_content <- '<div class="section"><h3>Visualizations</h3>'
  
  # Count plots
  if (!is.null(plots$count) && length(plots$count) > 0) {
    html_content <- paste0(html_content, '<h4>Count Distributions</h4>')
    
    for (plot_name in names(plots$count)) {
      # Create separate HTML file for the plot (easier and more reliable)
      plot_file <- file.path(reports_dir, glue("plot_{syndrome}_{date}_{plot_name}.html"))
      htmlwidgets::saveWidget(plots$count[[plot_name]], plot_file, selfcontained = TRUE)
      
      html_content <- paste0(html_content, glue('
        <div class="plot-container">
            <h5>{stringr::str_to_title(gsub("_", " ", plot_name))}</h5>
            <iframe src="{basename(plot_file)}" width="100%" height="400" frameborder="0"></iframe>
        </div>
      '))
    }
  } else {
    html_content <- paste0(html_content, '<p><em>No count visualizations available.</em></p>')
  }
  
  # Per 10k plots  
  if (!is.null(plots$per10k) && length(plots$per10k) > 0) {
    html_content <- paste0(html_content, '<h4>Rates per 10,000 Population</h4>')
    
    for (plot_name in names(plots$per10k)) {
      # Create separate HTML file for the plot
      plot_file <- file.path(reports_dir, glue("plot_{syndrome}_{date}_per10k_{plot_name}.html"))
      htmlwidgets::saveWidget(plots$per10k[[plot_name]], plot_file, selfcontained = TRUE)
      
      html_content <- paste0(html_content, glue('
        <div class="plot-container">
            <h5>{stringr::str_to_title(gsub("_", " ", plot_name))} per 10k</h5>
            <iframe src="{basename(plot_file)}" width="100%" height="400" frameborder="0"></iframe>
        </div>
      '))
    }
  } else {
    html_content <- paste0(html_content, '<p><em>No per-10k visualizations available.</em></p>')
  }
  
  # Maps
  if (!is.null(plots$maps) && length(plots$maps) > 0) {
    html_content <- paste0(html_content, '<h4>Geographic Distribution</h4>')
    
    for (map_name in names(plots$maps)) {
      # Create separate HTML file for the map
      map_file <- file.path(reports_dir, glue("map_{syndrome}_{date}_{map_name}.html"))
      htmlwidgets::saveWidget(plots$maps[[map_name]], map_file, selfcontained = TRUE)
      
      html_content <- paste0(html_content, glue('
        <div class="plot-container">
            <h5>{stringr::str_to_title(gsub("_", " ", map_name))}</h5>
            <iframe src="{basename(map_file)}" width="100%" height="500" frameborder="0"></iframe>
        </div>
      '))
    }
  } else {
    html_content <- paste0(html_content, '<p><em>No maps available (check zipcode data).</em></p>')
  }
  
  html_content <- paste0(html_content, '</div>')
  return(html_content)
}

# ------------------------------------------------------------------
# 3.  Generate individual reports
# ------------------------------------------------------------------

# Get unique syndrome+date combinations that had alerts
report_combinations <- reports_df %>%
  select(presented_name, ObvsDate) %>%
  distinct() %>%
  arrange(ObvsDate, presented_name)

cat("Generating", nrow(report_combinations), "individual HTML reports...\n")

generated_reports <- list()

for (i in seq_len(nrow(report_combinations))) {
  syndrome <- report_combinations$presented_name[i]
  date <- report_combinations$ObvsDate[i]
  
  cat("Processing:", syndrome, "on", as.character(date), "\n")
  
  # Filter data for this syndrome+date
  syndrome_data <- reports_df %>%
    filter(presented_name == syndrome, ObvsDate == date)
  
  if (nrow(syndrome_data) == 0) next
  
  # Determine alert level (simplified - could be enhanced)
  alert_level <- if (nrow(syndrome_data) > 10) "HIGH" else if (nrow(syndrome_data) > 5) "MEDIUM" else "LOW"
  
  # Generate HTML content
  html_content <- paste0(
    html_header(syndrome, date, alert_level),
    create_summary_section(syndrome_data, date),
    create_visualization_section(syndrome, date, autoepi_report),
    html_footer()
  )
  
  # Save individual report
  clean_syndrome <- gsub("[^A-Za-z0-9_-]", "_", syndrome)
  report_filename <- glue("AutoEpi_Alert_{clean_syndrome}_{date}.html")
  report_path <- file.path(reports_dir, report_filename)
  
  writeLines(html_content, report_path)
  
  generated_reports[[length(generated_reports) + 1]] <- list(
    syndrome = syndrome,
    date = date,
    file_path = report_path,
    visit_count = nrow(syndrome_data)
  )
  
  cat("  SUCCESS: Saved:", report_filename, "\n")
}

# ------------------------------------------------------------------
# 4.  Save report metadata
# ------------------------------------------------------------------
individual_reports_metadata <- generated_reports
save(individual_reports_metadata, file = file.path(reports_dir, "individual_reports_metadata.RData"))

cat("\nHTML Report Generation Complete\n")
cat("===============================\n")
cat("Generated", length(generated_reports), "individual HTML reports\n")
cat("Reports saved to:", reports_dir, "\n")
cat("Metadata saved to: individual_reports_metadata.RData\n")
