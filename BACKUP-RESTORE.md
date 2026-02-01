# Alarma! Backup und Restore-Dokumentation

## Übersicht

Diese Dokumentation beschreibt die Backup- und Restore-Verfahren für das Alarma! Multi-Channel-Notification-Gateway. Ein zuverlässiges Backup-System ist essentiell, um Datenverlust zu vermeiden und einen schnellen Wiederherstellungsprozess im Notfall zu gewährleisten.

## RTO und RPO

- **Recovery Time Objective (RTO):** 1 Stunde
  - Die maximale Zeit, die benötigt wird, um das System nach einem Ausfall wiederherzustellen
  - Beinhaltet: Erkennung des Problems, Zugriff auf Backups, Durchführung der Wiederherstellung

- **Recovery Point Objective (RPO):** 24 Stunden
  - Der maximale Datenverlust, der akzeptabel ist
  - Bedeutet: Tägliche Backups mit maximal 24 Stunden Datenverlust

## Was muss gesichert werden?

### 1. Konfigurationsdateien

```txt
docker-compose/
├── docker-compose.yml
├── apprise.yml
├── ntfy-server.yml
├── sms-config.yml
├── .env (enthält Secrets!)
└── CONFIG-README.md
```

### 2. Docker Volumes

- **apprise-config** - Apprise-Konfigurationsdaten
- **sms-data** - SMS-Gateway-Daten und Konfiguration
- **whatsapp-data** - WhatsApp-Session und Konfiguration
- **signal-data** - Signal-Messenger-Daten
- **ntfy-cache** oder **ntfy** - ntfy-Server-Cache und Datenbank

### 3. Projektdateien (optional)

- PowerShell-Skripte
- Dokumentation
- README-Dateien

### 4. Secrets und Credentials

⚠️ **WICHTIG:** Backups enthalten sensible Daten und müssen verschlüsselt und sicher aufbewahrt werden!

## Backup-Strategie

### Empfohlener Backup-Zeitplan

| Typ | Häufigkeit | Aufbewahrung | Zweck |
| ----- | ----------- | -------------- | ------- |
| **Vollbackup** | Täglich (nachts) | 7 Tage | Tägliche Sicherung aller Daten |
| **Wöchentlich** | Sonntags | 4 Wochen | Monatliche Historie |
| **Monatlich** | 1. des Monats | 12 Monate | Langzeitarchivierung |
| **Vor Updates** | Manuell | Bis Update erfolgreich | Rollback-Option |

### Backup-Speicherorte

1. **Lokal:** `/opt/alarma-backups` oder `C:\Alarma!-Backups`
2. **NAS/Netzwerk:** Für zusätzliche Redundanz
3. **Cloud/Offsite:** Für Disaster Recovery (verschlüsselt!)

## Manuelle Backup-Prozeduren

### Schnell-Backup vor Änderungen

```bash
# Linux/macOS
cd /pfad/zu/alarma
docker-compose -f docker-compose/docker-compose.yml stop
tar -czf "alarma-backup-$(date +%Y%m%d-%H%M%S).tar.gz" docker-compose/
docker-compose -f docker-compose/docker-compose.yml start
```

```powershell
# Windows PowerShell
cd C:\Pfad\zu\Alarma!
docker-compose -f docker-compose/docker-compose.yml stop
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
Compress-Archive -Path docker-compose\* -DestinationPath "alarma-backup-$timestamp.zip"
docker-compose -f docker-compose/docker-compose.yml start
```

### Vollständiges manuelles Backup

#### Linux/macOS

```bash
#!/bin/bash
BACKUP_DIR="/opt/alarma-backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="alarma-full-$TIMESTAMP"

# Erstelle Backup-Verzeichnis
mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

# Sichere Konfigurationsdateien
cp -r docker-compose "$BACKUP_DIR/$BACKUP_NAME/"

# Sichere Docker Volumes
docker run --rm \
  -v apprise-config:/volume \
  -v "$BACKUP_DIR/$BACKUP_NAME":/backup \
  alpine tar czf /backup/apprise-config.tar.gz -C /volume .

docker run --rm \
  -v sms-data:/volume \
  -v "$BACKUP_DIR/$BACKUP_NAME":/backup \
  alpine tar czf /backup/sms-data.tar.gz -C /volume .

docker run --rm \
  -v whatsapp-data:/volume \
  -v "$BACKUP_DIR/$BACKUP_NAME":/backup \
  alpine tar czf /backup/whatsapp-data.tar.gz -C /volume .

docker run --rm \
  -v signal-data:/volume \
  -v "$BACKUP_DIR/$BACKUP_NAME":/backup \
  alpine tar czf /backup/signal-data.tar.gz -C /volume .

docker run --rm \
  -v ntfy:/volume \
  -v "$BACKUP_DIR/$BACKUP_NAME":/backup \
  alpine tar czf /backup/ntfy.tar.gz -C /volume .

# Erstelle Gesamt-Archiv
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

echo "Backup erstellt: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
```

#### Windows PowerShell

```powershell
$BackupDir = "C:\Alarma!-Backups"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupName = "alarma-full-$Timestamp"

# Erstelle Backup-Verzeichnis
New-Item -ItemType Directory -Force -Path "$BackupDir\$BackupName"

# Sichere Konfigurationsdateien
Copy-Item -Recurse docker-compose "$BackupDir\$BackupName\"

# Sichere Docker Volumes (erfordert Docker Desktop)
docker run --rm `
  -v apprise-config:/volume `
  -v "${BackupDir}\${BackupName}:/backup" `
  alpine tar czf /backup/apprise-config.tar.gz -C /volume .

# ... (weitere Volumes wie oben)

# Erstelle ZIP-Archiv
Compress-Archive -Path "$BackupDir\$BackupName\*" -DestinationPath "$BackupDir\$BackupName.zip"
Remove-Item -Recurse -Force "$BackupDir\$BackupName"

Write-Host "Backup erstellt: $BackupDir\$BackupName.zip"
```

## Automatisierte Backups mit Skripten

### Backup-Skripte verwenden

Das Projekt enthält fertige Backup-Skripte für Windows und Linux:

#### Windows

```powershell
# Backup erstellen
.\scripts\backup-alarma.ps1 -BackupDir "C:\Alarma!-Backups" -RetentionDays 7 -Encrypt

# Mit Benachrichtigung
.\scripts\backup-alarma.ps1 -BackupDir "C:\Alarma!-Backups" -NotifyUrl "http://localhost:8080/notify"
```

#### Linux

```bash
# Backup erstellen
./scripts/backup-alarma.sh -d /opt/alarma-backups -r 7 -e

# Mit Benachrichtigung
./scripts/backup-alarma.sh -d /opt/alarma-backups -n http://localhost:8080/notify
```

### Automatisierung einrichten

#### Windows (Task Scheduler)

```powershell
# Erstelle geplante Aufgabe
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Alarma!\scripts\backup-alarma.ps1 -BackupDir C:\Alarma!-Backups -RetentionDays 7"

$Trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

Register-ScheduledTask -TaskName "Alarma! Daily Backup" `
  -Action $Action -Trigger $Trigger -Principal $Principal `
  -Description "Tägliches Backup des Alarma!-Systems"
```

#### Linux (Cron)

```bash
# Bearbeite crontab
crontab -e

# Füge folgende Zeile hinzu (täglich um 2:00 Uhr)
0 2 * * * /opt/alarma/scripts/backup-alarma.sh -d /opt/alarma-backups -r 7 -e >> /var/log/alarma-backup.log 2>&1
```

#### Docker Container (Alternative)

Erstelle einen Backup-Container, der regelmäßig läuft:

```yaml
services:
  backup:
    image: alpine:latest
    volumes:
      - apprise-config:/volumes/apprise-config:ro
      - sms-data:/volumes/sms-data:ro
      - whatsapp-data:/volumes/whatsapp-data:ro
      - signal-data:/volumes/signal-data:ro
      - ntfy:/volumes/ntfy:ro
      - ./backups:/backups
      - ./scripts:/scripts:ro
    environment:
      - BACKUP_RETENTION_DAYS=7
    command: >
      sh -c "apk add --no-cache bash && 
             /scripts/backup-docker-volumes.sh"
    restart: "no"
```

## Restore-Prozeduren

### Vor dem Restore

1. **Backup überprüfen:** Stelle sicher, dass das Backup vollständig und nicht beschädigt ist
2. **Aktuellen Zustand sichern:** Erstelle ein Backup des aktuellen Zustands (falls möglich)
3. **Services stoppen:** Stoppe alle laufenden Container
4. **Dokumentation:** Notiere den Grund für den Restore und den Zeitpunkt

### Automatisierter Restore mit Skripten

#### Windows

```powershell
# Liste verfügbare Backups
.\scripts\restore-alarma.ps1 -ListBackups -BackupDir "C:\Alarma!-Backups"

# Restore durchführen
.\scripts\restore-alarma.ps1 -BackupFile "C:\Alarma!-Backups\alarma-full-20260130-020000.zip"

# Mit Verify-Option
.\scripts\restore-alarma.ps1 -BackupFile "C:\Alarma!-Backups\alarma-full-20260130-020000.zip" -Verify
```

### Restore mit Skripten (Linux)

```bash
# Liste verfügbare Backups
./scripts/restore-alarma.sh -l -d /opt/alarma-backups

# Restore durchführen
./scripts/restore-alarma.sh -f /opt/alarma-backups/alarma-full-20260130-020000.tar.gz

# Mit Verify-Option
./scripts/restore-alarma.sh -f /opt/alarma-backups/alarma-full-20260130-020000.tar.gz -v
```

### Manueller Restore

#### Schritt 1: Container stoppen

```bash
cd /pfad/zu/alarma
docker-compose -f docker-compose/docker-compose.yml down
```

#### Schritt 2: Backup entpacken

```bash
# Linux
BACKUP_FILE="/opt/alarma-backups/alarma-full-20260130-020000.tar.gz"
RESTORE_DIR="/tmp/alarma-restore"
mkdir -p "$RESTORE_DIR"
tar -xzf "$BACKUP_FILE" -C "$RESTORE_DIR"

# Windows
$BackupFile = "C:\Alarma!-Backups\alarma-full-20260130-020000.zip"
$RestoreDir = "C:\Temp\alarma-restore"
Expand-Archive -Path $BackupFile -DestinationPath $RestoreDir
```

#### Schritt 3: Konfigurationsdateien wiederherstellen

```bash
# Linux
cp -r "$RESTORE_DIR/docker-compose/"* ./docker-compose/

# Windows
Copy-Item -Recurse "$RestoreDir\docker-compose\*" .\docker-compose\
```

#### Schritt 4: Docker Volumes wiederherstellen

```bash
# Linux - Beispiel für apprise-config
docker run --rm \
  -v apprise-config:/volume \
  -v "$RESTORE_DIR":/backup \
  alpine sh -c "rm -rf /volume/* && tar xzf /backup/apprise-config.tar.gz -C /volume"

# Wiederhole für alle Volumes:
# - sms-data
# - whatsapp-data
# - signal-data
# - ntfy
```

```powershell
# Windows - Beispiel für apprise-config
docker run --rm `
  -v apprise-config:/volume `
  -v "${RestoreDir}:/backup" `
  alpine sh -c "rm -rf /volume/* && tar xzf /backup/apprise-config.tar.gz -C /volume"
```

#### Schritt 5: Container starten

```bash
docker-compose -f docker-compose/docker-compose.yml up -d
```

#### Schritt 6: Funktionalität überprüfen

```bash
# Container-Status prüfen
docker-compose -f docker-compose/docker-compose.yml ps

# Logs überprüfen
docker-compose -f docker-compose/docker-compose.yml logs

# Test-Nachricht senden
curl -X POST http://localhost:8080/notify -d "Test nach Restore"
```

### Restore-Checkliste

- [ ] Backup-Datei identifiziert und verifiziert
- [ ] Aktueller Zustand gesichert (falls möglich)
- [ ] Container gestoppt
- [ ] Konfigurationsdateien wiederhergestellt
- [ ] Docker Volumes wiederhergestellt
- [ ] Container neu gestartet
- [ ] Logs auf Fehler überprüft
- [ ] Funktionstest durchgeführt
- [ ] Test-Benachrichtigung gesendet
- [ ] Restore dokumentiert

## Backup-Integrität testen

### Regelmäßige Integritätsprüfungen

Es wird empfohlen, monatlich die Backup-Integrität zu testen:

```bash
# Linux
./scripts/restore-alarma.sh -f /opt/alarma-backups/latest.tar.gz -v --dry-run

# Windows
.\scripts\restore-alarma.ps1 -BackupFile "C:\Alarma!-Backups\latest.zip" -Verify -WhatIf
```

### Test-Restore in isolierter Umgebung

1. **Test-VM oder Container erstellen**
2. **Backup-Datei kopieren**
3. **Restore durchführen**
4. **Funktionalität vollständig testen**
5. **Restore-Zeit messen** (zur RTO-Validierung)

### Backup-Validierung

```bash
# Archiv-Integrität prüfen
tar -tzf backup.tar.gz > /dev/null && echo "OK" || echo "FEHLER"

# ZIP-Integrität prüfen (Windows)
Test-Archive -Path backup.zip

# GPG-verschlüsselte Backups
gpg --verify backup.tar.gz.gpg
```

## Offsite-Backup-Empfehlungen

### Cloud-Speicher

#### Mit rclone

```bash
# rclone installieren und konfigurieren
curl https://rclone.org/install.sh | sudo bash
rclone config

# Backup zu Cloud kopieren
rclone copy /opt/alarma-backups/ remote:alarma-backups/ \
  --include "alarma-full-*.tar.gz*" \
  --max-age 30d
```

#### Mit AWS S3

```bash
# AWS CLI verwenden
aws s3 sync /opt/alarma-backups/ s3://my-backup-bucket/alarma/ \
  --exclude "*" --include "alarma-full-*.tar.gz*" \
  --storage-class GLACIER
```

### NAS/Netzwerklaufwerk

```bash
# Linux - NFS Mount
mount -t nfs nas.local:/backups /mnt/nas-backups
cp /opt/alarma-backups/alarma-full-*.tar.gz /mnt/nas-backups/

# Windows - Netzlaufwerk
New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\NAS\Backups"
Copy-Item C:\Alarma!-Backups\*.zip Z:\Alarma!\
```

### Backup-Verschlüsselung für Offsite

```bash
# Mit GPG verschlüsseln
gpg --symmetric --cipher-algo AES256 backup.tar.gz

# Oder mit OpenSSL
openssl enc -aes-256-cbc -salt -in backup.tar.gz -out backup.tar.gz.enc
```

## Disaster Recovery Szenarien

### Szenario 1: Einzelner Container-Ausfall

**Symptom:** Ein Container startet nicht oder verhält sich fehlerhaft

**Lösung:**

1. Container neu starten: `docker-compose restart <service>`
2. Falls erfolglos: Nur das betroffene Volume wiederherstellen
3. Container neu bauen: `docker-compose up -d --force-recreate <service>`

### Szenario 2: Datenverlust in einem Volume

**Symptom:** Konfiguration oder Daten fehlen in einem Service

**Lösung:**

1. Betroffenen Container stoppen
2. Nur das betroffene Volume aus Backup wiederherstellen
3. Container neu starten
4. Funktionalität testen

### Szenario 3: Kompletter System-Ausfall

**Symptom:** Server-Crash, Hardware-Fehler, Ransomware

**Lösung:**

1. Neue Server-Instanz bereitstellen
2. Docker und Docker Compose installieren
3. Vollständigen Restore durchführen
4. Alle Services starten und testen
5. DNS/IP-Adressen aktualisieren

**Geschätzte Zeit:** 30-60 Minuten (RTO)

### Szenario 4: Fehlerhaftes Update

**Symptom:** Nach Update funktioniert das System nicht mehr

**Lösung:**

1. Sofortiger Rollback auf Pre-Update-Backup
2. Problem analysieren
3. Update-Prozess überarbeiten
4. Erneuter Update-Versuch in Test-Umgebung

## Monitoring und Alerting

### Backup-Monitoring

Überwache folgende Aspekte:

1. **Backup-Erfolg:** Wurde das Backup erfolgreich erstellt?
2. **Backup-Größe:** Ist die Größe plausibel? (Warnung bei großen Abweichungen)
3. **Backup-Alter:** Ist das neueste Backup aktuell? (Warnung wenn > 25 Stunden alt)
4. **Speicherplatz:** Ist genug Platz für weitere Backups vorhanden?

### Integration mit Alarma!

Die Backup-Skripte können Benachrichtigungen über das Alarma!-System selbst senden:

```bash
# Bei Erfolg
curl -X POST http://localhost:8080/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "✅ Alarma! Backup erfolgreich", "priority": "low"}'

# Bei Fehler
curl -X POST http://localhost:8080/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "❌ Alarma! Backup FEHLGESCHLAGEN!", "priority": "high"}'
```

### PRTG-Integration

```powershell
# Backup-Status für PRTG
.\scripts\backup-alarma.ps1 -CheckOnly | ConvertTo-Json | 
  Send-PRTGNotification.ps1 -SensorId 12345
```

## Troubleshooting

### Problem: Backup schlägt fehl - "Permission denied"

**Lösung:**

- Prüfe Dateiberechtigungen im Backup-Verzeichnis
- Stelle sicher, dass der User Docker-Berechtigungen hat
- Bei Linux: User zur `docker`-Gruppe hinzufügen

```bash
sudo usermod -aG docker $USER
```

### Problem: Volume-Restore funktioniert nicht

**Lösung:**

- Stelle sicher, dass Container gestoppt sind
- Prüfe Volume-Namen: `docker volume ls`
- Verifiziere Backup-Archiv-Integrität
- Versuche manuelles Restore mit `docker run`

### Problem: Restore dauert zu lange (RTO überschritten)

**Lösung:**

- Verwende schnelleren Speicher für Backups
- Komprimierung reduzieren (weniger CPU-Last)
- Inkrementelle Backups statt Vollbackups
- Separate Backup-Server für I/O-Entlastung

### Problem: Backup-Speicherplatz voll

**Lösung:**

- Erhöhe Retention-Policy-Wert
- Implementiere automatische Bereinigung alter Backups
- Verschiebe alte Backups zu langsameren/günstigeren Speicher
- Nutze deduplizierung (z.B. mit `borg backup`)

### Problem: Verschlüsselte Backups können nicht entschlüsselt werden

**Lösung:**

- Stelle sicher, dass GPG-Schlüssel verfügbar sind
- Prüfe Passphrase
- Verifiziere, dass das richtige Verschlüsselungsverfahren verwendet wird
- Bewahre GPG-Schlüssel und Passphrases SICHER und SEPARAT auf

### Problem: Backup-Benachrichtigungen werden nicht gesendet

**Lösung:**

- Prüfe, ob Alarma!-Services laufen
- Verifiziere Notification-URL
- Teste Benachrichtigung manuell mit `curl`
- Prüfe Firewall-Regeln

## Best Practices

### Backup-Best-Practices

1. ✅ **3-2-1-Regel befolgen:**
   - 3 Kopien der Daten
   - 2 verschiedene Medien
   - 1 Kopie offsite

2. ✅ **Verschlüsselung:** Alle Backups verschlüsseln (enthalten Secrets!)

3. ✅ **Automatisierung:** Manuelle Backups werden vergessen

4. ✅ **Testen:** Regelmäßig Restore-Tests durchführen

5. ✅ **Dokumentation:** Restore-Prozedur aktuell halten

6. ✅ **Monitoring:** Backup-Erfolg überwachen

7. ✅ **Retention:** Alte Backups automatisch löschen

8. ✅ **Vor Updates:** Immer Backup vor Änderungen

### Restore-Best-Practices

1. ✅ **Ruhe bewahren:** Überstürzte Aktionen vermeiden

2. ✅ **Dokumentieren:** Alle Schritte protokollieren

3. ✅ **Validieren:** Backup vor Restore prüfen

4. ✅ **Safety-Backup:** Aktuellen Zustand sichern (falls möglich)

5. ✅ **Schrittweise:** Nicht mehrere Änderungen gleichzeitig

6. ✅ **Verifizieren:** Nach Restore gründlich testen

7. ✅ **Lernen:** Root-Cause-Analyse durchführen

## Checklisten

### Wöchentliche Backup-Checks

- [ ] Neuestes Backup existiert und ist < 25 Stunden alt
- [ ] Backup-Log auf Fehler prüfen
- [ ] Speicherplatz ausreichend (> 20% frei)
- [ ] Backup-Benachrichtigungen erhalten
- [ ] Offsite-Kopie aktualisiert

### Monatliche Backup-Tests

- [ ] Test-Restore in isolierter Umgebung durchführen
- [ ] Backup-Integrität verifizieren
- [ ] Restore-Zeit messen (RTO-Validierung)
- [ ] Dokumentation auf Aktualität prüfen
- [ ] Backup-Skripte auf Updates prüfen

### Vor großen Änderungen

- [ ] Vollbackup erstellen
- [ ] Backup verifizieren
- [ ] Offsite-Kopie aktualisieren
- [ ] Restore-Prozedur griffbereit
- [ ] Rollback-Plan dokumentieren

## Weiterführende Ressourcen

- [Docker Volume Backup Dokumentation](https://docs.docker.com/storage/volumes/#backup-restore-or-migrate-data-volumes)
- [Borg Backup](https://www.borgbackup.org/) - Deduplizierendes Backup-Tool
- [Restic](https://restic.net/) - Modernes Backup-Programm
- [Duplicati](https://www.duplicati.com/) - Backup mit Cloud-Unterstützung

## Änderungshistorie

| Datum | Version | Änderung |
| ------- | --------- | ---------- |
| 2026-01-30 | 1.0 | Initiale Dokumentation erstellt |

---

**Hinweis:** Diese Dokumentation sollte regelmäßig überprüft und bei Änderungen am System aktualisiert werden.
