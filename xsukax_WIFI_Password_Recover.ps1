#Requires -RunAsAdministrator
<#
.SYNOPSIS
    xsukax WIFI Password Recover - Complete GUI Application
.DESCRIPTION
    Professional WiFi password recovery tool for Windows 10/11
    Retrieves and displays saved WiFi profiles with passwords
.AUTHOR
    xsukax
.VERSION
    2.0.1
.NOTES
    Requires Administrator privileges
    Compatible with Windows 10 and Windows 11
#>

# =============================================================================
# INITIALIZATION AND LOGGING SETUP
# =============================================================================

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptDir "xsukax_WIFI_Recover_Log.txt"
$script:logInitialized = $false

function Initialize-Log {
    try {
        $header = @"
================================================================================
xsukax WIFI Password Recover - Session Log
================================================================================
Session Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Script Version: 2.0.1
Script Path: $($MyInvocation.ScriptName)
PowerShell Version: $($PSVersionTable.PSVersion.ToString())
OS Version: $([System.Environment]::OSVersion.VersionString)
Computer Name: $env:COMPUTERNAME
User: $env:USERNAME
Working Directory: $scriptDir
Log File: $logFile
================================================================================

"@
        Set-Content -Path $logFile -Value $header -Encoding UTF8 -Force
        $script:logInitialized = $true
        return $true
    }
    catch {
        $script:logInitialized = $false
        return $false
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "DEBUG"   { Write-Host $logMessage -ForegroundColor Cyan }
        default   { Write-Host $logMessage }
    }
    
    # File output
    if ($script:logInitialized) {
        try {
            Add-Content -Path $logFile -Value $logMessage -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            # Silently fail if log file is locked
        }
    }
}

# Initialize logging
Initialize-Log | Out-Null
Write-Log "Application starting..." "INFO"

# =============================================================================
# LOAD REQUIRED ASSEMBLIES
# =============================================================================

try {
    Write-Log "Loading System.Windows.Forms assembly..." "INFO"
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Write-Log "System.Windows.Forms loaded successfully" "SUCCESS"
    
    Write-Log "Loading System.Drawing assembly..." "INFO"
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    Write-Log "System.Drawing loaded successfully" "SUCCESS"
}
catch {
    Write-Log "CRITICAL: Failed to load required assemblies - $($_.Exception.Message)" "ERROR"
    [System.Windows.Forms.MessageBox]::Show(
        "Failed to load required Windows Forms assemblies.`n`nError: $($_.Exception.Message)`n`nLog: $logFile",
        "Critical Error - xsukax WIFI Password Recover",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}

# =============================================================================
# GLOBAL VARIABLES
# =============================================================================

$script:allWifiData = @()
$script:isScanning = $false

# =============================================================================
# WIFI RETRIEVAL FUNCTIONS
# =============================================================================

function Get-SafeRegexMatch {
    param(
        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [string]$InputString,
        
        [Parameter(Mandatory=$true)]
        [string]$Pattern,
        
        [Parameter(Mandatory=$false)]
        [int]$GroupIndex = 1
    )
    
    try {
        # Return null for empty or null strings
        if ([string]::IsNullOrWhiteSpace($InputString)) {
            return $null
        }
        
        if ($InputString -match $Pattern) {
            if ($matches.Count -gt $GroupIndex) {
                return $matches[$GroupIndex].Trim()
            }
        }
        return $null
    }
    catch {
        Write-Log "Regex match error: $($_.Exception.Message)" "WARNING"
        return $null
    }
}

function Get-WiFiProfileList {
    try {
        Write-Log "Executing netsh command to retrieve WiFi profile list..." "INFO"
        
        $output = netsh wlan show profiles 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -ne 0) {
            Write-Log "netsh command failed with exit code: $exitCode" "ERROR"
            throw "Failed to execute netsh command. WiFi adapter may be disabled or unavailable."
        }
        
        $profiles = @()
        foreach ($line in $output) {
            # Skip null or empty lines
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            
            $profileName = Get-SafeRegexMatch -InputString $line -Pattern "All User Profile\s*:\s*(.+)"
            if ($profileName -and -not [string]::IsNullOrWhiteSpace($profileName)) {
                $profiles += $profileName
                Write-Log "Found profile: $profileName" "DEBUG"
            }
        }
        
        Write-Log "Found $($profiles.Count) WiFi profiles" "SUCCESS"
        return $profiles
    }
    catch {
        Write-Log "Error retrieving WiFi profile list: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Get-WiFiProfileDetails {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProfileName
    )
    
    try {
        Write-Log "Retrieving details for profile: $ProfileName" "DEBUG"
        
        $output = netsh wlan show profile name="$ProfileName" key=clear 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -ne 0) {
            Write-Log "Failed to retrieve profile '$ProfileName' (exit code: $exitCode)" "WARNING"
            return $null
        }
        
        $outputText = $output -join "`n"
        
        # Extract SSID (use profile name as fallback)
        $ssid = $ProfileName
        
        # Extract Authentication
        $authentication = Get-SafeRegexMatch -InputString $outputText -Pattern "Authentication\s*:\s*(.+)"
        if (-not $authentication) { $authentication = "N/A" }
        
        # Extract Cipher/Encryption
        $encryption = Get-SafeRegexMatch -InputString $outputText -Pattern "Cipher\s*:\s*(.+)"
        if (-not $encryption) { $encryption = "N/A" }
        
        # Extract Password/Key Content
        $password = Get-SafeRegexMatch -InputString $outputText -Pattern "Key Content\s*:\s*(.+)"
        if (-not $password) { $password = "N/A" }
        
        Write-Log "Profile '$ProfileName': Auth=$authentication, Enc=$encryption, Pass=$($password -ne 'N/A')" "DEBUG"
        
        return [PSCustomObject]@{
            SSID = $ssid
            Password = $password
            Authentication = $authentication
            Encryption = $encryption
        }
    }
    catch {
        Write-Log "Error processing profile '$ProfileName': $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Get-AllWiFiProfiles {
    param(
        [Parameter(Mandatory=$false)]
        [scriptblock]$ProgressCallback
    )
    
    try {
        $script:isScanning = $true
        Write-Log "Starting WiFi profile scan..." "INFO"
        
        # Get profile list
        $profileNames = Get-WiFiProfileList
        
        if ($profileNames.Count -eq 0) {
            Write-Log "No WiFi profiles found on this system" "WARNING"
            return @()
        }
        
        $results = @()
        $total = $profileNames.Count
        $current = 0
        
        foreach ($profileName in $profileNames) {
            $current++
            
            # Update progress
            if ($ProgressCallback) {
                & $ProgressCallback -Current $current -Total $total -ProfileName $profileName
            }
            
            # Get profile details
            $profileData = Get-WiFiProfileDetails -ProfileName $profileName
            
            if ($profileData) {
                $results += $profileData
            }
            else {
                Write-Log "Skipping profile '$profileName' due to errors" "WARNING"
            }
        }
        
        Write-Log "WiFi scan completed. Retrieved $($results.Count) profiles successfully." "SUCCESS"
        $script:isScanning = $false
        
        return $results
    }
    catch {
        $script:isScanning = $false
        Write-Log "Error in Get-AllWiFiProfiles: $($_.Exception.Message)" "ERROR"
        throw
    }
}

# =============================================================================
# UI HELPER FUNCTIONS
# =============================================================================

function Update-StatusLabel {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.Label]$Label,
        
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [Parameter(Mandatory=$false)]
        [System.Drawing.Color]$Color = [System.Drawing.Color]::Black
    )
    
    $Label.Text = $Text
    $Label.ForeColor = $Color
    $Label.Refresh()
}

function Populate-DataGrid {
    param(
        [Parameter(Mandatory=$true)]
        [System.Windows.Forms.DataGridView]$Grid,
        
        [Parameter(Mandatory=$true)]
        [array]$Data
    )
    
    try {
        $Grid.Rows.Clear()
        
        foreach ($item in $Data) {
            $rowIndex = $Grid.Rows.Add()
            $row = $Grid.Rows[$rowIndex]
            
            $row.Cells["SSID"].Value = $item.SSID
            $row.Cells["Password"].Value = $item.Password
            $row.Cells["Authentication"].Value = $item.Authentication
            $row.Cells["Encryption"].Value = $item.Encryption
            
            # Color coding
            if ($item.Password -eq "N/A") {
                $row.Cells["Password"].Style.ForeColor = [System.Drawing.Color]::Gray
                $row.Cells["Password"].Style.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Italic)
            }
            else {
                $row.Cells["Password"].Style.ForeColor = [System.Drawing.Color]::DarkGreen
                $row.Cells["Password"].Style.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
            }
        }
        
        Write-Log "DataGrid populated with $($Data.Count) rows" "DEBUG"
    }
    catch {
        Write-Log "Error populating DataGrid: $($_.Exception.Message)" "ERROR"
    }
}

function Filter-WiFiData {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Data,
        
        [Parameter(Mandatory=$true)]
        [string]$SearchTerm
    )
    
    if ([string]::IsNullOrWhiteSpace($SearchTerm)) {
        return $Data
    }
    
    return $Data | Where-Object {
        $_.SSID -like "*$SearchTerm*" -or
        $_.Password -like "*$SearchTerm*" -or
        $_.Authentication -like "*$SearchTerm*" -or
        $_.Encryption -like "*$SearchTerm*"
    }
}

# =============================================================================
# MAIN GUI CREATION
# =============================================================================

try {
    Write-Log "Creating main application window..." "INFO"
    
    # Main Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "xsukax WIFI Password Recover v2.0.1"
    $form.Size = New-Object System.Drawing.Size(920, 680)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 250)
    $form.Icon = [System.Drawing.SystemIcons]::Shield
    
    # =========================================================================
    # HEADER SECTION
    # =========================================================================
    
    $headerPanel = New-Object System.Windows.Forms.Panel
    $headerPanel.Location = New-Object System.Drawing.Point(0, 0)
    $headerPanel.Size = New-Object System.Drawing.Size(920, 80)
    $headerPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $form.Controls.Add($headerPanel)
    
    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Location = New-Object System.Drawing.Point(20, 15)
    $titleLabel.Size = New-Object System.Drawing.Size(880, 35)
    $titleLabel.Text = "xsukax WIFI Password Recover"
    $titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
    $titleLabel.ForeColor = [System.Drawing.Color]::White
    $titleLabel.BackColor = [System.Drawing.Color]::Transparent
    $titleLabel.TextAlign = "MiddleLeft"
    $headerPanel.Controls.Add($titleLabel)
    
    $subtitleLabel = New-Object System.Windows.Forms.Label
    $subtitleLabel.Location = New-Object System.Drawing.Point(20, 50)
    $subtitleLabel.Size = New-Object System.Drawing.Size(880, 25)
    $subtitleLabel.Text = "Professional WiFi Password Recovery Tool"
    $subtitleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $subtitleLabel.ForeColor = [System.Drawing.Color]::FromArgb(200, 220, 255)
    $subtitleLabel.BackColor = [System.Drawing.Color]::Transparent
    $subtitleLabel.TextAlign = "MiddleLeft"
    $headerPanel.Controls.Add($subtitleLabel)
    
    # =========================================================================
    # TOOLBAR SECTION
    # =========================================================================
    
    $toolbarPanel = New-Object System.Windows.Forms.Panel
    $toolbarPanel.Location = New-Object System.Drawing.Point(20, 100)
    $toolbarPanel.Size = New-Object System.Drawing.Size(880, 50)
    $toolbarPanel.BackColor = [System.Drawing.Color]::White
    $toolbarPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($toolbarPanel)
    
    # Scan Button
    $scanButton = New-Object System.Windows.Forms.Button
    $scanButton.Location = New-Object System.Drawing.Point(20, 10)
    $scanButton.Size = New-Object System.Drawing.Size(120, 30)
    $scanButton.Text = "Scan WiFi"
    $scanButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $scanButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $scanButton.ForeColor = [System.Drawing.Color]::White
    $scanButton.FlatStyle = "Flat"
    $scanButton.FlatAppearance.BorderSize = 0
    $scanButton.Cursor = "Hand"
    $toolbarPanel.Controls.Add($scanButton)
    
    # Export Button
    $exportButton = New-Object System.Windows.Forms.Button
    $exportButton.Location = New-Object System.Drawing.Point(150, 10)
    $exportButton.Size = New-Object System.Drawing.Size(120, 30)
    $exportButton.Text = "Export Data"
    $exportButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $exportButton.BackColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
    $exportButton.ForeColor = [System.Drawing.Color]::White
    $exportButton.FlatStyle = "Flat"
    $exportButton.FlatAppearance.BorderSize = 0
    $exportButton.Cursor = "Hand"
    $toolbarPanel.Controls.Add($exportButton)
    
    # Copy Button
    $copyButton = New-Object System.Windows.Forms.Button
    $copyButton.Location = New-Object System.Drawing.Point(280, 10)
    $copyButton.Size = New-Object System.Drawing.Size(120, 30)
    $copyButton.Text = "Copy Selected"
    $copyButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $copyButton.BackColor = [System.Drawing.Color]::FromArgb(106, 90, 205)
    $copyButton.ForeColor = [System.Drawing.Color]::White
    $copyButton.FlatStyle = "Flat"
    $copyButton.FlatAppearance.BorderSize = 0
    $copyButton.Cursor = "Hand"
    $toolbarPanel.Controls.Add($copyButton)
    
    # View Log Button
    $logButton = New-Object System.Windows.Forms.Button
    $logButton.Location = New-Object System.Drawing.Point(410, 10)
    $logButton.Size = New-Object System.Drawing.Size(120, 30)
    $logButton.Text = "View Log"
    $logButton.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $logButton.BackColor = [System.Drawing.Color]::FromArgb(96, 96, 96)
    $logButton.ForeColor = [System.Drawing.Color]::White
    $logButton.FlatStyle = "Flat"
    $logButton.FlatAppearance.BorderSize = 0
    $logButton.Cursor = "Hand"
    $toolbarPanel.Controls.Add($logButton)
    
    # =========================================================================
    # STATUS SECTION
    # =========================================================================
    
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(20, 160)
    $statusLabel.Size = New-Object System.Drawing.Size(880, 25)
    $statusLabel.Text = "Ready. Click 'Scan WiFi' to retrieve saved networks."
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $form.Controls.Add($statusLabel)
    
    # =========================================================================
    # DATA GRID SECTION
    # =========================================================================
    
    $dataGridView = New-Object System.Windows.Forms.DataGridView
    $dataGridView.Location = New-Object System.Drawing.Point(20, 195)
    $dataGridView.Size = New-Object System.Drawing.Size(880, 390)
    $dataGridView.BackgroundColor = [System.Drawing.Color]::White
    $dataGridView.BorderStyle = "Fixed3D"
    $dataGridView.AllowUserToAddRows = $false
    $dataGridView.AllowUserToDeleteRows = $false
    $dataGridView.AllowUserToResizeRows = $false
    $dataGridView.ReadOnly = $true
    $dataGridView.SelectionMode = "FullRowSelect"
    $dataGridView.MultiSelect = $false
    $dataGridView.AutoSizeColumnsMode = "Fill"
    $dataGridView.ColumnHeadersHeightSizeMode = "AutoSize"
    $dataGridView.RowHeadersVisible = $false
    $dataGridView.Font = New-Object System.Drawing.Font("Consolas", 9)
    $dataGridView.EnableHeadersVisualStyles = $false
    $dataGridView.ColumnHeadersDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 212)
    $dataGridView.ColumnHeadersDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
    $dataGridView.ColumnHeadersDefaultCellStyle.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $dataGridView.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(240, 248, 255)
    
    # Define Columns
    $colSSID = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colSSID.HeaderText = "WiFi Network (SSID)"
    $colSSID.Name = "SSID"
    $colSSID.FillWeight = 30
    $dataGridView.Columns.Add($colSSID) | Out-Null
    
    $colPassword = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colPassword.HeaderText = "Password"
    $colPassword.Name = "Password"
    $colPassword.FillWeight = 30
    $dataGridView.Columns.Add($colPassword) | Out-Null
    
    $colAuth = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colAuth.HeaderText = "Authentication"
    $colAuth.Name = "Authentication"
    $colAuth.FillWeight = 20
    $dataGridView.Columns.Add($colAuth) | Out-Null
    
    $colEncryption = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $colEncryption.HeaderText = "Encryption"
    $colEncryption.Name = "Encryption"
    $colEncryption.FillWeight = 20
    $dataGridView.Columns.Add($colEncryption) | Out-Null
    
    $form.Controls.Add($dataGridView)
    
    # =========================================================================
    # FOOTER SECTION
    # =========================================================================
    
    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Location = New-Object System.Drawing.Point(0, 595)
    $footerPanel.Size = New-Object System.Drawing.Size(920, 50)
    $footerPanel.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 240)
    $footerPanel.BorderStyle = "FixedSingle"
    $form.Controls.Add($footerPanel)
    
    $footerLabel = New-Object System.Windows.Forms.Label
    $footerLabel.Location = New-Object System.Drawing.Point(0, 0)
    $footerLabel.Size = New-Object System.Drawing.Size(920, 50)
    $footerLabel.Text = "xsukax WIFI Password Recover | Log: $logFile"
    $footerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $footerLabel.ForeColor = [System.Drawing.Color]::Gray
    $footerLabel.TextAlign = "MiddleCenter"
    $footerPanel.Controls.Add($footerLabel)
    
    Write-Log "Main window created successfully" "SUCCESS"
    
    # =========================================================================
    # EVENT HANDLERS
    # =========================================================================
    
    # Scan Button Click
    $scanButton.Add_Click({
        if ($script:isScanning) {
            Write-Log "Scan already in progress, ignoring request" "WARNING"
            return
        }
        
        try {
            Write-Log "User initiated WiFi scan" "INFO"
            Update-StatusLabel -Label $statusLabel -Text "Scanning WiFi profiles..." -Color ([System.Drawing.Color]::FromArgb(0, 120, 212))
            $scanButton.Enabled = $false
            $form.Refresh()
            
            $progressCallback = {
                param($Current, $Total, $ProfileName)
                $statusText = "Processing $Current of $Total - $ProfileName"
                Update-StatusLabel -Label $statusLabel -Text $statusText -Color ([System.Drawing.Color]::FromArgb(0, 120, 212))
            }
            
            $script:allWifiData = Get-AllWiFiProfiles -ProgressCallback $progressCallback
            
            if ($script:allWifiData.Count -eq 0) {
                Update-StatusLabel -Label $statusLabel -Text "No WiFi profiles found on this system" -Color ([System.Drawing.Color]::Orange)
            }
            else {
                Populate-DataGrid -Grid $dataGridView -Data $script:allWifiData
                Update-StatusLabel -Label $statusLabel -Text "Scan complete. Found $($script:allWifiData.Count) WiFi profile(s)" -Color ([System.Drawing.Color]::Green)
            }
        }
        catch {
            Write-Log "Scan error: $($_.Exception.Message)" "ERROR"
            Update-StatusLabel -Label $statusLabel -Text "Error: $($_.Exception.Message)" -Color ([System.Drawing.Color]::Red)
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to scan WiFi profiles:`n`n$($_.Exception.Message)`n`nCheck log: $logFile",
                "Scan Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        finally {
            $scanButton.Enabled = $true
        }
    })
    
    # Export Button Click
    $exportButton.Add_Click({
        try {
            if ($script:allWifiData.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "No data to export. Please scan WiFi profiles first.",
                    "Export Data",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                return
            }
            
            Write-Log "User initiated data export" "INFO"
            
            $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
            $saveDialog.Filter = "CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
            $saveDialog.Title = "Export WiFi Passwords"
            $saveDialog.FileName = "WiFi_Passwords_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $saveDialog.DefaultExt = "csv"
            
            if ($saveDialog.ShowDialog() -eq "OK") {
                $filePath = $saveDialog.FileName
                $extension = [System.IO.Path]::GetExtension($filePath)
                
                if ($extension -eq ".csv") {
                    $script:allWifiData | Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
                }
                else {
                    $content = "xsukax WIFI Password Recover - Export`n"
                    $content += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
                    $content += "Total Profiles: $($script:allWifiData.Count)`n"
                    $content += "=" * 100 + "`n`n"
                    
                    foreach ($item in $script:allWifiData) {
                        $content += "SSID: $($item.SSID)`n"
                        $content += "Password: $($item.Password)`n"
                        $content += "Authentication: $($item.Authentication)`n"
                        $content += "Encryption: $($item.Encryption)`n"
                        $content += "-" * 100 + "`n`n"
                    }
                    
                    [System.IO.File]::WriteAllText($filePath, $content, [System.Text.Encoding]::UTF8)
                }
                
                Write-Log "Data exported to: $filePath" "SUCCESS"
                [System.Windows.Forms.MessageBox]::Show(
                    "Data exported successfully!`n`nFile: $filePath",
                    "Export Success",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
        }
        catch {
            Write-Log "Export error: $($_.Exception.Message)" "ERROR"
            [System.Windows.Forms.MessageBox]::Show(
                "Export failed:`n`n$($_.Exception.Message)",
                "Export Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    })
    
    # Copy Button Click
    $copyButton.Add_Click({
        try {
            if ($dataGridView.SelectedRows.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Please select a WiFi profile from the list first.",
                    "Copy Selected",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                return
            }
            
            $selectedRow = $dataGridView.SelectedRows[0]
            $ssid = $selectedRow.Cells["SSID"].Value
            $password = $selectedRow.Cells["Password"].Value
            $auth = $selectedRow.Cells["Authentication"].Value
            $enc = $selectedRow.Cells["Encryption"].Value
            
            $copyText = "WiFi Network: $ssid`nPassword: $password`nAuthentication: $auth`nEncryption: $enc"
            [System.Windows.Forms.Clipboard]::SetText($copyText)
            
            Write-Log "Copied credentials for '$ssid' to clipboard" "SUCCESS"
            Update-StatusLabel -Label $statusLabel -Text "Credentials for '$ssid' copied to clipboard" -Color ([System.Drawing.Color]::Green)
        }
        catch {
            Write-Log "Copy error: $($_.Exception.Message)" "ERROR"
        }
    })
    
    # DataGrid Double-Click
    $dataGridView.Add_CellDoubleClick({
        param($sender, $e)
        
        try {
            if ($e.RowIndex -ge 0) {
                $password = $dataGridView.Rows[$e.RowIndex].Cells["Password"].Value
                $ssid = $dataGridView.Rows[$e.RowIndex].Cells["SSID"].Value
                
                if ($password -and $password -ne "N/A") {
                    [System.Windows.Forms.Clipboard]::SetText($password)
                    Write-Log "Double-click: Copied password for '$ssid'" "SUCCESS"
                    Update-StatusLabel -Label $statusLabel -Text "Password for '$ssid' copied to clipboard" -Color ([System.Drawing.Color]::Green)
                }
            }
        }
        catch {
            Write-Log "Double-click error: $($_.Exception.Message)" "ERROR"
        }
    })
    
    # View Log Button Click
    $logButton.Add_Click({
        try {
            if (Test-Path $logFile) {
                Write-Log "User opened log file" "INFO"
                Start-Process notepad.exe -ArgumentList "`"$logFile`""
            }
            else {
                [System.Windows.Forms.MessageBox]::Show(
                    "Log file not found:`n$logFile",
                    "View Log",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
            }
        }
        catch {
            Write-Log "Error opening log: $($_.Exception.Message)" "ERROR"
        }
    })
    
    # Form Shown Event
    $form.Add_Shown({
        Write-Log "Main window displayed" "SUCCESS"
    })
    
    # Form Closing Event
    $form.Add_FormClosing({
        Write-Log "Application closing by user" "INFO"
        Write-Log "Session ended: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "INFO"
        Write-Log "================================================================================" "INFO"
    })
    
    # =========================================================================
    # SHOW FORM
    # =========================================================================
    
    Write-Log "Displaying main window..." "INFO"
    [void]$form.ShowDialog()
    
    Write-Log "Application terminated normally" "SUCCESS"
}
catch {
    $criticalError = $_.Exception.Message
    Write-Log "CRITICAL APPLICATION ERROR: $criticalError" "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" "ERROR"
    
    [System.Windows.Forms.MessageBox]::Show(
        "A critical error occurred:`n`n$criticalError`n`nPlease check the log file for details:`n$logFile",
        "Critical Error - xsukax WIFI Password Recover",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    
    exit 1
}

# End of script