# Transpro Network Speed Test - System Info Collector
# Collects hardware + network info, then opens the speed test page
# with all data passed as URL query parameters.

# ============================================================
# IT ADMIN CONFIG — set this once after uploading to SharePoint
# ============================================================
$sharePointURL = 'https://orlando-g26.github.io/Hardware-Inspection-tool/speedtest-webpage.html'
# ============================================================

# ---- Hardware ----
try {
    $cpu      = Get-CimInstance Win32_Processor | Select-Object -First 1
    $cs       = Get-CimInstance Win32_ComputerSystem
    $os       = Get-CimInstance Win32_OperatingSystem
    $ramBytes = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum

    $cpuFull = ($cpu.Name.Trim() -replace '\s+', ' ') + ' (' + $cpu.NumberOfCores + 'C / ' + $cpu.NumberOfLogicalProcessors + 'T)'
    $ramStr  = [string][math]::Round($ramBytes / 1GB) + ' GB'
    $osStr   = $os.Caption.Trim() + ' (Build ' + $os.BuildNumber + ')'
    $model   = ($cs.Manufacturer.Trim() + ' ' + $cs.Model.Trim()) -replace '\s+', ' '
} catch {
    Write-Warning "Hardware info error: $_"
    $cpuFull = 'Unknown'
    $ramStr  = 'Unknown'
    $osStr   = 'Unknown'
    $model   = 'Unknown'
}

# ---- Network ----
try {
    $adapter = Get-NetAdapter |
        Where-Object { $_.Status -eq 'Up' -and $_.Virtual -eq $false } |
        Sort-Object LinkSpeed -Descending |
        Select-Object -First 1

    if ($adapter) {
        if ($adapter.LinkSpeed -is [string]) {
            if ($adapter.LinkSpeed -match '([\d.]+)\s*(Gbps|Mbps|Kbps)') {
                $num  = [double]$Matches[1]
                $speedMbps = switch ($Matches[2]) {
                    'Gbps' { $num * 1000 }
                    'Mbps' { $num }
                    'Kbps' { $num / 1000 }
                }
            } else { $speedMbps = 0 }
        } else {
            $speedMbps = [math]::Round($adapter.LinkSpeed / 1e6)
        }
        $netSpeed = if ($speedMbps -ge 1000) { [string]($speedMbps / 1000) + ' Gbps' } else { [string][math]::Round($speedMbps) + ' Mbps' }

        $isWifi = $adapter.PhysicalMediaType -eq 'Native 802.11' -or
                  $adapter.InterfaceDescription -match 'Wi.?Fi|Wireless|802\.11'

        if ($isWifi) {
            $netType = 'Wi-Fi'
            try {
                $wlan        = (netsh wlan show interfaces 2>$null) -join "`n"
                $ssidMatch   = [regex]::Match($wlan, '(?m)^\s+SSID\s*:\s*(?!BSSID)(.+)$')
                $signalMatch = [regex]::Match($wlan, 'Signal\s*:\s*(\d+)%')
                if ($ssidMatch.Success) {
                    $ssid    = $ssidMatch.Groups[1].Value.Trim()
                    $signal  = if ($signalMatch.Success) { ' (' + $signalMatch.Groups[1].Value + '% signal)' } else { '' }
                    $netType = 'Wi-Fi - ' + $ssid + $signal
                }
            } catch {}
        } else {
            $netType = 'Ethernet'
        }
    } else {
        $netType  = 'Unknown'
        $netSpeed = 'Unknown'
    }
} catch {
    Write-Warning "Network info error: $_"
    $netType  = 'Unknown'
    $netSpeed = 'Unknown'
}

# ---- Build target URL ----
$esc = { param($s) [Uri]::EscapeDataString([string]$s) }

$query  = 'hwready=1'
$query += '&cpu='      + (& $esc $cpuFull)
$query += '&ram='      + (& $esc $ramStr)
$query += '&os='       + (& $esc $osStr)
$query += '&model='    + (& $esc $model)
$query += '&netType='  + (& $esc $netType)
$query += '&netSpeed=' + (& $esc $netSpeed)

if ($sharePointURL) {
    $targetURL = $sharePointURL + '?' + $query
} else {
    # Fall back to local HTML file for testing
    $htmlFile = Join-Path $PSScriptRoot "speedtest-webpage.html"
    if (-not (Test-Path $htmlFile)) {
        Write-Error "speedtest-webpage.html not found in: $PSScriptRoot"
        Read-Host "Press Enter to exit"
        exit 1
    }
    $targetURL = [System.Uri]::new($htmlFile).AbsoluteUri + '?' + $query
}

# ---- Open in browser ----
$browsers = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path ${env:ProgramFiles}      'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path ${env:ProgramFiles}      'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:LocalAppData}      'Google\Chrome\Application\chrome.exe')
)

$browserExe = $browsers | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($browserExe) {
    Start-Process -FilePath $browserExe -ArgumentList $targetURL
} else {
    Start-Process $targetURL
}

Write-Host "Done. Browser should have opened." -ForegroundColor Green
Read-Host "Press Enter to close"
