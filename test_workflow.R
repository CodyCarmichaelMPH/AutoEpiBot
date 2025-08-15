############################################################
##  AutoEpiBot - Test Workflow Script
##  --------------------------------------------------------
##  Simple test to verify all components work correctly
##  Run this to test graphs, email, and reports
############################################################

cat("=== AutoEpiBot Test Workflow ===\n")
cat("Time:", format(Sys.time()), "\n\n")

# Check if we have the required data files
required_files <- c("AutoEpi_Settings.RData", "reportsData.RData")
missing_files <- !sapply(required_files, file.exists)

if (any(missing_files)) {
  cat("Missing required files:\n")
  cat(paste("-", required_files[missing_files], collapse = "\n"), "\n")
  cat("\nPlease run the full workflow first or ensure test data exists.\n")
  stop("Cannot proceed without required data files")
}

cat("✓ All required data files present\n\n")

# Load required libraries
cat("Loading required libraries...\n")
required_packages <- c("dplyr", "plotly", "htmlwidgets", "glue")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat("ERROR: Missing package:", pkg, "\n")
    cat("Please run: install.packages('", pkg, "')\n")
    stop("Missing required package")
  }
}
cat("✓ All required packages available\n\n")

# Load settings and data
load("AutoEpi_Settings.RData")
load("reportsData.RData")

cat("Data loaded:\n")
cat("- reports_df:", nrow(reports_df), "rows\n")
cat("- Date range:", as.character(min(reports_df$ObvsDate)), "to", as.character(max(reports_df$ObvsDate)), "\n")
cat("- Syndromes:", length(unique(reports_df$presented_name)), "\n\n")

# Test 1: Graph generation
cat("=== TEST 1: Graph Generation ===\n")
tryCatch({
  # Create a simple test graph
  library(plotly)
  sample_data <- head(reports_df, 20)
  
  test_plot <- plot_ly(sample_data, x = ~Sex, type = "histogram") %>%
    layout(title = "Test Graph - Sex Distribution")
  
  cat("✓ Basic plotly graph created\n")
  
  # Test saving as HTML widget
  temp_dir <- tempdir()
  test_file <- file.path(temp_dir, "test_plot.html")
  htmlwidgets::saveWidget(test_plot, test_file, selfcontained = TRUE)
  
  if (file.exists(test_file)) {
    cat("✓ Graph saved as HTML widget (", file.size(test_file), "bytes)\n")
  } else {
    cat("✗ Failed to save graph as HTML widget\n")
  }
  
}, error = function(e) {
  cat("✗ Graph generation failed:", conditionMessage(e), "\n")
})

# Test 2: Report generation
cat("\n=== TEST 2: Report Generation ===\n")
tryCatch({
  cat("Running ReportCreator.R...\n")
  source("ReportCreator.R")
  cat("✓ ReportCreator.R completed successfully\n")
  
  # Check if report was created
  reports_dir <- autoepi_settings$IO$Reports_Dir
  report_files <- list.files(reports_dir, pattern = "AutoEpi_Report_.*\\.RData", full.names = TRUE)
  
  if (length(report_files) > 0) {
    latest_report <- report_files[order(file.info(report_files)$mtime, decreasing = TRUE)][1]
    cat("✓ Report file created:", basename(latest_report), "\n")
    
    # Check report structure
    load(latest_report)
    if (exists("autoepi_report") && length(autoepi_report) > 0) {
      first_date <- names(autoepi_report)[1]
      first_syndrome <- names(autoepi_report[[first_date]])[1]
      syndrome_data <- autoepi_report[[first_date]][[first_syndrome]]
      
      total_visualizations <- 0
      if ("count" %in% names(syndrome_data)) {
        total_visualizations <- total_visualizations + length(syndrome_data$count)
      }
      if ("per10k" %in% names(syndrome_data)) {
        total_visualizations <- total_visualizations + length(syndrome_data$per10k)
      }
      if ("maps" %in% names(syndrome_data)) {
        total_visualizations <- total_visualizations + length(syndrome_data$maps)
      }
      
      cat("✓ Report contains", total_visualizations, "visualizations\n")
    } else {
      cat("✗ Report structure is empty or invalid\n")
    }
  } else {
    cat("✗ No report files found\n")
  }
  
}, error = function(e) {
  cat("✗ Report generation failed:", conditionMessage(e), "\n")
})

# Test 3: HTML Report generation
cat("\n=== TEST 3: HTML Report Generation ===\n")
tryCatch({
  cat("Running HTMLReportGenerator.R...\n")
  source("HTMLReportGenerator.R")
  cat("✓ HTMLReportGenerator.R completed successfully\n")
  
  # Check if HTML reports were created
  html_files <- list.files(reports_dir, pattern = "AutoEpi_Alert_.*\\.html", full.names = TRUE)
  
  if (length(html_files) > 0) {
    cat("✓ Created", length(html_files), "HTML report(s)\n")
    for (file in html_files) {
      cat("  -", basename(file), "(", file.size(file), "bytes)\n")
    }
  } else {
    cat("✗ No HTML reports found\n")
  }
  
}, error = function(e) {
  cat("✗ HTML report generation failed:", conditionMessage(e), "\n")
})

# Test 4: Email system
cat("\n=== TEST 4: Email System ===\n")

# Check if we have email starter info
if (file.exists("EmailStarterInfo.RData")) {
  cat("✓ EmailStarterInfo.RData found\n")
  
  # Check Outlook availability
  if (.Platform$OS.type == "windows" && requireNamespace("RDCOMClient", quietly = TRUE)) {
    outlook_available <- tryCatch({
      outlook_app <- RDCOMClient::COMCreate("Outlook.Application")
      cat("✓ Outlook COM object created successfully\n")
      TRUE
    }, error = function(e) {
      cat("✗ Outlook not available:", conditionMessage(e), "\n")
      cat("  Email will be saved as HTML file\n")
      FALSE
    })
    
    if (outlook_available) {
      cat("✓ Email system ready - will create actual Outlook emails\n")
    } else {
      cat("⚠ Email system will use HTML file fallback\n")
    }
  } else {
    cat("⚠ RDCOMClient not available - email will be saved as HTML file\n")
  }
  
  # Test email creation (without sending)
  tryCatch({
    cat("Testing email creation...\n")
    source("EmailCreator.R")
    cat("✓ EmailCreator.R completed successfully\n")
  }, error = function(e) {
    cat("✗ Email creation failed:", conditionMessage(e), "\n")
  })
} else {
  cat("✗ EmailStarterInfo.RData not found\n")
  cat("  Run TSCreate.R first to generate email starter data\n")
}

cat("\n=== TEST SUMMARY ===\n")
cat("Test workflow completed at", format(Sys.time()), "\n")
cat("\nIf all tests passed:\n")
cat("1. Graphs should be working in HTML reports\n")
cat("2. Email system should create proper Outlook emails (if available)\n")
cat("3. All files should be ready for GitHub push\n")
cat("\nNext step: Test on another PC to verify everything works!\n")
