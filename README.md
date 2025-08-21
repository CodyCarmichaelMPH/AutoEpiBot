# AutoEpiBot

Automated epidemiological surveillance system for syndromic surveillance using NSSP ESSENCE data.

## Overview

AutoEpiBot is an R-based system that automates the process of:
1. **Data Collection**: Pulling time-series data from NSSP ESSENCE
2. **Alert Detection**: Identifying potential outbreaks based on statistical thresholds
3. **Report Generation**: Creating detailed HTML reports with visualizations
4. **Email Notifications**: Sending daily summaries via Microsoft Graph API

## Prerequisites

- **R** (version 4.0 or higher)
- **RStudio** (recommended)
- **Microsoft 365 Account** (for email notifications)
- **NSSP ESSENCE Access** (credentials required)

## Installation

### 1. Install Required R Packages

Run the installation script to install all required packages:

```r
source("install_packages.R")
```

### 2. Initial Setup

1. **Run GUI.R** to configure your settings:
   ```r
   source("GUI.R")
   ```
   - Set your ESSENCE credentials
   - Configure email settings
   - Set up file paths
   - Select climate stations
   - Choose syndromes to monitor

2. **Create Logs Directory**:
   ```r

source("LogsCreate.R")
   ```

## Usage Tutorial

### Step 1: Initial Configuration

1. **Open GUI.R** in RStudio
2. **Configure Settings**:
   - **Credentials**: Enter your NSSP ESSENCE username and password
   - **Email Settings**: Add recipient email addresses
   - **File Paths**: Set directories for logs, reports, and data
   - **Climate Stations**: Select weather stations to monitor
   - **Syndromes**: Choose which syndromes to track
3. **Save Settings**: Click "Save Settings" to create `AutoEpi_Settings.RData`

### Step 2: Daily Workflow

The complete workflow consists of these steps (run in order):

#### 2.1 Data Collection and Alert Detection
```r
source("TSCreate.R")
```
- Pulls time-series data from ESSENCE
- Calculates alert levels based on statistical thresholds
- Creates `InvestigateTSRecords.RData` for flagged records
- Updates `autoepi_logs.csv` with new entries

#### 2.2 Investigation (Optional)
```r
source("TSInvestigate.R")
```
- Performs detailed investigation of flagged records
- Queries visit-level data for potential outbreaks
- Updates logs with False Positive classifications
- Creates `reportsData.RData` for confirmed signals

#### 2.3 Report Generation
```r
source("ReportCreator.R")
```
- Generates comprehensive reports for flagged syndromes
- Creates visualizations (counts, rates, maps)
- Saves reports as `AutoEpi_Report_YYYY-MM-DD.RData`

#### 2.4 HTML Report Rendering
```r
source("render_autoepi_reports.R")
```
- Converts RData reports to HTML format
- Creates interactive visualizations
- Saves HTML files in `Rendered/` directory
- Updates logs with report locations

#### 2.5 Email Notification
```r
source("EmailCreator.R")
```
- Sends daily summary email via Microsoft Graph
- Includes links to generated reports
- Updates logs with email status
- Cleans up temporary files

### Step 3: Automated Execution

For automated daily runs, use the main runner script:

```r
source("AutoEpiBot_Runner.R")
```

This script:
- Runs all steps in sequence
- Handles errors gracefully
- Logs all activities
- Sends email notifications

## File Structure

```
AutoEpiBot/
├── GUI.R                          # Configuration interface
├── AutoEpiBot_Runner.R            # Main execution script
├── TSCreate.R                     # Data collection & alert detection
├── TSInvestigate.R                # Detailed investigation
├── ReportCreator.R                # Report generation
├── render_autoepi_reports.R       # HTML rendering
├── EmailCreator.R                 # Email notifications
├── LogsCreate.R                   # Log initialization
├── install_packages.R             # Package installation
├── autoepi_report_template.Rmd    # HTML report template
├── SyndromeSheets/                # Syndrome definitions
├── TestLogs/                      # Test data
├── ZipLayer/                      # Geographic data
└── Documentation/                 # Additional documentation
```

## Configuration Files

- **AutoEpi_Settings.RData**: Main configuration (created by GUI.R)
- **LogsFileLoc.RData**: Log file location
- **autoepi_logs.csv**: Main log file with all activities

## Output Files

- **AutoEpi_Report_YYYY-MM-DD.RData**: Generated reports
- **Rendered/YYYY-MM-DD/**: HTML reports and visualizations
- **EmailStarterInfo.RData**: Email metadata
- **InvestigateTSRecords.RData**: Investigation data

## Alert Levels

The system uses these alert levels:
- **Normal**: No significant increase
- **Warning**: Moderate increase (colorID = 2)
- **Alert**: Significant increase (colorID ≥ 3)
- **False Positive**: Initially flagged but later determined to be normal
- NOTE: For now, curtailed to allow for shipping; future implementation will make this displayed as an ease of eval step.
## Troubleshooting

### Common Issues

1. **ESSENCE Authentication Error**:
   - Verify credentials in GUI.R
   - Check network connectivity
   - Ensure ESSENCE access is active

2. **Email Not Sending**:
   - Verify Microsoft 365 account is signed in
   - Check email settings in GUI.R
   - Ensure Microsoft365R package is installed

3. **Missing Reports**:
   - Check that ReportCreator.R completed successfully
   - Verify file paths in settings
   - Check for sufficient disk space

### Debug Mode

Run individual scripts with debug output:
```r
# Enable debug mode
options(verbose = TRUE)
source("TSCreate.R")
```

## Support

For issues or questions:
1. Check the console output for error messages
2. Review the log files in your configured logs directory
3. Verify all prerequisites are installed
4. Ensure file paths are correctly configured

## License

This software is developed for epidemiological surveillance and public health monitoring.
