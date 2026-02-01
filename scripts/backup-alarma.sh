#!/bin/bash

################################################################################
# Alarma! Backup Script für Linux/macOS
#
# Beschreibung:
#   Erstellt vollständige Backups des Alarma!-Systems inklusive:
#   - Docker-Compose-Konfigurationsdateien
#   - Alle Docker-Volumes (apprise-config, sms-data, whatsapp-data, signal-data, ntfy)
#   - Erstellt komprimierte und optional verschlüsselte Archive
#   - Bereinigt alte Backups basierend auf Retention-Policy
#   - Sendet Benachrichtigungen über Alarma! bei Erfolg/Fehler
#   - Umfassendes Logging aller Operationen
#
# Verwendung:
#   ./backup-alarma.sh [OPTIONS]
#
# Optionen:
#   -d DIR      Backup-Verzeichnis (Standard: /opt/alarma-backups)
#   -p DIR      Projekt-Verzeichnis (Standard: aktuelles Verzeichnis)
#   -r DAYS     Retention in Tagen (Standard: 7)
#   -e          Backup mit GPG verschlüsseln
#   -k KEY      GPG-Key-ID für Verschlüsselung
#   -n URL      Notification-URL für Alarma!
#   -s          Volume-Backup überspringen
#   -l FILE     Log-Datei (Standard: BACKUP_DIR/backup.log)
#   -h          Diese Hilfe anzeigen
#
# Beispiele:
#   ./backup-alarma.sh
#   ./backup-alarma.sh -d /mnt/backups -r 14
#   ./backup-alarma.sh -e -k backup@example.com -n http://localhost:8080/notify
#
# Autor: Alarma! Project
# Version: 1.0
# Datum: 2026-01-30
#
################################################################################

set -euo pipefail  # Strikte Fehlerbehandlung
# set -x  # Uncomment für Debug-Ausgabe

# Konstanten
readonly SCRIPT_VERSION="1.0"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)
readonly BACKUP_NAME="alarma-full-${TIMESTAMP}"

# Docker-Volumes, die gesichert werden sollen
readonly DOCKER_VOLUMES=(
    "apprise-config"
    "sms-data"
    "whatsapp-data"
    "signal-data"
    "ntfy"
)

# Standard-Parameter
BACKUP_DIR="/opt/alarma-backups"
PROJECT_DIR="$(pwd)"
RETENTION_DAYS=7
ENCRYPT=false
ENCRYPTION_KEY=""
NOTIFY_URL=""
SKIP_VOLUMES=false
LOG_FILE=""
COMPRESS=true

# Globale Variablen
TEMP_DIR=""
BACKUP_CREATED=false

################################################################################
# Farben für Ausgabe
################################################################################

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'  # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly NC=''
fi

################################################################################
# Logging-Funktionen
################################################################################

# Initialisiert das Logging-System
init_logging() {
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="${BACKUP_DIR}/backup.log"
    fi
    
    # Stelle sicher, dass das Log-Verzeichnis existiert
    local log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir"
    
    log "================================================"
    log "Alarma! Backup Script v${SCRIPT_VERSION} gestartet"
    log "Zeitstempel: ${TIMESTAMP}"
    log "================================================"
}

# Schreibt eine Nachricht ins Log und auf die Konsole
log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_message="[${timestamp}] [${level}] ${message}"
    
    # Konsolenausgabe mit Farben
    case "$level" in
        ERROR)
            echo -e "${RED}${log_message}${NC}" >&2
            ;;
        WARNING)
            echo -e "${YELLOW}${log_message}${NC}"
            ;;
        SUCCESS)
            echo -e "${GREEN}${log_message}${NC}"
            ;;
        *)
            echo "$log_message"
            ;;
    esac
    
    # In Datei schreiben
    if [[ -n "$LOG_FILE" ]]; then
        echo "$log_message" >> "$LOG_FILE"
    fi
}

################################################################################
# Hilfsfunktionen
################################################################################

# Zeigt Hilfe an
show_help() {
    cat << EOF
Alarma! Backup Script v${SCRIPT_VERSION}

Verwendung: $0 [OPTIONS]

Optionen:
  -d DIR      Backup-Verzeichnis (Standard: /opt/alarma-backups)
  -p DIR      Projekt-Verzeichnis (Standard: aktuelles Verzeichnis)
  -r DAYS     Retention in Tagen (Standard: 7)
  -e          Backup mit GPG verschlüsseln
  -k KEY      GPG-Key-ID oder Email für Verschlüsselung
  -n URL      Notification-URL für Alarma!
  -s          Volume-Backup überspringen
  -l FILE     Log-Datei (Standard: BACKUP_DIR/backup.log)
  -h          Diese Hilfe anzeigen

Beispiele:
  $0
  $0 -d /mnt/backups -r 14
  $0 -e -k backup@example.com -n http://localhost:8080/notify

EOF
    exit 0
}

# Prüft, ob Docker läuft
check_docker() {
    if ! command -v docker &> /dev/null; then
        log "Docker ist nicht installiert" ERROR
        return 1
    fi
    
    if ! docker ps &> /dev/null; then
        log "Docker läuft nicht oder keine Berechtigung" ERROR
        return 1
    fi
    
    return 0
}

# Prüft, ob ein Docker-Volume existiert
check_volume_exists() {
    local volume_name="$1"
    docker volume inspect "$volume_name" &> /dev/null
}

# Sendet eine Benachrichtigung über Alarma!
send_notification() {
    local message="$1"
    local priority="${2:-normal}"
    
    if [[ -z "$NOTIFY_URL" ]]; then
        return 0
    fi
    
    local json_payload=$(cat <<EOF
{
    "message": "$message",
    "priority": "$priority"
}
EOF
)
    
    if curl -s -X POST "$NOTIFY_URL" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        --max-time 10 &> /dev/null; then
        log "Benachrichtigung gesendet: $message"
    else
        log "Fehler beim Senden der Benachrichtigung" WARNING
    fi
}

# Bereinigt temporäre Dateien
cleanup_temp() {
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        log "Bereinige temporäre Dateien..."
        rm -rf "$TEMP_DIR"
        log "Temporäre Dateien gelöscht"
    fi
}

# Bereinigt alte Backups
cleanup_old_backups() {
    log "Bereinige Backups älter als ${RETENTION_DAYS} Tage..."
    
    local pattern="alarma-full-*.tar.gz"
    if [[ "$ENCRYPT" = true ]]; then
        pattern="alarma-full-*.tar.gz.gpg"
    fi
    
    local deleted_count=0
    
    # Finde und lösche alte Backups
    while IFS= read -r -d '' backup_file; do
        if [[ -f "$backup_file" ]]; then
            local file_age_days=$(( ($(date +%s) - $(stat -c %Y "$backup_file" 2>/dev/null || stat -f %m "$backup_file")) / 86400 ))
            
            if [[ $file_age_days -gt $RETENTION_DAYS ]]; then
                if rm -f "$backup_file"; then
                    log "Gelöscht: $(basename "$backup_file")" SUCCESS
                    ((deleted_count++))
                else
                    log "Fehler beim Löschen: $(basename "$backup_file")" WARNING
                fi
            fi
        fi
    done < <(find "$BACKUP_DIR" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    
    if [[ $deleted_count -eq 0 ]]; then
        log "Keine alten Backups zum Löschen gefunden"
    else
        log "Alte Backups bereinigt: ${deleted_count} Dateien gelöscht"
    fi
}

################################################################################
# Backup-Funktionen
################################################################################

# Sichert Konfigurationsdateien
backup_config_files() {
    local dest_dir="$1"
    
    log "Sichere Konfigurationsdateien..."
    
    local config_source="${PROJECT_DIR}/docker-compose"
    
    if [[ ! -d "$config_source" ]]; then
        log "Docker-Compose-Verzeichnis nicht gefunden: $config_source" ERROR
        return 1
    fi
    
    local config_dest="${dest_dir}/docker-compose"
    
    if cp -r "$config_source" "$config_dest"; then
        # Prüfe, ob .env-Datei existiert (wichtig!)
        if [[ -f "${config_dest}/.env" ]]; then
            log "✓ .env-Datei gesichert (enthält Secrets!)" SUCCESS
        else
            log ".env-Datei nicht gefunden - möglicherweise keine Secrets vorhanden" WARNING
        fi
        
        log "Konfigurationsdateien erfolgreich gesichert" SUCCESS
        return 0
    else
        log "Fehler beim Sichern der Konfigurationsdateien" ERROR
        return 1
    fi
}

# Sichert ein Docker-Volume
backup_docker_volume() {
    local volume_name="$1"
    local dest_dir="$2"
    
    log "Sichere Docker-Volume: $volume_name"
    
    # Prüfe, ob Volume existiert
    if ! check_volume_exists "$volume_name"; then
        log "Volume '$volume_name' existiert nicht - überspringe" WARNING
        return 0
    fi
    
    local backup_file="${dest_dir}/${volume_name}.tar.gz"
    
    # Verwende Alpine-Container zum Erstellen des Volume-Backups
    if docker run --rm \
        -v "${volume_name}:/volume:ro" \
        -v "${dest_dir}:/backup" \
        alpine tar czf "/backup/${volume_name}.tar.gz" -C /volume . 2>&1 | tee -a "$LOG_FILE"; then
        
        if [[ -f "$backup_file" ]]; then
            local size_mb=$(du -m "$backup_file" | cut -f1)
            log "✓ Volume '$volume_name' gesichert (${size_mb} MB)" SUCCESS
            return 0
        else
            log "Backup-Datei wurde nicht erstellt: $backup_file" ERROR
            return 1
        fi
    else
        log "Fehler beim Sichern von Volume '$volume_name'" ERROR
        return 1
    fi
}

# Sichert alle Docker-Volumes
backup_all_volumes() {
    local dest_dir="$1"
    
    log "Starte Backup aller Docker-Volumes..."
    
    local success_count=0
    local fail_count=0
    
    for volume in "${DOCKER_VOLUMES[@]}"; do
        if backup_docker_volume "$volume" "$dest_dir"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    log "Volume-Backup abgeschlossen: ${success_count} erfolgreich, ${fail_count} fehlgeschlagen"
    
    if [[ $fail_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# Erstellt ein komprimiertes Archiv
create_archive() {
    local source_dir="$1"
    local dest_file="$2"
    
    log "Erstelle komprimiertes Archiv..."
    
    if tar czf "$dest_file" -C "$(dirname "$source_dir")" "$(basename "$source_dir")"; then
        local size_mb=$(du -m "$dest_file" | cut -f1)
        log "✓ Archiv erstellt: $dest_file (${size_mb} MB)" SUCCESS
        return 0
    else
        log "Fehler beim Erstellen des Archivs" ERROR
        return 1
    fi
}

# Verschlüsselt das Backup mit GPG
encrypt_backup() {
    local backup_file="$1"
    local key_id="$2"
    
    log "Verschlüssele Backup mit GPG..."
    
    # Prüfe, ob GPG verfügbar ist
    if ! command -v gpg &> /dev/null; then
        log "GPG ist nicht installiert. Bitte installieren Sie GPG." ERROR
        return 1
    fi
    
    local output_file="${backup_file}.gpg"
    
    if [[ -n "$key_id" ]]; then
        # Verschlüsseln mit Public Key
        if gpg --encrypt --recipient "$key_id" --output "$output_file" "$backup_file" 2>&1 | tee -a "$LOG_FILE"; then
            rm -f "$backup_file"
            local size_mb=$(du -m "$output_file" | cut -f1)
            log "✓ Backup verschlüsselt (${size_mb} MB)" SUCCESS
            echo "$output_file"
            return 0
        fi
    else
        # Symmetrische Verschlüsselung (Passphrase erforderlich)
        if gpg --symmetric --cipher-algo AES256 --output "$output_file" "$backup_file" 2>&1 | tee -a "$LOG_FILE"; then
            rm -f "$backup_file"
            local size_mb=$(du -m "$output_file" | cut -f1)
            log "✓ Backup verschlüsselt (${size_mb} MB)" SUCCESS
            echo "$output_file"
            return 0
        fi
    fi
    
    log "GPG-Verschlüsselung fehlgeschlagen" ERROR
    return 1
}

# Erstellt Backup-Metadaten
create_metadata() {
    local dest_dir="$1"
    local backup_file="$2"
    
    log "Erstelle Backup-Metadaten..."
    
    local metadata_file="${dest_dir}/backup-metadata.json"
    local size_mb=$(du -m "$backup_file" | cut -f1)
    
    cat > "$metadata_file" << EOF
{
    "timestamp": "${TIMESTAMP}",
    "date": "$(date '+%Y-%m-%d %H:%M:%S')",
    "version": "${SCRIPT_VERSION}",
    "hostname": "$(hostname)",
    "user": "$(whoami)",
    "backup_file": "$(basename "$backup_file")",
    "backup_size_mb": ${size_mb},
    "project_dir": "${PROJECT_DIR}",
    "volumes_backed_up": [$(printf '"%s",' "${DOCKER_VOLUMES[@]}" | sed 's/,$//')],
    "encrypted": ${ENCRYPT},
    "compression": ${COMPRESS}
}
EOF
    
    log "Metadaten gespeichert: $metadata_file"
}

################################################################################
# Haupt-Workflow
################################################################################

# Hauptfunktion für den Backup-Prozess
run_backup() {
    log "Initialisiere Backup-Prozess..."
    
    # Erstelle Backup-Verzeichnis
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log "Backup-Verzeichnis erstellt: $BACKUP_DIR"
    fi
    
    # Prüfe Docker
    if ! check_docker; then
        return 1
    fi
    log "Docker ist verfügbar"
    
    # Erstelle temporäres Verzeichnis
    TEMP_DIR="${BACKUP_DIR}/${BACKUP_NAME}"
    mkdir -p "$TEMP_DIR"
    log "Temporäres Verzeichnis: $TEMP_DIR"
    
    # Backup-Schritte
    if ! backup_config_files "$TEMP_DIR"; then
        return 1
    fi
    
    if [[ "$SKIP_VOLUMES" = false ]]; then
        if ! backup_all_volumes "$TEMP_DIR"; then
            return 1
        fi
    else
        log "Volume-Backup übersprungen (--skip-volumes aktiv)" WARNING
    fi
    
    # Erstelle Archiv
    local archive_file="${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
    
    if [[ "$COMPRESS" = true ]]; then
        if ! create_archive "$TEMP_DIR" "$archive_file"; then
            return 1
        fi
    else
        # Ohne Komprimierung einfach umbenennen
        mv "$TEMP_DIR" "$archive_file"
    fi
    
    # Erstelle Metadaten
    create_metadata "$TEMP_DIR" "$archive_file"
    
    # Verschlüsselung (optional)
    local final_backup_file="$archive_file"
    if [[ "$ENCRYPT" = true ]]; then
        if encrypted_file=$(encrypt_backup "$archive_file" "$ENCRYPTION_KEY"); then
            final_backup_file="$encrypted_file"
        else
            return 1
        fi
    fi
    
    BACKUP_CREATED=true
    
    # Bereinigung
    cleanup_temp
    cleanup_old_backups
    
    # Erfolg!
    local backup_size_mb=$(du -m "$final_backup_file" | cut -f1)
    local success_message="✅ Alarma! Backup erfolgreich erstellt: ${BACKUP_NAME} (${backup_size_mb} MB)"
    log "$success_message" SUCCESS
    
    send_notification "$success_message" "low"
    
    log "================================================"
    log "Backup abgeschlossen"
    log "Datei: $final_backup_file"
    log "Größe: ${backup_size_mb} MB"
    log "================================================"
    
    return 0
}

################################################################################
# Error Handler
################################################################################

error_handler() {
    local exit_code=$?
    local error_message="❌ Alarma! Backup FEHLGESCHLAGEN (Exit Code: ${exit_code})"
    
    log "$error_message" ERROR
    
    send_notification "$error_message" "high"
    
    cleanup_temp
    
    exit $exit_code
}

trap error_handler ERR

################################################################################
# Argument-Parsing
################################################################################

while getopts "d:p:r:ek:n:sl:h" opt; do
    case $opt in
        d) BACKUP_DIR="$OPTARG" ;;
        p) PROJECT_DIR="$OPTARG" ;;
        r) RETENTION_DAYS="$OPTARG" ;;
        e) ENCRYPT=true ;;
        k) ENCRYPTION_KEY="$OPTARG" ;;
        n) NOTIFY_URL="$OPTARG" ;;
        s) SKIP_VOLUMES=true ;;
        l) LOG_FILE="$OPTARG" ;;
        h) show_help ;;
        \?)
            echo "Ungültige Option: -$OPTARG" >&2
            show_help
            ;;
    esac
done

################################################################################
# Script-Ausführung
################################################################################

main() {
    # Banner
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  Alarma! Backup Script v${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    
    # Logging initialisieren
    init_logging
    
    # Parameter ausgeben
    log "Backup-Verzeichnis: $BACKUP_DIR"
    log "Projekt-Verzeichnis: $PROJECT_DIR"
    log "Retention: $RETENTION_DAYS Tage"
    log "Verschlüsselung: $ENCRYPT"
    log "Volumes überspringen: $SKIP_VOLUMES"
    log "Benachrichtigungs-URL: ${NOTIFY_URL:-Nicht konfiguriert}"
    
    # Backup starten
    if run_backup; then
        exit 0
    else
        exit 1
    fi
}

# Script starten
main "$@"
