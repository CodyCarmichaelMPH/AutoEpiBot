@echo off
title AutoEpiBot - Quick Daily Check
color 0E

echo.
echo ========================================
echo      AutoEpiBot Daily Check
echo ========================================
echo.
echo Starting daily health alert check...
echo This will check the last 14 days for alerts.
echo.

"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling

echo.
echo Daily check completed!
echo Check the reports folder for any generated reports.
echo.
pause 