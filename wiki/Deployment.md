# AutoEpiBot Deployment Guide

This guide covers deploying AutoEpiBot in production environments on Windows 10/11 systems, including setup, monitoring, and maintenance procedures.

## System Requirements

### Minimum Specifications
- **OS**: Windows 10 (version 1903+) or Windows 11
- **CPU**: 2 cores
- **RAM**: 4GB
- **Storage**: 10GB available space
- **Network**: Internet connectivity for API calls

### Recommended Specifications
- **OS**: Windows 11
- **CPU**: 4 cores
- **RAM**: 8GB
- **Storage**: 50GB SSD
- **Network**: Stable broadband connection

## Installation Steps

### 1. System Preparation

#### Windows 10/11
1. Download R from [CRAN](https://cran.r-project.org/)
2. Install R with default settings (R 4.3.0 or later recommended)
3. Verify installation by opening R or RStudio
4. Ensure PowerShell 5.0 or later is available

### 2. R Package Installation

```r
# Install required packages
packages <- c(
  "yaml", "httr", "jsonlite", "dplyr", "lubridate",
  "rmarkdown", "blastula", "ggplot2", "knitr", "kableExtra"
)

install.packages(packages, dependencies = TRUE)
```

### 3. AutoEpiBot Installation

#### Standard User Installation
```powershell
# Extract AutoEpiBot files to user profile
# Navigate to AutoEpiBot directory
cd $env:USERPROFILE\AutoEpiBot

# Run setup script
.\scripts\windows11_setup.ps1
```

#### Administrator Installation (if available)
```powershell
# Run as administrator for system-wide installation
.\scripts\windows11_setup.ps1 -InstallPath "C:\AutoEpiBot"
```

### 4. Configuration Setup

```powershell
# Edit configuration file
notepad config.yaml

# Or use PowerShell to edit
powershell -Command "notepad config.yaml"
```

## Production Configuration

### Environment Variables

Create user environment variables in Windows:

```bash
# R configuration
export R_LIBS_USER="/opt/autoeipbot/r_libs"
export TZ="America/New_York"

# AutoEpiBot paths
export AUTOEIPBOT_HOME="/opt/autoeipbot"
export AUTOEIPBOT_CONFIG="/opt/autoeipbot/config.yaml"
```

### Service Configuration

#### Systemd Service (Linux)

Create `/etc/systemd/system/autoeipbot.service`:

```ini
[Unit]
Description=AutoEpiBot NSSP ESSENCE Alert Automation
After=network.target

[Service]
Type=oneshot
User=autoeipbot
Group=autoeipbot
WorkingDirectory=/opt/autoeipbot
Environment=R_LIBS_USER=/opt/autoeipbot/r_libs
Environment=TZ=America/New_York
ExecStart=/usr/bin/Rscript main.R --mode rolling
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

#### Windows Task Scheduler

1. Create batch file `$env:USERPROFILE\AutoEpiBot\run_autoeipbot.bat`:
```batch
@echo off
cd /d "$env:USERPROFILE\AutoEpiBot"
Rscript main.R --mode rolling
```

2. Schedule task:
   - **Trigger**: Daily at 9:00 AM (Pacific Time)
   - **Action**: Start program `$env:USERPROFILE\AutoEpiBot\run_autoeipbot.bat`
   - **User**: Current user account
   - **Run Level**: Limited (standard user permissions)

### Manual Scheduling (Alternative)

For environments where Task Scheduler is not available:

1. **Windows Alarms & Clock**:
   - Set daily reminder at 9:00 AM
   - Action: Run `$env:USERPROFILE\AutoEpiBot\run_autoeipbot.bat`

2. **Outlook Calendar**:
   - Create recurring daily appointment
   - Include batch file path in description

3. **PowerShell Scheduled Job**:
```powershell
Register-ScheduledJob -Name "AutoEpiBot" -ScriptBlock {
    Set-Location "$env:USERPROFILE\AutoEpiBot"
    & "C:\Program Files\R\R-4.5.1\bin\Rscript.exe" main.R --mode rolling
} -Trigger (New-JobTrigger -Daily -At 9:00AM)
```

## Security Configuration

### User Setup

For standard user deployment:
- No additional user creation required
- Uses current user account
- User profile-based installation

For administrator deployment:
```powershell
# Create service account (if administrator access available)
New-LocalUser -Name "AutoEpiBot" -Description "AutoEpiBot Service Account" -AccountNeverExpires
Add-LocalGroupMember -Group "Users" -Member "AutoEpiBot"
```

### File Permissions

```powershell
# Secure configuration files (if administrator access available)
icacls config.yaml /inheritance:r /grant:r "%USERNAME%:F"
icacls scripts\ /inheritance:r /grant:r "%USERNAME%:F"
icacls logs\ /inheritance:r /grant:r "%USERNAME%:F"
```

### Network Security

```powershell
# Windows Firewall configuration (if administrator access available)
netsh advfirewall firewall add rule name="AutoEpiBot HTTPS" dir=out action=allow protocol=TCP localport=any remoteport=443
netsh advfirewall firewall add rule name="AutoEpiBot SMTP" dir=out action=allow protocol=TCP localport=any remoteport=587
```

## Monitoring Setup

### Log Monitoring

#### Windows Log Rotation

Create PowerShell script for log rotation:

```powershell
# Create log rotation script
$logScript = @"
# AutoEpiBot Log Rotation Script
param([string]`$LogPath = "$env:USERPROFILE\AutoEpiBot\logs")

# Remove logs older than 30 days
Get-ChildItem -Path `$LogPath -Filter "*.log" | Where-Object { `$_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item

# Remove CSV logs older than 1 year
Get-ChildItem -Path `$LogPath -Filter "*.csv" | Where-Object { `$_.LastWriteTime -lt (Get-Date).AddYears(-1) } | Remove-Item
"@

$rotationPath = "$env:USERPROFILE\AutoEpiBot\rotate_logs.ps1"
$logScript | Out-File -FilePath $rotationPath -Encoding UTF8
```

#### Log Analysis Script

Create `$env:USERPROFILE\AutoEpiBot\check_status.ps1`:

```powershell
# AutoEpiBot Status Check Script
param([string]$LogPath = "$env:USERPROFILE\AutoEpiBot\logs")

Write-Host "AutoEpiBot Status Check" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green

# Check if log directory exists
if (Test-Path $LogPath) {
    $latestLog = Get-ChildItem -Path $LogPath -Filter "autoeipbot_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    if ($latestLog) {
        Write-Host "Latest log file: $($latestLog.Name)" -ForegroundColor Green
        Write-Host "Last modified: $($latestLog.LastWriteTime)" -ForegroundColor Green
        
        # Check for errors
        $errors = Get-Content $latestLog.FullName | Select-String "ERROR"
        if ($errors) {
            Write-Host "Found $($errors.Count) errors in latest log" -ForegroundColor Red
        } else {
            Write-Host "No errors found in latest log" -ForegroundColor Green
        }
        
        # Check for successful completion
        $success = Get-Content $latestLog.FullName | Select-String "AutoEpiBot completed successfully"
        if ($success) {
            Write-Host "Last run completed successfully" -ForegroundColor Green
        } else {
            Write-Host "Last run may not have completed successfully" -ForegroundColor Yellow
        }
    } else {
        Write-Host "No log files found" -ForegroundColor Yellow
    }
} else {
    Write-Host "Log directory not found: $LogPath" -ForegroundColor Red
}
```

### Health Checks

#### System Health Script

Create `$env:USERPROFILE\AutoEpiBot\health_check.ps1`:

```powershell
# AutoEpiBot Health Check Script
param([string]$InstallPath = "$env:USERPROFILE\AutoEpiBot")

Write-Host "AutoEpiBot Health Check" -ForegroundColor Green
Write-Host "=====================" -ForegroundColor Green

# Check disk space
$drive = (Get-Item $InstallPath).PSDrive
$diskUsage = [math]::Round((($drive.Used / $drive.Free) * 100), 2)
if ($diskUsage -gt 90) {
    Write-Host "WARNING: Disk usage is ${diskUsage}%" -ForegroundColor Red
} else {
    Write-Host "Disk usage: ${diskUsage}%" -ForegroundColor Green
}

# Check memory usage
$memory = Get-Counter '\Memory\Available MBytes'
$memoryUsage = [math]::Round((($memory.CounterSamples[0].CookedValue / 1024) * 100), 2)
if ($memoryUsage -gt 90) {
    Write-Host "WARNING: Memory usage is ${memoryUsage}%" -ForegroundColor Red
} else {
    Write-Host "Memory usage: ${memoryUsage}%" -ForegroundColor Green
}

# Check R installation
$rPath = "C:\Program Files\R\R-4.5.1\bin\Rscript.exe"
if (Test-Path $rPath) {
    Write-Host "R installation: Found" -ForegroundColor Green
} else {
    Write-Host "ERROR: R installation not found" -ForegroundColor Red
}

# Check configuration file
$configPath = "$InstallPath\config.yaml"
if (Test-Path $configPath) {
    Write-Host "Configuration file: Found" -ForegroundColor Green
} else {
    Write-Host "ERROR: Configuration file not found" -ForegroundColor Red
}

Write-Host "Health check completed" -ForegroundColor Green
```

### Monitoring Integration

#### Windows Event Log Integration

Create `$env:USERPROFILE\AutoEpiBot\event_log.ps1`:

```powershell
# AutoEpiBot Event Log Integration
param([string]$LogPath = "$env:USERPROFILE\AutoEpiBot\logs")

# Check for latest log file
$latestLog = Get-ChildItem -Path $LogPath -Filter "autoeipbot_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($latestLog) {
    # Check for successful completion
    $success = Get-Content $latestLog.FullName | Select-String "AutoEpiBot completed successfully"
    if ($success) {
        Write-EventLog -LogName Application -Source "AutoEpiBot" -EventId 1000 -EntryType Information -Message "AutoEpiBot completed successfully"
    } else {
        Write-EventLog -LogName Application -Source "AutoEpiBot" -EventId 1001 -EntryType Error -Message "AutoEpiBot did not complete successfully"
    }
} else {
    Write-EventLog -LogName Application -Source "AutoEpiBot" -EventId 1002 -EntryType Warning -Message "No AutoEpiBot log file found"
}
```

## 🔄 Backup Strategy

### Configuration Backup

```bash
# Create backup script
cat > /opt/autoeipbot/scripts/backup.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/opt/autoeipbot/backups"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

mkdir -p "$BACKUP_DIR"

# Backup configuration
cp config.yaml "$BACKUP_DIR/config_$DATE.yaml"

# Backup logs (last 7 days)
tar -czf "$BACKUP_DIR/logs_$DATE.tar.gz" logs/

# Backup reports (last 30 days)
tar -czf "$BACKUP_DIR/reports_$DATE.tar.gz" reports/

# Clean old backups (keep 30 days)
find "$BACKUP_DIR" -name "*.yaml" -mtime +30 -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete

echo "Backup completed: $DATE"
EOF

chmod +x /opt/autoeipbot/scripts/backup.sh
```

### Automated Backup

```bash
# Add to crontab
0 2 * * * /opt/autoeipbot/scripts/backup.sh >> /opt/autoeipbot/logs/backup.log 2>&1
```

## 🚨 Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check service status
systemctl status autoeipbot

# Check logs
journalctl -u autoeipbot -f

# Test manual execution
sudo -u autoeipbot Rscript main.R --mode rolling
```

#### API Connection Issues
```bash
# Test API connectivity
curl -u "username:password" "https://essence.syndromicsurveillance.org/nssp_essence/api/timeSeries"

# Check network connectivity
ping essence.syndromicsurveillance.org

# Verify credentials
grep -A 2 "api:" config.yaml
```

#### Email Delivery Problems
```bash
# Test SMTP connection
telnet smtp.gmail.com 587

# Check email configuration
grep -A 5 "email:" config.yaml

# Test email sending
Rscript -e "source('scripts/send_email.R'); config <- yaml::read_yaml('config.yaml'); send_test_email(config)"
```

### Performance Issues

#### High Memory Usage
```bash
# Monitor memory usage
ps aux | grep Rscript

# Check for memory leaks
Rscript -e "gc(); print(memory.size())"
```

#### Slow Processing
```bash
# Profile execution time
time Rscript main.R --mode rolling

# Check API response times
grep "API request" logs/autoeipbot_*.log | tail -10
```

## 📈 Scaling Considerations

### Horizontal Scaling
- Deploy multiple instances for different regions
- Use load balancer for API requests
- Implement shared storage for logs and reports

### Vertical Scaling
- Increase server resources based on syndrome count
- Optimize R memory settings
- Implement caching for historical data

### Performance Optimization
```r
# R memory settings
options(memory.limit = 4096)  # 4GB limit
gc()  # Force garbage collection

# Parallel processing (future enhancement)
library(parallel)
num_cores <- detectCores() - 1
```

## 🔄 Maintenance Schedule

### Daily Tasks
- Monitor log files for errors
- Check disk space usage
- Verify email delivery

### Weekly Tasks
- Review alert patterns
- Update syndrome definitions if needed
- Test backup restoration

### Monthly Tasks
- Update R packages
- Review performance metrics
- Validate API credentials
- Test disaster recovery procedures

### Quarterly Tasks
- Security audit
- Performance optimization review
- Documentation updates
- Training for new team members

---

*For additional support, consult the main README.md and scripts documentation.* 