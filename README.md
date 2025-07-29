# AutoEpiBot

**Automated Epidemiological Alert Detection and Reporting System**

AutoEpiBot is a comprehensive R-based system for automated syndromic surveillance alert detection, validation, and reporting. It provides real-time monitoring of emergency department data for early detection of public health events with enhanced demographic and temporal analysis.

## Features

### 🚨 **Alert Detection**
- Real-time monitoring of multiple syndromes
- Statistical validation using historical data
- Configurable thresholds and validation rules
- False positive reduction through multi-criteria validation

### 📊 **Comprehensive Reporting**
- Enhanced demographic analysis (age, gender, time patterns)
- Hospital distribution analysis
- Time series visualization
- Professional HTML reports with interactive charts
- Executive summaries for leadership

### 🔧 **Automation**
- Rolling window analysis
- Automated report generation
- Email notifications (optional)
- Logging and monitoring

### 📈 **Analytics**
- Z-score based statistical validation
- Historical trend analysis
- Demographic breakdowns
- Temporal pattern identification
- Hospital-specific analysis

## Quick Start

### 🚀 For New Users (Recommended)

**Option 1: GUI Interface (Most User-Friendly)**
1. **Double-click `launch_gui.bat`** - Opens a modern GUI interface
2. **Click "🔧 Setup Wizard"** - Follow the guided setup
3. **Click "🔄 Run Daily Check"** - Start monitoring alerts

**Option 2: Menu-Driven Interface**
1. **Double-click `setup_autoeipbot.bat`** - Run the setup wizard
2. **Double-click `run_autoeipbot.bat`** - Opens a menu-driven interface
3. **Select option 1** - Run daily alert check

**Option 3: One-Click Daily Run**
1. **Double-click `quick_run.bat`** - Runs daily check with one click

### 🔧 For Advanced Users

**Prerequisites:**
- R 4.0+ with required packages
- Access to ESSENCE API
- Windows PowerShell (for setup scripts)

**Installation:**

1. **Clone the repository**
   ```bash
   git clone https://github.com/CodyCarmichaelMPH/AutoEpiBot.git
   cd AutoEpiBot
   ```

2. **Install R packages**
   
   **Option A: Using PowerShell (Recommended)**
   ```powershell
   # Find R installation and run package installation
   $rPath = Get-ChildItem "C:\Program Files\R" -Directory | Sort-Object Name -Descending | Select-Object -First 1
   & "$($rPath.FullName)\bin\Rscript.exe" install_packages.R
   ```
   
   **Option B: Using Command Prompt**
   ```cmd
   # Find R installation and run package installation
   "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" install_packages.R
   ```
   
   **Option C: Using R GUI**
   ```r
   # Open R GUI and run:
   source("install_packages.R")
   ```

3. **Configure the system**
   ```cmd
   # Copy the template configuration
   copy config_template.yaml config.yaml
   # Edit config.yaml with your settings
   ```

4. **Run the system**
   
   **Option A: Using PowerShell**
   ```powershell
   # Test run
   & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling --dry-run
   
   # Production run
   & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling
   ```
   
   **Option B: Using Command Prompt**
   ```cmd
   # Test run
   "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling --dry-run
   
   # Production run
   "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling
   ```
   
   **Option C: Using the provided batch files (after setup)**
   ```cmd
   # Run the setup script first
   powershell -ExecutionPolicy Bypass -File scripts\windows11_setup.ps1
   
   # Then use the created batch files
   run_manual.bat
   ```

## Configuration

### API Settings
```yaml
api:
  base_url: "https://your-essence-instance.com"
  username: "your_username"
  password: "your_password"
```

### Syndrome Definitions
```yaml
syndromes:
  - name: "Influenza-like Illness"
    ccddCategory: "cdc"
    datasource: "va"
    medical_grouping: "influenza"
    cc_and_discharge: "true"
    multi_detector: "true"
```

### Validation Parameters
```yaml
validation:
  historical_days: 30
  z_score_threshold: 2.0
  min_count_threshold: 5
```

## Usage

### Command Line Options
- `--mode rolling`: Perform rolling window analysis
- `--mode historical`: Analyze historical data
- `--dry-run`: Test mode without generating reports
- `--date YYYY-MM-DD`: Analyze specific date

### Example Commands

**Using PowerShell (Recommended)**
```powershell
# Test the system
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling --dry-run

# Run for specific date
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling --date 2024-01-15

# Production run
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling
```

**Using Command Prompt**
```cmd
# Test the system
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling --dry-run

# Run for specific date
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling --date 2024-01-15

# Production run
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling
```

## Report Features

### Executive Summary
- Alert status and validation results
- Statistical significance testing
- Key metrics and ratios

### Demographic Analysis
- Age and gender distribution
- Population breakdowns
- Age category analysis

### Time Series Analysis
- Daily visit trends
- Temporal patterns
- Historical comparisons

### Hospital Analysis
- Facility-specific breakdowns
- Geographic distribution
- Resource utilization patterns

### Time of Day Analysis
- Hourly visit patterns
- Temporal clustering
- Operational insights

## File Structure

```
AutoEpiBot/
├── main.R                 # Main application entry point
├── config.yaml           # Configuration file (create from template)
├── config_template.yaml  # Configuration template
├── install_packages.R    # Package installation script
├── scripts/
│   ├── generate_report.R    # Report generation
│   ├── pull_timeseries.R    # Data retrieval
│   ├── validate_alert.R     # Alert validation
│   ├── send_email.R         # Email notifications
│   └── helpers/
│       └── logging.R        # Logging utilities
├── reports/              # Generated reports
├── logs/                 # System logs
└── wiki/                 # Documentation
```

## API Integration

AutoEpiBot integrates with ESSENCE (Electronic Surveillance System for the Early Notification of Community-based Epidemics) API to:

- Pull real-time emergency department data
- Retrieve historical time series data
- Access detailed demographic information
- Generate comprehensive reports

## Validation Logic

The system uses multiple criteria for alert validation:

1. **Statistical Significance**: Z-score based on historical data
2. **Minimum Count Threshold**: Ensures sufficient data for analysis
3. **Historical Context**: Compares against 30-day baseline
4. **Trend Analysis**: Identifies sustained increases vs. single-day spikes

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Troubleshooting

### Common Windows Issues

**"Rscript is not recognized"**
- R is not in your system PATH
- Use the full path: `"C:\Program Files\R\R-4.5.1\bin\Rscript.exe"`
- Or use PowerShell with automatic R detection

**"Execution Policy Error"**
- Run PowerShell as Administrator
- Execute: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

**"R Version Not Found"**
- Check your R installation path: `dir "C:\Program Files\R"`
- Update the path in commands to match your R version

**"Package Installation Fails"**
- Ensure internet connection
- Try using R GUI: `source("install_packages.R")`
- Check R version compatibility (R 4.0+ required)

### Finding Your R Installation
```powershell
# PowerShell command to find R installations
Get-ChildItem "C:\Program Files\R" -Directory | Sort-Object Name -Descending
```

## Support

For questions or support, please open an issue on GitHub or contact the development team.

## Acknowledgments

- Built for public health surveillance
- Inspired by SyndromicEpiAlert system
- Designed for automated epidemiological monitoring

---

**AutoEpiBot** - Automated Epidemiological Alert Detection and Reporting 