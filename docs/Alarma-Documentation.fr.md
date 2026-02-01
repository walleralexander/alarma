# Alarma!

## Passerelle de Notification Multi-Canal

**Un concept d'Alexander Waller et Claude AI**  
**30 janvier 2026**

**WebPoint Internet Solutions**
**Version :** 1.0

---

## Résumé exécutif

Cette solution permet à la Organisation Exemple d'envoyer des notifications via **SMS, WhatsApp, Signal, Microsoft Teams et e-mail** - via un **système unique auto-hébergé**. Le smartphone Android est utilisé comme passerelle pour SMS, WhatsApp et Signal, ce qui réduit au minimum les coûts externes.

**Avantages principaux :**

- ✅ **Aucun frais cloud mensuel** - complètement auto-hébergé
- ✅ **Un point de terminaison API** pour tous les canaux de communication
- ✅ **Smartphone Android comme passerelle** - aucun fournisseur SMS coûteux nécessaire
- ✅ **Les SMS fonctionnent sans Internet** - réseau mobile en cas de panne
- ✅ **Open Source** - aucun verrouillage fournisseur
- ✅ **Prêt immédiatement** - basé sur Docker, configuré en 30 minutes

---

## Architecture système

### Vue d'ensemble des composants

```txt
┌─────────────────────────────────────────────────────────────┐
│                Surveillance & Scripts                        │
│            (PRTG, PowerShell, Zabbix, etc.)                 │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP POST
                     ▼
┌─────────────────────────────────────────────────────────────┐
│               Passerelle API Apprise                         │
│          (Contrôle central - Port 8000)                      │
│              Routage basé sur les tags                       │
└─────┬──────────┬──────────┬──────────┬──────────┬──────────┘
      │          │          │          │          │
      ▼          ▼          ▼          ▼          ▼
┌──────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐
│   SMS    │ │WhatsApp│ │ Signal │ │ Teams  │ │  E-mail  │
│Passerelle│ │Passer. │ │Passer. │ │Webhook │ │  SMTP    │
│(Port 3000│ │(3001)  │ │(3002)  │ │        │ │          │
└────┬─────┘ └────┬───┘ └────┬───┘ └────────┘ └──────────┘
     │            │          │
     └────────────┴──────────┘
                  ▼
┌──────────────────────────────────┐
│   Smartphone Android (250 €)     │
│    (Relais SMS/WhatsApp/Signal)  │
└──────────────────────────────────┘
```

### Configuration des conteneurs

| Conteneur | Image | Port | Fonction |
| --------- | ----- | ---- | -------- |
| **apprise-api** | lscr.io/linuxserver/apprise-api | 8000 | API centrale & routage |
| **sms-gateway** | capcom6/sms-gateway | 3000 | SMS via Android |
| **whatsapp-gateway** | dickyermawan/kilas | 3001 | WhatsApp via Android |
| **signal-gateway** | bbernhard/signal-cli-rest-api | 3002 | Signal via Android |
| **ntfy** (optionnel) | binwiederhier/ntfy | 8080 | Notifications push |

---

## 🆘 SMS comme système de secours

### Pourquoi les SMS sont critiques

**Les SMS sont le seul canal qui fonctionne même en cas de panne Internet !**

Les SMS utilisent le **réseau mobile (GSM/LTE)**, pas Internet. Cela fait des SMS le composant critique pour les scénarios d'urgence et de catastrophe.

### Avantages des SMS en cas de panne

- 📡 **Infrastructure séparée** : Les réseaux mobiles sont indépendants d'Internet
- 🔋 **Alimentation de secours** : Les tours relais ont des batteries et des générateurs
- 📶 **Bande passante minimale** : Fonctionne même en cas de surcharge du réseau
- ⚡ **Priorité** : L'envoi de SMS a la priorité sur le réseau mobile
- 🔄 **Redondance** : Plusieurs opérateurs de téléphonie mobile disponibles

### Scénarios d'utilisation des SMS

| Scénario | WhatsApp/Signal/Teams | SMS |
| -------- | --------------------- | --- |
| Panne Internet de la municipalité | ❌ Non disponible | ✅ Fonctionne |
| Panne de courant avec panne du routeur | ❌ Non disponible | ✅ Fonctionne |
| Attaque DDoS sur l'infrastructure | ❌ Non disponible | ✅ Fonctionne |
| Panne du fournisseur (fibre optique) | ❌ Non disponible | ✅ Fonctionne |
| Catastrophe naturelle (inondation) | ❌ Non disponible | ✅ Fonctionne |
| Fonctionnement normal | ✅ Fonctionne | ✅ Fonctionne |

### Stratégie de notification recommandée

**Alertes normales (Tag : `avertissement` ou `info`) :**

- WhatsApp + Teams + E-mail
- **NE PAS** utiliser les SMS (économiser les coûts)

**Alertes critiques (Tag : `critique` ou `urgence`) :**

- **SMS + WhatsApp + Signal + Teams + E-mail**
- Les SMS garantissent la livraison même en cas de panne !

**Exemples PowerShell :**

```powershell
# Avertissement normal (sans SMS - économique)
Send-WarningAlert -Title "Sauvegarde" -Body "Sauvegarde réussie"

# Urgence critique (AVEC SMS - tolérant aux pannes !)
Send-CriticalAlert -Title "Serveur DOWN" -Body "Serveur principal inaccessible"

# SMS uniquement pour les urgences absolues
Send-CustomNotification -Tags "sms" -Title "URGENCE" -Body "Centre de données hors ligne"
```

> **⚠️ IMPORTANT :** Dans les situations critiques, les SMS sont le seul canal fiable. Tous les autres services (WhatsApp, Signal, Teams, e-mail) nécessitent une connexion Internet fonctionnelle !

---

## Installation & Configuration

### Prérequis

**Côté serveur :**

- Serveur Linux (Ubuntu/Debian recommandé)
- Docker & Docker Compose installés
- Min. 2 Go RAM, 10 Go de stockage
- Accès réseau au serveur (LAN ou VPN)

**Côté client :**

- Smartphone Android (Android 5.0+)
- Carte SIM active pour les SMS
- Compte WhatsApp (optionnel)

### Étape 1 : Créer la structure de répertoires

```bash
mkdir -p /opt/notification-gateway/{apprise-config,sms-data,whatsapp-data,ntfy/cache,ntfy/etc}
cd /opt/notification-gateway
```

### Étape 2 : Créer le fichier Docker Compose

Fichier : `/opt/notification-gateway/docker-compose.yml`

```yaml
version: '3.8'

networks:
  notification-network:
    driver: bridge

services:
  # Passerelle SMS - Android comme relais SMS
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

  # Passerelle WhatsApp - Android comme relais WhatsApp
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

  # Passerelle Signal - Signal Messenger
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

  # API Apprise - Contrôle central
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

  # ntfy - Optionnel pour les notifications push
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

### Étape 3 : Configuration de la passerelle SMS

Fichier : `/opt/notification-gateway/sms-config.yml`

```yaml
server:
  listen: 0.0.0.0:3000
  mode: private
  private_token: "YOUR_SECURE_TOKEN_HERE"

database:
  dsn: "/data/sms-gateway.db"
```

### Étape 4 : Configuration Apprise

Fichier : `/opt/notification-gateway/apprise-config/apprise.yml`

```yaml
# Configuration multi-canal pour Alarma! - Organisation Exemple
version: 1

urls:
  # SMS via passerelle Android
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
      tag: sms, critique, urgence
  
  # WhatsApp via passerelle Android
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
      tag: whatsapp, equipe, info
  
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
      tag: signal, securise, equipe
  
  # Microsoft Teams
  - teams://outlook.office.com/webhook/XXXXXXXX:
      tag: teams, direction, info
  
  # E-mail via SMTP
  - mailtos://smtp-user:smtp-pass@smtp.example.com:587?from=alertes@example.com&to=it@example.com:
      tag: email, sauvegarde, log
  
  # Notifications push ntfy
  - ntfy://ntfy/hohenems-alertes:
      tag: push, mobile
```

### Étape 5 : Démarrer les conteneurs

```bash
cd /opt/notification-gateway
docker-compose up -d
```

**Vérifier les journaux :**

```bash
docker-compose logs -f
```

### Étape 6 : Configuration de l'application Android

#### Application SMS Gateway

1. **Télécharger l'application :**
   - GitHub : <https://github.com/capcom6/android-sms-gateway/releases>
   - Installer la dernière APK

2. **Configurer l'application :**
   - Ouvrir l'application → Settings → Cloud Server
   - API URL : `http://IP-DU-SERVEUR:3000/api/mobile/v1`
   - Private Token : `YOUR_SECURE_TOKEN_HERE`
   - Activer Cloud Server

3. **Noter les identifiants :**
   - Dans l'application sous "Home", le nom d'utilisateur et le mot de passe sont affichés
   - Utiliser ceux-ci pour l'en-tête Authorization (Base64)

#### Application WhatsApp Gateway

1. **Ouvrir l'interface web :**
   - Navigateur : `http://IP-DU-SERVEUR:3001`

2. **Créer une session :**
   - Session ID : `YourSessionID`
   - Scanner le code QR avec WhatsApp
   - (Paramètres → Appareils liés → Lier un appareil)

---

## Utilisation

### Notification de base (tous les canaux)

**PowerShell :**

```powershell
$notification = @{
    urls = "tag=critique"
    title = "Alerte serveur"
    body = "Charge CPU critique : 95%"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://serveur-notifications:8000/notify" `
    -Method Post -Body $notification -ContentType "application/json"
```

**Curl/Bash :**

```bash
curl -X POST http://serveur-notifications:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=critique",
    "title": "Alerte serveur",
    "body": "Charge CPU critique : 95%"
  }'
```

### Notifications spécifiques à un canal

**SMS uniquement :**

```powershell
$sms = @{
    urls = "tag=sms"
    body = "Sauvegarde Serveur01 terminée avec succès"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://serveur-notifications:8000/notify" `
    -Method Post -Body $sms -ContentType "application/json"
```

**WhatsApp uniquement :**

```powershell
$whatsapp = @{
    urls = "tag=whatsapp"
    title = "Info équipe"
    body = "Fenêtre de maintenance aujourd'hui 20h00-22h00"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://serveur-notifications:8000/notify" `
    -Method Post -Body $whatsapp -ContentType "application/json"
```

**Teams + E-mail :**

```powershell
$notification = @{
    urls = "tag=direction"
    title = "Rapport mensuel"
    body = "Le rapport mensuel IT est disponible"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://serveur-notifications:8000/notify" `
    -Method Post -Body $notification -ContentType "application/json"
```

---

## Module PowerShell

### Installation du module PowerShell

Enregistrer le fichier du module sous : `NotificationGateway.psm1`

```powershell
# Intégrer le module dans le profil PowerShell
Import-Module "C:\Scripts\NotificationGateway.psm1"
```

### Utilisation du module PowerShell

```powershell
# Notification critique (SMS, WhatsApp, Teams)
Send-CriticalAlert -Title "Alerte pare-feu" -Body "Nombre inhabituel de tentatives de connexion"

# Message d'information (WhatsApp et Teams uniquement)
Send-InfoMessage -Title "Mise à jour disponible" -Body "Des mises à jour Windows sont prêtes"

# Notification SMS
Send-SMSAlert -Body "Serveur DC01 inaccessible"

# Notification personnalisée
Send-CustomNotification -Tags "teams,email" -Title "Rapport" -Body "Rapport hebdomadaire"
```

---

## Intégration PRTG

### Capteur : EXE/Script Advanced

**Enregistrer le script sous :** `C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\prtg-notification.ps1`

**Dans PRTG :**

1. Ajouter un capteur : "EXE/Script Advanced"
2. Sélectionner le script : `prtg-notification.ps1`
3. Paramètres (optionnel) : `-Server serveur-notifications -Port 8000`
4. En cas de statut "Warning" ou "Error" du capteur → Créer un déclencheur de notification

**Modèle de notification :**

- Méthode : Execute Program
- Programme : `C:\Scripts\Send-PRTGNotification.ps1`
- Paramètres : `-SensorName "%sensorname%" -Status "%status%" -Message "%message%"`

---

## Surveillance & Maintenance

### Vérifier le statut des conteneurs

```bash
docker-compose ps
docker-compose logs sms-gateway
docker-compose logs whatsapp-gateway
```

### Vérification de la connexion

**Passerelle SMS :**

```bash
curl -u username:password http://localhost:3000/3rdparty/v1/message
```

**Passerelle WhatsApp :**

```bash
curl -H "X-API-KEY: YOUR_SECURE_API_KEY_HERE" http://localhost:3001/api/status
```

**API Apprise :**

```bash
curl http://localhost:8000/
```

### Sauvegarde

**Sauvegarder les données importantes :**

```bash
# Configurations
tar -czf notification-backup-$(date +%Y%m%d).tar.gz \
  apprise-config/ sms-config.yml docker-compose.yml

# Données de session
tar -czf sessions-backup-$(date +%Y%m%d).tar.gz \
  sms-data/ whatsapp-data/
```

### Mises à jour

```bash
cd /opt/notification-gateway
docker-compose pull
docker-compose up -d
```

---

## Sécurité

### Mesures recommandées

1. **Règles de pare-feu :**
   - Libérer les ports uniquement en interne (LAN/VPN)
   - Aucun accès direct à Internet

2. **Clés API :**
   - Utiliser des tokens sécurisés et longs
   - Rotation régulière

3. **HTTPS :**
   - Proxy inverse (nginx/Traefik) avec SSL
   - Certificats Let's Encrypt

4. **Surveillance :**
   - Surveiller les tentatives de connexion échouées
   - Configurer une limitation de débit

### Configuration SSL/TLS (optionnel)

**Exemple de proxy inverse Nginx :**

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

## Dépannage

### Les SMS ne sont pas envoyés

**Vérifier :**

1. L'application Android est-elle en cours d'exécution et connectée ?
2. Les autorisations SMS sont-elles accordées ?
3. Les identifiants API sont-ils corrects dans apprise.yml ?

```bash
# Tester les SMS directement
curl -X POST http://localhost:3000/3rdparty/v1/message \
  -u username:password \
  -H "Content-Type: application/json" \
  -d '{"message":"Test","phoneNumbers":["+43XXXXXXXXX"]}'
```

### Connexion WhatsApp perdue

**Solution :**

1. Ouvrir l'interface web de la passerelle WhatsApp : `http://IP-DU-SERVEUR:3001`
2. Vérifier le statut de la session
3. Scanner à nouveau le code QR si nécessaire

### L'API Apprise ne répond pas

```bash
# Redémarrer le conteneur
docker-compose restart apprise-api

# Vérifier les journaux
docker-compose logs apprise-api
```

---

## Coûts & ROI

### Coûts uniques

- Smartphone Android (passerelle) : **250 €**
- Temps de développement : ~4 heures (ressources internes)
- Matériel serveur : Déjà disponible (VM)
- **Total : 250 €**

### Coûts récurrents

- Coûts SMS : ~0,09 € par SMS (contrat de téléphonie mobile existant)
- Contrat de téléphonie mobile : ~10-15 €/mois
- Exploitation du serveur : Négligeable (partie de l'infrastructure existante)
- **Total : ~15-20 €/mois**

### Alternative : Passerelle SMS cloud

- Twilio/MessageBird : ~0,08 € par SMS + frais de base 20 €/mois
- WhatsApp Business API : 0,005-0,025 € par message
- Passerelle SMS matérielle : 1 500-3 000 € (unique)
- **Total : ~50-100 €/mois** (cloud) ou **1 500 € +** (matériel)

### Calcul du ROI

**Notre solution :**

- Unique : 250 €
- Année 1 : 250 € + (12 × 15 €) = **430 €**
- Années 2-5 : 12 × 15 € = **180 €/an**

**Alternative cloud :**

- Années 1-5 : 12 × 75 € = **900 €/an**

**Économie :**

- Année 1 : 900 € - 430 € = **470 €**
- Année 2 : 900 € - 180 € = **720 €**
- **Économie sur 5 ans : ~3 350 €**

**Amortissement : Après 4 mois !**

---

## Possibilités d'extension

### Exemples d'intégration

- ✅ **Active Directory :** Scripts PowerShell sur événements utilisateur
- ✅ **VMware :** Alertes en cas de problèmes de VM
- ✅ **Veeam Backup :** Rapports d'état de sauvegarde
- ✅ **PRTG :** Alertes basées sur les capteurs
- ✅ **Routeur MikroTik :** Notifications basées sur des scripts
- ✅ **Palo Alto :** Syslog → Logstash → Script → Notification

### Canaux supplémentaires

- Telegram Bot (gratuit)
- Webhooks Slack
- Webhooks Discord
- Notifications push (ntfy)
- Matrix/Element

---

## Résumé

Cette solution offre à la Organisation Exemple un **système de notification professionnel et auto-hébergé** avec des coûts minimaux et une flexibilité maximale. En utilisant le smartphone Android comme passerelle, les services cloud coûteux sont éliminés et le système peut être exploité entièrement en interne.

**Avantages clés :**

- 💰 **Économie de coûts :** 500-1 000 €/an par rapport aux solutions cloud
- 🔒 **Souveraineté des données :** Toutes les données restent en interne
- 🎯 **Flexibilité :** Une API pour tous les canaux
- ⚡ **Rapidité :** Notifications instantanées
- 🔧 **Faible maintenance :** Basé sur Docker, conteneurs stables

---

## Contact & Support

**Créateur :** Alexander  
**Département :** Organisation, Gestion des Processus et IT  
**Organisation :** Organisation Exemple  
**E-mail :** <office@webpoint.at>

**Version de la documentation :** 1.0  
**Dernière mise à jour :** 29 janvier 2026
