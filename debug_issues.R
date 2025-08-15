# Debug Issues Script - Focused on Email, Graphs, and Installer
cat("=== AutoEpiBot Issue Debug ===\n")

# Issue 1: Check installer file
cat("\n1. INSTALLER FILE CHECK\n")
if (file.exists("install_packages.R")) {
  cat("✓ install_packages.R exists\n")
  cat("  Size:", file.size("install_packages.R"), "bytes\n")
} else {
  cat("X install_packages.R missing\n")
}

# Issue 2: Email creating HTML file instead of actual email
cat("\n2. EMAIL FUNCTIONALITY CHECK\n")
cat("Checking if EmailCreator.R creates actual emails vs HTML files...\n")

# Check if RDCOMClient is available
if (.Platform$OS.type == "windows") {
  if (requireNamespace("RDCOMClient", quietly = TRUE)) {
    cat("✓ RDCOMClient package available\n")
    tryCatch({
      outlook <- RDCOMClient::COMCreate("Outlook.Application")
      cat("✓ Outlook COM object created - email functionality should work\n")
    }, error = function(e) {
      cat("X Outlook COM creation failed:", conditionMessage(e), "\n")
      cat("  This means emails will be saved as HTML files instead\n")
    })
  } else {
    cat("X RDCOMClient package not available\n")
  }
} else {
  cat("X Not on Windows - email functionality limited\n")
}

# Issue 3: Graphs not working - check current report structure
cat("\n3. GRAPH FUNCTIONALITY CHECK\n")

# Check if we have report data
if (file.exists("reportsData.RData")) {
  load("reportsData.RData")
  cat("✓ reportsData.RData loaded -", nrow(reports_df), "rows\n")
  
  if (nrow(reports_df) > 0) {
    cat("✓ Have report data to work with\n")
    
    # Check if settings exist
    if (file.exists("AutoEpi_Settings.RData")) {
      load("AutoEpi_Settings.RData")
      cat("✓ Settings loaded\n")
      
      # Check what report types are enabled
      rs <- autoepi_settings$Report_Settings
      enabled_reports <- c()
      if (rs$Age_Group_Bar) enabled_reports <- c(enabled_reports, "Age_Group_Bar")
      if (rs$Sex_Only_Graph) enabled_reports <- c(enabled_reports, "Sex_Only_Graph") 
      if (rs$Hospital_Bar_Graph) enabled_reports <- c(enabled_reports, "Hospital_Bar_Graph")
      
      cat("  Enabled graph types:", paste(enabled_reports, collapse = ", "), "\n")
      
      # Check if plotly package works
      if (requireNamespace("plotly", quietly = TRUE)) {
        cat("✓ plotly package available\n")
        
        # Try creating a simple graph
        tryCatch({
          test_plot <- plotly::plot_ly(data = head(reports_df, 10), 
                                     x = ~Sex, type = "histogram")
          cat("✓ Simple plotly graph created successfully\n")
          
          # Check htmlwidgets functionality
          if (requireNamespace("htmlwidgets", quietly = TRUE)) {
            cat("✓ htmlwidgets package available\n")
            
            # Test saving widget
            temp_file <- tempfile(fileext = ".html")
            htmlwidgets::saveWidget(test_plot, temp_file, selfcontained = TRUE)
            
            if (file.exists(temp_file)) {
              cat("✓ Graph saved as HTML widget successfully\n")
              unlink(temp_file)
            } else {
              cat("X Failed to save graph as HTML widget\n")
            }
          } else {
            cat("X htmlwidgets package not available\n")
          }
          
        }, error = function(e) {
          cat("X Graph creation failed:", conditionMessage(e), "\n")
        })
      } else {
        cat("X plotly package not available\n")
      }
      
    } else {
      cat("X AutoEpi_Settings.RData missing\n")
    }
  } else {
    cat("X No data in reports_df\n")
  }
} else {
  cat("X reportsData.RData missing\n")
}

# Check if AutoEpi report files exist
cat("\n4. CHECKING GENERATED REPORTS\n")
if (file.exists("AutoEpi_Settings.RData")) {
  load("AutoEpi_Settings.RData")
  reports_dir <- autoepi_settings$IO$Reports_Dir
  
  if (dir.exists(reports_dir)) {
    report_files <- list.files(reports_dir, pattern = "AutoEpi_Report_.*\\.RData", full.names = TRUE)
    
    if (length(report_files) > 0) {
      cat("✓ Found", length(report_files), "report files\n")
      latest_report <- report_files[order(file.info(report_files)$mtime, decreasing = TRUE)][1]
      cat("  Latest:", basename(latest_report), "\n")
      
      # Check report structure
      load(latest_report)
      if (exists("autoepi_report")) {
        cat("✓ autoepi_report object exists\n")
        cat("  Dates:", length(autoepi_report), "\n")
        
        if (length(autoepi_report) > 0) {
          first_date <- names(autoepi_report)[1]
          cat("  Syndromes in first date:", length(autoepi_report[[first_date]]), "\n")
          
          if (length(autoepi_report[[first_date]]) > 0) {
            first_syndrome <- names(autoepi_report[[first_date]])[1]
            syndrome_data <- autoepi_report[[first_date]][[first_syndrome]]
            cat("  Sections:", paste(names(syndrome_data), collapse = ", "), "\n")
            
            # Check for actual graphs
            total_graphs <- 0
            if ("count" %in% names(syndrome_data)) {
              total_graphs <- total_graphs + length(syndrome_data$count)
              cat("  Count graphs:", length(syndrome_data$count), "\n")
            }
            if ("per10k" %in% names(syndrome_data)) {
              total_graphs <- total_graphs + length(syndrome_data$per10k)
              cat("  Per10k graphs:", length(syndrome_data$per10k), "\n")
            }
            if ("maps" %in% names(syndrome_data)) {
              total_graphs <- total_graphs + length(syndrome_data$maps)
              cat("  Maps:", length(syndrome_data$maps), "\n")
            }
            
            if (total_graphs > 0) {
              cat("✓ Report contains", total_graphs, "total visualizations\n")
            } else {
              cat("X Report contains no visualizations\n")
            }
          }
        }
      } else {
        cat("X autoepi_report object missing from file\n")
      }
    } else {
      cat("X No report files found in", reports_dir, "\n")
    }
  } else {
    cat("X Reports directory does not exist:", reports_dir, "\n")
  }
}

cat("\n=== SUMMARY ===\n")
cat("To fix issues:\n")
cat("1. Installer: install_packages.R should be present for git push\n")
cat("2. Email: Check Outlook is running and RDCOMClient works\n") 
cat("3. Graphs: Run ReportCreator.R to generate visualizations first\n")
cat("\nNext step: Run source('ReportCreator.R') to generate graphs\n")
