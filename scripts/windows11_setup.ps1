# AutoEpiBot Windows 11 Setup Script (Standard User Version)
# PowerShell script for Windows 11 deployment without admin privileges

param(
    [string]$InstallPath = "$env:USERPROFILE\AutoEpiBot",
    [string]$UserName = $env:USERNAME,
    [switch]$CreateDesktopShortcut = $true
)

Write-Host "AutoEpiBot Windows 11 Setup (Standard User)" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green

# Check if running as administrator (warn but don't require)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) {
    Write-Host "Running as administrator - some features may not work in standard user mode" -ForegroundColor Yellow
} else {
    Write-Host "Running as standard user - this is the recommended mode" -ForegroundColor Green
}

# Check Windows version
$os = Get-WmiObject -Class Win32_OperatingSystem
if ($os.Caption -notlike "*Windows 11*") {
    Write-Host "Warning: This script is designed for Windows 11. Current OS: $($os.Caption)" -ForegroundColor Yellow
}

# Create installation directory in user profile
Write-Host "Creating installation directory..." -ForegroundColor Yellow
if (!(Test-Path $InstallPath)) {
    try {
        New-Item -ItemType Directory -Path $InstallPath -Force
        Write-Host "Created directory: $InstallPath" -ForegroundColor Green
    } catch {
        Write-Host "Error creating directory: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Trying alternative location..." -ForegroundColor Yellow
        $InstallPath = "$env:USERPROFILE\Documents\AutoEpiBot"
        New-Item -ItemType Directory -Path $InstallPath -Force
        Write-Host "Created directory: $InstallPath" -ForegroundColor Green
    }
} else {
    Write-Host "Directory already exists: $InstallPath" -ForegroundColor Green
}

# Check R installation
Write-Host "Checking R installation..." -ForegroundColor Yellow
$rPaths = @(
    "C:\Program Files\R\R-4.5.1\bin\Rscript.exe",
    "C:\Program Files\R\R-4.4.0\bin\Rscript.exe",
    "C:\Program Files\R\R-4.3.0\bin\Rscript.exe"
)

$rPath = $null
foreach ($path in $rPaths) {
    if (Test-Path $path) {
        $rPath = $path
        break
    }
}

if ($rPath) {
    Write-Host "R found: $rPath" -ForegroundColor Green
} else {
    Write-Host "R not found. Please install R 4.3.0 or later." -ForegroundColor Red
    Write-Host "Download from: https://cran.r-project.org/" -ForegroundColor Yellow
    Write-Host "After installation, run this script again." -ForegroundColor Yellow
}

# Create batch file for execution
$batchContent = @"
@echo off
cd /d "$InstallPath"
"$rPath" main.R --mode rolling
"@

$batchPath = "$InstallPath\run_autoeipbot.bat"
$batchContent | Out-File -FilePath $batchPath -Encoding ASCII
Write-Host "Created batch file: $batchPath" -ForegroundColor Green

# Create PowerShell script for monitoring
$psContent = @"
# AutoEpiBot Monitoring Script
param([string]`$LogPath = "$InstallPath\logs")

Write-Host "AutoEpiBot Status Check" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green

# Check if log directory exists
if (Test-Path `$LogPath) {
    `$latestLog = Get-ChildItem -Path `$LogPath -Filter "autoeipbot_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if (`$latestLog) {
        Write-Host "Latest log file: `$(`$latestLog.Name)" -ForegroundColor Green
        Write-Host "Last modified: `$(`$latestLog.LastWriteTime)" -ForegroundColor Green
        
        # Check for errors
        `$errors = Get-Content `$latestLog.FullName | Select-String "ERROR"
        if (`$errors) {
            Write-Host "Found `$(`$errors.Count) errors in latest log" -ForegroundColor Red
        } else {
            Write-Host "No errors found in latest log" -ForegroundColor Green
        }
        
        # Check for successful completion
        `$success = Get-Content `$latestLog.FullName | Select-String "AutoEpiBot completed successfully"
        if (`$success) {
            Write-Host "Last run completed successfully" -ForegroundColor Green
        } else {
            Write-Host "Last run may not have completed successfully" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No log files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "Log directory not found: `$LogPath" -ForegroundColor Red
}
"@

$psPath = "$InstallPath\check_status.ps1"
$psContent | Out-File -FilePath $psPath -Encoding UTF8
Write-Host "Created monitoring script: $psPath" -ForegroundColor Green

# Create Task Scheduler task (user-level)
Write-Host "Creating scheduled task..." -ForegroundColor Yellow
$taskName = "AutoEpiBot Daily Run"
$taskAction = New-ScheduledTaskAction -Execute $batchPath
$taskTrigger = New-ScheduledTaskTrigger -Daily -At 9:00AM
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun

try {
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -User $UserName -RunLevel Limited
    Write-Host "Created scheduled task: $taskName" -ForegroundColor Green
    Write-Host "Task will run daily at 9:00 AM" -ForegroundColor Green
} catch {
    Write-Host "Error creating scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "You may need to run this manually or contact your IT department for scheduling." -ForegroundColor Yellow
}

# Create desktop shortcut if requested
if ($CreateDesktopShortcut) {
    Write-Host "Creating desktop shortcut..." -ForegroundColor Yellow
    try {
        $shortcutPath = "$env:USERPROFILE\Desktop\AutoEpiBot.lnk"
        $WshShell = New-Object -comObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $batchPath
        $shortcut.WorkingDirectory = $InstallPath
        $shortcut.Description = "AutoEpiBot - NSSP ESSENCE Alert System"
        $shortcut.Save()
        Write-Host "Created desktop shortcut: $shortcutPath" -ForegroundColor Green
    } catch {
        Write-Host "Error creating desktop shortcut: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Create manual run script
$manualScript = @"
# AutoEpiBot Manual Run Script
Write-Host "AutoEpiBot Manual Run" -ForegroundColor Green
Write-Host "====================" -ForegroundColor Green
Write-Host "Running AutoEpiBot in manual mode..." -ForegroundColor Yellow
& "$rPath" main.R --mode rolling --dry-run
Write-Host "Press any key to continue..."
`$null = `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
"@

$manualPath = "$InstallPath\run_manual.ps1"
$manualScript | Out-File -FilePath $manualPath -Encoding UTF8
Write-Host "Created manual run script: $manualPath" -ForegroundColor Green

Write-Host "`nSetup completed!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Copy AutoEpiBot files to: $InstallPath" -ForegroundColor White
Write-Host "2. Update config.yaml with your credentials" -ForegroundColor White
Write-Host "3. Test the system with: $batchPath" -ForegroundColor White
Write-Host "4. Monitor with: $psPath" -ForegroundColor White
Write-Host "5. Manual run: $manualPath" -ForegroundColor White
Write-Host "`nNote: If scheduled tasks don't work, you can:" -ForegroundColor Cyan
Write-Host "- Run manually using the batch file" -ForegroundColor White
Write-Host "- Use Windows Task Scheduler manually" -ForegroundColor White
Write-Host "- Contact your IT department for automation" -ForegroundColor White 