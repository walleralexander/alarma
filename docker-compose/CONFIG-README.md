# Alarma! - Konfigurationsdateien

## WebPoint Internet Solutions - Ein Konzept von Alexander Waller und Claude AI

**Version:** 1.0  
**Datum:** 30. Januar 2026

---

## 📦 Enthaltene Dateien

### 1. **docker-compose.yml**

Haupt-Konfigurationsdatei für alle Docker Container.

**Enthält:**

- SMS Gateway (Port 3000)
- WhatsApp Gateway (Port 3001)
- Signal Gateway (Port 3002)
- Apprise API (Port 8000)
- ntfy Server (Port 8080)

### 2. **sms-config.yml**

Konfiguration für den SMS Gateway Container.

**Wichtig anzupassen:**

- `private_token` - Sicheren Token vergeben
- `rate_limiting` - Falls gewünscht anpassen

### 3. **apprise.yml**

Zentrale Konfiguration aller Notification-Kanäle.

**MUSS angepasst werden:**

- ✅ Telefonnummern für SMS, WhatsApp, Signal
- ✅ E-Mail-Adressen und SMTP-Zugangsdaten
- ✅ Microsoft Teams Webhook URL
- ✅ SMS Gateway Basic Auth (Base64 encoded)

### 4. **ntfy-server.yml**

Konfiguration für den ntfy Push-Notification Server.

**Optional anzupassen:**

- `base-url` - Bei externem Zugriff
- `auth-file` - Für Authentifizierung
- Verschiedene Limits

### 5. **install.sh**

Automatisches Installations-Script.

**Führt aus:**

- Prüft Docker Installation
- Erstellt Verzeichnisstruktur
- Kopiert Konfigurationen
- Startet Container
- Zeigt Status an

---

## 🚀 Schnellstart

### Schritt 1: Installation vorbereiten

```bash
# Alle Dateien in ein Verzeichnis kopieren
mkdir alarma-setup
cd alarma-setup

# Dateien hier ablegen:
# - docker-compose.yml
# - sms-config.yml
# - apprise.yml
# - ntfy-server.yml
# - install.sh
```

### Schritt 2: Konfiguration anpassen

**apprise.yml bearbeiten:**

```bash
nano apprise.yml

# Anpassen:
# - Zeile 34: Telefonnummer für SMS
# - Zeile 51: Telefonnummer für WhatsApp  
# - Zeile 67: Telefonnummer für Signal
# - Zeile 78: Teams Webhook URL
# - Zeile 89: E-Mail Einstellungen
# - Zeile 32: SMS Gateway Authorization
```

**Base64 für SMS Gateway erstellen:**

```bash
# Username und Passwort aus SMS Gateway App (nach Installation)
echo -n "username:password" | base64
# Ergebnis in apprise.yml Zeile 32 eintragen
```

**sms-config.yml anpassen:**

```bash
nano sms-config.yml

# Zeile 11: private_token ändern
private_token: "IhrSicheresTokenHier"
```

### Schritt 3: Installation ausführen

```bash
# Script ausführbar machen
chmod +x install.sh

# Installation starten
sudo ./install.sh
```

Das Script führt automatisch aus:

1. ✅ Prüft Voraussetzungen (Docker, Docker Compose)
2. ✅ Erstellt `/opt/alarma/` Verzeichnisstruktur
3. ✅ Kopiert alle Konfigurationsdateien
4. ✅ Setzt korrekte Berechtigungen
5. ✅ Lädt Docker Images
6. ✅ Startet alle Container
7. ✅ Prüft Erreichbarkeit

---

## 📱 Android Apps einrichten

### SMS Gateway App

1. **Download:**
   - <https://github.com/capcom6/android-sms-gateway/releases>
   - Neueste APK herunterladen und installieren

2. **Konfiguration:**
   - App öffnen → Settings → Cloud Server
   - **API URL:** `http://SERVER-IP:3000/api/mobile/v1`
   - **Private Token:** (aus sms-config.yml)
   - Cloud Server aktivieren

3. **Credentials notieren:**
   - Unter "Home" → Username und Password anzeigen
   - Für apprise.yml Base64 Authorization benötigt

### WhatsApp Gateway

1. **Web-UI öffnen:**
   - Browser: `http://SERVER-IP:3001`

2. **Session erstellen:**
   - Session ID: `YourSessionID`
   - QR-Code scannen mit WhatsApp
   - (Einstellungen → Verknüpfte Geräte → Gerät verknüpfen)

### Signal Gateway

1. **Web-UI öffnen:**
   - Browser: `http://SERVER-IP:3002`

2. **Telefonnummer registrieren:**

   ```bash
   curl -X POST http://SERVER-IP:3002/v1/register/+43XXXXXXXXX
   ```

3. **Verifizierungs-Code eingeben:**

   ```bash
   curl -X POST http://SERVER-IP:3002/v1/register/+43XXXXXXXXX/verify \
     -H "Content-Type: application/json" \
     -d '{"code":"123456"}'
   ```

---

## ✅ Test-Benachrichtigungen

### Via Curl

```bash
# Test an Teams
curl -X POST http://localhost:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=teams",
    "title": "Alarma! Test",
    "body": "System läuft!"
  }'

# Test an alle Kanäle
curl -X POST http://localhost:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=kritisch",
    "title": "Test Alert",
    "body": "Das ist ein Test aller Kanäle"
  }'

# Nur SMS
curl -X POST http://localhost:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=sms",
    "body": "SMS Test"
  }'

# Nur Signal (verschlüsselt)
curl -X POST http://localhost:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=signal",
    "title": "Sicher",
    "body": "Verschlüsselter Test"
  }'
```

### Via PowerShell

```powershell
# PowerShell Module laden (siehe PowerShell-Scripts-README.md)
Import-Module "C:\Scripts\NotificationGateway.psm1"
Set-NotificationServer -Server "SERVER-IP" -Port 8000

# Test
Send-InfoMessage -Title "Alarma! Test" -Body "PowerShell Integration funktioniert!"
```

---

## 🔧 Verwaltung

### Container Status

```bash
cd /opt/alarma
docker-compose ps
```

### Logs anzeigen

```bash
# Alle Container
docker-compose logs -f

# Nur ein Container
docker-compose logs -f alarma-apprise
docker-compose logs -f alarma-sms
docker-compose logs -f alarma-whatsapp
docker-compose logs -f alarma-signal
```

### Container neu starten

```bash
# Alle Container
docker-compose restart

# Nur ein Container
docker-compose restart alarma-apprise
```

### Container stoppen

```bash
docker-compose down
```

### Container starten

```bash
docker-compose up -d
```

### Updates

```bash
# Images aktualisieren
docker-compose pull

# Container mit neuen Images neu starten
docker-compose up -d
```

---

## 🔒 Sicherheit

### Empfohlene Maßnahmen

1. **Firewall konfigurieren:**

   ```bash
   # Nur interne Zugriffe erlauben
   sudo ufw allow from 192.168.0.0/16 to any port 8000
   sudo ufw allow from 192.168.0.0/16 to any port 3000
   sudo ufw allow from 192.168.0.0/16 to any port 3001
   sudo ufw allow from 192.168.0.0/16 to any port 3002
   sudo ufw allow from 192.168.0.0/16 to any port 8080
   ```

2. **Tokens ändern:**
   - SMS Gateway `private_token`
   - WhatsApp Gateway `API_KEY`
   - Alle in apprise.yml

3. **HTTPS einrichten (Produktion):**
   - Nginx Reverse Proxy
   - Let's Encrypt Zertifikate

4. **Backups:**

   ```bash
   # Konfiguration sichern
   tar -czf alarma-backup-$(date +%Y%m%d).tar.gz \
     /opt/alarma/config \
     /opt/alarma/docker-compose.yml
   
   # Daten sichern (Sessions, etc.)
   tar -czf alarma-data-$(date +%Y%m%d).tar.gz \
     /opt/alarma/data
   ```

---

## 📊 Monitoring

### Health Checks

```bash
# Apprise API
curl http://localhost:8000/

# SMS Gateway
curl http://localhost:3000/

# ntfy
curl http://localhost:8080/
```

### Prometheus Metrics (optional)

Apprise API stellt Metriken bereit:

```bash
curl http://localhost:8000/metrics
```

---

## ❓ Troubleshooting

### Container startet nicht

```bash
# Logs prüfen
docker-compose logs CONTAINER_NAME

# Berechtigungen prüfen
ls -la /opt/alarma/data
ls -la /opt/alarma/config
```

### SMS werden nicht gesendet

1. **Android App Status prüfen:**
   - App geöffnet?
   - Cloud Server verbunden?
   - SMS-Berechtigungen erteilt?

2. **Gateway-Logs prüfen:**

   ```bash
   docker-compose logs -f alarma-sms
   ```

3. **Test direkt am Gateway:**

   ```bash
   curl -X POST http://localhost:3000/3rdparty/v1/message \
     -u username:password \
     -H "Content-Type: application/json" \
     -d '{"message":"Test","phoneNumbers":["+43XXXXXXXXX"]}'
   ```

### WhatsApp funktioniert nicht

1. **Session Status prüfen:**
   - Browser: `http://SERVER-IP:3001`
   - Session aktiv?

2. **QR-Code neu scannen:**
   - Session löschen und neu erstellen

3. **Logs prüfen:**

   ```bash
   docker-compose logs -f alarma-whatsapp
   ```

### Signal Probleme

1. **Registrierung prüfen:**

   ```bash
   curl http://localhost:3002/v1/about
   ```

2. **Neu registrieren bei Bedarf**

3. **Logs prüfen:**

   ```bash
   docker-compose logs -f alarma-signal
   ```

---

## 📞 Support

**Erstellt von:** Alexander Waller und Claude AI  
**Organisation:** WebPoint Internet Solutions - IT  
**Datum:** 30. Januar 2026

**Bei Fragen:**

- Dokumentation: `Alarma-Dokumentation.md`
- PowerShell Scripts: `PowerShell-Scripts-README.md`
- GitHub Issues (falls öffentlich)

---

## 📝 Änderungshistorie

### v1.0 - 30.01.2026

- Initiale Version
- Alle 5 Kanäle integriert (SMS, WhatsApp, Signal, Teams, E-Mail)
- Docker Compose Setup
- Automatisches Installations-Script
