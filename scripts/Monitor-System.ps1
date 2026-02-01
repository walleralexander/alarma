# System Monitoring Script mit Notification Gateway
# Version 1.0 - Stadt Hohenems
# Created: 29.01.2026
#
# Überwacht Systemmetriken und sendet Benachrichtigungen bei Problemen

<#
.SYNOPSIS
    Überwacht System-Ressourcen und sendet Alerts
    
.DESCRIPTION
    Dieses Script überwacht CPU, RAM, Disk und Dienste und sendet
    automatisch Benachrichtigungen über das Notification Gateway.
    
.PARAMETER ComputerName
    Name des zu überwachenden Computers (Standard: localhost)
    
.PARAMETER Server
    Notification Gateway Server
    
.PARAMETER Port
    Notification Gateway Port
    
.PARAMETER CPUThreshold
    CPU Schwellenwert in Prozent (Standard: 80)
    
.PARAMETER MemoryThreshold
    RAM Schwellenwert in Prozent (Standard: 85)
    
.PARAMETER DiskThreshold
    Disk Schwellenwert in Prozent (Standard: 90)
    
.EXAMPLE
    .\Monitor-System.ps1 -ComputerName "DC01" -CPUThreshold 75
    
.EXAMPLE
    .\Monitor-System.ps1 -Server "192.168.1.100" -Port 8000
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$Server = "notification-server",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 8000,
    
    [Parameter(Mandatory=$false)]
    [int]$CPUThreshold = 80,
    
    [Parameter(Mandatory=$false)]
    [int]$MemoryThreshold = 85,
    
    [Parameter(Mandatory=$false)]
    [int]$DiskThreshold = 90
)

# Notification URL
$NotificationUrl = "http://${Server}:${Port}/notify"

# Log-Datei
$LogFile = "C:\Logs\SystemMonitor-$ComputerName.log"

# Funktion: Logging
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    
    Write-Host $logMessage
    
    try {
        $logDir = Split-Path $LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $logMessage
    }
    catch {
        Write-Warning "Konnte nicht ins Log schreiben: $_"
    }
}

# Funktion: Notification senden
function Send-Alert {
    param(
        [string]$Title,
        [string]$Body,
        [string]$Priority = "warning"
    )
    
    try {
        $tags = switch ($Priority) {
            "critical" { "kritisch" }
            "warning"  { "warnung,whatsapp,teams" }
            "info"     { "info,teams" }
            default    { "info,email" }
        }
        
        $notification = @{
            urls = "tag=$tags"
            title = $Title
            body = $Body
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod `
            -Uri $NotificationUrl `
            -Method Post `
            -Body $notification `
            -ContentType "application/json" `
            -TimeoutSec 30 `
            -ErrorAction Stop
        
        Write-Log "Alert gesendet: $Title" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "Fehler beim Senden: $_" -Level "ERROR"
        return $false
    }
}

# Funktion: CPU überwachen
function Test-CPU {
    param([int]$Threshold)
    
    Write-Log "Prüfe CPU-Auslastung..." -Level "DEBUG"
    
    try {
        $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction Stop |
            Select-Object -ExpandProperty CounterSamples |
            Select-Object -ExpandProperty CookedValue
        
        $cpuRounded = [Math]::Round($cpu, 2)
        Write-Log "CPU: $cpuRounded%" -Level "DEBUG"
        
        if ($cpu -ge $Threshold) {
            $title = "⚠️ CPU Alert: $ComputerName"
            $body = @"
CPU-Auslastung kritisch!

Server: $ComputerName
CPU: $cpuRounded%
Schwellenwert: $Threshold%
Zeit: $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")

Bitte System prüfen.
"@
            Send-Alert -Title $title -Body $body -Priority "warning"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Log "Fehler bei CPU-Prüfung: $_" -Level "ERROR"
        return $true  # Fehler nicht als Problem werten
    }
}

# Funktion: RAM überwachen
function Test-Memory {
    param([int]$Threshold)
    
    Write-Log "Prüfe RAM-Auslastung..." -Level "DEBUG"
    
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $totalRAM = $os.TotalVisibleMemorySize
        $freeRAM = $os.FreePhysicalMemory
        $usedRAM = $totalRAM - $freeRAM
        $usedPercent = [Math]::Round(($usedRAM / $totalRAM) * 100, 2)
        
        Write-Log "RAM: $usedPercent% ($([Math]::Round($usedRAM/1MB, 2)) GB von $([Math]::Round($totalRAM/1MB, 2)) GB)" -Level "DEBUG"
        
        if ($usedPercent -ge $Threshold) {
            $title = "⚠️ RAM Alert: $ComputerName"
            $body = @"
RAM-Auslastung kritisch!

Server: $ComputerName
RAM: $usedPercent%
Verwendet: $([Math]::Round($usedRAM/1MB, 2)) GB
Gesamt: $([Math]::Round($totalRAM/1MB, 2)) GB
Schwellenwert: $Threshold%
Zeit: $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")

Bitte System prüfen.
"@
            Send-Alert -Title $title -Body $body -Priority "warning"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Log "Fehler bei RAM-Prüfung: $_" -Level "ERROR"
        return $true
    }
}

# Funktion: Disk überwachen
function Test-Disks {
    param([int]$Threshold)
    
    Write-Log "Prüfe Festplatten..." -Level "DEBUG"
    
    try {
        $disks = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction Stop
        $criticalDisks = @()
        
        foreach ($disk in $disks) {
            $usedSpace = $disk.Size - $disk.FreeSpace
            $usedPercent = [Math]::Round(($usedSpace / $disk.Size) * 100, 2)
            
            Write-Log "Disk $($disk.DeviceID): $usedPercent% ($([Math]::Round($disk.FreeSpace/1GB, 2)) GB frei)" -Level "DEBUG"
            
            if ($usedPercent -ge $Threshold) {
                $criticalDisks += @{
                    Drive = $disk.DeviceID
                    Used = $usedPercent
                    Free = [Math]::Round($disk.FreeSpace/1GB, 2)
                    Total = [Math]::Round($disk.Size/1GB, 2)
                }
            }
        }
        
        if ($criticalDisks.Count -gt 0) {
            $diskInfo = $criticalDisks | ForEach-Object {
                "$($_.Drive) - $($_.Used)% belegt ($($_.Free) GB frei von $($_.Total) GB)"
            }
            
            $title = "⚠️ Disk Alert: $ComputerName"
            $body = @"
Festplatten-Auslastung kritisch!

Server: $ComputerName
Schwellenwert: $Threshold%

Betroffene Laufwerke:
$($diskInfo -join "`n")

Zeit: $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")

Bitte Speicherplatz freigeben.
"@
            Send-Alert -Title $title -Body $body -Priority "warning"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Log "Fehler bei Disk-Prüfung: $_" -Level "ERROR"
        return $true
    }
}

# Funktion: Kritische Dienste überwachen
function Test-CriticalServices {
    Write-Log "Prüfe kritische Dienste..." -Level "DEBUG"
    
    # Liste kritischer Dienste (anpassen nach Bedarf)
    $criticalServices = @(
        "W32Time",          # Windows Time
        "Dhcp",             # DHCP Client
        "Dnscache",         # DNS Client
        "EventLog",         # Windows Event Log
        "LanmanWorkstation" # Workstation
    )
    
    try {
        $stoppedServices = @()
        
        foreach ($serviceName in $criticalServices) {
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            
            if ($service -and $service.Status -ne "Running") {
                $stoppedServices += "$($service.DisplayName) ($serviceName)"
                Write-Log "Dienst nicht aktiv: $serviceName" -Level "WARN"
            }
        }
        
        if ($stoppedServices.Count -gt 0) {
            $title = "🚨 Service Alert: $ComputerName"
            $body = @"
Kritische Dienste sind gestoppt!

Server: $ComputerName
Zeit: $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")

Gestoppte Dienste:
$($stoppedServices -join "`n")

Bitte Dienste prüfen und starten.
"@
            Send-Alert -Title $title -Body $body -Priority "critical"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Log "Fehler bei Service-Prüfung: $_" -Level "ERROR"
        return $true
    }
}

# Haupt-Monitoring
Write-Log "=== System Monitoring Start ===" -Level "INFO"
Write-Log "Computer: $ComputerName" -Level "INFO"
Write-Log "Notification Server: $NotificationUrl" -Level "INFO"

$allOK = $true

# CPU prüfen
if (-not (Test-CPU -Threshold $CPUThreshold)) {
    $allOK = $false
}

# RAM prüfen
if (-not (Test-Memory -Threshold $MemoryThreshold)) {
    $allOK = $false
}

# Disks prüfen
if (-not (Test-Disks -Threshold $DiskThreshold)) {
    $allOK = $false
}

# Services prüfen
if (-not (Test-CriticalServices)) {
    $allOK = $false
}

# Zusammenfassung
if ($allOK) {
    Write-Log "=== Alle Prüfungen OK ===" -Level "INFO"
} else {
    Write-Log "=== Probleme festgestellt, Alerts gesendet ===" -Level "WARN"
}

Write-Log "=== System Monitoring Ende ===" -Level "INFO"

# Exit Code
if ($allOK) {
    exit 0
} else {
    exit 1
}
