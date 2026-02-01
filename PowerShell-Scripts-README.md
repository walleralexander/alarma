# PowerShell Scripts - Notification Gateway
## WebPoint Internet Solutions IT

**Version:** 1.0  
**Datum:** 29. Januar 2026  
**Ersteller:** Alexander

---

## Übersicht

Diese PowerShell Scripts ermöglichen die Integration des Multi-Channel Notification Gateway in die IT-Infrastruktur der WebPoint Internet Solutions.

## Dateien

### 1. NotificationGateway.psm1
**PowerShell Modul mit Hilfsfunktionen**

**Installation:**
```powershell
# Modul importieren
Import-Module "C:\Scripts\NotificationGateway.psm1"

# Server konfigurieren
Set-NotificationServer -Server "192.168.1.100" -Port 8000

# Verbindung testen
Test-NotificationGateway
```

**Verfügbare Funktionen:**
- `Send-CriticalAlert` - Kritische Benachrichtigung (SMS + WhatsApp + Teams)
- `Send-WarningAlert` - Warnung (WhatsApp + Teams)
- `Send-InfoMessage` - Information (WhatsApp + Teams)
- `Send-SMSAlert` - Nur SMS
- `Send-WhatsAppMessage` - Nur WhatsApp
- `Send-TeamsMessage` - Nur Teams
- `Send-EmailNotification` - Nur E-Mail
- `Send-CustomNotification` - Benutzerdefiniert mit Tags

**Beispiele:**
```powershell
# Kritischer Alert
Send-CriticalAlert -Title "Firewall Down" -Body "Palo Alto nicht erreichbar"

# Warnung
Send-WarningAlert -Title "CPU Hoch" -Body "DC01: CPU bei 85%"

# Info
Send-InfoMessage -Title "Backup OK" -Body "Nightly Backup erfolgreich"

# Nur SMS
Send-SMSAlert -Body "Server DC01 down"

# Custom mit Tags
Send-CustomNotification -Tags "teams,email" -Title "Report" -Body "Wochenbericht verfügbar"
```

---

### 2. Send-PRTGNotification.ps1
**PRTG Integration Script**

**Installation:**
1. Script kopieren nach:
   ```
   C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\
   ```

2. In PRTG Notification Template erstellen:
   - **Methode:** Execute Program
   - **Program:** `Send-PRTGNotification.ps1`
   - **Parameter:**
     ```
     -SensorName "%sensorname%" -DeviceName "%device%" -Status "%status%" -Message "%message%"
     ```

3. Notification Trigger konfigurieren:
   - Bei Sensor Status "Warning" oder "Error"

**Parameter:**
- `-SensorName` - PRTG Sensor Name
- `-DeviceName` - Gerätename
- `-Status` - Status (Up, Warning, Down, Error)
- `-Message` - Fehlermeldung
- `-Server` - Notification Server (Standard: notification-server)
- `-Port` - Port (Standard: 8000)

**Beispiel:**
```powershell
.\scripts\Send-PRTGNotification.ps1 `
    -SensorName "Ping" `
    -DeviceName "DC01" `
    -Status "Down" `
    -Message "Host nicht erreichbar"
```

**Log-Datei:**
`C:\Logs\PRTG-Notifications.log`

---

### 3. Monitor-System.ps1
**System-Monitoring mit automatischen Alerts**

**Verwendung:**
```powershell
# Lokales System überwachen
.\scripts\Monitor-System.ps1

# Spezifisches System
.\scripts\Monitor-System.ps1 -ComputerName "DC01"

# Custom Schwellenwerte
.\scripts\Monitor-System.ps1 -CPUThreshold 75 -MemoryThreshold 80 -DiskThreshold 85

# Custom Notification Server
.\scripts\Monitor-System.ps1 -Server "192.168.1.100" -Port 8000
```

**Parameter:**
- `-ComputerName` - Zu überwachender Computer (Standard: localhost)
- `-Server` - Notification Gateway Server
- `-Port` - Notification Gateway Port
- `-CPUThreshold` - CPU Schwellenwert % (Standard: 80)
- `-MemoryThreshold` - RAM Schwellenwert % (Standard: 85)
- `-DiskThreshold` - Disk Schwellenwert % (Standard: 90)

**Überwachte Metriken:**
- ✅ CPU-Auslastung
- ✅ RAM-Auslastung
- ✅ Festplatten-Speicherplatz
- ✅ Kritische Windows-Dienste

**Log-Datei:**
`C:\Logs\SystemMonitor-{ComputerName}.log`

**Beispiel für geplante Aufgabe:**
```powershell
# Alle 15 Minuten ausführen
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Scripts\Monitor-System.ps1"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 15)
Register-ScheduledTask -TaskName "SystemMonitor" -Action $action -Trigger $trigger -User "SYSTEM"
```

---

### 4. Setup-MonitoringTasks.ps1
**Automatisches Setup für geplante Monitoring-Tasks**

**Verwendung:**
```powershell
# Als Administrator ausführen!
.\scripts\Setup-MonitoringTasks.ps1

# Mit custom Parametern
.\scripts\Setup-MonitoringTasks.ps1 -ScriptPath "D:\Scripts" -NotificationServer "192.168.1.100"
```

**Erstellt folgende Aufgaben:**

1. **System-Check** (alle 15 Minuten)
   - Überwacht CPU, RAM, Disk, Dienste
   - Sendet Alerts bei Problemen

2. **Täglicher Report** (08:00 Uhr)
   - System-Status Zusammenfassung
   - An Teams & E-Mail

3. **Wöchentlicher Report** (Montag 09:00 Uhr)
   - Wochen-Zusammenfassung
   - An Teams & E-Mail

**Parameter:**
- `-ScriptPath` - Pfad für Scripts (Standard: C:\Scripts)
- `-LogPath` - Pfad für Logs (Standard: C:\Logs)
- `-NotificationServer` - Notification Server

**Hinweis:** Erfordert Administrator-Rechte!

---

## Schnellstart

### 1. Module installieren
```powershell
# Als Administrator
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Modul kopieren nach
Copy-Item ".\scripts\NotificationGateway.psm1" "C:\Scripts\"

# In Profil einbinden (optional)
Add-Content $PROFILE 'Import-Module "C:\Scripts\NotificationGateway.psm1"'
```

### 2. Test-Notification senden
```powershell
Import-Module "C:\Scripts\NotificationGateway.psm1"
Set-NotificationServer -Server "notification-server" -Port 8000
Test-NotificationGateway

Send-InfoMessage -Title "Test" -Body "Hallo vom Notification Gateway!"
```

### 3. Monitoring einrichten
```powershell
# Als Administrator
.\scripts\Setup-MonitoringTasks.ps1
```

### 4. PRTG integrieren
1. `Send-PRTGNotification.ps1` in PRTG Verzeichnis kopieren
2. Notification Template erstellen
3. Bei Sensors Trigger konfigurieren

---

## Konfiguration

### Notification Server ändern
```powershell
# Im Modul
Set-NotificationServer -Server "192.168.1.100" -Port 8000

# In Scripts direkt
$NotificationUrl = "http://192.168.1.100:8000/notify"
```

### Tag-System

**Vordefinierte Tags in Apprise:**
- `kritisch` - SMS + WhatsApp + Teams + Email (für kritische Alerts)
- `warnung` - WhatsApp + Teams (für Warnungen)
- `info` - Teams + Email (für Informationen)
- `sms` - Nur SMS
- `whatsapp` - Nur WhatsApp
- `teams` - Nur Microsoft Teams
- `email` - Nur E-Mail

**Tags können kombiniert werden:**
```powershell
Send-CustomNotification -Tags "teams,email,push" -Title "Info" -Body "Nachricht"
```

---

## Troubleshooting

### Problem: Notifications kommen nicht an

**Prüfen:**
```powershell
# 1. Verbindung testen
Test-NotificationGateway

# 2. URL manuell testen
Invoke-RestMethod -Uri "http://notification-server:8000/" -Method Get

# 3. Manuelle Notification senden
$test = @{
    urls = "tag=teams"
    body = "Test"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://notification-server:8000/notify" -Method Post -Body $test -ContentType "application/json"
```

### Problem: Scripts werden nicht ausgeführt

**Execution Policy prüfen:**
```powershell
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problem: PRTG Notifications funktionieren nicht

**Prüfen:**
1. Script-Pfad korrekt in PRTG?
2. Parameter richtig übergeben?
3. Log-Datei prüfen: `C:\Logs\PRTG-Notifications.log`
4. Test manuell ausführen:
   ```powershell
   .\scripts\Send-PRTGNotification.ps1 -SensorName "Test" -Status "Down"
   ```

### Problem: Scheduled Tasks laufen nicht

**Prüfen:**
```powershell
# Task Status anzeigen
Get-ScheduledTask | Where-Object {$_.TaskName -like "*Notification*"}

# Task History prüfen
Get-ScheduledTask -TaskName "Notification-Gateway-System-Check" | Get-ScheduledTaskInfo

# Task manuell starten
Start-ScheduledTask -TaskName "Notification-Gateway-System-Check"
```

---

## Best Practices

### 1. Schwellenwerte anpassen
Passe die Schwellenwerte an deine Umgebung an:
```powershell
# Produktionsserver - konservativ
.\scripts\Monitor-System.ps1 -CPUThreshold 70 -MemoryThreshold 80

# Entwicklungsserver - toleranter
.\scripts\Monitor-System.ps1 -CPUThreshold 85 -MemoryThreshold 90
```

### 2. Log-Rotation einrichten
```powershell
# Alte Logs löschen (älter als 30 Tage)
Get-ChildItem "C:\Logs\*.log" | 
    Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | 
    Remove-Item
```

### 3. Monitoring-Intervalle
- **Kritische Server:** 5-10 Minuten
- **Standard Server:** 15-30 Minuten
- **Entwicklung:** 60 Minuten

### 4. Alert-Fatigue vermeiden
Nicht zu viele Notifications senden:
- Kritisch: Sofort
- Warnung: Nach 3 aufeinanderfolgenden Checks
- Info: Zusammengefasst (täglich/wöchentlich)

---

## Integration Beispiele

### VMware vCenter Alerts
```powershell
# Bei VM-Event Notification senden
$vmEvent = Get-VIEvent -MaxSamples 1
if ($vmEvent.EventTypeId -eq "VmPoweredOffEvent") {
    Send-WarningAlert -Title "VM Down" -Body "VM $($vmEvent.Vm.Name) wurde ausgeschaltet"
}
```

### Veeam Backup Status
```powershell
# Nach Backup-Job
$job = Get-VBRJob -Name "Daily Backup"
if ($job.GetLastResult() -eq "Failed") {
    Send-CriticalAlert -Title "Backup Failed" -Body "Job: $($job.Name)"
} else {
    Send-InfoMessage -Title "Backup OK" -Body "Job: $($job.Name) erfolgreich"
}
```

### Active Directory Events
```powershell
# Bei Admin-Login
$event = Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4672} -MaxEvents 1
Send-InfoMessage -Title "Admin Login" -Body "User: $($event.Properties[1].Value)"
```

---

## Support & Kontakt

**Ersteller:** Alexander  
**Abteilung:** Organisation, Prozessmanagement und IT  
**Organisation:** WebPoint Internet Solutions  

**Bei Fragen oder Problemen:**
- Interne IT-Dokumentation prüfen
- Log-Dateien analysieren
- Test-Notifications senden

**Version:** 1.0  
**Letzte Aktualisierung:** 29. Januar 2026
