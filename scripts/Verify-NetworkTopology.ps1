<#
.SYNOPSIS
    Automatyczna weryfikacja topologii sieci K3s (5 switchy MikroTik)

.DESCRIPTION
    Skrypt łączy się do wszystkich 5 switchy przez SSH, zbiera dane LLDP,
    sprawdza połączenia trunk oraz weryfikuje zgodność z oczekiwaną topologią.
    
    WYMAGANIA:
    - Posh-SSH module: Install-Module -Name Posh-SSH -Force
    - Dostęp SSH do wszystkich switchy (port 22)
    - Laptop w sieci 192.168.255.0/28 (Management VLAN 600)

.PARAMETER Username
    Login do switchy (domyślnie: admin)

.PARAMETER Password
    Hasło do switchy (domyślnie: ZSE-BCU-2025!SecureP@ss)

.PARAMETER ExpectedTopologyFile
    Plik JSON z oczekiwaną topologią (domyślnie: expected-topology.json)

.PARAMETER ExportReport
    Ścieżka do pliku HTML z raportem (opcjonalne)

.EXAMPLE
    .\Verify-NetworkTopology.ps1

.EXAMPLE
    .\Verify-NetworkTopology.ps1 -ExportReport "C:\Reports\topology-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"

.NOTES
    Author: ZSE-BCU Infrastructure Team
    Version: 1.0
    Created: 2025-01-27
#>

[CmdletBinding()]
param(
    [string]$Username = "admin",
    [SecureString]$Password = (ConvertTo-SecureString "ZSE-BCU-2025!SecureP@ss" -AsPlainText -Force),
    [string]$ExpectedTopologyFile = "$PSScriptRoot\expected-topology.json",
    [string]$ExportReport = ""
)

# ═══════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════

$switches = @(
    @{ Name = "CORE-SWITCH-01";   IP = "192.168.255.1";  Role = "Core" }
    @{ Name = "ACCESS-SWITCH-01"; IP = "192.168.255.11"; Role = "Access" }
    @{ Name = "ACCESS-SWITCH-02"; IP = "192.168.255.12"; Role = "Access" }
    @{ Name = "ACCESS-SWITCH-03"; IP = "192.168.255.13"; Role = "Access" }
    @{ Name = "ACCESS-SWITCH-04"; IP = "192.168.255.14"; Role = "Redundancy" }
)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ═══════════════════════════════════════════════════════════════
# FUNCTIONS
# ═══════════════════════════════════════════════════════════════

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    
    $params = @{
        ForegroundColor = $Color
        NoNewline = $NoNewline
    }
    Write-Host $Message @params
}

function Test-PoshSSH {
    if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
        Write-ColorOutput "❌ BŁĄD: Moduł Posh-SSH nie jest zainstalowany!" -Color Red
        Write-ColorOutput "Zainstaluj: Install-Module -Name Posh-SSH -Force" -Color Yellow
        exit 1
    }
    Import-Module Posh-SSH -ErrorAction Stop
}

function Connect-MikroTik {
    param(
        [string]$IP,
        [string]$Username,
        [SecureString]$Password
    )
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        $session = New-SSHSession -ComputerName $IP -Credential $credential -AcceptKey -ErrorAction Stop
        return $session
    }
    catch {
        return $null
    }
}

function Invoke-MikroTikCommand {
    param(
        [object]$Session,
        [string]$Command
    )
    
    try {
        $stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
        Start-Sleep -Milliseconds 500
        
        # Clear initial output
        $null = $stream.Read()
        
        # Send command
        $stream.WriteLine($Command)
        Start-Sleep -Milliseconds 1000
        
        # Read output
        $output = $stream.Read()
        
        return $output
    }
    catch {
        return $null
    }
}

function Get-LLDPNeighbor {
    param(
        [object]$Session
    )
    
    $output = Invoke-MikroTikCommand -Session $Session -Command "/ip neighbor print detail without-paging"
    
    if (-not $output) {
        return @()
    }
    
    # Parse LLDP output
    $neighbors = @()
    $lines = $output -split "`n"
    
    $currentNeighbor = @{}
    foreach ($line in $lines) {
        $line = $line.Trim()
        
        if ($line -match "^\d+") {
            # New neighbor entry
            if ($currentNeighbor.Count -gt 0) {
                $neighbors += [PSCustomObject]$currentNeighbor
                $currentNeighbor = @{}
            }
        }
        
        if ($line -match "interface=(.+)") {
            $currentNeighbor.LocalInterface = $matches[1].Trim()
        }
        if ($line -match "identity=(.+)") {
            $currentNeighbor.RemoteDevice = $matches[1].Trim()
        }
        if ($line -match "interface-name=(.+)") {
            $currentNeighbor.RemoteInterface = $matches[1].Trim()
        }
        if ($line -match "address=(.+)") {
            $currentNeighbor.RemoteIP = $matches[1].Trim()
        }
    }
    
    # Add last neighbor
    if ($currentNeighbor.Count -gt 0) {
        $neighbors += [PSCustomObject]$currentNeighbor
    }
    
    return $neighbors
}

function Get-VLANConfiguration {
    param(
        [object]$Session
    )
    
    $output = Invoke-MikroTikCommand -Session $Session -Command "/interface bridge vlan print detail without-paging"
    
    if (-not $output) {
        return @()
    }
    
    # Parse VLAN configuration
    $vlans = @()
    $lines = $output -split "`n"
    
    foreach ($line in $lines) {
        if ($line -match "vlan-ids=(\d+).*tagged=([^\s]+)") {
            $vlans += @{
                VLANID = $matches[1]
                TaggedPorts = $matches[2]
            }
        }
    }
    
    return $vlans
}

function Test-Connectivity {
    param(
        [string]$IP
    )
    
    $ping = Test-Connection -ComputerName $IP -Count 2 -Quiet
    return $ping
}

function Import-ExpectedTopology {
    param(
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-ColorOutput "⚠️  UWAGA: Brak pliku $FilePath - używam domyślnej topologii" -Color Yellow
        return Get-DefaultTopology
    }
    
    try {
        $topology = Get-Content $FilePath -Raw | ConvertFrom-Json
        return $topology
    }
    catch {
        Write-ColorOutput "❌ BŁĄD: Nie mogę wczytać $FilePath" -Color Red
        return Get-DefaultTopology
    }
}

function Get-DefaultTopology {
    return @{
        "CORE-SWITCH-01" = @(
            @{ LocalPort = "sfp-sfpplus1"; RemoteDevice = "ACCESS-SWITCH-01"; RemotePort = "sfp-sfpplus1" }
            @{ LocalPort = "sfp-sfpplus2"; RemoteDevice = "ACCESS-SWITCH-02"; RemotePort = "sfp-sfpplus1" }
            @{ LocalPort = "sfp-sfpplus3"; RemoteDevice = "ACCESS-SWITCH-03"; RemotePort = "sfp-sfpplus1" }
            @{ LocalPort = "sfp-sfpplus4"; RemoteDevice = "ACCESS-SWITCH-04"; RemotePort = "sfp-sfpplus1" }
        )
        "ACCESS-SWITCH-01" = @(
            @{ LocalPort = "sfp-sfpplus1"; RemoteDevice = "CORE-SWITCH-01"; RemotePort = "sfp-sfpplus1" }
        )
        "ACCESS-SWITCH-02" = @(
            @{ LocalPort = "sfp-sfpplus1"; RemoteDevice = "CORE-SWITCH-01"; RemotePort = "sfp-sfpplus2" }
        )
        "ACCESS-SWITCH-03" = @(
            @{ LocalPort = "sfp-sfpplus1"; RemoteDevice = "CORE-SWITCH-01"; RemotePort = "sfp-sfpplus3" }
        )
        "ACCESS-SWITCH-04" = @(
            @{ LocalPort = "sfp-sfpplus1"; RemoteDevice = "CORE-SWITCH-01"; RemotePort = "sfp-sfpplus4" }
        )
    }
}

function Compare-Topology {
    param(
        [hashtable]$ExpectedTopology,
        [hashtable]$ActualTopology
    )
    
    $results = @{
        Matches = @()
        Missing = @()
        Unexpected = @()
    }
    
    # Check expected connections
    foreach ($device in $ExpectedTopology.Keys) {
        foreach ($expectedConn in $ExpectedTopology[$device]) {
            $found = $false
            
            if ($ActualTopology.ContainsKey($device)) {
                foreach ($actualConn in $ActualTopology[$device]) {
                    if ($actualConn.LocalInterface -eq $expectedConn.LocalPort -and
                        $actualConn.RemoteDevice -like "*$($expectedConn.RemoteDevice)*") {
                        
                        $results.Matches += [PSCustomObject]@{
                            Device = $device
                            LocalPort = $expectedConn.LocalPort
                            RemoteDevice = $expectedConn.RemoteDevice
                            RemotePort = $actualConn.RemoteInterface
                        }
                        $found = $true
                        break
                    }
                }
            }
            
            if (-not $found) {
                $results.Missing += [PSCustomObject]@{
                    Device = $device
                    LocalPort = $expectedConn.LocalPort
                    ExpectedRemote = $expectedConn.RemoteDevice
                    ExpectedRemotePort = $expectedConn.RemotePort
                }
            }
        }
    }
    
    # Check for unexpected connections
    foreach ($device in $ActualTopology.Keys) {
        foreach ($actualConn in $ActualTopology[$device]) {
            if (-not $ExpectedTopology.ContainsKey($device)) {
                continue
            }
            
            $expected = $false
            foreach ($expectedConn in $ExpectedTopology[$device]) {
                if ($actualConn.LocalInterface -eq $expectedConn.LocalPort) {
                    $expected = $true
                    break
                }
            }
            
            if (-not $expected -and $actualConn.LocalInterface -match "sfp") {
                $results.Unexpected += [PSCustomObject]@{
                    Device = $device
                    LocalPort = $actualConn.LocalInterface
                    ActualRemote = $actualConn.RemoteDevice
                    ActualRemotePort = $actualConn.RemoteInterface
                }
            }
        }
    }
    
    return $results
}

function Export-HTMLReport {
    param(
        [hashtable]$TestResults,
        [string]$OutputPath
    )
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Network Topology Verification Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f5f5f5; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px; margin-bottom: 30px; }
        .header h1 { margin: 0; font-size: 32px; }
        .header .timestamp { font-size: 14px; opacity: 0.9; margin-top: 10px; }
        .section { background: white; padding: 25px; margin-bottom: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .section h2 { margin-top: 0; color: #333; border-bottom: 2px solid #667eea; padding-bottom: 10px; }
        .success { color: #22c55e; font-weight: bold; }
        .error { color: #ef4444; font-weight: bold; }
        .warning { color: #f59e0b; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; }
        th { background: #667eea; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #e5e7eb; }
        tr:hover { background: #f9fafb; }
        .status-ok { background: #dcfce7; color: #15803d; padding: 5px 10px; border-radius: 5px; display: inline-block; }
        .status-fail { background: #fee2e2; color: #991b1b; padding: 5px 10px; border-radius: 5px; display: inline-block; }
        .status-warn { background: #fef3c7; color: #92400e; padding: 5px 10px; border-radius: 5px; display: inline-block; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); text-align: center; }
        .summary-card .number { font-size: 48px; font-weight: bold; margin: 10px 0; }
        .summary-card .label { font-size: 14px; color: #6b7280; text-transform: uppercase; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🌐 Network Topology Verification Report</h1>
        <div class="timestamp">Generated: $timestamp</div>
        <div class="timestamp">K3s Infrastructure - ZSE BCU</div>
    </div>
    
    <div class="summary">
        <div class="summary-card">
            <div class="label">Total Switches</div>
            <div class="number" style="color: #667eea;">$($TestResults.TotalSwitches)</div>
        </div>
        <div class="summary-card">
            <div class="label">Reachable</div>
            <div class="number" style="color: #22c55e;">$($TestResults.ReachableSwitches)</div>
        </div>
        <div class="summary-card">
            <div class="label">Correct Connections</div>
            <div class="number" style="color: #22c55e;">$($TestResults.CorrectConnections)</div>
        </div>
        <div class="summary-card">
            <div class="label">Issues Found</div>
            <div class="number" style="color: #ef4444;">$($TestResults.IssuesFound)</div>
        </div>
    </div>
"@

    # Connectivity table
    $html += @"
    <div class="section">
        <h2>Switch Connectivity</h2>
        <table>
            <tr>
                <th>Switch Name</th>
                <th>IP Address</th>
                <th>Role</th>
                <th>Status</th>
                <th>Response Time</th>
            </tr>
"@

    foreach ($switch in $TestResults.Connectivity) {
        $statusClass = if ($switch.Reachable) { "status-ok" } else { "status-fail" }
        $statusText = if ($switch.Reachable) { "✓ Online" } else { "✗ Offline" }
        $responseTime = if ($switch.ResponseTime) { "$($switch.ResponseTime)ms" } else { "N/A" }
        
        $html += @"
            <tr>
                <td><strong>$($switch.Name)</strong></td>
                <td><code>$($switch.IP)</code></td>
                <td>$($switch.Role)</td>
                <td><span class="$statusClass">$statusText</span></td>
                <td>$responseTime</td>
            </tr>
"@
    }

    $html += @"
        </table>
    </div>
"@

    # Topology matches
    if ($TestResults.TopologyMatches.Count -gt 0) {
        $html += @"
    <div class="section">
        <h2>✓ Correct Connections ($($TestResults.TopologyMatches.Count))</h2>
        <table>
            <tr>
                <th>Local Device</th>
                <th>Local Port</th>
                <th>Remote Device</th>
                <th>Remote Port</th>
            </tr>
"@

        foreach ($match in $TestResults.TopologyMatches) {
            $html += @"
            <tr>
                <td><strong>$($match.Device)</strong></td>
                <td><code>$($match.LocalPort)</code></td>
                <td><strong>$($match.RemoteDevice)</strong></td>
                <td><code>$($match.RemotePort)</code></td>
            </tr>
"@
        }

        $html += @"
        </table>
    </div>
"@
    }

    # Missing connections
    if ($TestResults.MissingConnections.Count -gt 0) {
        $html += @"
    <div class="section">
        <h2>✗ Missing Connections ($($TestResults.MissingConnections.Count))</h2>
        <table>
            <tr>
                <th>Local Device</th>
                <th>Local Port</th>
                <th>Expected Remote</th>
                <th>Expected Remote Port</th>
            </tr>
"@

        foreach ($missing in $TestResults.MissingConnections) {
            $html += @"
            <tr>
                <td><strong>$($missing.Device)</strong></td>
                <td><code>$($missing.LocalPort)</code></td>
                <td><strong>$($missing.ExpectedRemote)</strong></td>
                <td><code>$($missing.ExpectedRemotePort)</code></td>
            </tr>
"@
        }

        $html += @"
        </table>
    </div>
"@
    }

    # Unexpected connections
    if ($TestResults.UnexpectedConnections.Count -gt 0) {
        $html += @"
    <div class="section">
        <h2>⚠ Unexpected Connections ($($TestResults.UnexpectedConnections.Count))</h2>
        <table>
            <tr>
                <th>Local Device</th>
                <th>Local Port</th>
                <th>Actual Remote</th>
                <th>Actual Remote Port</th>
            </tr>
"@

        foreach ($unexpected in $TestResults.UnexpectedConnections) {
            $html += @"
            <tr>
                <td><strong>$($unexpected.Device)</strong></td>
                <td><code>$($unexpected.LocalPort)</code></td>
                <td><strong>$($unexpected.ActualRemote)</strong></td>
                <td><code>$($unexpected.ActualRemotePort)</code></td>
            </tr>
"@
        }

        $html += @"
        </table>
    </div>
"@
    }

    $html += @"
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-ColorOutput "📄 Raport zapisany: $OutputPath" -Color Green
}

# ═══════════════════════════════════════════════════════════════
# MAIN SCRIPT
# ═══════════════════════════════════════════════════════════════

Clear-Host

Write-ColorOutput "═══════════════════════════════════════════════════════════════" -Color Cyan
Write-ColorOutput "  Network Topology Verification - K3s Infrastructure" -Color Cyan
Write-ColorOutput "═══════════════════════════════════════════════════════════════" -Color Cyan
Write-Host ""

# Step 1: Check prerequisites
Write-ColorOutput "[1/5] Sprawdzanie wymagań..." -Color Yellow
Test-PoshSSH
Write-ColorOutput "✓ Moduł Posh-SSH dostępny" -Color Green
Write-Host ""

# Step 2: Load expected topology
Write-ColorOutput "[2/5] Wczytywanie oczekiwanej topologii..." -Color Yellow
$expectedTopology = Import-ExpectedTopology -FilePath $ExpectedTopologyFile
Write-ColorOutput "✓ Topologia wczytana ($(($expectedTopology.Keys | ForEach-Object { $expectedTopology[$_].Count } | Measure-Object -Sum).Sum) oczekiwanych połączeń)" -Color Green
Write-Host ""

# Step 3: Test connectivity
Write-ColorOutput "[3/5] Testowanie połączenia z switchami..." -Color Yellow
$connectivityResults = @()

foreach ($switch in $switches) {
    Write-ColorOutput "  Testing $($switch.Name) ($($switch.IP))... " -NoNewline
    
    $ping = Test-Connectivity -IP $switch.IP
    $responseTime = if ($ping) { (Test-Connection -ComputerName $switch.IP -Count 1).ResponseTime } else { $null }
    
    $connectivityResults += [PSCustomObject]@{
        Name = $switch.Name
        IP = $switch.IP
        Role = $switch.Role
        Reachable = $ping
        ResponseTime = $responseTime
    }
    
    if ($ping) {
        Write-ColorOutput "✓ ($($responseTime)ms)" -Color Green
    }
    else {
        Write-ColorOutput "✗ Brak połączenia" -Color Red
    }
}
Write-Host ""

# Step 4: Collect LLDP data
Write-ColorOutput "[4/5] Zbieranie danych LLDP..." -Color Yellow
$actualTopology = @{}
$sessions = @{}

foreach ($switch in $switches | Where-Object { ($connectivityResults | Where-Object { $_.Name -eq $switch.Name }).Reachable }) {
    Write-ColorOutput "  Connecting to $($switch.Name)... " -NoNewline
    
    $session = Connect-MikroTik -IP $switch.IP -Username $Username -Password $Password
    
    if ($session) {
        Write-ColorOutput "✓" -Color Green
        $sessions[$switch.Name] = $session
        
        Write-ColorOutput "  Collecting LLDP neighbors from $($switch.Name)... " -NoNewline
        $neighbors = Get-LLDPNeighbor -Session $session
        $actualTopology[$switch.Name] = $neighbors
        Write-ColorOutput "✓ ($($neighbors.Count) neighbors)" -Color Green
    }
    else {
        Write-ColorOutput "✗ SSH failed" -Color Red
    }
}
Write-Host ""

# Step 5: Compare topologies
Write-ColorOutput "[5/5] Weryfikacja topologii..." -Color Yellow
$comparison = Compare-Topology -ExpectedTopology $expectedTopology -ActualTopology $actualTopology

Write-Host ""
Write-ColorOutput "═══════════════════════════════════════════════════════════════" -Color Cyan
Write-ColorOutput "  WYNIKI WERYFIKACJI" -Color Cyan
Write-ColorOutput "═══════════════════════════════════════════════════════════════" -Color Cyan
Write-Host ""

Write-ColorOutput "Switche osiągalne: " -NoNewline
Write-ColorOutput "$($connectivityResults | Where-Object { $_.Reachable } | Measure-Object | Select-Object -ExpandProperty Count)/$($switches.Count)" -Color $(if (($connectivityResults | Where-Object { $_.Reachable }).Count -eq $switches.Count) { "Green" } else { "Yellow" })

Write-ColorOutput "Prawidłowe połączenia: " -NoNewline
Write-ColorOutput "$($comparison.Matches.Count)" -Color Green

Write-ColorOutput "Brakujące połączenia: " -NoNewline
Write-ColorOutput "$($comparison.Missing.Count)" -Color $(if ($comparison.Missing.Count -eq 0) { "Green" } else { "Red" })

Write-ColorOutput "Nieoczekiwane połączenia: " -NoNewline
Write-ColorOutput "$($comparison.Unexpected.Count)" -Color $(if ($comparison.Unexpected.Count -eq 0) { "Green" } else { "Yellow" })

Write-Host ""

# Display matches
if ($comparison.Matches.Count -gt 0) {
    Write-ColorOutput "✓ PRAWIDŁOWE POŁĄCZENIA:" -Color Green
    foreach ($match in $comparison.Matches) {
        Write-Host "  $($match.Device) [$($match.LocalPort)] ←→ $($match.RemoteDevice) [$($match.RemotePort)]"
    }
    Write-Host ""
}

# Display missing connections
if ($comparison.Missing.Count -gt 0) {
    Write-ColorOutput "✗ BRAKUJĄCE POŁĄCZENIA:" -Color Red
    foreach ($missing in $comparison.Missing) {
        Write-Host "  $($missing.Device) [$($missing.LocalPort)] -/→ $($missing.ExpectedRemote) [$($missing.ExpectedRemotePort)]"
    }
    Write-Host ""
}

# Display unexpected connections
if ($comparison.Unexpected.Count -gt 0) {
    Write-ColorOutput "⚠ NIEOCZEKIWANE POŁĄCZENIA:" -Color Yellow
    foreach ($unexpected in $comparison.Unexpected) {
        Write-Host "  $($unexpected.Device) [$($unexpected.LocalPort)] ←→ $($unexpected.ActualRemote) [$($unexpected.ActualRemotePort)]"
    }
    Write-Host ""
}

# Export HTML report
if ($ExportReport) {
    $testResults = @{
        TotalSwitches = $switches.Count
        ReachableSwitches = ($connectivityResults | Where-Object { $_.Reachable }).Count
        CorrectConnections = $comparison.Matches.Count
        IssuesFound = $comparison.Missing.Count + $comparison.Unexpected.Count
        Connectivity = $connectivityResults
        TopologyMatches = $comparison.Matches
        MissingConnections = $comparison.Missing
        UnexpectedConnections = $comparison.Unexpected
    }
    
    Export-HTMLReport -TestResults $testResults -OutputPath $ExportReport
}

# Cleanup SSH sessions
foreach ($session in $sessions.Values) {
    Remove-SSHSession -SSHSession $session | Out-Null
}

# Final verdict
Write-ColorOutput "═══════════════════════════════════════════════════════════════" -Color Cyan
if ($comparison.Missing.Count -eq 0 -and $comparison.Unexpected.Count -eq 0 -and ($connectivityResults | Where-Object { $_.Reachable }).Count -eq $switches.Count) {
    Write-ColorOutput "  ✓ TOPOLOGIA PRAWIDŁOWA - Sieć gotowa do użytku!" -Color Green
}
elseif ($comparison.Missing.Count -gt 0) {
    Write-ColorOutput "  ✗ TOPOLOGIA NIEPRAWIDŁOWA - Sprawdź brakujące połączenia!" -Color Red
}
else {
    Write-ColorOutput "  ⚠ TOPOLOGIA Z OSTRZEŻENIAMI - Sprawdź nieoczekiwane połączenia" -Color Yellow
}
Write-ColorOutput "═══════════════════════════════════════════════════════════════" -Color Cyan
