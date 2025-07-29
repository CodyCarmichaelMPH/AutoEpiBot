# AutoEpiBot GUI Application
# Modern Windows GUI for AutoEpiBot

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "AutoEpiBot - NSSP ESSENCE Alert System"
$form.Size = New-Object System.Drawing.Size(600,500)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::WhiteSmoke

# Create title label
$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "AutoEpiBot Alert System"
$titleLabel.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.ForeColor = [System.Drawing.Color]::DarkBlue
$titleLabel.Location = New-Object System.Drawing.Point(200, 20)
$titleLabel.Size = New-Object System.Drawing.Size(300, 30)
$titleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($titleLabel)

# Create subtitle
$subtitleLabel = New-Object System.Windows.Forms.Label
$subtitleLabel.Text = "NSSP ESSENCE Multi-Syndrome Alert Automation"
$subtitleLabel.Font = New-Object System.Drawing.Font("Arial", 10)
$subtitleLabel.ForeColor = [System.Drawing.Color]::Gray
$subtitleLabel.Location = New-Object System.Drawing.Point(150, 50)
$subtitleLabel.Size = New-Object System.Drawing.Size(400, 20)
$subtitleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$form.Controls.Add($subtitleLabel)

# Create status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Ready to run"
$statusLabel.Font = New-Object System.Drawing.Font("Arial", 9)
$statusLabel.ForeColor = [System.Drawing.Color]::Green
$statusLabel.Location = New-Object System.Drawing.Point(20, 420)
$statusLabel.Size = New-Object System.Drawing.Size(300, 20)
$form.Controls.Add($statusLabel)

# Function to update status
function Update-Status {
    param($message, $color = "Green")
    $statusLabel.Text = $message
    $statusLabel.ForeColor = [System.Drawing.Color]::$color
    $form.Refresh()
}

# Function to run R script
function Run-RScript {
    param([string]$arguments)
    Update-Status "Running AutoEpiBot..." "Blue"
    
    try {
        $rscriptPath = "C:\Program Files\R\R-4.5.1\bin\Rscript.exe"
        
        # Check if R is installed
        if (-not (Test-Path $rscriptPath)) {
            throw "R is not installed or not found at expected location"
        }
        
        # Split arguments properly
        $argArray = $arguments -split '\s+'
        
        $process = Start-Process -FilePath $rscriptPath -ArgumentList $argArray -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -eq 0) {
            Update-Status "Completed successfully!" "Green"
            [System.Windows.Forms.MessageBox]::Show("AutoEpiBot completed successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            Update-Status "Error occurred" "Red"
            [System.Windows.Forms.MessageBox]::Show("AutoEpiBot encountered an error. Check the logs for details.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    } catch {
        Update-Status "Failed to run" "Red"
        [System.Windows.Forms.MessageBox]::Show("Failed to run AutoEpiBot: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# Create buttons
$buttonY = 100
$buttonHeight = 40
$buttonWidth = 200

# Daily Check Button
$dailyButton = New-Object System.Windows.Forms.Button
$dailyButton.Text = "Run Daily Check"
$dailyButton.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$dailyButton.Location = New-Object System.Drawing.Point(50, $buttonY)
$dailyButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$dailyButton.BackColor = [System.Drawing.Color]::LightBlue
$dailyButton.Add_Click({ Run-RScript "main.R --mode rolling" })
$form.Controls.Add($dailyButton)

# Test Run Button
$testButton = New-Object System.Windows.Forms.Button
$testButton.Text = "Test Run"
$testButton.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$testButton.Location = New-Object System.Drawing.Point(300, $buttonY)
$testButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$testButton.BackColor = [System.Drawing.Color]::LightYellow
$testButton.Add_Click({ Run-RScript "main.R --mode rolling --dry-run" })
$form.Controls.Add($testButton)

# Manual Check Button
$manualButton = New-Object System.Windows.Forms.Button
$manualButton.Text = "Manual Date Range"
$manualButton.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$manualButton.Location = New-Object System.Drawing.Point(50, ($buttonY + 60))
$manualButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$manualButton.BackColor = [System.Drawing.Color]::LightGreen
$manualButton.Add_Click({
    $startDate = [Microsoft.VisualBasic.Interaction]::InputBox("Enter start date (YYYY-MM-DD):", "Start Date", "2025-07-01")
    if ($startDate -ne "") {
        $endDate = [Microsoft.VisualBasic.Interaction]::InputBox("Enter end date (YYYY-MM-DD):", "End Date", "2025-07-20")
        if ($endDate -ne "") {
            Run-RScript "main.R --mode manual --startDate $startDate --endDate $endDate"
        }
    }
})
$form.Controls.Add($manualButton)

# Install Packages Button
$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = "Install Packages"
$installButton.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$installButton.Location = New-Object System.Drawing.Point(300, ($buttonY + 60))
$installButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$installButton.BackColor = [System.Drawing.Color]::LightCoral
$installButton.Add_Click({ Run-RScript "install_packages.R" })
$form.Controls.Add($installButton)

# Open Reports Button
$reportsButton = New-Object System.Windows.Forms.Button
$reportsButton.Text = "Open Reports"
$reportsButton.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$reportsButton.Location = New-Object System.Drawing.Point(50, ($buttonY + 120))
$reportsButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$reportsButton.BackColor = [System.Drawing.Color]::LightSteelBlue
$reportsButton.Add_Click({ 
    if (Test-Path "reports") {
        Start-Process "reports"
    } else {
        [System.Windows.Forms.MessageBox]::Show("Reports folder not found.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})
$form.Controls.Add($reportsButton)

# Open Logs Button
$logsButton = New-Object System.Windows.Forms.Button
$logsButton.Text = "Open Logs"
$logsButton.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$logsButton.Location = New-Object System.Drawing.Point(300, ($buttonY + 120))
$logsButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$logsButton.BackColor = [System.Drawing.Color]::LightGray
$logsButton.Add_Click({ 
    if (Test-Path "logs") {
        Start-Process "logs"
    } else {
        [System.Windows.Forms.MessageBox]::Show("Logs folder not found.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})
$form.Controls.Add($logsButton)

# Configure Button
$configButton = New-Object System.Windows.Forms.Button
$configButton.Text = "Configure"
$configButton.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$configButton.Location = New-Object System.Drawing.Point(50, ($buttonY + 180))
$configButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$configButton.BackColor = [System.Drawing.Color]::LightSalmon
$configButton.Add_Click({ 
    if (Test-Path "config.yaml") {
        Start-Process "notepad" -ArgumentList "config.yaml"
    } else {
        [System.Windows.Forms.MessageBox]::Show("Configuration file not found. Run setup first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})
$form.Controls.Add($configButton)

# Setup Button
$setupButton = New-Object System.Windows.Forms.Button
$setupButton.Text = "Setup Wizard"
$setupButton.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$setupButton.Location = New-Object System.Drawing.Point(300, ($buttonY + 180))
$setupButton.Size = New-Object System.Drawing.Size($buttonWidth, $buttonHeight)
$setupButton.BackColor = [System.Drawing.Color]::LightPink
$setupButton.Add_Click({ 
    if (Test-Path "setup_autoeipbot.bat") {
        Start-Process "setup_autoeipbot.bat"
    } else {
        [System.Windows.Forms.MessageBox]::Show("Setup file not found.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
})
$form.Controls.Add($setupButton)

# Exit Button
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "Exit"
$exitButton.Font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
$exitButton.Location = New-Object System.Drawing.Point(175, ($buttonY + 240))
$exitButton.Size = New-Object System.Drawing.Size(100, 35)
$exitButton.BackColor = [System.Drawing.Color]::LightCoral
$exitButton.Add_Click({ $form.Close() })
$form.Controls.Add($exitButton)

# Show form
$form.ShowDialog() 