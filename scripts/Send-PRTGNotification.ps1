# PRTG Notification Script
# Version 1.0 - Stadt Hohenems
# Created: 29.01.2026
#
# Verwendung:
# 1. Script speichern in: C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\
# 2. PRTG Notification Template erstellen mit diesem Script
# 3. Bei Sensor Warning/Error wird Notification gesendet

<#
.SYNOPSIS
    Sendet PRTG Sensor-Alerts über das Notification Gateway
    
.PARAMETER SensorName
    Name des PRTG Sensors
    
.PARAMETER DeviceName
    Name des überwachten Geräts
    
.PARAMETER Status
    Status des Sensors (Up, Warning, Down, Error, Paused)
    
.PARAMETER Message
    Fehlermeldung oder Status-Info
    
.PARAMETER LastValue
    Letzter gemessener Wert
    
.PARAMETER Server
    Notification Gateway Server (Standard: notification-server)
    
.PARAMETER Port
    Notification Gateway Port (Standard: 8000)
    
.EXAMPLE
    .\Send-PRTGNotification.ps1 -SensorName "Ping" -DeviceName "DC01" -Status "Down" -Message "Host nicht erreichbar"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SensorName = "%sensorname%",
    
    [Parameter(Mandatory=$false)]
    [string]$DeviceName = "%device%",
    
    [Parameter(Mandatory=$false)]
    [string]$Status = "%status%",
    
    [Parameter(Mandatory=$false)]
    [string]$Message = "%message%",
    
    [Parameter(Mandatory=$false)]
    [string]$LastValue = "%lastvalue%",
    
    [Parameter(Mandatory=$false)]
    [string]$Server = "notification-server",
    
    [Parameter(Mandatory=$false)]
    [int]$Port = 8000
)

# Konfiguration
$NotificationUrl = "http://${Server}:${Port}/notify"
$LogFile = "C:\Logs\PRTG-Notifications.log"

# Log-Funktion
function Write-Log {
    param([string]$Message)
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"
    
    # In Datei schreiben
    try {
        $logDir = Split-Path $LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $logMessage
    }
    catch {
        # Fallback auf Event Log
        Write-EventLog -LogName Application -Source "PRTG-Notification" -EventId 1000 -Message $logMessage -ErrorAction SilentlyContinue
    }
}

# Bestimme Priorität basierend auf Status
function Get-NotificationTags {
    param([string]$Status)
    
    switch ($Status.ToLower()) {
        "down"    { return "kritisch" }
        "error"   { return "kritisch" }
        "warning" { return "warnung,whatsapp,teams" }
        "unusual" { return "info,teams" }
        default   { return "info,email" }
    }
}

# Emoji für Status
function Get-StatusEmoji {
    param([string]$Status)
    
    switch ($Status.ToLower()) {
        "up"      { return "✅" }
        "down"    { return "🚨" }
        "error"   { return "❌" }
        "warning" { return "⚠️" }
        "unusual" { return "⚡" }
        "paused"  { return "⏸️" }
        default   { return "ℹ️" }
    }
}

# Hauptlogik
try {
    Write-Log "PRTG Alert empfangen: Sensor=$SensorName, Device=$DeviceName, Status=$Status"
    
    # Bestimme Tags
    $tags = Get-NotificationTags -Status $Status
    $emoji = Get-StatusEmoji -Status $Status
    
    # Erstelle Nachricht
    $title = "$emoji PRTG Alert: $DeviceName"
    $body = @"
Sensor: $SensorName
Status: $Status
Device: $DeviceName
Message: $Message
Letzter Wert: $LastValue
Zeit: $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")
"@
    
    # Erstelle JSON Body
    $notification = @{
        urls = "tag=$tags"
        title = $title
        body = $body
    } | ConvertTo-Json
    
    Write-Log "Sende Notification mit Tags: $tags"
    
    # Sende Notification
    $response = Invoke-RestMethod `
        -Uri $NotificationUrl `
        -Method Post `
        -Body $notification `
        -ContentType "application/json" `
        -TimeoutSec 30 `
        -ErrorAction Stop
    
    Write-Log "Notification erfolgreich gesendet"
    
    # PRTG XML Output (für Sensor-Script)
    Write-Host "<?xml version=`"1.0`" encoding=`"UTF-8`" ?>"
    Write-Host "<prtg>"
    Write-Host "  <result>"
    Write-Host "    <channel>Notifications Sent</channel>"
    Write-Host "    <value>1</value>"
    Write-Host "  </result>"
    Write-Host "  <text>Notification gesendet für $SensorName</text>"
    Write-Host "</prtg>"
    
    exit 0
}
catch {
    $errorMessage = $_.Exception.Message
    Write-Log "FEHLER beim Senden: $errorMessage"
    
    # PRTG XML Error Output
    Write-Host "<?xml version=`"1.0`" encoding=`"UTF-8`" ?>"
    Write-Host "<prtg>"
    Write-Host "  <error>1</error>"
    Write-Host "  <text>Fehler beim Senden: $errorMessage</text>"
    Write-Host "</prtg>"
    
    exit 1
}
