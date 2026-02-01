# 🚨 Alarma! - Multi-Channel Notification Gateway

> A self-hosted, cost-effective notification system for SMS, WhatsApp, Signal, Teams, and Email

**Developed by WebPoint Internet Solutions** | *A concept by Alexander Waller and Claude AI*

---

## 📋 Overview

Alarma! is a Docker-based solution that enables sending notifications across **multiple channels** - controlled via **a single API**. The system uses an Android smartphone as a gateway for SMS, WhatsApp, and Signal, eliminating the need for expensive cloud providers.

### ✨ Core Features

- 🆓 **No Cloud Costs** - Fully self-hosted
- 📱 **Android as Gateway** - Leverage existing hardware
- 🎯 **One API Endpoint** - For all channels
- 🔧 **Docker-based** - Ready in 30 minutes
- 🔒 **Open Source** - No vendor lock-ins
- 💰 **ROI in 4 Months** - Save ~€700/year
- 🛡️ **Failsafe** - SMS works without internet (cellular network)

### 🔌 Supported Channels

| Channel | Gateway | Status |
| ------- | --------- | -------- |
| 📧 **Email** | SMTP | ✅ Ready |
| 📱 **SMS** | Android App | ✅ Ready |
| 💬 **WhatsApp** | Android App | ✅ Ready |
| 🔐 **Signal** | signal-cli | ✅ Ready |
| 👔 **Microsoft Teams** | Webhook | ✅ Ready |
| 🔔 **Push (ntfy)** | ntfy.sh | ✅ Ready |

---

## 🏗️ Architecture

```txt
┌─────────────────────────────────────────────────┐
│   Monitoring & Scripts (PRTG, PowerShell)      │
└────────────────┬────────────────────────────────┘
                 │ HTTP POST
                 ▼
┌─────────────────────────────────────────────────┐
│          Apprise API Gateway (Port 8000)        │
│              Tag-based Routing                  │
└─────┬──────┬──────┬──────┬──────┬──────────────┘
      │      │      │      │      │
      ▼      ▼      ▼      ▼      ▼
    SMS   WhatsApp Signal Teams Email
     └──────┴───────┴──────┘
              ▼
     ┌────────────────────┐
     │ Android Smartphone │
     └────────────────────┘
```

---

## 🚀 Quick Start

### Prerequisites

- Linux server (Ubuntu/Debian)
- Docker & Docker Compose
- Android smartphone (Android 5.0+)
- Min. 2 GB RAM, 10 GB storage

### Installation

```bash
# Clone repository
git clone https://github.com/walleralexander/alarma.git
cd alarma

# Create directory structure
mkdir -p apprise-config sms-data whatsapp-data signal-data ntfy/{cache,etc}

# Adjust configuration
cp docker-compose.example.yml docker-compose.yml
cp apprise-config/apprise.example.yml apprise-config/apprise.yml
# Edit configuration files according to your needs

# Start containers
docker-compose up -d

# Check status
docker-compose ps
```

### Android App Setup

1. **Install SMS Gateway App**: [GitHub Releases](https://github.com/capcom6/android-sms-gateway/releases)
2. Configure app with server IP and token
3. **WhatsApp Gateway**: Open web UI and scan QR code

---

## 💻 Usage

### Basic Notification

**PowerShell:**

```powershell
$notification = @{
    urls = "tag=critical"
    title = "Server Alert"
    body = "CPU usage critical: 95%"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://notification-server:8000/notify" `
    -Method Post -Body $notification -ContentType "application/json"
```

**Curl:**

```bash
curl -X POST http://notification-server:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=critical",
    "title": "Server Alert",
    "body": "CPU usage critical: 95%"
  }'
```

### PowerShell Module

```powershell
# Import module
Import-Module .\scripts\NotificationGateway.psm1

# Usage
Send-CriticalAlert -Title "Firewall Alert" -Body "Unusual activity detected"
Send-InfoMessage -Title "Update" -Body "Windows updates available"
Send-SMSAlert -Body "Server DC01 unreachable"
```

---

## 📊 Cost Comparison

### Our Solution

- **One-time:** €250 (Android smartphone)
- **Ongoing:** ~€15/month (mobile plan)
- **Year 1:** €430 total cost

### Cloud Alternative (Twilio/MessageBird)

- **Ongoing:** ~€75/month
- **Year 1:** €900 total cost

### 💰 Savings

€470 in the first year, €720 in subsequent years

---

## 🔧 Integration

Alarma! integrates easily with existing systems:

- ✅ **PRTG Network Monitor** - Sensor-based alerts
- ✅ **PowerShell Scripts** - Automated notifications
- ✅ **Veeam Backup** - Backup status reports
- ✅ **VMware vCenter** - VM status alerts
- ✅ **Active Directory** - User event notifications
- ✅ **MikroTik Router** - Script-based alerts

---

## 📖 Documentation

Find the complete documentation here:

- [**Alarma!-Documentation.en.md**](docs/Alarma!-Documentation.en.md) - Complete guide
- [**PowerShell-Scripts-README.md**](PowerShell-Scripts-README.md) - PowerShell integration
- Docker Compose examples in the repository

---

## 🛠️ Components

| Container | Image | Description |
| ----------- | ------- | -------------- |
| **apprise-api** | lscr.io/linuxserver/apprise-api | Central API & routing |
| **sms-gateway** | capcom6/sms-gateway | SMS via Android |
| **whatsapp-gateway** | dickyermawan/kilas | WhatsApp via Android |
| **signal-gateway** | bbernhard/signal-cli-rest-api | Signal Messenger |
| **ntfy** | binwiederhier/ntfy | Push notifications |

---

## 🔒 Security

- Expose all ports internally only (LAN/VPN)
- Use secure API tokens
- Optional: HTTPS via reverse proxy (nginx/Traefik)
- Implement rate limiting
- Regular container updates

---

## 🤝 Contributing

This project was developed for the Example Organization. Suggestions for improvement and pull requests are welcome!

### Development

```bash
# Fork and clone repository
git clone https://github.com/YOUR-USERNAME/alarma.git

# Create branch
git checkout -b feature/new-feature

# Commit changes
git commit -am "Add new feature"

# Push and create pull request
git push origin feature/new-feature
```

---

## 📝 License

This project is licensed under the MIT License - see LICENSE file for details.

---

## 👨‍💻 Authors

**Alexander Waller**  
Organization, Process Management and IT  
Example Organization  
Email: `office@webpoint.at`

With support from Claude AI

---

## 🙏 Acknowledgments

- [Apprise](https://github.com/caronc/apprise) - Multi-notification library
- [SMS Gateway](https://github.com/capcom6/android-sms-gateway) - Android SMS gateway
- [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api) - Signal integration
- All open-source projects that make this solution possible

---

## 📞 Support

For questions or issues:

1. Check the [documentation](docs/Alarma!-Documentation.en.md)
2. Review the [issues](https://github.com/walleralexander/alarma/issues)
3. Create a new issue with detailed description

---

**Version:** 1.0  
**Last Updated:** January 29, 2026

---

⭐ If you like this project, give it a star on GitHub!
