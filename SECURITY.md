# 🔒 Security Policy

**Alarma! Notification Gateway**
**WebPoint Internet Solutions**
**Version:** 1.0 | **Datum:** 30. Januar 2026

---

## 🛡️ Reporting Security Vulnerabilities

Die Sicherheit von Alarma! ist uns wichtig. Wenn Sie eine Sicherheitslücke entdecken, melden Sie diese bitte **vertraulich**:

### Kontakt

**E-Mail:** <office@webpoint.at>  
**Betreff:** `[SECURITY] Alarma! Vulnerability Report`

### Was in den Report gehört

- Beschreibung der Schwachstelle
- Schritte zur Reproduktion
- Betroffene Komponenten/Versionen
- Potenzielle Auswirkungen
- Vorschläge zur Behebung (optional)

### Unsere Zusagen

- ✅ Bestätigung innerhalb von **48 Stunden**
- ✅ Regelmäßige Updates zum Bearbeitungsstand
- ✅ Nennung in Credits (falls gewünscht)
- ✅ **Keine rechtlichen Schritte** bei verantwortungsvoller Offenlegung

---

## 🔐 Security Best Practices

### 1. Netzwerksicherheit

#### Firewall-Regeln (Linux - iptables)

```bash
# Nur lokales Netzwerk darf auf Apprise API zugreifen
iptables -A INPUT -p tcp --dport 8000 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8000 -j DROP

# SMS Gateway nur von localhost
iptables -A INPUT -p tcp --dport 3000 -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 3000 -j DROP

# WhatsApp Gateway nur intern
iptables -A INPUT -p tcp --dport 3001 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 3001 -j DROP

# Signal Gateway nur intern
iptables -A INPUT -p tcp --dport 3002 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 3002 -j DROP

# ntfy nur intern
iptables -A INPUT -p tcp --dport 8080 -s 192.168.1.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8080 -j DROP

# Regeln speichern
iptables-save > /etc/iptables/rules.v4
```

#### Windows Firewall (PowerShell)

```powershell
# Apprise API - nur lokales Netzwerk
New-NetFirewallRule -DisplayName "Alarma! Apprise API" `
    -Direction Inbound -LocalPort 8000 -Protocol TCP `
    -RemoteAddress 192.168.1.0/24 -Action Allow

# SMS Gateway - nur localhost
New-NetFirewallRule -DisplayName "Alarma! SMS Gateway" `
    -Direction Inbound -LocalPort 3000 -Protocol TCP `
    -RemoteAddress 127.0.0.1 -Action Allow

# WhatsApp Gateway - nur lokales Netzwerk
New-NetFirewallRule -DisplayName "Alarma! WhatsApp Gateway" `
    -Direction Inbound -LocalPort 3001 -Protocol TCP `
    -RemoteAddress 192.168.1.0/24 -Action Allow

# Alle anderen Zugriffe blockieren
New-NetFirewallRule -DisplayName "Alarma! Block External" `
    -Direction Inbound -LocalPort 3000,3001,3002,8000,8080 -Protocol TCP `
    -Action Block
```

### 2. Token & Password Management

#### Starke Tokens generieren

```bash
# Linux/Mac/WSL
openssl rand -hex 32

# PowerShell
[Convert]::ToBase64String((1..32 | ForEach-Object { Get-Random -Maximum 256 }))

# Python
python3 -c "import secrets; print(secrets.token_hex(32))"
```

#### Basic Auth für SMS Gateway

```bash
# Username:Password zu Base64
echo -n "admin:SuperSecurePassword2026" | base64
# Ausgabe: YWRtaW46U3VwZXJTZWN1cmVQYXNzd29yZDIwMjY=

# In apprise.yml verwenden:
# Authorization: Basic YWRtaW46U3VwZXJTZWN1cmVQYXNzd29yZDIwMjY=
```

#### Password Complexity Requirements

- **Minimum:** 16 Zeichen
- **Empfohlen:** 32+ Zeichen für API Keys
- Mix aus: Groß-/Kleinbuchstaben, Zahlen, Sonderzeichen
- **KEINE** Dictionary Words
- **KEINE** persönlichen Informationen

### 3. .env Datei Verschlüsselung

Siehe detaillierte Anleitung in [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md)

#### Quick Guide GPG

```bash
# Verschlüsseln (AES256)
gpg --symmetric --cipher-algo AES256 .env

# Entschlüsseln
gpg --decrypt .env.gpg > .env

# Datei-Berechtigungen
chmod 600 .env
```

#### Quick Guide Age (Modern)

```bash
# Key generieren (einmalig)
age-keygen -o ~/.alarma-age.key

# Verschlüsseln
age -r $(age-keygen -y ~/.alarma-age.key) .env > .env.age

# Entschlüsseln
age --decrypt -i ~/.alarma-age.key .env.age > .env
```

### 4. SSL/TLS Setup mit Reverse Proxy

#### nginx mit Let's Encrypt

**Installation:**

```bash
# Ubuntu/Debian
apt install nginx certbot python3-certbot-nginx

# Zertifikat anfordern
certbot --nginx -d notifications.example.com

# Auto-Renewal testen
certbot renew --dry-run
```

**nginx Configuration:**

`/etc/nginx/sites-available/alarma`

```nginx
# HTTP → HTTPS Redirect
server {
    listen 80;
    server_name notifications.example.com;
    return 301 https://$server_name$request_uri;
}

# HTTPS Server
server {
    listen 443 ssl http2;
    server_name notifications.example.com;

    # SSL Certificates
    ssl_certificate /etc/letsencrypt/live/notifications.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/notifications.example.com/privkey.pem;

    # SSL Configuration (Mozilla Intermediate)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;

    # HSTS (1 year)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Apprise API Proxy
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Rate Limiting
        limit_req zone=apprise_limit burst=10 nodelay;
        limit_req_status 429;
    }
}

# Rate Limiting Configuration (in http block)
# Add to /etc/nginx/nginx.conf:
# http {
#     limit_req_zone $binary_remote_addr zone=apprise_limit:10m rate=10r/s;
# }
```

**Aktivieren:**

```bash
ln -s /etc/nginx/sites-available/alarma /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
```

#### Traefik Alternative

`docker-compose.yml` ergänzen:

```yaml
services:
  traefik:
    image: traefik:v2.10
    command:
      - "--api.insecure=false"
      - "--providers.docker=true"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.email=it@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt

  apprise-api:
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.apprise.rule=Host(`notifications.example.com`)"
      - "traefik.http.routers.apprise.entrypoints=websecure"
      - "traefik.http.routers.apprise.tls.certresolver=letsencrypt"
```

### 5. Container Security

#### Read-Only Filesystems

```yaml
services:
  apprise-api:
    read_only: true
    tmpfs:
      - /tmp
      - /var/run
```

#### Drop Capabilities

```yaml
services:
  apprise-api:
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # Nur falls Port < 1024
```

#### Security Options

```yaml
services:
  apprise-api:
    security_opt:
      - no-new-privileges:true
      - apparmor=docker-default
      - seccomp=default
```

### 6. Audit Logging

#### Docker Container Logs sammeln

```bash
# Logs zentral sammeln
docker compose logs --follow > /var/log/alarma/container.log

# Logrotate einrichten
cat > /etc/logrotate.d/alarma << 'EOF'
/var/log/alarma/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
}
EOF
```

#### Failed Login Attempts monitoren

```bash
# PowerShell Script
$logs = docker compose logs sms-gateway | Select-String -Pattern "failed|unauthorized|403"
if ($logs.Count -gt 10) {
    Send-CriticalAlert -Title "Security Alert" -Body "Viele fehlgeschlagene Login-Versuche: $($logs.Count)"
}
```

### 7. Network Segmentation

#### Docker Networks Isolation

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # Kein Internet-Zugriff

services:
  apprise-api:
    networks:
      - frontend
      - backend

  sms-gateway:
    networks:
      - backend  # Nur intern erreichbar
```

---

## 🔍 Security Checklist (Pre-Deployment)

### Infrastruktur

- [ ] Firewall-Regeln konfiguriert und getestet
- [ ] VPN-Zugriff eingerichtet (falls extern)
- [ ] Ports nur intern exponiert
- [ ] Network Segmentation implementiert

### Authentifizierung

- [ ] Alle Default-Passwörter geändert
- [ ] Starke Tokens generiert (min. 32 Zeichen)
- [ ] Basic Auth für SMS Gateway aktiviert
- [ ] .env Datei verschlüsselt

### Verschlüsselung

- [ ] SSL/TLS für alle externen Verbindungen
- [ ] Reverse Proxy mit HTTPS eingerichtet
- [ ] Zertifikate gültig und Auto-Renewal aktiv
- [ ] TLS 1.2+ erzwungen, 1.0/1.1 deaktiviert

### Container

- [ ] Images von vertrauenswürdigen Quellen
- [ ] Container mit non-root User laufen
- [ ] Read-only Filesystems wo möglich
- [ ] Capabilities minimiert
- [ ] Security Options gesetzt

### Monitoring

- [ ] Logging aktiviert
- [ ] Logrotate konfiguriert
- [ ] Failed login monitoring eingerichtet
- [ ] Alerts für Security Events

### Backup & Recovery

- [ ] Backup-Script getestet
- [ ] Restore-Prozedur dokumentiert und getestet
- [ ] Backups verschlüsselt
- [ ] Offsite-Backup eingerichtet

### Dokumentation

- [ ] Passwörter in Password Manager
- [ ] Notfall-Kontakte dokumentiert
- [ ] Incident Response Plan erstellt
- [ ] Team geschult

---

## 🚨 Incident Response

### Bei Sicherheitsvorfall

1. **Isolieren**

   ```bash
   docker compose down  # System herunterfahren
   ```

2. **Analysieren**

   ```bash
   docker compose logs > incident-$(date +%Y%m%d).log
   ```

3. **Credentials rotieren** (siehe [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md))

4. **System härten** (Checkliste oben durchgehen)

5. **Dokumentieren** (Incident Report erstellen)

6. **Team informieren**

---

## 🔄 Security Updates

### Container Images aktualisieren

```bash
# Images aktualisieren
docker compose pull

# Mit neuen Images starten
docker compose up -d

# Alte Images entfernen
docker image prune -a
```

### Regelmäßigkeit

- **Sicherheitsupdates:** Sofort
- **Minor Updates:** Monatlich
- **Major Updates:** Nach Testing quartalsweise

---

## 📚 Weitere Ressourcen

- **OWASP Top 10:** <https://owasp.org/www-project-top-ten/>
- **Docker Security Best Practices:** <https://docs.docker.com/engine/security/>
- **CIS Docker Benchmark:** <https://www.cisecurity.org/benchmark/docker>
- **NIST Cybersecurity Framework:** <https://www.nist.gov/cyberframework>

---

## 📞 Security Contact

**E-Mail:** <office@webpoint.at>  
**Abteilung:** Organisation, Prozessmanagement und IT  
**WebPoint Internet Solutions**

---

**Version:** 1.0  
**Letzte Aktualisierung:** 30. Januar 2026
