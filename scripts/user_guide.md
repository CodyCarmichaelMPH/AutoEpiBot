# AutoEpiBot User Guide (Standard User)

## Overview
This guide is designed for users who do not have administrator privileges and need to run AutoEpiBot in a restricted IT environment.

## Prerequisites

### Required Software
- R 4.3.0 or later - Download from https://cran.r-project.org/
- Windows 11 (or Windows 10)
- PowerShell (built into Windows)

### IT Requirements
- Ability to install R on your machine
- Access to your user profile directory
- Internet access for API calls
- Email access (Outlook/Office 365)

## Installation

### Step 1: Install R
1. Download R from https://cran.r-project.org/
2. Run the installer as a standard user
3. Accept default installation settings
4. Verify installation by opening R or RStudio

### Step 2: Setup AutoEpiBot
1. Extract AutoEpiBot files to your desired location
2. Open PowerShell as a standard user
3. Navigate to the AutoEpiBot directory
4. Run the setup script:

```powershell
.\scripts\windows11_setup.ps1
```

This will:
- Create installation directory in your user profile
- Detect your R installation
- Create batch files for execution
- Create monitoring scripts
- Attempt to create a scheduled task (may require IT approval)

### Step 3: Configure the System
1. Edit `config.yaml` with your credentials:
   ```yaml
   api:
     username: "your_username"
     password: "your_password"
   
   email:
     from_address: "your_email@yourdomain.com"
     to_addresses:
       - "recipient@yourdomain.com"
   ```

2. Test the configuration:
   ```powershell
   & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" test_config.R
   ```

## Running AutoEpiBot

### Manual Execution
```powershell
# Run in dry-run mode (no emails sent)
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling --dry-run

# Run with email notifications
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling

# Run for specific date range
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode manual --startDate 2025-07-01 --endDate 2025-07-15
```

### Using the Batch File
```powershell
# Navigate to AutoEpiBot directory
cd $env:USERPROFILE\AutoEpiBot

# Run the batch file
.\run_autoeipbot.bat
```

### Using the Manual Script
```powershell
# Run the PowerShell script (includes pause)
.\run_manual.ps1
```

## Monitoring and Reports

### Check System Status
```powershell
.\check_status.ps1
```

### Generate Leadership Reports
```powershell
# Summary report
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" scripts\leadership_report.R --summary

# Export data
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" scripts\leadership_report.R --export my_report.csv
```

### View Logs
- **System logs**: `logs\autoeipbot_YYYY-MM-DD.log`
- **Alert logs**: `logs\autoeipbot_YYYY.csv` (yearly structure)
- **Reports**: `reports\` directory

## Scheduling (IT-Dependent)

### Option 1: Windows Task Scheduler (User Level)
1. Open Task Scheduler
2. Create Basic Task
3. Set trigger to daily at 9:00 AM (Pacific Time)
4. Set action to run: `$env:USERPROFILE\AutoEpiBot\run_autoeipbot.bat`
5. Run whether user is logged on or not

### Option 2: Manual Scheduling
- Set calendar reminders for 9:00 AM Pacific Time
- Use Windows Alarms & Clock
- Create recurring Outlook calendar events

### Option 3: IT Department
- Request IT to set up automated scheduling
- Provide them with the batch file location
- Ask for daily execution at 9:00 AM

## Troubleshooting

### Common Issues

#### "R not found" Error
- Verify R is installed: `& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" --version`
- Update the path in batch files if needed
- Contact IT if R installation is restricted

#### "Permission Denied" Errors
- Ensure you're running from your user profile directory
- Check that you have write permissions to the AutoEpiBot folder
- Try running from `$env:USERPROFILE\Documents\AutoEpiBot`

#### Email Not Sending
- Verify Outlook/Office 365 credentials in `config.yaml`
- Check with IT about email restrictions
- Test with `--dry-run` mode first

#### API Authentication Errors
- Verify NSSP ESSENCE credentials
- Check with your organization's API access
- Ensure internet connectivity

### Getting Help

#### Log Analysis
```powershell
# View latest log
Get-Content logs\autoeipbot_$(Get-Date -Format 'yyyy-MM-dd').log -Tail 20

# Search for errors
Get-Content logs\autoeipbot_$(Get-Date -Format 'yyyy-MM-dd').log | Select-String "ERROR"
```

#### Configuration Issues
```powershell
# Test configuration
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" test_config.R

# Validate email settings
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" -e "source('scripts/send_email.R'); config <- yaml::read_yaml('config.yaml'); cat('Email enabled:', config\$email\$enabled)"
```

## File Locations

### User Profile Structure
```
$env:USERPROFILE\AutoEpiBot\
├── main.R                    # Main script
├── config.yaml               # Configuration
├── run_autoeipbot.bat       # Batch file
├── run_manual.ps1           # Manual run script
├── check_status.ps1         # Status checker
├── logs\                    # Log files
├── reports\                 # Generated reports
└── scripts\                 # Script modules
```

### Desktop Shortcut
- Location: `$env:USERPROFILE\Desktop\AutoEpiBot.lnk`
- Double-click to run the system

## Security Considerations

### Credential Management
- Store credentials in `config.yaml` (not in scripts)
- Use environment variables if required by IT
- Never commit credentials to version control

### Network Access
- Ensure firewall allows outbound HTTPS connections
- Verify proxy settings if required by your organization
- Test API connectivity before deployment

### Data Privacy
- Logs contain alert information but no patient data
- Reports are generated locally
- Email notifications contain summary information only

## Support

### Internal Support
- Contact your IT department for system-level issues
- Work with your organization's API administrators
- Coordinate with email system administrators

### Documentation
- Check the `README.md` for technical details
- Review `wiki/Deployment.md` for advanced setup
- Examine log files for detailed error information

## Quick Reference

### Daily Operations
```powershell
# Morning check
.\check_status.ps1

# Manual run (if needed)
.\run_autoeipbot.bat

# Generate report
& "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" scripts\leadership_report.R --summary
```

### Weekly Tasks
- Review log files for errors
- Check report generation
- Verify email notifications
- Update credentials if needed

### Monthly Tasks
- Export leadership data
- Review system performance
- Update R packages if needed
- Backup configuration files 