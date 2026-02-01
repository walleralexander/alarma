#!/bin/bash
# Alarma! Installation Script
# WebPoint Internet Solutions - Ein Konzept von Alexander Waller und Claude AI
# 30. Januar 2026

set -e

echo "============================================"
echo "  Alarma! Installation"
echo "  Multi-Channel Notification Gateway"
echo "============================================"
echo ""

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funktionen
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check Prerequisites
echo "Prüfe Voraussetzungen..."

if ! command -v docker &> /dev/null; then
    print_error "Docker ist nicht installiert!"
    echo "Bitte installieren: https://docs.docker.com/engine/install/"
    exit 1
fi
print_success "Docker gefunden"

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose ist nicht installiert!"
    echo "Bitte installieren: https://docs.docker.com/compose/install/"
    exit 1
fi
print_success "Docker Compose gefunden"

echo ""

# Installationsverzeichnis
INSTALL_DIR="/opt/alarma"
print_info "Installationsverzeichnis: $INSTALL_DIR"

# Verzeichnisstruktur erstellen
echo ""
echo "Erstelle Verzeichnisstruktur..."

sudo mkdir -p "$INSTALL_DIR"/{config/{apprise,ntfy},data/{sms,whatsapp,signal,apprise-attachments,ntfy-cache}}

print_success "Verzeichnisse erstellt"

# Dateien kopieren
echo ""
echo "Kopiere Konfigurationsdateien..."

if [ -f "docker-compose.yml" ]; then
    sudo cp docker-compose.yml "$INSTALL_DIR/"
    print_success "docker-compose.yml kopiert"
else
    print_error "docker-compose.yml nicht gefunden!"
    exit 1
fi

if [ -f "sms-config.yml" ]; then
    sudo cp sms-config.yml "$INSTALL_DIR/config/"
    print_success "sms-config.yml kopiert"
fi

if [ -f "apprise.yml" ]; then
    sudo cp apprise.yml "$INSTALL_DIR/config/apprise/"
    print_success "apprise.yml kopiert"
fi

if [ -f "ntfy-server.yml" ]; then
    sudo cp ntfy-server.yml "$INSTALL_DIR/config/ntfy/server.yml"
    print_success "ntfy-server.yml kopiert"
fi

# Berechtigungen setzen
echo ""
echo "Setze Berechtigungen..."
sudo chown -R 1000:1000 "$INSTALL_DIR/config"
sudo chown -R 1000:1000 "$INSTALL_DIR/data"
print_success "Berechtigungen gesetzt"

# .env Datei erstellen
echo ""
echo "Erstelle .env Datei..."
cat > "$INSTALL_DIR/.env" << 'EOF'
# Alarma! Environment Variables
TZ=Europe/Vienna
PUID=1000
PGID=1000

# Sicherheit - BITTE ÄNDERN!
WHATSAPP_API_KEY=YOUR_SECURE_API_KEY_HERE
SMS_PRIVATE_TOKEN=YOUR_SECURE_TOKEN_HERE

# Netzwerk
APPRISE_PORT=8000
SMS_PORT=3000
WHATSAPP_PORT=3001
SIGNAL_PORT=3002
NTFY_PORT=8080
EOF
print_success ".env Datei erstellt"

# Konfiguration anpassen
echo ""
echo "============================================"
print_info "WICHTIG: Konfiguration anpassen!"
echo "============================================"
echo ""
echo "Bitte passe folgende Dateien an:"
echo "1. $INSTALL_DIR/config/sms-config.yml"
echo "   - private_token ändern"
echo ""
echo "2. $INSTALL_DIR/config/apprise/apprise.yml"
echo "   - Telefonnummern eintragen"
echo "   - E-Mail-Adressen konfigurieren"
echo "   - Teams Webhook URL eintragen"
echo "   - SMS Gateway Authorization (Base64) anpassen"
echo ""
echo "3. $INSTALL_DIR/.env"
echo "   - API Keys ändern"
echo ""

read -p "Konfiguration angepasst? (j/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Jj]$ ]]; then
    print_info "Bitte zuerst die Konfiguration anpassen!"
    print_info "Danach ausführen: cd $INSTALL_DIR && docker-compose up -d"
    exit 0
fi

# Docker Images pullen
echo ""
echo "Lade Docker Images..."
cd "$INSTALL_DIR"
sudo docker-compose pull
print_success "Docker Images geladen"

# Container starten
echo ""
echo "Starte Alarma! Container..."
sudo docker-compose up -d
print_success "Container gestartet"

# Warte auf Startup
echo ""
echo "Warte auf Container-Start (30 Sekunden)..."
sleep 30

# Status prüfen
echo ""
echo "Container Status:"
sudo docker-compose ps

# Health Check
echo ""
echo "Prüfe Erreichbarkeit..."

if curl -s http://localhost:8000 > /dev/null; then
    print_success "Apprise API erreichbar (Port 8000)"
else
    print_error "Apprise API nicht erreichbar"
fi

if curl -s http://localhost:3000 > /dev/null; then
    print_success "SMS Gateway erreichbar (Port 3000)"
else
    print_error "SMS Gateway nicht erreichbar"
fi

if curl -s http://localhost:8080 > /dev/null; then
    print_success "ntfy erreichbar (Port 8080)"
else
    print_error "ntfy nicht erreichbar"
fi

# Zusammenfassung
echo ""
echo "============================================"
echo "  Installation abgeschlossen!"
echo "============================================"
echo ""
echo "Nächste Schritte:"
echo ""
echo "1. Android Apps installieren:"
echo "   - SMS Gateway: https://github.com/android-sms-gateway/client-android/releases"
echo "   - WhatsApp: Standard WhatsApp App"
echo "   - Signal: Standard Signal App"
echo ""
echo "2. Apps konfigurieren:"
echo "   - SMS Gateway: Server http://$(hostname -I | awk '{print $1}'):3000"
echo "   - WhatsApp Gateway: http://$(hostname -I | awk '{print $1}'):3001"
echo "   - Signal Gateway: http://$(hostname -I | awk '{print $1}'):3002"
echo ""
echo "3. Test-Notification senden:"
echo "   curl -X POST http://localhost:8000/notify \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"urls\":\"tag=teams\",\"title\":\"Test\",\"body\":\"Alarma! läuft!\"}'"
echo ""
echo "Web-Interfaces:"
echo "  - Apprise: http://$(hostname -I | awk '{print $1}'):8000"
echo "  - WhatsApp: http://$(hostname -I | awk '{print $1}'):3001"
echo "  - Signal: http://$(hostname -I | awk '{print $1}'):3002"
echo "  - ntfy: http://$(hostname -I | awk '{print $1}'):8080"
echo ""
echo "Logs anzeigen:"
echo "  cd $INSTALL_DIR && sudo docker-compose logs -f"
echo ""
echo "Container stoppen:"
echo "  cd $INSTALL_DIR && sudo docker-compose down"
echo ""
print_success "Alarma! ist bereit!"
