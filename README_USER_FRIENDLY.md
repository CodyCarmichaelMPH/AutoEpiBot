# AutoEpiBot - User-Friendly Guide

## 🚀 Quick Start

### For New Users:
1. **Double-click `setup_autoeipbot.bat`** - This will guide you through initial setup
2. **Follow the setup wizard** - It will help you configure everything
3. **Double-click `run_autoeipbot.bat`** - This opens the main menu

### For Daily Use:
- **Double-click `quick_run.bat`** - Runs the daily check with one click
- **Double-click `run_autoeipbot.bat`** - Opens the full menu for more options

## 📋 Main Menu Options

When you run `run_autoeipbot.bat`, you'll see these options:

### [1] Run Daily Alert Check (Recommended)
- Checks the last 14 days for health alerts
- Sends email notifications if alerts are found
- Generates reports automatically

### [2] Run Manual Date Range Check
- Check a specific date range
- Enter start and end dates when prompted
- Useful for historical analysis

### [3] Test Run (No emails sent)
- Runs the system without sending emails
- Perfect for testing your configuration
- Safe to run anytime

### [4] Install/Update Packages
- Updates all required software packages
- Run this if you get package errors
- Only needed occasionally

### [5] View Recent Reports
- Opens the reports folder
- Shows all generated alert reports
- Reports are HTML files you can open in any browser

### [6] View System Logs
- Opens the logs folder
- Shows system activity and error logs
- Useful for troubleshooting

### [7] Open Configuration
- Opens the configuration file in Notepad
- Edit your API credentials, email settings, etc.
- Save the file when done

### [8] Exit
- Closes the program

## 🔧 Configuration

The system uses a file called `config.yaml` for all settings. You can edit this file by:

1. Running the main menu and selecting option 7
2. Or opening `config.yaml` directly in Notepad

### Key Settings to Configure:

**API Credentials:**
```yaml
api:
  username: "your_essence_username"
  password: "your_essence_password"
```

**Email Settings:**
```yaml
email:
  from_address: "your_email@yourdomain.com"
  to_addresses:
    - "recipient1@yourdomain.com"
    - "recipient2@yourdomain.com"
```

**Syndromes to Monitor:**
```yaml
syndromes:
  - name: "ILI v1"
    ccddCategory: "influenza%20like%20illness%20v1"
  - name: "COVID-like illness"
    ccddCategory: "covid%20like%20illness%20v1"
```

## 📁 File Structure

```
AutoEpiBot/
├── run_autoeipbot.bat          # Main menu (double-click this!)
├── quick_run.bat               # One-click daily check
├── setup_autoeipbot.bat        # Initial setup wizard
├── config.yaml                 # Configuration file
├── reports/                    # Generated reports (HTML files)
├── logs/                       # System logs
└── main.R                      # Main program (advanced users only)
```

## 🆘 Troubleshooting

### "R is not installed" Error
- Download and install R from https://cran.r-project.org/
- Make sure to install R version 4.3.0 or higher

### "Package installation failed" Error
- Run the main menu and select option 4
- This will reinstall all required packages

### "Configuration file not found" Error
- Run `setup_autoeipbot.bat` to create the configuration file
- Or copy `config_template.yaml` to `config.yaml`

### "API request failed" Error
- Check your username and password in `config.yaml`
- Make sure your NSSP ESSENCE credentials are correct
- Verify your internet connection

### "Email sending failed" Error
- Check your email settings in `config.yaml`
- Make sure your email address and SMTP settings are correct
- Try running a test run first (option 3)

## 📧 Email Notifications

The system sends two types of emails:

1. **Alert Emails** - Sent when a health alert is detected
   - Contains detailed information about the alert
   - Includes a link to the full report

2. **Leadership Report Emails** - Sent after each run
   - Summary of all alerts found
   - List of reports generated
   - Statistics and trends

## 📊 Reports

Reports are generated as HTML files in the `reports/` folder. Each report includes:

- **Alert Summary** - Key information about the alert
- **Time Series Analysis** - Charts showing trends over time
- **Demographic Analysis** - Age and gender breakdowns
- **Hospital Analysis** - Which hospitals reported cases
- **Time of Day Analysis** - When cases occurred

## 🔄 Automation

To run the system automatically every day:

1. **Windows Task Scheduler:**
   - Open Task Scheduler
   - Create a new task
   - Set the action to run `quick_run.bat`
   - Schedule it to run daily at 9:00 AM

2. **Or use the setup script:**
   - Run `scripts/windows11_setup.ps1` as administrator
   - This will set up automatic daily runs

## 📞 Support

If you need help:

1. **Check the logs** - Use option 6 in the main menu
2. **Run a test** - Use option 3 to test without sending emails
3. **Review configuration** - Use option 7 to check your settings
4. **Contact your IT support** - For technical issues

## 🎯 Tips for Success

- **Start with test runs** - Use option 3 to test your setup
- **Check logs regularly** - Use option 6 to monitor system health
- **Keep credentials updated** - Update your API credentials if they change
- **Review reports** - Check the reports folder for generated alerts
- **Set up automation** - Use Task Scheduler for daily automatic runs

---

**AutoEpiBot** - Making public health surveillance simple and accessible! 🏥 