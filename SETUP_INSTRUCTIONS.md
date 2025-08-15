# AutoEpiBot Setup Instructions

## Quick Start Guide for New Computers

### 1. Clone the Repository
```bash
git clone https://github.com/CodyCarmichaelMPH/AutoEpiBot.git
cd AutoEpiBot
```

### 2. Install Required R Packages
Open R or RStudio and run:
```r
# Core packages
install.packages(c(
  "shiny", "httr", "jsonlite", "dplyr", "readr", 
  "purrr", "plotly", "glue", "leaflet", "tidyr", "stringr"
))

# For email functionality (Windows only)
install.packages("RDCOMClient")
```

### 3. Open the R Project
- Double-click `AutoEpi.Rproj` to open in RStudio
- Or set your working directory to the AutoEpiBot folder

### 4. Configure Settings
Run the GUI to set up your configuration:
```r
source("GUI.R")
```

This opens a Shiny app where you need to configure:
- **ESSENCE Credentials** (username/password)
- **Date ranges** and lookback periods
- **Folder locations** for logs and reports
- **Syndrome list file** (use the included SyndromeSheets/Syndrome_Master_List.csv)
- **Report settings** (which graphs/maps to generate)

### 5. Test the Workflow

#### Option A: Full Workflow (requires ESSENCE access)
```r
# Step 1: Initialize logging system
source("LogsCreate.R")

# Step 2: Pull time series data from ESSENCE
source("TSCreate.R")

# Step 3: Analyze and filter alerts
source("TSInvestigate.R")

# Step 4: Generate reports and visualizations
source("ReportCreator.R")

# Step 5: Create email summary
source("EmailCreator.R")
```

#### Option B: Test with Mock Data (no ESSENCE needed)
```r
# Load the test diagnostic script
source("test_data.R")
```

### 6. Folder Structure After Setup
```
AutoEpiBot/
├── GUI.R                    # Configuration interface
├── LogsCreate.R            # Initialize logging
├── TSCreate.R              # Data collection
├── TSInvestigate.R         # Analysis & filtering
├── ReportCreator.R         # Visualizations & mapping
├── EmailCreator.R          # Email summaries
├── SyndromeSheets/         # Syndrome definitions
│   ├── Syndrome_Master_List.csv
│   └── Test_Master_List.csv
├── AutoEpi_Settings.RData  # Your settings (created by GUI)
├── Logs/                   # Log files (created at runtime)
├── Reports/                # Generated reports (created at runtime)
└── TestLogs/               # Sample logs (if using test data)
```

## Troubleshooting

### Common Issues:
1. **Package installation fails**: Make sure R is updated to latest version
2. **ESSENCE API errors**: Verify credentials and network access
3. **File path issues**: Use forward slashes (/) in all paths, even on Windows
4. **Email not working**: RDCOMClient requires Microsoft Outlook installed

### Testing Without ESSENCE Access:
If you don't have ESSENCE credentials, you can still test the visualization and email components by creating mock data files.

### Support:
For issues after November 1, 2025, contact Cody Carmichael, MPH, CPH at codymicah.carmichael@gmail.com
