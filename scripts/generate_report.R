# AutoEpiBot - Report Generation
# HTML Report Generation for Validated Alerts

generate_report <- function(syndrome, alert_date, validation_result, config) {
  log_info(paste("Generating report for", syndrome$name, "on", alert_date))
  
  tryCatch({
    # Create syndrome-specific report directory
    syndrome_dir <- file.path(config$output$report_folder, gsub("[^a-zA-Z0-9]", "_", syndrome$name))
    dir.create(syndrome_dir, recursive = TRUE, showWarnings = FALSE)
    
    # Generate report filename
    report_filename <- paste0(format(as.Date(alert_date), "%Y-%m-%d"), ".html")
    report_path <- file.path(syndrome_dir, report_filename)
    
    # Pull detailed data for enhanced analysis
    detailed_data <- pull_alert_details(syndrome, alert_date, config)
    
    # Create RMarkdown content
    rmd_content <- create_report_content(syndrome, alert_date, validation_result, config)
    
    # Write RMarkdown file
    rmd_file <- tempfile(fileext = ".Rmd")
    writeLines(rmd_content, rmd_file)
    
    # Render HTML report with detailed data
    rmarkdown::render(
      rmd_file,
      output_file = report_path,
      output_format = "html_document",
      quiet = TRUE,
      params = list(
        syndrome_name = syndrome$name,
        alert_date = alert_date,
        validation_result = validation_result,
        detailed_data = detailed_data
      )
    )
    
    # Clean up temporary file
    unlink(rmd_file)
    
    log_info(paste("Report generated successfully:", report_path))
    return(report_path)
    
  }, error = function(e) {
    log_error(paste("Error generating report for", syndrome$name, "on", alert_date, ":", e$message))
    return(NULL)
  })
}

# Create RMarkdown content for the report
create_report_content <- function(syndrome, alert_date, validation_result, config) {
  alert_date_formatted <- format(as.Date(alert_date), "%B %d, %Y")
  
  rmd_content <- paste0('
---
title: "AutoEpiBot Alert Report"
subtitle: "', syndrome$name, ' - ', alert_date_formatted, '"
date: "', Sys.Date(), '"
output:
  html_document:
    toc: true
    toc_float: true
    theme: cosmo
    highlight: tango
    css: styles.css
params:
  syndrome_name: "', syndrome$name, '"
  alert_date: "', alert_date, '"
  validation_result: !r validation_result
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE, warning = FALSE, message = FALSE)
library(ggplot2)
library(dplyr)
library(knitr)
library(DT)
```

# AutoEpiBot Alert Report

## Executive Summary

**Syndrome:** `r params$syndrome_name`  
**Alert Date:** `r format(as.Date(params$alert_date), "%B %d, %Y")`  
**Report Generated:** `r format(Sys.time(), "%B %d, %Y at %I:%M %p")`

### Alert Status

```{r alert-status}
validation <- params$validation_result

status_color <- if(validation$is_valid) "green" else "red"
status_text <- if(validation$is_valid) "VALID ALERT" else "FALSE POSITIVE"

cat("**Status:** ", status_text, "\\n")
cat("**Reason:** ", validation$reason, "\\n")
```

## Validation Details

### Count Comparison

```{r count-comparison}
validation <- params$validation_result

cat("**Current Count:** ", validation$current_count, "\\n")
cat("**Expected Count:** ", round(validation$expected_count, 1), "\\n")
cat("**Ratio:** ", round(validation$expected_ratio, 2), "x expected\\n")
cat("**Z-Score:** ", round(validation$z_score, 2), "\\n")
cat("**P-Value:** ", format(validation$p_value, scientific = TRUE), "\\n")
```

### Historical Context
```{r historical-context}
validation <- params$validation_result

cat("**30-Day Average:** ", round(validation$historical_mean, 1), "\\n")
cat("**30-Day Standard Deviation:** ", round(validation$historical_sd, 1), "\\n")
cat("**Historical Range:** ", round(validation$historical_min, 1), " - ", round(validation$historical_max, 1), "\\n")
```

## Demographic Analysis

```{r demographic-setup, include=FALSE}
# Load detailed data if available
detailed_data <- params$detailed_data
if(!is.null(detailed_data) && nrow(detailed_data) > 0) {
  data_available <- TRUE
} else {
  data_available <- FALSE
}
```

### Age and Gender Distribution
```{r age-gender, echo=FALSE, warning=FALSE, message=FALSE}
if(data_available) {
  age_gender_summary <- detailed_data %>%
    group_by(age_group, gender) %>%
    summarise(count = n(), .groups = "drop") %>%
    arrange(age_group, gender)
  
  # Create visualization
  p1 <- ggplot(age_gender_summary, aes(x = age_group, y = count, fill = gender)) +
    geom_bar(stat = "identity", position = "dodge") +
    labs(title = "Age and Gender Distribution",
         x = "Age Group", y = "Count", fill = "Gender") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  print(p1)
} else {
  cat("Detailed demographic data not available for this alert.\\n")
}
```

### Age Distribution
```{r age-only, echo=FALSE, warning=FALSE, message=FALSE}
if(data_available) {
  age_summary <- detailed_data %>%
    group_by(age_group) %>%
    summarise(count = n(), .groups = "drop") %>%
    arrange(age_group)
  
  # Create visualization
  p2 <- ggplot(age_summary, aes(x = age_group, y = count)) +
    geom_bar(stat = "identity", fill = "steelblue") +
    labs(title = "Age Distribution",
         x = "Age Group", y = "Count") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  print(p2)
}
```

### Gender Distribution
```{r gender-only, echo=FALSE, warning=FALSE, message=FALSE}
if(data_available) {
  gender_summary <- detailed_data %>%
    group_by(gender) %>%
    summarise(count = n(), .groups = "drop") %>%
    arrange(gender)
  
  # Create visualization
  p3 <- ggplot(gender_summary, aes(x = gender, y = count)) +
    geom_bar(stat = "identity", fill = "lightcoral") +
    labs(title = "Gender Distribution",
         x = "Gender", y = "Count") +
    theme_minimal()
  
  print(p3)
}
```

## Time Series Analysis

### Daily Counts
```{r time-series, echo=FALSE, warning=FALSE, message=FALSE}
if(data_available) {
  daily_counts <- detailed_data %>%
    group_by(date) %>%
    summarise(count = n(), .groups = "drop") %>%
    arrange(date)
  
  # Create visualization
  p4 <- ggplot(daily_counts, aes(x = date, y = count)) +
    geom_line(color = "blue", size = 1) +
    geom_point(color = "red", size = 2) +
    labs(title = "Daily Visit Counts",
         x = "Date", y = "Count") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  print(p4)
}
```

## Hospital Analysis

### Hospital Distribution
```{r hospital, echo=FALSE, warning=FALSE, message=FALSE}
if(data_available) {
  hospital_summary <- detailed_data %>%
    group_by(hospital_name) %>%
    summarise(count = n(), .groups = "drop") %>%
    arrange(desc(count)) %>%
    head(10)
  
  # Create visualization
  p5 <- ggplot(hospital_summary, aes(x = reorder(hospital_name, count), y = count)) +
    geom_bar(stat = "identity", fill = "darkgreen") +
    coord_flip() +
    labs(title = "Top 10 Hospitals by Visit Count",
         x = "Hospital", y = "Count") +
    theme_minimal()
  
  print(p5)
}
```

## Time of Day Analysis

### Visit Distribution by Hour
```{r time-of-day, echo=FALSE, warning=FALSE, message=FALSE}
if(data_available) {
  time_summary <- detailed_data %>%
    group_by(hour_of_day) %>%
    summarise(count = n(), .groups = "drop") %>%
    arrange(hour_of_day)
  
  # Create visualization
  p6 <- ggplot(time_summary, aes(x = hour_of_day, y = count)) +
    geom_bar(stat = "identity", fill = "orange") +
    labs(title = "Visit Distribution by Hour of Day",
         x = "Hour", y = "Count") +
    theme_minimal() +
    scale_x_continuous(breaks = seq(0, 23, 2))
  
  print(p6)
}
```

```{r count-comparison}
current_count <- validation$current_count
expected_count <- validation$expected_count
historical_mean <- validation$historical_mean

comparison_df <- data.frame(
  Metric = c("Current Count", "Expected Count", "Historical Mean"),
  Value = c(current_count, expected_count, historical_mean),
  stringsAsFactors = FALSE
)

knitr::kable(comparison_df, format = "html", 
              col.names = c("Metric", "Value"),
              align = c("l", "r")) %>%
  kableExtra::kable_styling(bootstrap_options = c("striped", "hover"))
```

### Validation Ratios

```{r validation-ratios}
expected_ratio <- validation$expected_ratio
historical_ratio <- validation$historical_ratio
z_score <- validation$z_score

ratios_df <- data.frame(
  Ratio = c("Current/Expected", "Current/Historical Mean", "Z-Score"),
  Value = c(round(expected_ratio, 2), round(historical_ratio, 2), round(z_score, 2)),
  stringsAsFactors = FALSE
)

knitr::kable(ratios_df, format = "html",
              col.names = c("Ratio", "Value"),
              align = c("l", "r")) %>%
  kableExtra::kable_styling(bootstrap_options = c("striped", "hover"))
```

### Validation Checks

```{r validation-checks}
checks_df <- data.frame(
  Check = c("Above Expected", "Above Historical Mean", "Statistically Significant", "Below False Positive Threshold"),
  Result = c(validation$is_above_expected, validation$is_above_historical, 
             validation$is_statistically_significant, validation$is_below_false_positive_threshold),
  stringsAsFactors = FALSE
)

checks_df$Result <- ifelse(checks_df$Result, "✅ PASS", "❌ FAIL")

knitr::kable(checks_df, format = "html",
              col.names = c("Validation Check", "Result"),
              align = c("l", "c")) %>%
  kableExtra::kable_styling(bootstrap_options = c("striped", "hover"))
```

## Historical Context

```{r historical-context, fig.width=10, fig.height=6}
# Note: This would need historical data to be passed in validation_result
# For now, we\'ll create a placeholder chart

if (!is.null(validation$historical_data) && nrow(validation$historical_data) > 0) {
  historical_data <- validation$historical_data
  
  ggplot(historical_data, aes(x = date, y = count)) +
    geom_line(color = "blue", alpha = 0.7) +
    geom_point(data = historical_data[historical_data$date == as.Date(params$alert_date), ], 
               color = "red", size = 3) +
    geom_hline(yintercept = validation$expected_count, linetype = "dashed", color = "orange") +
    geom_hline(yintercept = validation$historical_mean, linetype = "dotted", color = "green") +
    labs(title = paste("Historical Trend -", params$syndrome_name),
         subtitle = paste("Alert date:", format(as.Date(params$alert_date), "%B %d, %Y")),
         x = "Date", y = "Count") +
    theme_minimal() +
    theme(plot.title = element_text(size = 14, face = "bold"),
          plot.subtitle = element_text(size = 12))
} else {
  cat("Historical data not available for chart generation.")
}
```

## Technical Details

### Configuration Used

- **Historical Days:** `r config$validation$historical_days`
- **Minimum Alert Level:** `r config$validation$min_alert_level`
- **False Positive Threshold:** `r config$validation$false_positive_threshold`x expected

### Data Quality

- **Deduplicated Count:** `r validation$deduplicated_count`
- **Raw Count:** `r validation$current_count`
- **Deduplication Applied:** `r ifelse(validation$deduplicated_count != validation$current_count, "Yes", "No")`

## Recommendations

```{r recommendations}
if (validation$is_valid) {
  cat("### Recommended Actions:")
  cat("\\n")
  cat("1. **Immediate Review:** Investigate the elevated case count for potential public health significance")
  cat("\\n")
  cat("2. **Data Verification:** Confirm the accuracy of case counts and classification")
  cat("\\n")
  cat("3. **Follow-up Monitoring:** Continue monitoring this syndrome for the next 7-14 days")
  cat("\\n")
  cat("4. **Stakeholder Notification:** Consider notifying relevant public health partners")
} else {
  cat("### Recommended Actions:")
  cat("\\n")
  cat("1. **No Action Required:** This alert has been classified as a false positive")
  cat("\\n")
  cat("2. **System Monitoring:** Continue routine monitoring for future alerts")
  cat("\\n")
  cat("3. **Threshold Review:** Consider reviewing validation thresholds if false positives become frequent")
}
```

---

*Report generated by AutoEpiBot - NSSP ESSENCE Alert Automation System*
')
  
  return(rmd_content)
}

# Create CSS styles for the report
create_report_styles <- function() {
  css_content <- '
/* AutoEpiBot Report Styles */

body {
  font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
  line-height: 1.6;
  color: #333;
}

h1, h2, h3, h4 {
  color: #2c3e50;
  border-bottom: 2px solid #ecf0f1;
  padding-bottom: 10px;
}

.alert-valid {
  background-color: #d4edda;
  border: 1px solid #c3e6cb;
  color: #155724;
  padding: 15px;
  border-radius: 5px;
  margin: 10px 0;
}

.alert-false-positive {
  background-color: #f8d7da;
  border: 1px solid #f5c6cb;
  color: #721c24;
  padding: 15px;
  border-radius: 5px;
  margin: 10px 0;
}

.table {
  margin: 20px 0;
}

.table th {
  background-color: #f8f9fa;
  font-weight: bold;
}

.recommendations {
  background-color: #e3f2fd;
  border-left: 4px solid #2196f3;
  padding: 15px;
  margin: 20px 0;
}

.technical-details {
  background-color: #f5f5f5;
  padding: 15px;
  border-radius: 5px;
  margin: 20px 0;
  font-family: "Courier New", monospace;
  font-size: 0.9em;
}
'
  
  return(css_content)
}

# Send summary email with all reports
send_summary_email <- function(results, config) {
  log_info("Preparing summary email")
  
  tryCatch({
    # Count results
    total_syndromes <- length(results)
    total_alerts <- 0
    valid_alerts <- 0
    false_positives <- 0
    
    for (syndrome_name in names(results)) {
      syndrome_results <- results[[syndrome_name]]
      if (syndrome_results$status != "no_alerts" && syndrome_results$status != "no_data") {
        for (date_result in syndrome_results) {
          if (is.list(date_result) && !is.null(date_result$status)) {
            total_alerts <- total_alerts + 1
            if (date_result$status == "sent") {
              valid_alerts <- valid_alerts + 1
            } else if (date_result$status == "false_positive") {
              false_positives <- false_positives + 1
            }
          }
        }
      }
    }
    
    # Create email content
    email_content <- create_summary_email_content(results, config)
    
    # Send email
    send_email(email_content, config)
    
    log_info(paste("Summary email sent with", total_alerts, "alerts processed"))
    
  }, error = function(e) {
    log_error(paste("Error sending summary email:", e$message))
  })
}

# Create summary email content
create_summary_email_content <- function(results, config) {
  # Build summary table
  summary_rows <- list()
  
  for (syndrome_name in names(results)) {
    syndrome_results <- results[[syndrome_name]]
    
    if (syndrome_results$status == "no_alerts") {
      summary_rows[[length(summary_rows) + 1]] <- list(
        syndrome = syndrome_name,
        date = "N/A",
        status = "No alerts",
        details = ""
      )
    } else if (syndrome_results$status == "no_data") {
      summary_rows[[length(summary_rows) + 1]] <- list(
        syndrome = syndrome_name,
        date = "N/A",
        status = "No data",
        details = ""
      )
    } else {
      for (date_name in names(syndrome_results)) {
        date_result <- syndrome_results[[date_name]]
        if (is.list(date_result) && !is.null(date_result$status)) {
          details <- if (date_result$status == "sent") {
            paste("Report generated:", date_result$report_path)
          } else if (date_result$status == "false_positive") {
            paste("Reason:", date_result$validation$reason)
          } else {
            ""
          }
          
          summary_rows[[length(summary_rows) + 1]] <- list(
            syndrome = syndrome_name,
            date = date_name,
            status = date_result$status,
            details = details
          )
        }
      }
    }
  }
  
  # Create email body
  email_body <- paste0(
    "<h2>AutoEpiBot Alert Summary</h2>",
    "<p><strong>Report Date:</strong> ", format(Sys.time(), "%B %d, %Y at %I:%M %p"), "</p>",
    "<p><strong>Total Syndromes Processed:</strong> ", length(results), "</p>",
    "<br>",
    "<h3>Alert Summary</h3>",
    "<table border='1' style='border-collapse: collapse; width: 100%;'>",
    "<tr style='background-color: #f2f2f2;'>",
    "<th style='padding: 8px; text-align: left;'>Syndrome</th>",
    "<th style='padding: 8px; text-align: left;'>Date</th>",
    "<th style='padding: 8px; text-align: left;'>Status</th>",
    "<th style='padding: 8px; text-align: left;'>Details</th>",
    "</tr>"
  )
  
  for (row in summary_rows) {
    status_color <- switch(row$status,
      "sent" = "#d4edda",
      "false_positive" = "#f8d7da",
      "no_alerts" = "#fff3cd",
      "no_data" = "#f8d7da",
      "#f8f9fa"
    )
    
    email_body <- paste0(email_body,
      "<tr style='background-color: ", status_color, ";'>",
      "<td style='padding: 8px;'>", row$syndrome, "</td>",
      "<td style='padding: 8px;'>", row$date, "</td>",
      "<td style='padding: 8px;'>", row$status, "</td>",
      "<td style='padding: 8px;'>", row$details, "</td>",
      "</tr>"
    )
  }
  
  email_body <- paste0(email_body,
    "</table>",
    "<br>",
    "<p><em>This report was generated automatically by AutoEpiBot.</em></p>"
  )
  
  return(email_body)
} 