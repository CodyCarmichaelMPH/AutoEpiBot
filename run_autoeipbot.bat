@echo off
title AutoEpiBot - NSSP ESSENCE Alert System
color 0A

echo.
echo ========================================
echo         AutoEpiBot Alert System
echo ========================================
echo.
echo Welcome to AutoEpiBot!
echo This system monitors NSSP ESSENCE for health alerts.
echo.

:menu
echo Please select an option:
echo.
echo [1] Run Daily Alert Check (Recommended)
echo [2] Run Manual Date Range Check
echo [3] Test Run (No emails sent)
echo [4] Install/Update Packages
echo [5] View Recent Reports
echo [6] View System Logs
echo [7] Open Configuration
echo [8] Exit
echo.
set /p choice="Enter your choice (1-8): "

if "%choice%"=="1" goto daily
if "%choice%"=="2" goto manual
if "%choice%"=="3" goto test
if "%choice%"=="4" goto install
if "%choice%"=="5" goto reports
if "%choice%"=="6" goto logs
if "%choice%"=="7" goto config
if "%choice%"=="8" goto exit
echo Invalid choice. Please try again.
goto menu

:daily
echo.
echo Running daily alert check...
echo This will check the last 14 days for alerts.
echo.
pause
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling
echo.
echo Daily check completed!
pause
goto menu

:manual
echo.
echo Manual Date Range Check
echo.
set /p startdate="Enter start date (YYYY-MM-DD): "
set /p enddate="Enter end date (YYYY-MM-DD): "
echo.
echo Running manual check from %startdate% to %enddate%...
pause
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode manual --startDate %startdate% --endDate %enddate%
echo.
echo Manual check completed!
pause
goto menu

:test
echo.
echo Running test run (no emails will be sent)...
echo.
pause
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling --dry-run
echo.
echo Test run completed!
pause
goto menu

:install
echo.
echo Installing/Updating R packages...
echo This may take a few minutes...
echo.
pause
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" install_packages.R
echo.
echo Package installation completed!
pause
goto menu

:reports
echo.
echo Opening reports folder...
start reports
goto menu

:logs
echo.
echo Opening logs folder...
start logs
goto menu

:config
echo.
echo Opening configuration file...
notepad config.yaml
goto menu

:exit
echo.
echo Thank you for using AutoEpiBot!
echo.
pause
exit 