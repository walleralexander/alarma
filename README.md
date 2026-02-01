# 🚨 Alarma! - Multi-Channel Notification Gateway

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![Version](https://img.shields.io/badge/Version-1.0-blue)](https://github.com/walleralexander/alarma)
[![Status](https://img.shields.io/badge/Status-Beta-orange)](https://github.com/walleralexander/alarma)
[![AI Generated](https://img.shields.io/badge/AI-Generated-purple?logo=anthropic)](https://claude.ai)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-lightgrey)](https://github.com/walleralexander/alarma)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/walleralexander/alarma/pulls)

> **⚠️ DISCLAIMER / HAFTUNGSAUSSCHLUSS**
>
> This code is **AI-generated and untested**. AI can make errors - **human oversight and testing is mandatory**. All code is **open source and in BETA** status. Use at your own risk.
>
> Dieser Code ist **KI-generiert und ungetestet**. KI kann Fehler machen - **menschliche Überprüfung und Tests sind zwingend erforderlich**. Der gesamte Code ist **Open Source und im BETA-Status**. Verwendung auf eigene Gefahr.

**Kurzbeschreibung**
 Ein selbst-gehostetes, kosteneffizientes Notification-System für SMS, WhatsApp, Signal, Teams und E-Mail

**Entwickelt von WebPoint Internet Solutions** | *Ein Konzept von Alexander Waller und Claude AI*

---

## 📋 Übersicht

Alarma! ist eine Docker-basierte Lösung, die es ermöglicht, Benachrichtigungen über **mehrere Kanäle** zu versenden - gesteuert über **eine einzige API**. Das System nutzt ein Android-Smartphone als Gateway für SMS, WhatsApp und Signal, wodurch teure Cloud-Provider überflüssig werden.

### ✨ Kernfeatures

- 🆓 **Keine Cloud-Kosten** - Vollständig selbst-gehostet
- 📱 **Android als Gateway** - Bestehende Hardware nutzen
- 🎯 **Ein API-Endpunkt** - Für alle Kanäle
- 🔧 **Docker-basiert** - In 30 Minuten einsatzbereit
- 🔒 **Open Source** - Keine Vendor Lock-ins
- 💰 **ROI in 4 Monaten** - Einsparung von ~€700/Jahr
- 🛡️ **Ausfallsicher** - SMS funktioniert auch ohne Internet (Mobilfunknetz)

### 🔌 Unterstützte Kanäle

| Kanal | Gateway | Status |
| ------- | --------- | -------- |
| 📧 **E-Mail** | SMTP | ✅ Ready |
| 📱 **SMS** | Android App | ✅ Ready |
| 💬 **WhatsApp** | Android App | ✅ Ready |
| 🔐 **Signal** | signal-cli | ✅ Ready |
| 👔 **Microsoft Teams** | Webhook | ✅ Ready |
| 🔔 **Push (ntfy)** | ntfy.sh | ✅ Ready |

---

## 🏗️ Architektur

```txt
┌──────────────────────────────────────────────────────────────────────┐
│                     EXTERNE SYSTEME & TRIGGER                        │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐              │
│  │   PRTG       │   │  PowerShell  │   │   Scripts    │              │
│  │   Monitor    │   │   Module     │   │   & APIs     │              │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘              │
└─────────┼──────────────────┼──────────────────┼──────────────────────┘
          │                  │                  │
          │  HTTP POST       │  HTTP POST       │  HTTP POST
          └──────────────────┴──────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     DOCKER CONTAINER STACK                           │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────┐         │
│  │         Apprise API Gateway (Port 8000)                 │         │
│  │         • Tag-basiertes Routing                         │         │
│  │         • Multi-Service Orchestration                   │         │
│  │         • REST API Endpoint                             │         │
│  └───┬─────────┬──────────┬──────────┬──────────┬──────────┘         │
│      │         │          │          │          │                    │
│      │  ┌──────▼──────┐ ┌─▼────────┐ │ ┌────────▼────┐ ┌───────────┐ │
│      │  │SMS Gateway  │ │ WhatsApp │ │ │   Signal    │ │   ntfy    │ │
│      │  │(Port 3000)  │ │ Gateway  │ │ │   CLI       │ │(Port 8080)│ │
│      │  │   Android   │ │  Android │ │ │  REST API   │ │   Push    │ │
│      │  └──────┬──────┘ └──┬───────┘ │ └─────────────┘ └───────────┘ │
│      │         │           │         │                               │
│  ┌───▼─────────▼───────────▼─────────▼─────┐                         │
│  │       alarma-network (Bridge)           │                         │
│  └─────────────────────────────────────────┘                         │
│                      │                                               │
└──────────────────────┼───────────────────────────────────────────────┘
                       │
       ┌───────────────┼───────────────┐
       │               │               │
       ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   📱 SMS    │ │ 💬 WhatsApp│ │ 🔐 Signal   │
│             │ │             │ │             │
│   Android   │ │   Android   │ │   Phone #   │
│  Smartphone │ │  Smartphone │ │   +43...    │
└─────────────┘ └─────────────┘ └─────────────┘

       ┌───────────────┬───────────────┐
       │               │               │
       ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ 👔 MS Teams │ │ 📧 E-Mail  │ │ 🔔 Push     │
│             │ │             │ │             │
│  Webhook    │ │    SMTP     │ │   ntfy      │
│    URL      │ │   Server    │ │   Topics    │
└─────────────┘ └─────────────┘ └─────────────┘

KEY FEATURES:
═══════════
• Single API Endpoint für alle Kanäle
• Tag-basiertes Routing (kritisch/warnung/info)
• Android-basierte Gateway-Lösung (SMS/WhatsApp)
• Keine Cloud-Abhängigkeiten
• Vollständig selbst-gehostet
```

---

## 🚀 Quick Start

### Voraussetzungen

- Linux-Server (Ubuntu/Debian)
- Docker & Docker Compose
- Android Smartphone (Android 5.0+)
- Min. 2 GB RAM, 10 GB Speicher

### Installation

```bash
# Repository klonen
git clone https://github.com/walleralexander/alarma.git
cd alarma

# Verzeichnisstruktur erstellen
mkdir -p apprise-config sms-data whatsapp-data signal-data ntfy/{cache,etc}

# Konfiguration anpassen
cp docker-compose.example.yml docker-compose.yml
cp apprise-config/apprise.example.yml apprise-config/apprise.yml
# Bearbeite die Konfigurationsdateien nach deinen Bedürfnissen

# Container starten
docker compose up -d

# Status prüfen
docker compose ps
```

### Android App Setup

1. **SMS Gateway App** installieren: [GitHub Releases](https://github.com/capcom6/android-sms-gateway/releases)
2. App konfigurieren mit Server-IP und Token
3. **WhatsApp Gateway**: Web-UI öffnen und QR-Code scannen

---

## 💻 Verwendung

### Basic Notification

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

**Curl:**

```bash
curl -X POST http://notification-server:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=kritisch",
    "title": "Server Alert",
    "body": "CPU Auslastung kritisch: 95%"
  }'
```

### PowerShell Module

```powershell
# Modul importieren
Import-Module .\scripts\NotificationGateway.psm1

# Verwendung
Send-CriticalAlert -Title "Firewall Alert" -Body "Ungewöhnliche Aktivität erkannt"
Send-InfoMessage -Title "Update" -Body "Windows Updates verfügbar"
Send-SMSAlert -Body "Server DC01 nicht erreichbar"
```

---

## 📊 Kostenvergleich

### Unsere Lösung

- **Einmalig:** €250 (Android Smartphone)
- **Laufend:** ~€15/Monat (Mobilfunkvertrag)
- **Jahr 1:** €430 Gesamtkosten

### Cloud-Alternative (Twilio/MessageBird)

- **Laufend:** ~€75/Monat
- **Jahr 1:** €900 Gesamtkosten

### 💰 Einsparung

€470 im ersten Jahr, €720 in Folgejahren

---

## 🔧 Integration

Alarma! lässt sich einfach in bestehende Systeme integrieren:

- ✅ **PRTG Network Monitor** - Sensor-basierte Alerts
- ✅ **PowerShell Scripts** - Automatisierte Benachrichtigungen
- ✅ **Veeam Backup** - Backup-Status Reports
- ✅ **VMware vCenter** - VM-Status Alerts
- ✅ **Active Directory** - User-Event Notifications
- ✅ **MikroTik Router** - Script-basierte Alerts

---

## 📖 Dokumentation

Die vollständige Dokumentation findest du hier:

- [**Alarma-Dokumentation.md**](Alarma-Dokumentation.md) - Komplette Anleitung
- [**PowerShell-Scripts-README.md**](PowerShell-Scripts-README.md) - PowerShell Integration
- Docker Compose Beispiele im Repository

---

## 🛠️ Komponenten

| Container | Image | Beschreibung |
| ----------- | ------- | -------------- |
| **apprise-api** | lscr.io/linuxserver/apprise-api | Zentrale API & Routing |
| **sms-gateway** | capcom6/sms-gateway | SMS über Android |
| **whatsapp-gateway** | dickyermawan/kilas | WhatsApp über Android |
| **signal-gateway** | bbernhard/signal-cli-rest-api | Signal Messenger |
| **ntfy** | binwiederhier/ntfy | Push-Notifications |

---

## 🔒 Sicherheit

- Alle Ports nur intern freigeben (LAN/VPN)
- Sichere API-Tokens verwenden
- Optional: HTTPS via Reverse Proxy (nginx/Traefik)
- Rate Limiting implementieren
- Regelmäßige Updates der Container

---

## 🤝 Beitragen

Verbesserungsvorschläge und Pull Requests sind willkommen!

### Entwicklung

```bash
# Repository forken und klonen
git clone https://github.com/DEIN-USERNAME/alarma.git

# Branch erstellen
git checkout -b feature/neue-funktion

# Änderungen committen
git commit -am "Füge neue Funktion hinzu"

# Push und Pull Request erstellen
git push origin feature/neue-funktion
```

---

## 📝 Lizenz

Dieses Projekt steht unter der MIT-Lizenz - siehe LICENSE-Datei für Details.

---

## 👨‍💻 Autoren

**Alexander Waller**
WebPoint Internet Solutions
E-Mail: `office@webpoint.at`

Mit Unterstützung von Claude AI

---

## 🙏 Danksagungen

- [Apprise](https://github.com/caronc/apprise) - Multi-Notification-Library
- [SMS Gateway](https://github.com/capcom6/android-sms-gateway) - Android SMS Gateway
- [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api) - Signal Integration
- Alle Open-Source-Projekte, die diese Lösung möglich machen

---

## 📞 Support

Bei Fragen oder Problemen:

1. Prüfe die [Dokumentation](Alarma-Dokumentation.md)
2. Schau dir die [Issues](https://github.com/walleralexander/alarma/issues) an
3. Erstelle ein neues Issue mit detaillierter Beschreibung

---

**Version:** 1.0  
**Letzte Aktualisierung:** 29. Januar 2026

---

⭐ Wenn dir dieses Projekt gefällt, gib ihm einen Stern auf GitHub!
