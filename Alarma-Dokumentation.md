# Alarma!

## Multi-Channel Notification Gateway

**Ein Konzept von Alexander Waller und Claude AI**  
**30. Januar 2026**

**WebPoint Internet Solutions**
**Version:** 1.0

---

## Executive Summary

Diese Lösung ermöglicht es der WebPoint Internet Solutions, Benachrichtigungen über **SMS, WhatsApp, Signal, Microsoft Teams und E-Mail** zu versenden - und zwar über ein **einziges, selbst-gehostetes System**. Das Android-Handy wird dabei als Gateway für SMS, WhatsApp und Signal genutzt, was externe Kosten auf ein Minimum reduziert.

**Kernvorteile:**

- ✅ **Keine monatlichen Cloud-Kosten** - komplett selbst-gehostet
- ✅ **Ein API-Endpunkt** für alle Kommunikationskanäle
- ✅ **Android-Handy als Gateway** - keine teuren SMS-Provider nötig
- ✅ **SMS funktioniert ohne Internet** - Mobilfunknetz bei Ausfällen
- ✅ **Open Source** - keine Vendor Lock-ins
- ✅ **Sofort einsatzbereit** - Docker-basiert, in 30 Minuten aufgesetzt

---

## Systemarchitektur

### Komponenten-Übersicht

```txt
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring & Scripts                      │
│            (PRTG, PowerShell, Zabbix, etc.)                 │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP POST
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   Apprise API Gateway                        │
│              (Zentrale Steuerung - Port 8000)               │
│                Tag-basiertes Routing                         │
└─────┬──────────┬──────────┬──────────┬──────────┬──────────┘
      │          │          │          │          │
      ▼          ▼          ▼          ▼          ▼
┌──────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐
│   SMS    │ │WhatsApp│ │ Signal │ │ Teams  │ │  Email   │
│ Gateway  │ │Gateway │ │Gateway │ │Webhook │ │  SMTP    │
│(Port 3000│ │(3001)  │ │(3002)  │ │        │ │          │
└────┬─────┘ └────┬───┘ └────┬───┘ └────────┘ └──────────┘
     │            │          │
     └────────────┴──────────┘
                  ▼
┌──────────────────────────────────┐
│   Android Smartphone (€250)      │
│  (SMS/WhatsApp/Signal Relay)     │
└──────────────────────────────────┘
```

### Container-Setup

| Container | Image | Port | Funktion |
| --------- | ----- | ---- | -------- |
| **apprise-api** | lscr.io/linuxserver/apprise-api | 8000 | Zentrale API & Routing |
| **sms-gateway** | capcom6/sms-gateway | 3000 | SMS über Android |
| **whatsapp-gateway** | dickyermawan/kilas | 3001 | WhatsApp über Android |
| **signal-gateway** | bbernhard/signal-cli-rest-api | 3002 | Signal über Android |
| **ntfy** (optional) | binwiederhier/ntfy | 8080 | Push-Notifications |

---

## 🆘 SMS als Ausfallsicherung

### Warum SMS kritisch ist

**SMS ist der einzige Kanal, der auch bei Internetausfall funktioniert!**

SMS nutzt das **Mobilfunknetz (GSM/LTE)**, nicht das Internet. Dies macht SMS zur kritischen Komponente für Notfall- und Katastrophenszenarien.

### Vorteile von SMS bei Ausfällen

- 📡 **Separate Infrastruktur**: Mobilfunknetze sind unabhängig vom Internet
- 🔋 **Notstromversorgung**: Funkmasten haben Batterien und Generatoren  
- 📶 **Minimale Bandbreite**: Funktioniert auch bei Netzüberlastung
- ⚡ **Priorität**: SMS-Versand hat Vorrang im Mobilfunknetz
- 🔄 **Redundanz**: Mehrere Mobilfunkanbieter verfügbar

### Szenarien für SMS-Einsatz

| Szenario | WhatsApp/Signal/Teams | SMS |
| -------- | --------------------- | --- |
| Internetausfall Gemeinde | ❌ Nicht verfügbar | ✅ Funktioniert |
| Stromausfall mit Router-Ausfall | ❌ Nicht verfügbar | ✅ Funktioniert |
| DDoS-Angriff auf Infrastruktur | ❌ Nicht verfügbar | ✅ Funktioniert |
| Provider-Ausfall (Glasfaser) | ❌ Nicht verfügbar | ✅ Funktioniert |
| Naturkatastrophe (Hochwasser) | ❌ Nicht verfügbar | ✅ Funktioniert |
| Normalbetrieb | ✅ Funktioniert | ✅ Funktioniert |

### Empfohlene Notification-Strategie

**Normale Alerts (Tag: `warnung` oder `info`):**

- WhatsApp + Teams + E-Mail
- SMS **NICHT** verwenden (Kosten sparen)

**Kritische Alerts (Tag: `kritisch` oder `notfall`):**

- **SMS + WhatsApp + Signal + Teams + E-Mail**
- SMS garantiert Zustellung auch bei Ausfällen!

**PowerShell Beispiele:**

```powershell
# Normale Warnung (ohne SMS - kostensparend)
Send-WarningAlert -Title "Backup" -Body "Backup erfolgreich"

# Kritischer Notfall (MIT SMS - Ausfallsicher!)
Send-CriticalAlert -Title "Server DOWN" -Body "Hauptserver nicht erreichbar"

# Nur SMS für absolute Notfälle
Send-CustomNotification -Tags "sms" -Title "NOTFALL" -Body "Rechenzentrum offline"
```

> **⚠️ WICHTIG:** In kritischen Situationen ist SMS der einzige verlässliche Kanal. Alle anderen Dienste (WhatsApp, Signal, Teams, E-Mail) benötigen eine funktionierende Internet-Verbindung!

---

## Installation & Setup

### Voraussetzungen

**Server-Seite:**

- Linux-Server (Ubuntu/Debian empfohlen)
- Docker & Docker Compose installiert
- Min. 2 GB RAM, 10 GB Speicher
- Netzwerkzugriff zum Server (LAN oder VPN)

**Client-Seite:**

- Android Smartphone (Android 5.0+)
- Aktive SIM-Karte für SMS
- WhatsApp Account (optional)

### Schritt 1: Verzeichnisstruktur erstellen

```bash
mkdir -p /opt/notification-gateway/{apprise-config,sms-data,whatsapp-data,ntfy/cache,ntfy/etc}
cd /opt/notification-gateway
```

### Schritt 2: Docker Compose Datei erstellen

Datei: `/opt/notification-gateway/docker-compose.yml`

```yaml
version: '3.8'

networks:
  notification-network:
    driver: bridge

services:
  # SMS Gateway - Android als SMS Relay
  sms-gateway:
    image: capcom6/sms-gateway:latest
    container_name: sms-gateway
    ports:
      - "3000:3000"
    volumes:
      - ./sms-config.yml:/app/config.yml
      - ./sms-data:/data
    environment:
      - TZ=Europe/Vienna
    networks:
      - notification-network
    restart: unless-stopped

  # WhatsApp Gateway - Android als WhatsApp Relay  
  whatsapp-gateway:
    image: dickyermawan/kilas:latest
    container_name: whatsapp-gateway
    ports:
      - "3001:3001"
    volumes:
      - ./whatsapp-data:/app/data
    environment:
      - API_KEY=YOUR_SECURE_API_KEY_HERE
      - TZ=Europe/Vienna
    networks:
      - notification-network
    restart: unless-stopped

  # Signal Gateway - Signal Messenger
  signal-gateway:
    image: bbernhard/signal-cli-rest-api:latest
    container_name: signal-gateway
    ports:
      - "3002:8080"
    volumes:
      - ./signal-data:/home/.local/share/signal-cli
    environment:
      - MODE=native
      - TZ=Europe/Vienna
    networks:
      - notification-network
    restart: unless-stopped

  # Apprise API - Zentrale Steuerung
  apprise-api:
    image: lscr.io/linuxserver/apprise-api:latest
    container_name: apprise-api
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Vienna
    volumes:
      - ./apprise-config:/config
    ports:
      - "8000:8000"
    networks:
      - notification-network
    depends_on:
      - sms-gateway
      - whatsapp-gateway
      - signal-gateway
    restart: unless-stopped

  # ntfy - Optional für Push-Notifications
  ntfy:
    image: binwiederhier/ntfy:latest
    container_name: ntfy
    command: serve
    ports:
      - "8080:80"
    volumes:
      - ./ntfy/cache:/var/cache/ntfy
      - ./ntfy/etc:/etc/ntfy
    environment:
      - TZ=Europe/Vienna
    networks:
      - notification-network
    restart: unless-stopped
```

### Schritt 3: SMS Gateway Konfiguration

Datei: `/opt/notification-gateway/sms-config.yml`

```yaml
server:
  listen: 0.0.0.0:3000
  mode: private
  private_token: "YOUR_SECURE_TOKEN_HERE"

database:
  dsn: "/data/sms-gateway.db"
```

### Schritt 4: Apprise Konfiguration

Datei: `/opt/notification-gateway/apprise-config/apprise.yml`

```yaml
# Multi-Channel Konfiguration für Alarma! - WebPoint Internet Solutions
version: 1

urls:
  # SMS über Android Gateway
  - json://sms-gateway:3000/3rdparty/v1/message:
      headers:
        Authorization: Basic dXNlcm5hbWU6cGFzc3dvcmQ=
        Content-Type: application/json
      method: POST
      payload: |
        {
          "message": "{{title}}: {{body}}",
          "phoneNumbers": ["+43XXXXXXXXX"]
        }
      tag: sms, kritisch, notfall
  
  # WhatsApp über Android Gateway
  - json://whatsapp-gateway:3001/api/send-message:
      headers:
        X-API-KEY: YOUR_SECURE_API_KEY_HERE
        Content-Type: application/json
      method: POST
      payload: |
        {
          "sessionId": "YourSessionID",
          "chatId": "43XXXXXXXXX",
          "text": "*{{title}}*\n\n{{body}}"
        }
      tag: whatsapp, team, info
  
  # Signal Messenger
  - json://signal-gateway:8080/v2/send:
      headers:
        Content-Type: application/json
      method: POST
      payload: |
        {
          "message": "{{title}}\n\n{{body}}",
          "number": "+43XXXXXXXXX",
          "recipients": ["+43XXXXXXXXX"]
        }
      tag: signal, secure, team
  
  # Microsoft Teams
  - teams://outlook.office.com/webhook/XXXXXXXX:
      tag: teams, management, info
  
  # E-Mail via SMTP
  - mailtos://smtp-user:smtp-pass@smtp.example.com:587?from=alerts@example.com&to=it@example.com:
      tag: email, backup, log
  
  # ntfy Push Notifications
  - ntfy://ntfy/hohenems-alerts:
      tag: push, mobile
```

### Schritt 5: Container starten

```bash
cd /opt/notification-gateway
docker compose up -d
```

**Logs prüfen:**

```bash
docker compose logs -f
```

### Schritt 6: Android App Setup

#### SMS Gateway App

1. **App herunterladen:**
   - GitHub: <https://github.com/capcom6/android-sms-gateway/releases>
   - Neueste APK installieren

2. **App konfigurieren:**
   - App öffnen → Settings → Cloud Server
   - API URL: `http://SERVER-IP:3000/api/mobile/v1`
   - Private Token: `YOUR_SECURE_TOKEN_HERE`
   - Cloud Server aktivieren

3. **Credentials notieren:**
   - In der App unter "Home" werden Username & Password angezeigt
   - Diese für Authorization Header verwenden (Base64)

#### WhatsApp Gateway App

1. **Web-UI öffnen:**
   - Browser: `http://SERVER-IP:3001`

2. **Session erstellen:**
   - Session ID: `YourSessionID`
   - QR-Code scannen mit WhatsApp
   - (Einstellungen → Verknüpfte Geräte → Gerät verknüpfen)

---

## Verwendung

### Basic Notification (Alle Kanäle)

**PowerShell:**

```powershell
$notification = @{
    urls = "tag=kritisch"
    title = "Server Alert"
    body = "CPU Auslastung kritisch: 95%"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://notification-server:8000/notify" `
    -Method Post -Body $notification -ContentType "application/json"
```

**Curl/Bash:**

```bash
curl -X POST http://notification-server:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=kritisch",
    "title": "Server Alert",
    "body": "CPU Auslastung kritisch: 95%"
  }'
```

### Kanal-spezifische Benachrichtigungen

**Nur SMS:**

```powershell
$sms = @{
    urls = "tag=sms"
    body = "Backup Server01 erfolgreich abgeschlossen"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://notification-server:8000/notify" `
    -Method Post -Body $sms -ContentType "application/json"
```

**Nur WhatsApp:**

```powershell
$whatsapp = @{
    urls = "tag=whatsapp"
    title = "Team Info"
    body = "Wartungsfenster heute 20:00-22:00 Uhr"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://notification-server:8000/notify" `
    -Method Post -Body $whatsapp -ContentType "application/json"
```

**Teams + Email:**

```powershell
$notification = @{
    urls = "tag=management"
    title = "Monatsbericht"
    body = "Der IT-Monatsbericht steht zur Verfügung"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://notification-server:8000/notify" `
    -Method Post -Body $notification -ContentType "application/json"
```

---

## PowerShell Module

### PowerShell Module Installation

Modul-Datei speichern als: `NotificationGateway.psm1`

```powershell
# Modul in PowerShell Profil einbinden
Import-Module "C:\Scripts\NotificationGateway.psm1"
```

### PowerShell PowershellModule Verwendung

```powershell
# Kritische Benachrichtigung (SMS, WhatsApp, Teams)
Send-CriticalAlert -Title "Firewall Alert" -Body "Ungewöhnlich viele Login-Versuche"

# Info-Nachricht (nur WhatsApp und Teams)
Send-InfoMessage -Title "Update verfügbar" -Body "Windows Updates stehen bereit"

# SMS Benachrichtigung
Send-SMSAlert -Body "Server DC01 nicht erreichbar"

# Custom Notification
Send-CustomNotification -Tags "teams,email" -Title "Bericht" -Body "Wochenreport"
```

---

## PRTG Integration

### Sensor: EXE/Script Advanced

**Script speichern als:** `C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\prtg-notification.ps1`

**In PRTG:**

1. Sensor hinzufügen: "EXE/Script Advanced"
2. Script auswählen: `prtg-notification.ps1`
3. Parameter (optional): `-Server notification-server -Port 8000`
4. Bei Sensor-Status "Warning" oder "Error" → Notification Trigger erstellen

**Notification Template:**

- Methode: Execute Program
- Program: `C:\Scripts\Send-PRTGNotification.ps1`
- Parameter: `-SensorName "%sensorname%" -Status "%status%" -Message "%message%"`

---

## Monitoring & Wartung

### Container Status prüfen

```bash
docker compose ps
docker compose logs sms-gateway
docker compose logs whatsapp-gateway
```

### Verbindungs-Check

**SMS Gateway:**

```bash
curl -u username:password http://localhost:3000/3rdparty/v1/message
```

**WhatsApp Gateway:**

```bash
curl -H "X-API-KEY: YOUR_SECURE_API_KEY_HERE" http://localhost:3001/api/status
```

**Apprise API:**

```bash
curl http://localhost:8000/
```

### Backup

**Wichtige Daten sichern:**

```bash
# Konfigurationen
tar -czf notification-backup-$(date +%Y%m%d).tar.gz \
  apprise-config/ sms-config.yml docker-compose.yml

# Session-Daten
tar -czf sessions-backup-$(date +%Y%m%d).tar.gz \
  sms-data/ whatsapp-data/
```

### Updates

```bash
cd /opt/notification-gateway
docker compose pull
docker compose up -d
```

---

## Sicherheit

### Empfohlene Maßnahmen

1. **Firewall-Regeln:**
   - Ports nur intern freigeben (LAN/VPN)
   - Kein direkter Internet-Zugriff

2. **API Keys:**
   - Sichere, lange Tokens verwenden
   - Regelmäßig rotieren

3. **HTTPS:**
   - Reverse Proxy (nginx/Traefik) mit SSL
   - Let's Encrypt Zertifikate

4. **Monitoring:**
   - Failed Login Attempts überwachen
   - Rate Limiting einrichten

### SSL/TLS Setup (Optional)

**Nginx Reverse Proxy Beispiel:**

```nginx
server {
    listen 443 ssl;
    server_name notifications.example.com;
    
    ssl_certificate /etc/ssl/certs/notification.crt;
    ssl_certificate_key /etc/ssl/private/notification.key;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

---

## Troubleshooting

### SMS werden nicht gesendet

**Prüfen:**

1. Android App läuft und ist verbunden?
2. SMS-Berechtigungen erteilt?
3. API-Credentials korrekt in apprise.yml?

```bash
# Test SMS direkt
curl -X POST http://localhost:3000/3rdparty/v1/message \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"message":"Test","phoneNumbers":["+43XXXXXXXXX"]}'
```

### WhatsApp Verbindung verloren

**Lösung:**

1. WhatsApp Gateway Web-UI öffnen: `http://SERVER-IP:3001`
2. Session Status prüfen
3. QR-Code erneut scannen falls nötig

### Apprise API antwortet nicht

```bash
# Container neu starten
docker compose restart apprise-api

# Logs prüfen
docker compose logs apprise-api
```

---

## Kosten & ROI

### Einmalige Kosten

- Android Smartphone (Gateway): **€250**
- Entwicklungszeit: ~4 Stunden (interne Ressourcen)
- Server-Hardware: Bereits vorhanden (VM)
- **Gesamt: €250**

### Laufende Kosten

- SMS-Kosten: ~€0.09 pro SMS (bestehender Mobilfunkvertrag)
- Mobilfunkvertrag: ~€10-15/Monat
- Server-Betrieb: Negligible (Teil bestehender Infrastruktur)
- **Gesamt: ~€15-20/Monat**

### Alternative: Cloud SMS Gateway

- Twilio/MessageBird: ~€0.08 pro SMS + Grundgebühr €20/Monat
- WhatsApp Business API: €0.005-0.025 pro Nachricht
- Hardware-SMS-Gateway: €1.500-3.000 (einmalig)
- **Gesamt: ~€50-100/Monat** (Cloud) oder **€1.500+** (Hardware)

### ROI-Berechnung

**Unsere Lösung:**

- Einmalig: €250
- Jahr 1: €250 + (12 × €15) = **€430**
- Jahr 2-5: 12 × €15 = **€180/Jahr**

**Cloud-Alternative:**

- Jahr 1-5: 12 × €75 = **€900/Jahr**

**Einsparung:**

- Jahr 1: €900 - €430 = **€470**
- Jahr 2: €900 - €180 = **€720**
- **5-Jahres-Einsparung: ~€3.350**

**Amortisation: Nach 4 Monaten!**

---

## Erweiterungsmöglichkeiten

### Integration Beispiele

- ✅ **Active Directory:** PowerShell Scripts bei User-Events
- ✅ **VMware:** Alarmierung bei VM-Problemen
- ✅ **Veeam Backup:** Backup-Status Reports
- ✅ **PRTG:** Sensor-basierte Alerts
- ✅ **MikroTik Router:** Script-basierte Notifications
- ✅ **Palo Alto:** Syslog → Logstash → Script → Notification

### Zusätzliche Kanäle

- Telegram Bot (kostenlos)
- Slack Webhooks
- Discord Webhooks
- Push-Notifications (ntfy)
- Matrix/Element

---

## Zusammenfassung

Diese Lösung bietet der WebPoint Internet Solutions ein **professionelles, selbst-gehostetes Notification-System** mit minimalen Kosten und maximaler Flexibilität. Durch die Verwendung des Android-Handys als Gateway entfallen teure Cloud-Services, und das System kann vollständig intern betrieben werden.

**Key Benefits:**

- 💰 **Kostenersparnis:** €500-1.000/Jahr vs. Cloud-Lösungen
- 🔒 **Datensouveränität:** Alle Daten bleiben intern
- 🎯 **Flexibilität:** Ein API für alle Kanäle
- ⚡ **Geschwindigkeit:** Sofortige Benachrichtigungen
- 🔧 **Wartungsarm:** Docker-basiert, stabile Container

---

## Kontakt & Support

**Ersteller:** Alexander  
**Abteilung:** Organisation, Prozessmanagement und IT  
**Organisation:** WebPoint Internet Solutions  
**E-Mail:** <office@webpoint.at>  

**Dokumentversion:** 1.0  
**Letzte Aktualisierung:** 29. Januar 2026
