# 🚨 Alarma! - Passerelle de Notification Multi-Canal

> Un système de notification auto-hébergé et rentable pour SMS, WhatsApp, Signal, Teams et e-mail

**Développé par WebPoint Internet Solutions** | *Un concept d'Alexander Waller et Claude AI*

---

## 📋 Vue d'ensemble

Alarma! est une solution basée sur Docker qui permet d'envoyer des notifications via **plusieurs canaux** - contrôlées par **une seule API**. Le système utilise un smartphone Android comme passerelle pour SMS, WhatsApp et Signal, rendant ainsi superflus les fournisseurs cloud coûteux.

### ✨ Fonctionnalités principales

- 🆓 **Aucun frais cloud** - Entièrement auto-hébergé
- 📱 **Android comme passerelle** - Utilisation du matériel existant
- 🎯 **Un point de terminaison API** - Pour tous les canaux
- 🔧 **Basé sur Docker** - Opérationnel en 30 minutes
- 🔒 **Open Source** - Aucun verrouillage fournisseur
- 💰 **ROI en 4 mois** - Économie de ~700 €/an
- 🛡️ **Tolérant aux pannes** - Les SMS fonctionnent même sans Internet (réseau mobile)

### 🔌 Canaux supportés

| Canal | Passerelle | Statut |
| ------- | --------- | -------- |
| 📧 **E-mail** | SMTP | ✅ Prêt |
| 📱 **SMS** | Application Android | ✅ Prêt |
| 💬 **WhatsApp** | Application Android | ✅ Prêt |
| 🔐 **Signal** | signal-cli | ✅ Prêt |
| 👔 **Microsoft Teams** | Webhook | ✅ Prêt |
| 🔔 **Push (ntfy)** | ntfy.sh | ✅ Prêt |

---

## 🏗️ Architecture

```txt
┌─────────────────────────────────────────────────┐
│   Surveillance & Scripts (PRTG, PowerShell)     │
└────────────────┬────────────────────────────────┘
                 │ HTTP POST
                 ▼
┌─────────────────────────────────────────────────┐
│      Passerelle API Apprise (Port 8000)         │
│          Routage basé sur les tags              │
└─────┬──────┬──────┬──────┬──────┬──────────────┘
      │      │      │      │      │
      ▼      ▼      ▼      ▼      ▼
    SMS   WhatsApp Signal Teams E-mail
     └──────┴───────┴──────┘
              ▼
     ┌────────────────────┐
     │ Smartphone Android │
     └────────────────────┘
```

---

## 🚀 Démarrage rapide

### Prérequis

- Serveur Linux (Ubuntu/Debian)
- Docker & Docker Compose
- Smartphone Android (Android 5.0+)
- Min. 2 Go RAM, 10 Go de stockage

### Installation

```bash
# Cloner le dépôt
git clone https://github.com/walleralexander/alarma.git
cd alarma

# Créer la structure de répertoires
mkdir -p apprise-config sms-data whatsapp-data signal-data ntfy/{cache,etc}

# Adapter la configuration
cp docker-compose.example.yml docker-compose.yml
cp apprise-config/apprise.example.yml apprise-config/apprise.yml
# Modifiez les fichiers de configuration selon vos besoins

# Démarrer les conteneurs
docker compose up -d

# Vérifier le statut
docker compose ps
```

### Configuration de l'application Android

1. **Installer l'application SMS Gateway** : [GitHub Releases](https://github.com/capcom6/android-sms-gateway/releases)
2. Configurer l'application avec l'IP du serveur et le token
3. **Passerelle WhatsApp** : Ouvrir l'interface web et scanner le code QR

---

## 💻 Utilisation

### Notification de base

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

**Curl :**

```bash
curl -X POST http://serveur-notifications:8000/notify \
  -H "Content-Type: application/json" \
  -d '{
    "urls": "tag=critique",
    "title": "Alerte serveur",
    "body": "Charge CPU critique : 95%"
  }'
```

### Module PowerShell

```powershell
# Importer le module
Import-Module .\scripts\NotificationGateway.psm1

# Utilisation
Send-CriticalAlert -Title "Alerte pare-feu" -Body "Activité inhabituelle détectée"
Send-InfoMessage -Title "Mise à jour" -Body "Mises à jour Windows disponibles"
Send-SMSAlert -Body "Serveur DC01 inaccessible"
```

---

## 📊 Comparaison des coûts

### Notre solution

- **Unique :** 250 € (smartphone Android)
- **Récurrent :** ~15 €/mois (contrat de téléphonie mobile)
- **Année 1 :** 430 € coûts totaux

### Alternative cloud (Twilio/MessageBird)

- **Récurrent :** ~75 €/mois
- **Année 1 :** 900 € coûts totaux

### 💰 Économie

470 € la première année, 720 € les années suivantes

---

## 🔧 Intégration

Alarma! s'intègre facilement dans les systèmes existants :

- ✅ **PRTG Network Monitor** - Alertes basées sur les capteurs
- ✅ **Scripts PowerShell** - Notifications automatisées
- ✅ **Veeam Backup** - Rapports d'état de sauvegarde
- ✅ **VMware vCenter** - Alertes d'état des VM
- ✅ **Active Directory** - Notifications d'événements utilisateur
- ✅ **Routeur MikroTik** - Alertes basées sur des scripts

---

## 📖 Documentation

Vous trouverez la documentation complète ici :

- [**Alarma!-Documentation.fr.md**](docs/Alarma!-Documentation.fr.md) - Guide complet
- [**PowerShell-Scripts-README.md**](PowerShell-Scripts-README.md) - Intégration PowerShell
- Exemples Docker Compose dans le dépôt

---

## 🛠️ Composants

| Conteneur | Image | Description |
| ----------- | ------- | -------------- |
| **apprise-api** | lscr.io/linuxserver/apprise-api | API centrale & routage |
| **sms-gateway** | capcom6/sms-gateway | SMS via Android |
| **whatsapp-gateway** | dickyermawan/kilas | WhatsApp via Android |
| **signal-gateway** | bbernhard/signal-cli-rest-api | Signal Messenger |
| **ntfy** | binwiederhier/ntfy | Notifications push |

---

## 🔒 Sécurité

- Libérer tous les ports uniquement en interne (LAN/VPN)
- Utiliser des tokens API sécurisés
- Optionnel : HTTPS via proxy inverse (nginx/Traefik)
- Implémenter une limitation de débit
- Mises à jour régulières des conteneurs

---

## 🤝 Contribuer

Ce projet a été développé pour la Organisation Exemple. Les suggestions d'amélioration et les Pull Requests sont les bienvenues !

### Développement

```bash
# Forker et cloner le dépôt
git clone https://github.com/VOTRE-NOM-UTILISATEUR/alarma.git

# Créer une branche
git checkout -b feature/nouvelle-fonctionnalite

# Commiter les modifications
git commit -am "Ajout d'une nouvelle fonctionnalité"

# Pusher et créer une Pull Request
git push origin feature/nouvelle-fonctionnalite
```

---

## 📝 Licence

Ce projet est sous licence MIT - voir le fichier LICENSE pour plus de détails.

---

## 👨‍💻 Auteurs

**Alexander Waller**  
Organisation, Gestion des Processus et IT  
Organisation Exemple  
E-mail : `office@webpoint.at`

Avec le soutien de Claude AI

---

## 🙏 Remerciements

- [Apprise](https://github.com/caronc/apprise) - Bibliothèque de multi-notifications
- [SMS Gateway](https://github.com/capcom6/android-sms-gateway) - Passerelle SMS Android
- [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api) - Intégration Signal
- Tous les projets open source qui rendent cette solution possible

---

## 📞 Support

En cas de questions ou de problèmes :

1. Consultez la [documentation](docs/Alarma!-Documentation.fr.md)
2. Consultez les [issues](https://github.com/walleralexander/alarma/issues)
3. Créez une nouvelle issue avec une description détaillée

---

**Version :** 1.0  
**Dernière mise à jour :** 29 janvier 2026

---

⭐ Si vous aimez ce projet, donnez-lui une étoile sur GitHub !
