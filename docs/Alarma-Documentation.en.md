# Alarma!

## Multi-Channel Notification Gateway

**A concept by Alexander Waller and Claude AI**  
**January 30, 2026**

**WebPoint Internet Solutions**
**Version:** 1.0

---

## Executive Summary

This solution enables the Example Organization to send notifications via **SMS, WhatsApp, Signal, Microsoft Teams, and Email** - through a **single, self-hosted system**. The Android phone is used as a gateway for SMS, WhatsApp, and Signal, reducing external costs to a minimum.

**Key Benefits:**

- ✅ **No monthly cloud costs** - completely self-hosted
- ✅ **One API endpoint** for all communication channels
- ✅ **Android phone as gateway** - no expensive SMS providers needed
- ✅ **SMS works without internet** - cellular network during outages
- ✅ **Open source** - no vendor lock-ins
- ✅ **Ready immediately** - Docker-based, set up in 30 minutes

---

## System Architecture

### Component Overview

```txt
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring & Scripts                      │
│            (PRTG, PowerShell, Zabbix, etc.)                 │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP POST
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   Apprise API Gateway                        │
│              (Central Control - Port 8000)                  │
│                Tag-based Routing                             │
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

### Container Setup

| Container | Image | Port | Function |
| --------- | ----- | ---- | -------- |
| **apprise-api** | lscr.io/linuxserver/apprise-api | 8000 | Central API & routing |
| **sms-gateway** | capcom6/sms-gateway | 3000 | SMS via Android |
| **whatsapp-gateway** | dickyermawan/kilas | 3001 | WhatsApp via Android |
| **signal-gateway** | bbernhard/signal-cli-rest-api | 3002 | Signal via Android |
| **ntfy** (optional) | binwiederhier/ntfy | 8080 | Push notifications |

---

## 🆘 SMS as Failsafe

### Why SMS is Critical

**SMS is the only channel that works even during internet outages!**

SMS uses the **cellular network (GSM/LTE)**, not the internet. This makes SMS a critical component for emergency and disaster scenarios.

### Advantages of SMS During Outages

- 📡 **Separate infrastructure**: Cellular networks are independent of the internet
- 🔋 **Emergency power**: Cell towers have batteries and generators  
- 📶 **Minimal bandwidth**: Works even during network congestion
- ⚡ **Priority**: SMS delivery has priority in cellular networks
- 🔄 **Redundancy**: Multiple mobile operators available

### Scenarios for SMS Use

| Scenario | WhatsApp/Signal/Teams | SMS |
| -------- | --------------------- | --- |
| Municipal internet outage | ❌ Not available | ✅ Works |
| Power outage with router failure | ❌ Not available | ✅ Works |
| DDoS attack on infrastructure | ❌ Not available | ✅ Works |
| Provider outage (fiber optic) | ❌ Not available | ✅ Works |
| Natural disaster (flood) | ❌ Not available | ✅ Works |
| Normal operation | ✅ Works | ✅ Works |

### Recommended Notification Strategy

**Normal Alerts (Tag: `warning` or `info`):**

- WhatsApp + Teams + Email
- **DO NOT** use SMS (save costs)

**Critical Alerts (Tag: `critical` or `emergency`):**

- **SMS + WhatsApp + Signal + Teams + Email**
- SMS guarantees delivery even during outages!

**PowerShell Examples:**

```powershell
# Normal warning (without SMS - cost-saving)
Send-WarningAlert -Title "Backup" -Body "Backup successful"

# Critical emergency (WITH SMS - failsafe!)
Send-CriticalAlert -Title "Server DOWN" -Body "Main server unreachable"

# SMS only for absolute emergencies
Send-CustomNotification -Tags "sms" -Title "EMERGENCY" -Body "Data center offline"
```

> **⚠️ IMPORTANT:** In critical situations, SMS is the only reliable channel. All other services (WhatsApp, Signal, Teams, Email) require a functioning internet connection!

---

## Installation & Setup

### Prerequisites

**Server-side:**

- Linux server (Ubuntu/Debian recommended)
- Docker & Docker Compose installed
- Min. 2 GB RAM, 10 GB storage
- Network access to server (LAN or VPN)

**Client-side:**

- Android smartphone (Android 5.0+)
- Active SIM card for SMS
- WhatsApp account (optional)

### Step 1: Create Directory Structure

```bash
mkdir -p /opt/notification-gateway/{apprise-config,sms-data,whatsapp-data,ntfy/cache,ntfy/etc}
cd /opt/notification-gateway
```

### Step 2: Create Docker Compose File

File: `/opt/notification-gateway/docker-compose.yml`

```yaml
version: '3.8'

networks:
  notification-network:
    driver: bridge

services:
  # SMS Gateway - Android as SMS Relay
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

  # WhatsApp Gateway - Android as WhatsApp Relay  
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

  # Apprise API - Central Control
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

  # ntfy - Optional for Push Notifications
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

### Step 3: SMS Gateway Configuration

File: `/opt/notification-gateway/sms-config.yml`

```yaml
server:
  listen: 0.0.0.0:3000
  mode: private
  private_token: "YOUR_SECURE_TOKEN_HERE"

database:
  dsn: "/data/sms-gateway.db"
```

### Step 4: Apprise Configuration

File: `/opt/notification-gateway/apprise-config/apprise.yml`

```yaml
# Multi-Channel Configuration for Alarma! - Example Organization
version: 1

urls:
  # SMS via Android Gateway
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
      tag: sms, critical, emergency
  
  # WhatsApp via Android Gateway
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
  
  # Email via SMTP
  - mailtos://smtp-user:smtp-pass@smtp.example.com:587?from=alerts@example.com&to=it@example.com:
      tag: email, backup, log
  
  # ntfy Push Notifications
  - ntfy://ntfy/hohenems-alerts:
      tag: push, mobile
```

### Step 5: Start Containers

```bash
cd /opt/notification-gateway
docker-compose up -d
```

**Check logs:**

```bash
docker-compose logs -f
```

### Step 6: Android App Setup

#### SMS Gateway App

1. **Download app:**
   - GitHub: <https://github.com/capcom6/android-sms-gateway/releases>
   - Install latest APK

2. **Configure app:**
   - Open app → Settings → Cloud Server
   - API URL: `http://SERVER-IP:3000/api/mobile/v1`
   - Private Token: `YOUR_SECURE_TOKEN_HERE`
   - Enable Cloud Server

3. **Note credentials:**
   - In the app under "Home" username & password are displayed
   - Use these for Authorization header (Base64)

#### WhatsApp Gateway App

1. **Open web UI:**
   - Browser: `http://SERVER-IP:3001`

2. **Create session:**
   - Session ID: `YourSessionID`
   - Scan QR code with WhatsApp
   - (Settings → Linked Devices → Link a Device)

---

## Usage

### Basic Notification (All Channels)

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

**Curl/Bash:**

```bash
curl -X POST http://notification-server:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=critical",
    "title": "Server Alert",
    "body": "CPU usage critical: 95%"
  }'
```

### Channel-specific Notifications

**SMS Only:**

```powershell
$sms = @{
    urls = "tag=sms"
    body = "Backup Server01 completed successfully"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://notification-server:8000/notify" `
    -Method Post -Body $sms -ContentType "application/json"
```

**WhatsApp Only:**

```powershell
$whatsapp = @{
    urls = "tag=whatsapp"
    title = "Team Info"
    body = "Maintenance window today 8:00 PM-10:00 PM"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://notification-server:8000/notify" `
    -Method Post -Body $whatsapp -ContentType "application/json"
```

**Teams + Email:**

```powershell
$notification = @{
    urls = "tag=management"
    title = "Monthly Report"
    body = "The IT monthly report is available"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://notification-server:8000/notify" `
    -Method Post -Body $notification -ContentType "application/json"
```

---

## PowerShell Module

### PowerShell Module Installation

Save module file as: `NotificationGateway.psm1`

```powershell
# Include module in PowerShell profile
Import-Module "C:\Scripts\NotificationGateway.psm1"
```

### PowerShell Module Usage

```powershell
# Critical notification (SMS, WhatsApp, Teams)
Send-CriticalAlert -Title "Firewall Alert" -Body "Unusually high number of login attempts"

# Info message (WhatsApp and Teams only)
Send-InfoMessage -Title "Update available" -Body "Windows updates are ready"

# SMS notification
Send-SMSAlert -Body "Server DC01 unreachable"

# Custom notification
Send-CustomNotification -Tags "teams,email" -Title "Report" -Body "Weekly report"
```

---

## PRTG Integration

### Sensor: EXE/Script Advanced

**Save script as:** `C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\prtg-notification.ps1`

**In PRTG:**

1. Add sensor: "EXE/Script Advanced"
2. Select script: `prtg-notification.ps1`
3. Parameters (optional): `-Server notification-server -Port 8000`
4. On sensor status "Warning" or "Error" → Create notification trigger

**Notification Template:**

- Method: Execute Program
- Program: `C:\Scripts\Send-PRTGNotification.ps1`
- Parameters: `-SensorName "%sensorname%" -Status "%status%" -Message "%message%"`

---

## Monitoring & Maintenance

### Check Container Status

```bash
docker-compose ps
docker-compose logs sms-gateway
docker-compose logs whatsapp-gateway
```

### Connection Check

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

**Backup important data:**

```bash
# Configurations
tar -czf notification-backup-$(date +%Y%m%d).tar.gz \
  apprise-config/ sms-config.yml docker-compose.yml

# Session data
tar -czf sessions-backup-$(date +%Y%m%d).tar.gz \
  sms-data/ whatsapp-data/
```

### Updates

```bash
cd /opt/notification-gateway
docker-compose pull
docker-compose up -d
```

---

## Security

### Recommended Measures

1. **Firewall rules:**
   - Expose ports internally only (LAN/VPN)
   - No direct internet access

2. **API keys:**
   - Use secure, long tokens
   - Rotate regularly

3. **HTTPS:**
   - Reverse proxy (nginx/Traefik) with SSL
   - Let's Encrypt certificates

4. **Monitoring:**
   - Monitor failed login attempts
   - Implement rate limiting

### SSL/TLS Setup (Optional)

**Nginx Reverse Proxy Example:**

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

### SMS not being sent

**Check:**

1. Is the Android app running and connected?
2. SMS permissions granted?
3. API credentials correct in apprise.yml?

```bash
# Test SMS directly
curl -X POST http://localhost:3000/3rdparty/v1/message \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"message":"Test","phoneNumbers":["+43XXXXXXXXX"]}'
```

### WhatsApp Connection Lost

**Solution:**

1. Open WhatsApp Gateway web UI: `http://SERVER-IP:3001`
2. Check session status
3. Rescan QR code if necessary

### Apprise API Not Responding

```bash
# Restart container
docker-compose restart apprise-api

# Check logs
docker-compose logs apprise-api
```

---

## Costs & ROI

### One-time Costs

- Android smartphone (gateway): **€250**
- Development time: ~4 hours (internal resources)
- Server hardware: Already available (VM)
- **Total: €250**

### Ongoing Costs

- SMS costs: ~€0.09 per SMS (existing mobile plan)
- Mobile plan: ~€10-15/month
- Server operation: Negligible (part of existing infrastructure)
- **Total: ~€15-20/month**

### Alternative: Cloud SMS Gateway

- Twilio/MessageBird: ~€0.08 per SMS + basic fee €20/month
- WhatsApp Business API: €0.005-0.025 per message
- Hardware SMS gateway: €1,500-3,000 (one-time)
- **Total: ~€50-100/month** (cloud) or **€1,500+** (hardware)

### ROI Calculation

**Our Solution:**

- One-time: €250
- Year 1: €250 + (12 × €15) = **€430**
- Year 2-5: 12 × €15 = **€180/year**

**Cloud Alternative:**

- Year 1-5: 12 × €75 = **€900/year**

**Savings:**

- Year 1: €900 - €430 = **€470**
- Year 2: €900 - €180 = **€720**
- **5-year savings: ~€3,350**

**Payback period: After 4 months!**

---

## Extension Possibilities

### Integration Examples

- ✅ **Active Directory:** PowerShell scripts for user events
- ✅ **VMware:** Alerting for VM issues
- ✅ **Veeam Backup:** Backup status reports
- ✅ **PRTG:** Sensor-based alerts
- ✅ **MikroTik Router:** Script-based notifications
- ✅ **Palo Alto:** Syslog → Logstash → Script → Notification

### Additional Channels

- Telegram Bot (free)
- Slack Webhooks
- Discord Webhooks
- Push Notifications (ntfy)
- Matrix/Element

---

## Summary

This solution provides the Example Organization with a **professional, self-hosted notification system** with minimal costs and maximum flexibility. By using the Android phone as a gateway, expensive cloud services are eliminated, and the system can be operated entirely internally.

**Key Benefits:**

- 💰 **Cost savings:** €500-1,000/year vs. cloud solutions
- 🔒 **Data sovereignty:** All data remains internal
- 🎯 **Flexibility:** One API for all channels
- ⚡ **Speed:** Instant notifications
- 🔧 **Low maintenance:** Docker-based, stable containers

---

## Contact & Support

**Creator:** Alexander  
**Department:** Organization, Process Management and IT  
**Organization:** Example Organization  
**Email:** <office@webpoint.at>  

**Document version:** 1.0  
**Last updated:** January 29, 2026
