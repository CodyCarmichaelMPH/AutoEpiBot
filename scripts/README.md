# AutoEpiBot Scripts

This directory contains the core modules for the AutoEpiBot system. Each script is designed to be modular and focused on a specific aspect of the alert processing workflow.

## 📁 Module Overview

### Core Modules

#### `pull_timeseries.R`
**Purpose**: NSSP ESSENCE API data retrieval and processing

**Key Functions**:
- `pull_timeseries()` - Retrieves time series data for syndromes
- `pull_data_details()` - Gets detailed case data for alert dates
- `pull_historical_timeseries()` - Fetches historical data for validation

**Inputs**: Syndrome configuration, date range, API config
**Outputs**: Data frames with time series or detailed case data

#### `validate_alert.R`
**Purpose**: Alert validation and false positive detection

**Key Functions**:
- `validate_alert()` - Main validation workflow
- `perform_validation_checks()` - Statistical validation logic
- `is_alert_processed()` - Duplicate detection
- `load_alert_log()` - Alert history management

**Inputs**: Syndrome data, historical data, validation config
**Outputs**: Validation results with statistical measures

#### `generate_report.R`
**Purpose**: HTML report generation using RMarkdown

**Key Functions**:
- `generate_report()` - Creates HTML reports for valid alerts
- `create_report_content()` - Builds RMarkdown content
- `create_report_styles()` - CSS styling for reports
- `send_summary_email()` - Email with report attachments

**Inputs**: Validation results, syndrome info, alert date
**Outputs**: Professional HTML reports with charts and analysis

#### `send_email.R`
**Purpose**: Email notification system

**Key Functions**:
- `send_email()` - Core email sending functionality
- `send_alert_email()` - Individual alert notifications
- `send_test_email()` - Email configuration testing
- `validate_email_config()` - Email settings validation

**Inputs**: Email content, recipient list, SMTP config
**Outputs**: Email delivery status

### Helper Modules

#### `helpers/logging.R`
**Purpose**: Centralized logging system

**Key Functions**:
- `init_logging()` - Initialize logging configuration
- `log_info()`, `log_error()`, `log_warn()`, `log_debug()` - Log levels
- `log_system_info()` - System diagnostics
- `log_performance()` - Performance monitoring

**Features**:
- Configurable log levels (DEBUG, INFO, WARN, ERROR)
- File and console output
- Timestamp formatting
- Performance tracking

## 🔄 Data Flow

```
1. main.R
   ↓
2. pull_timeseries.R (API calls)
   ↓
3. validate_alert.R (statistical analysis)
   ↓
4. generate_report.R (HTML creation)
   ↓
5. send_email.R (notifications)
```

## 📊 Data Structures

### Time Series Data
```r
data.frame(
  date = as.Date("2025-01-01"),
  count = 15,
  expected = 12.5,
  levels = 2.3,
  colorID = 2,
  color = "Yellow",
  altText = "Alert description"
)
```

### Validation Results
```r
list(
  is_valid = TRUE,
  reason = "Alert validated successfully",
  current_count = 15,
  expected_count = 12.5,
  historical_mean = 11.2,
  expected_ratio = 1.2,
  historical_ratio = 1.34,
  z_score = 2.1
)
```

### Alert Log Entry
```r
data.frame(
  date = as.Date("2025-01-01"),
  syndrome = "ILI v1",
  alert_type = "Yellow",
  status = "sent",
  timestamp = Sys.time()
)
```

## 🛠️ Error Handling

Each module implements comprehensive error handling:

- **API Errors**: Network timeouts, authentication failures
- **Data Errors**: Missing columns, invalid formats
- **File Errors**: Permission issues, disk space
- **Email Errors**: SMTP failures, invalid addresses

All errors are logged with context and the system continues processing other syndromes.

## 🔧 Configuration Dependencies

### Required Config Sections
- `api`: Authentication and base URL
- `syndromes`: Syndrome definitions
- `output`: File paths for reports and logs
- `validation`: Statistical thresholds
- `email`: SMTP settings (optional)
- `logging`: Log level and formatting

### Environment Variables
- `R_LIBS_USER`: R package library path
- `TZ`: Timezone for date handling

## 📈 Performance Considerations

### API Optimization
- 30-second timeouts for API calls
- Parallel processing not implemented (API rate limits)
- Caching of historical data (future enhancement)

### Memory Management
- Data frames cleaned after processing
- Large datasets processed in chunks
- Log rotation to prevent disk space issues

### Processing Speed
- Typical runtime: 2-5 minutes for 3 syndromes
- Bottleneck: API response times
- Optimization: Reduce syndrome count if needed

## 🧪 Testing

### Unit Tests
```r
# Test API connectivity
test_api_connection(config)

# Test validation logic
test_validation_checks()

# Test email configuration
test_email_send(config)
```

### Integration Tests
```r
# End-to-end workflow
test_full_workflow()

# Error handling
test_error_scenarios()

# Performance benchmarks
test_performance_metrics()
```

## 🔍 Debugging

### Debug Mode
```r
# Enable debug logging
config$logging$level <- "DEBUG"

# Run with verbose output
Rscript main.R --mode rolling
```

### Common Debug Scenarios
1. **API Authentication**: Check credentials and permissions
2. **Data Quality**: Verify syndrome CCDD categories
3. **Email Delivery**: Test SMTP configuration
4. **Report Generation**: Check RMarkdown dependencies

### Log Analysis
```bash
# View debug information
grep "DEBUG" logs/autoeipbot_*.log

# Check API responses
grep "API" logs/autoeipbot_*.log

# Monitor performance
grep "Performance" logs/autoeipbot_*.log
```

## 📚 Dependencies

### R Packages
- `yaml`: Configuration parsing
- `httr`: API requests
- `jsonlite`: JSON parsing
- `dplyr`: Data manipulation
- `lubridate`: Date handling
- `rmarkdown`: Report generation
- `blastula`: Email sending
- `ggplot2`: Chart creation
- `knitr`: Report formatting
- `kableExtra`: Table styling

### System Requirements
- R 4.0+
- Internet connectivity for API calls
- Write permissions for logs and reports
- SMTP access for email (optional)

## 🔄 Maintenance

### Regular Tasks
- Monitor log file sizes
- Review alert log for patterns
- Update syndrome definitions as needed
- Test email configuration monthly
- Backup configuration files

### Updates
- Check for R package updates
- Review API documentation changes
- Test with new syndrome categories
- Validate email provider settings

---

*For detailed API documentation, see the main README.md file.* 