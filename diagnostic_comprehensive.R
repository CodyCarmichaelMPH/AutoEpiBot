############################################################
##  AutoEpiBot - Comprehensive Diagnostic Script
##  --------------------------------------------------------
##  Tests all components to identify issues with:
##  - Graph generation and embedding
##  - Email functionality 
##  - Data processing pipeline
############################################################

cat("=== AutoEpiBot Comprehensive Diagnostic ===\n")
cat("Time:", format(Sys.time()), "\n\n")

# ------------------------------------------------------------------
# 1. Check Required Files and Dependencies
# ------------------------------------------------------------------
cat("1. CHECKING REQUIRED FILES AND DEPENDENCIES\n")
cat(strrep("=", 50), "\n")

required_files <- c(
  "AutoEpi_Settings.RData",
  "reportsData.RData", 
  "EmailStarterInfo.RData",
  "LogsFileLoc.RData",
  "ZipLayer/wa_washington_zip_codes_geo.min.json"
)

file_status <- sapply(required_files, function(f) {
  exists <- file.exists(f)
  size <- if (exists) file.size(f) else 0
  cat(if (exists) "✅" else "❌", f, "-", if (exists) paste(size, "bytes") else "MISSING", "\n")
  exists
})

# Check packages
required_packages <- c("dplyr", "readr", "plotly", "htmlwidgets", "leaflet", "glue", "RDCOMClient")
package_status <- sapply(required_packages, function(p) {
  avail <- requireNamespace(p, quietly = TRUE)
  cat(if (avail) "✅" else "❌", "Package:", p, "\n")
  avail
})

# ------------------------------------------------------------------
# 2. Test Data Loading and Structure
# ------------------------------------------------------------------
cat("\n2. TESTING DATA LOADING AND STRUCTURE\n")
cat(strrep("=", 50), "\n")

# Test settings loading
if (file.exists("AutoEpi_Settings.RData")) {
  load("AutoEpi_Settings.RData")
  cat("✅ Settings loaded\n")
  cat("   Report types enabled:\n")
  rs <- autoepi_settings$Report_Settings
  cat("   - Age Group Bar:", rs$Age_Group_Bar, "\n")
  cat("   - Age+Gender Stacked:", rs$Age_Gender_Stacked_Bar, "\n") 
  cat("   - Sex Only:", rs$Sex_Only_Graph, "\n")
  cat("   - Hospital Bar:", rs$Hospital_Bar_Graph, "\n")
  cat("   - Choropleth Map:", rs$Choropleth_Map, "\n")
  cat("   - Reports Dir:", autoepi_settings$IO$Reports_Dir, "\n")
} else {
  cat("❌ AutoEpi_Settings.RData missing\n")
}

# Test reports data
if (file.exists("reportsData.RData")) {
  load("reportsData.RData")
  cat("✅ reportsData.RData loaded\n")
  cat("   Rows:", nrow(reports_df), "Cols:", ncol(reports_df), "\n")
  cat("   Columns:", paste(names(reports_df), collapse = ", "), "\n")
  
  if (nrow(reports_df) > 0) {
    cat("   Date range:", as.character(min(reports_df$ObvsDate)), "to", as.character(max(reports_df$ObvsDate)), "\n")
    cat("   Syndromes:", length(unique(reports_df$presented_name)), "\n")
    cat("   Sample syndromes:", paste(head(unique(reports_df$presented_name), 3), collapse = ", "), "\n")
  }
} else {
  cat("❌ reportsData.RData missing\n")
}

# ------------------------------------------------------------------
# 3. Test Graph Generation
# ------------------------------------------------------------------
cat("\n3. TESTING GRAPH GENERATION\n")
cat(strrep("=", 50), "\n")

if (exists("reports_df") && nrow(reports_df) > 0) {
  # Try to create a simple test graph
  library(plotly)
  
  test_data <- head(reports_df, 20)
  cat("Creating test graph with", nrow(test_data), "records...\n")
  
  tryCatch({
    # Test basic plotly graph
    test_plot <- plot_ly(test_data, x = ~Sex, type = "histogram") %>%
      layout(title = "Test Graph - Sex Distribution")
    
    cat("✅ Plotly graph created successfully\n")
    cat("   Graph class:", class(test_plot), "\n")
    
    # Test saving as widget
    if (requireNamespace("htmlwidgets", quietly = TRUE)) {
      temp_file <- tempfile(fileext = ".html")
      htmlwidgets::saveWidget(test_plot, temp_file, selfcontained = TRUE)
      
      if (file.exists(temp_file)) {
        cat("✅ Graph saved as HTML widget\n")
        cat("   File size:", file.size(temp_file), "bytes\n")
        unlink(temp_file) # Clean up
      } else {
        cat("❌ Failed to save graph as HTML widget\n")
      }
    }
    
  }, error = function(e) {
    cat("❌ Graph creation failed:", conditionMessage(e), "\n")
  })
} else {
  cat("❌ No data available for graph testing\n")
}

# ------------------------------------------------------------------
# 4. Test Report Structure
# ------------------------------------------------------------------
cat("\n4. TESTING REPORT STRUCTURE\n") 
cat(strrep("=", 50), "\n")

# Check if AutoEpi report exists
reports_dir <- if (exists("autoepi_settings")) autoepi_settings$IO$Reports_Dir else "Reports"
report_files <- list.files(path = reports_dir, pattern = "^AutoEpi_Report_.*\\.RData$", full.names = TRUE)

if (length(report_files) > 0) {
  latest_report <- report_files[order(file.info(report_files)$mtime, decreasing = TRUE)][1]
  cat("✅ Found report file:", basename(latest_report), "\n")
  
  load(latest_report)
  if (exists("autoepi_report")) {
    cat("✅ autoepi_report object loaded\n")
    cat("   Structure levels:\n")
    cat("   - Dates:", length(autoepi_report), "\n")
    
    if (length(autoepi_report) > 0) {
      first_date <- names(autoepi_report)[1]
      cat("   - Syndromes in", first_date, ":", length(autoepi_report[[first_date]]), "\n")
      
      if (length(autoepi_report[[first_date]]) > 0) {
        first_syndrome <- names(autoepi_report[[first_date]])[1]
        syndrome_data <- autoepi_report[[first_date]][[first_syndrome]]
        cat("   - Sections in", first_syndrome, ":", paste(names(syndrome_data), collapse = ", "), "\n")
        
        # Check if graphs exist
        if ("count" %in% names(syndrome_data)) {
          cat("   - Count graphs:", length(syndrome_data$count), names(syndrome_data$count), "\n")
        }
        if ("per10k" %in% names(syndrome_data)) {
          cat("   - Per10k graphs:", length(syndrome_data$per10k), names(syndrome_data$per10k), "\n")
        }
        if ("maps" %in% names(syndrome_data)) {
          cat("   - Maps:", length(syndrome_data$maps), names(syndrome_data$maps), "\n")
        }
      }
    }
  } else {
    cat("❌ autoepi_report object not found in file\n")
  }
} else {
  cat("❌ No AutoEpi report files found in", reports_dir, "\n")
}

# ------------------------------------------------------------------
# 5. Test Email System
# ------------------------------------------------------------------
cat("\n5. TESTING EMAIL SYSTEM\n")
cat(strrep("=", 50), "\n")

# Check Outlook availability
if (.Platform$OS.type == "windows" && requireNamespace("RDCOMClient", quietly = TRUE)) {
  tryCatch({
    outlook_app <- RDCOMClient::COMCreate("Outlook.Application")
    cat("✅ Outlook COM object created successfully\n")
    
    # Test creating email without sending
    mail_item <- outlook_app$CreateItem(0)
    mail_item[["Subject"]] <- "AutoEpiBot Test Email"
    mail_item[["HTMLBody"]] <- "<h1>Test Email</h1><p>This is a test email from AutoEpiBot diagnostic.</p>"
    
    cat("✅ Test email created successfully\n")
    cat("   Subject set, HTML body set\n")
    
    # Don't send or display, just test creation
    cat("   Email creation successful (not sent)\n")
    
  }, error = function(e) {
    cat("❌ Outlook integration failed:", conditionMessage(e), "\n")
    cat("   Possible causes:\n")
    cat("   - Outlook not installed\n")
    cat("   - Outlook not running\n") 
    cat("   - Security settings blocking COM access\n")
  })
} else {
  if (.Platform$OS.type != "windows") {
    cat("⚠️  Email functionality only available on Windows\n")
  } else {
    cat("❌ RDCOMClient package not available\n")
  }
}

# ------------------------------------------------------------------
# 6. Test HTML Report Generation
# ------------------------------------------------------------------
cat("\n6. TESTING HTML REPORT GENERATION\n")
cat(strrep("=", 50), "\n")

if (exists("reports_df") && nrow(reports_df) > 0 && exists("autoepi_report")) {
  # Test creating a simple HTML report section
  tryCatch({
    # Get first syndrome/date combo
    first_combo <- reports_df[1, ]
    syndrome <- first_combo$presented_name
    date <- first_combo$ObvsDate
    
    cat("Testing HTML generation for:", syndrome, "on", as.character(date), "\n")
    
    # Test the visualization section function
    source("HTMLReportGenerator.R", local = TRUE)
    
    date_key <- as.character(date)
    if (date_key %in% names(autoepi_report) && syndrome %in% names(autoepi_report[[date_key]])) {
      plots <- autoepi_report[[date_key]][[syndrome]]
      cat("✅ Found plots for", syndrome, "on", date_key, "\n")
      cat("   Available sections:", paste(names(plots), collapse = ", "), "\n")
      
      # Test visualization section creation
      html_section <- create_visualization_section(syndrome, date, autoepi_report)
      cat("✅ HTML visualization section created\n")
      cat("   Length:", nchar(html_section), "characters\n")
      
      # Check for actual content vs. empty messages
      if (grepl("No visualization", html_section)) {
        cat("⚠️  HTML contains 'No visualization' message\n")
      } else {
        cat("✅ HTML contains actual visualization content\n")
      }
      
    } else {
      cat("❌ No plots found for", syndrome, "on", date_key, "\n")
    }
    
  }, error = function(e) {
    cat("❌ HTML generation test failed:", conditionMessage(e), "\n")
  })
} else {
  cat("❌ Cannot test HTML generation - missing data or report structure\n")
}

# ------------------------------------------------------------------
# 7. Summary and Recommendations
# ------------------------------------------------------------------
cat("\n7. SUMMARY AND RECOMMENDATIONS\n")
cat(strrep("=", 50), "\n")

issues_found <- 0

# File issues
missing_files <- sum(!file_status)
if (missing_files > 0) {
  cat("❌ Missing files:", missing_files, "\n")
  issues_found <- issues_found + 1
}

# Package issues  
missing_packages <- sum(!package_status)
if (missing_packages > 0) {
  cat("❌ Missing packages:", missing_packages, "\n")
  issues_found <- issues_found + 1
}

# Data issues
if (!exists("reports_df") || nrow(reports_df) == 0) {
  cat("❌ No report data available\n")
  issues_found <- issues_found + 1
}

# Report structure issues
if (length(report_files) == 0) {
  cat("❌ No report files generated\n") 
  issues_found <- issues_found + 1
}

if (issues_found == 0) {
  cat("✅ All systems appear to be working correctly\n")
} else {
  cat("⚠️  Found", issues_found, "issue(s) requiring attention\n")
}

cat("\nDiagnostic complete at", format(Sys.time()), "\n")
