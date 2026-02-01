# Scheduled Monitoring Task Setup
# Version 1.0 - Stadt Hohenems
# Created: 29.01.2026
#
# Dieses Script richtet geplante Aufgaben für automatisiertes Monitoring ein

<#
.SYNOPSIS
    Richtet Windows Scheduled Tasks für System-Monitoring ein
    
.DESCRIPTION
    Erstellt geplante Aufgaben, die regelmäßig System-Metriken überwachen
    und bei Problemen Benachrichtigungen senden.
    
.EXAMPLE
    .\Setup-MonitoringTasks.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ScriptPath = "C:\Scripts",
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath = "C:\Logs",
    
    [Parameter(Mandatory=$false)]
    [string]$NotificationServer = "notification-server"
)

# Erfordert Admin-Rechte
#Requires -RunAsAdministrator

Write-Host "=== Notification Gateway - Monitoring Tasks Setup ===" -ForegroundColor Cyan
Write-Host ""

# Verzeichnisse erstellen
Write-Host "Erstelle Verzeichnisse..." -ForegroundColor Yellow
@($ScriptPath, $LogPath) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
        Write-Host "  ✓ $_" -ForegroundColor Green
    } else {
        Write-Host "  ✓ $_ (bereits vorhanden)" -ForegroundColor Gray
    }
}

Write-Host ""

# Task 1: Alle 15 Minuten System-Check
Write-Host "Erstelle Task: System-Check (alle 15 Min)..." -ForegroundColor Yellow

$task1Name = "Notification-Gateway-System-Check"
$task1Action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath\Monitor-System.ps1`" -Server $NotificationServer"

$task1Trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$task1Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

try {
    # Entferne existierende Task falls vorhanden
    $existingTask = Get-ScheduledTask -TaskName $task1Name -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $task1Name -Confirm:$false
    }
    
    Register-ScheduledTask `
        -TaskName $task1Name `
        -Action $task1Action `
        -Trigger $task1Trigger `
        -Settings $task1Settings `
        -User "SYSTEM" `
        -RunLevel Highest `
        -Description "Überwacht System-Ressourcen und sendet Alerts bei Problemen" | Out-Null
    
    Write-Host "  ✓ Task erstellt" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Fehler: $_" -ForegroundColor Red
}

Write-Host ""

# Task 2: Täglich um 08:00 Uhr - Täglicher Report
Write-Host "Erstelle Task: Täglicher Report (08:00 Uhr)..." -ForegroundColor Yellow

$task2Name = "Notification-Gateway-Daily-Report"
$task2Script = @'
# Täglicher System Report
$NotificationUrl = "http://NOTIFICATION_SERVER:8000/notify"

# Sammle System-Infos
$uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$cpu = Get-Counter '\Processor(_Total)\% Processor Time' | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
$os = Get-CimInstance Win32_OperatingSystem
$memPercent = [Math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 2)

$report = @"
📊 Täglicher System Report

Server: $env:COMPUTERNAME
Uptime: $($uptime.Days) Tage, $($uptime.Hours) Stunden
CPU Durchschnitt: $([Math]::Round($cpu, 2))%
RAM Auslastung: $memPercent%

Status: Alle Systeme normal
"@

$notification = @{
    urls = "tag=info,teams,email"
    title = "Täglicher System Report - $env:COMPUTERNAME"
    body = $report
} | ConvertTo-Json

Invoke-RestMethod -Uri $NotificationUrl -Method Post -Body $notification -ContentType "application/json"
'@ -replace 'NOTIFICATION_SERVER', $NotificationServer

$task2ScriptPath = "$ScriptPath\Daily-Report.ps1"
$task2Script | Out-File -FilePath $task2ScriptPath -Encoding UTF8 -Force

$task2Action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$task2ScriptPath`""

$task2Trigger = New-ScheduledTaskTrigger -Daily -At "08:00"

try {
    $existingTask = Get-ScheduledTask -TaskName $task2Name -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $task2Name -Confirm:$false
    }
    
    Register-ScheduledTask `
        -TaskName $task2Name `
        -Action $task2Action `
        -Trigger $task2Trigger `
        -Settings $task1Settings `
        -User "SYSTEM" `
        -RunLevel Highest `
        -Description "Sendet täglichen System-Report um 08:00 Uhr" | Out-Null
    
    Write-Host "  ✓ Task erstellt" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Fehler: $_" -ForegroundColor Red
}

Write-Host ""

# Task 3: Wöchentlich Montags 09:00 - Wochenreport
Write-Host "Erstelle Task: Wöchentlicher Report (Mo 09:00)..." -ForegroundColor Yellow

$task3Name = "Notification-Gateway-Weekly-Report"
$task3Script = @'
# Wöchentlicher Report
$NotificationUrl = "http://NOTIFICATION_SERVER:8000/notify"

$report = @"
📈 Wöchentlicher IT Report

Server: $env:COMPUTERNAME
Zeitraum: $(Get-Date -Format "dd.MM.yyyy")

✅ Alle Monitoring-Tasks laufen
✅ Notification Gateway funktioniert
✅ Keine kritischen Alerts

Nächster Report: $(Get-Date).AddDays(7).ToString("dd.MM.yyyy")
"@

$notification = @{
    urls = "tag=info,teams,email"
    title = "📊 Wöchentlicher IT Report"
    body = $report
} | ConvertTo-Json

Invoke-RestMethod -Uri $NotificationUrl -Method Post -Body $notification -ContentType "application/json"
'@ -replace 'NOTIFICATION_SERVER', $NotificationServer

$task3ScriptPath = "$ScriptPath\Weekly-Report.ps1"
$task3Script | Out-File -FilePath $task3ScriptPath -Encoding UTF8 -Force

$task3Action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$task3ScriptPath`""

$task3Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "09:00"

try {
    $existingTask = Get-ScheduledTask -TaskName $task3Name -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $task3Name -Confirm:$false
    }
    
    Register-ScheduledTask `
        -TaskName $task3Name `
        -Action $task3Action `
        -Trigger $task3Trigger `
        -Settings $task1Settings `
        -User "SYSTEM" `
        -RunLevel Highest `
        -Description "Sendet wöchentlichen IT-Report jeden Montag um 09:00 Uhr" | Out-Null
    
    Write-Host "  ✓ Task erstellt" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Fehler: $_" -ForegroundColor Red
}

Write-Host ""

# Test Notification senden
Write-Host "Sende Test-Benachrichtigung..." -ForegroundColor Yellow

try {
    $testNotification = @{
        urls = "tag=info,teams"
        title = "✅ Monitoring Tasks Setup abgeschlossen"
        body = @"
Folgende Tasks wurden eingerichtet:

1. System-Check (alle 15 Min)
2. Täglicher Report (08:00 Uhr)
3. Wöchentlicher Report (Mo 09:00)

Server: $env:COMPUTERNAME
Zeit: $(Get-Date -Format "dd.MM.yyyy HH:mm:ss")
"@
    } | ConvertTo-Json
    
    Invoke-RestMethod `
        -Uri "http://${NotificationServer}:8000/notify" `
        -Method Post `
        -Body $testNotification `
        -ContentType "application/json" `
        -TimeoutSec 10 | Out-Null
    
    Write-Host "  ✓ Test-Benachrichtigung gesendet" -ForegroundColor Green
}
catch {
    Write-Host "  ⚠️ Test-Benachrichtigung fehlgeschlagen: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Setup abgeschlossen ===" -ForegroundColor Green
Write-Host ""
Write-Host "Erstellte Tasks:" -ForegroundColor Cyan
Write-Host "  • $task1Name" -ForegroundColor White
Write-Host "  • $task2Name" -ForegroundColor White
Write-Host "  • $task3Name" -ForegroundColor White
Write-Host ""
Write-Host "Tasks können in 'Task Scheduler' verwaltet werden." -ForegroundColor Gray
Write-Host ""

# Task-Status anzeigen
Write-Host "Task-Status:" -ForegroundColor Cyan
@($task1Name, $task2Name, $task3Name) | ForEach-Object {
    $task = Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
    if ($task) {
        $status = $task.State
        $color = if ($status -eq "Ready") { "Green" } else { "Yellow" }
        Write-Host "  • $_ : $status" -ForegroundColor $color
    }
}
