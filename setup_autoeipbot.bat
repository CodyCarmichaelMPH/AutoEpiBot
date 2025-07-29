@echo off
title AutoEpiBot Setup Wizard
color 0B

echo.
echo ========================================
echo      AutoEpiBot Setup Wizard
echo ========================================
echo.
echo Welcome to AutoEpiBot Setup!
echo This wizard will help you configure the system.
echo.

echo Step 1: Checking R installation...
"C:\Program Files\R\R-4.5.1\bin\R.exe" --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: R is not installed or not found!
    echo Please install R from https://cran.r-project.org/
    echo Make sure to install R version 4.3.0 or higher.
    pause
    exit /b 1
)
echo ✓ R is installed and working
echo.

echo Step 2: Installing required packages...
echo This may take a few minutes...
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" install_packages.R
if %errorlevel% neq 0 (
    echo ERROR: Package installation failed!
    pause
    exit /b 1
)
echo ✓ Packages installed successfully
echo.

echo Step 3: Configuration Setup
echo.
echo You need to configure the following settings:
echo - NSSP ESSENCE API credentials
echo - Email settings for notifications
echo - Syndrome definitions to monitor
echo.
echo The configuration file will open in Notepad.
echo Please update the following fields:
echo.
echo API Section:
echo - username: Your NSSP ESSENCE username
echo - password: Your NSSP ESSENCE password
echo.
echo Email Section:
echo - from_address: Your email address
echo - to_addresses: List of recipients
echo.
echo Save the file when done.
echo.
pause

if not exist config.yaml (
    copy config_template.yaml config.yaml
)
notepad config.yaml

echo.
echo Step 4: Testing Configuration
echo.
echo Would you like to test the configuration now?
set /p test="Run a test (y/n): "
if /i "%test%"=="y" (
    echo.
    echo Running test...
    "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling --dry-run
    echo.
    echo Test completed!
)

echo.
echo ========================================
echo      Setup Complete!
echo ========================================
echo.
echo AutoEpiBot is now configured and ready to use!
echo.
echo To run the system:
echo 1. Double-click "run_autoeipbot.bat"
echo 2. Select option 1 for daily checks
echo 3. Or select option 3 for test runs
echo.
echo The system will automatically:
echo - Check for health alerts daily
echo - Generate reports for valid alerts
echo - Send email notifications
echo - Log all activities
echo.
pause 