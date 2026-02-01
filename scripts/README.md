# Alarma! Backup & Restore Scripts

Dieses Verzeichnis enthält vollständige Backup- und Restore-Skripte für das Alarma!-System.

## 📁 Dateien

- **backup-alarma.ps1** - PowerShell Backup-Skript für Windows
- **backup-alarma.sh** - Bash Backup-Skript für Linux/macOS
- **restore-alarma.ps1** - PowerShell Restore-Skript für Windows
- **restore-alarma.sh** - Bash Restore-Skript für Linux/macOS

## 🚀 Schnellstart

### Windows

```powershell
# Backup erstellen
.\scripts\backup-alarma.ps1

# Backups auflisten
.\scripts\restore-alarma.ps1 -ListBackups

# Restore durchführen
.\scripts\restore-alarma.ps1 -BackupFile "C:\Alarma!-Backups\alarma-full-20260130-020000.zip"
```

### Linux/macOS

```bash
# Backup erstellen
./scripts/backup-alarma.sh

# Backups auflisten
./scripts/restore-alarma.sh -l

# Restore durchführen
./scripts/restore-alarma.sh -f /opt/alarma-backups/alarma-full-20260130-020000.tar.gz
```

## 📖 Dokumentation

Für vollständige Dokumentation, Best Practices und Troubleshooting siehe:

**[../BACKUP-RESTORE.md](../BACKUP-RESTORE.md)**

## ⚙️ Features

### Backup-Skripte

- ✅ Vollständige Sicherung aller Konfigurationen und Docker-Volumes
- ✅ Komprimierte Archive (tar.gz/zip)
- ✅ Optionale GPG-Verschlüsselung
- ✅ Automatische Bereinigung alter Backups (Retention Policy)
- ✅ Benachrichtigungen über Alarma! bei Erfolg/Fehler
- ✅ Umfassendes Logging
- ✅ Fehlerbehandlung und Rollback

### Restore-Skripte

- ✅ Auswahl und Auflistung verfügbarer Backups
- ✅ Automatische Entschlüsselung (bei verschlüsselten Backups)
- ✅ Pre-Restore-Backup als Sicherheit
- ✅ Automatisches Stoppen/Starten der Container
- ✅ Verifikation der wiederhergestellten Daten
- ✅ Interaktive Bestätigung (deaktivierbar mit -Force/-y)
- ✅ Umfassendes Logging und Fehlerbehandlung

## 📋 Beispiele

### Tägliches Backup mit Benachrichtigung

```powershell
# Windows
.\scripts\backup-alarma.ps1 `
    -BackupDir "D:\Backups\Alarma!" `
    -RetentionDays 14 `
    -NotifyUrl "http://localhost:8080/notify"
```

```bash
# Linux
./scripts/backup-alarma.sh \
    -d /mnt/nas/alarma-backups \
    -r 14 \
    -n http://localhost:8080/notify
```

### Verschlüsseltes Backup

```powershell
# Windows (benötigt GPG4Win)
.\scripts\backup-alarma.ps1 -Encrypt -EncryptionKey "backup@example.com"
```

```bash
# Linux
./scripts/backup-alarma.sh -e -k backup@example.com
```

### Restore mit Verifikation

```powershell
# Windows
.\scripts\restore-alarma.ps1 `
    -BackupFile "C:\Backups\alarma-full-20260130.zip" `
    -Verify `
    -NotifyUrl "http://localhost:8080/notify"
```

```bash
# Linux
./scripts/restore-alarma.sh \
    -f /opt/backups/alarma-full-20260130.tar.gz \
    -v \
    -n http://localhost:8080/notify
```

## 🔒 Sicherheit

⚠️ **WICHTIG:** Backups enthalten sensible Daten (API-Keys, Passwörter, etc.)!

- Verwenden Sie immer Verschlüsselung für Offsite-Backups
- Speichern Sie Backups sicher und mit eingeschränktem Zugriff
- Testen Sie regelmäßig die Restore-Funktionalität
- Bewahren Sie GPG-Schlüssel und Passphrases sicher auf

## 🤖 Automatisierung

### Windows (Task Scheduler)

```powershell
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Alarma!\scripts\backup-alarma.ps1"

$Trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

Register-ScheduledTask -TaskName "Alarma! Daily Backup" `
    -Action $Action -Trigger $Trigger
```

### Linux (Cron)

```bash
# crontab -e
0 2 * * * /opt/alarma/scripts/backup-alarma.sh -d /opt/backups -r 7 -e >> /var/log/alarma-backup.log 2>&1
```

## 🆘 Hilfe

Alle Skripte bieten eine integrierte Hilfe:

```powershell
# Windows
Get-Help .\scripts\backup-alarma.ps1 -Detailed
Get-Help .\scripts\restore-alarma.ps1 -Detailed
```

```bash
# Linux/macOS
./scripts/backup-alarma.sh -h
./scripts/restore-alarma.sh -h
```

## 🔍 Troubleshooting

### Problem: "Docker läuft nicht"

**Lösung:** Starten Sie Docker Desktop (Windows) oder den Docker-Service (Linux)

```bash
# Linux
sudo systemctl start docker
```

### Problem: "Permission denied" (Linux)

**Lösung:** User zur Docker-Gruppe hinzufügen

```bash
sudo usermod -aG docker $USER
# Neu anmelden erforderlich
```

### Problem: GPG-Verschlüsselung schlägt fehl

**Lösung:** Installieren Sie GPG

- **Windows:** [GPG4Win](https://www.gpg4win.org/)
- **Linux:** `sudo apt install gnupg` oder `sudo yum install gnupg`
- **macOS:** `brew install gnupg`

### Problem: Backup ist zu groß

**Lösung:**

- Bereinigen Sie alte Docker-Images: `docker image prune -a`
- Verwenden Sie stärkere Kompression
- Implementieren Sie inkrementelle Backups

## 📊 Was wird gesichert?

### Konfigurationsdateien

- `docker-compose/docker-compose.yml`
- `docker-compose/*.yml`
- `docker-compose/.env` (Secrets!)

### Docker-Volumes

- `apprise-config` - Apprise-Konfiguration
- `sms-data` - SMS-Gateway-Daten
- `whatsapp-data` - WhatsApp-Session
- `signal-data` - Signal-Messenger-Daten
- `ntfy` - ntfy-Server-Datenbank

## 🎯 RTO & RPO

- **Recovery Time Objective (RTO):** 1 Stunde
- **Recovery Point Objective (RPO):** 24 Stunden

Mit täglichen Backups um 2:00 Uhr nachts.

## 📝 Logs

Backup- und Restore-Operationen werden geloggt:

- **Windows:** `C:\Alarma!-Backups\backup.log` oder Temp-Verzeichnis
- **Linux:** `/opt/alarma-backups/backup.log` oder `/tmp/alarma-*.log`

## 🔗 Weiterführende Links

- [Vollständige Backup-Dokumentation](../BACKUP-RESTORE.md)
- [Alarma! Hauptdokumentation](../Alarma-Dokumentation.md)
- [Security Best Practices](../SECURITY.md)
- [Secrets Management](../SECRETS-MANAGEMENT.md)

## 📄 Lizenz

Diese Skripte sind Teil des Alarma!-Projekts und stehen unter derselben Lizenz.

## ✍️ Autor

Alarma! Project - 2026

---

**Hinweis:** Testen Sie Backups regelmäßig! Ein ungetestetes Backup ist kein Backup.
