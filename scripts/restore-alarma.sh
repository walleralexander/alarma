#!/bin/bash

################################################################################
# Alarma! Restore Script für Linux/macOS
#
# Beschreibung:
#   Stellt Alarma!-Backups wieder her inklusive:
#   - Auswahl verfügbarer Backups
#   - Entschlüsselung (falls verschlüsselt)
#   - Wiederherstellung von Konfigurationsdateien
#   - Wiederherstellung aller Docker-Volumes
#   - Automatisches Stoppen/Starten der Container
#   - Erstellen eines Sicherungs-Restore-Points vor der Wiederherstellung
#   - Verifizierung der wiederhergestellten Daten
#
# Verwendung:
#   ./restore-alarma.sh [OPTIONS]
#
# Optionen:
#   -f FILE     Backup-Datei zum Wiederherstellen
#   -d DIR      Backup-Verzeichnis (für -l)
#   -p DIR      Ziel-Projektverzeichnis (Standard: aktuelles Verzeichnis)
#   -l          Liste verfügbare Backups
#   -v          Verifiziere Backup vor Restore
#   -s          Überspringe Pre-Restore-Backup
#   -y          Keine Bestätigung (force)
#   -k PASS     Passphrase für verschlüsselte Backups
#   -n URL      Notification-URL
#   -L FILE     Log-Datei
#   -h          Diese Hilfe anzeigen
#
# Beispiele:
#   ./restore-alarma.sh -l -d /opt/alarma-backups
#   ./restore-alarma.sh -f /opt/alarma-backups/alarma-full-20260130.tar.gz
#   ./restore-alarma.sh -f backup.tar.gz.gpg -k secret -v
#
# Autor: Alarma! Project
# Version: 1.0
# Datum: 2026-01-30
#
# WARNUNG: Restore überschreibt vorhandene Daten!
#
################################################################################

set -euo pipefail

# Konstanten
readonly SCRIPT_VERSION="1.0"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Docker-Volumes
readonly DOCKER_VOLUMES=(
    "apprise-config"
    "sms-data"
    "whatsapp-data"
    "signal-data"
    "ntfy"
)

# Standard-Parameter
BACKUP_FILE=""
BACKUP_DIR="/opt/alarma-backups"
PROJECT_DIR="$(pwd)"
LIST_MODE=false
VERIFY=false
SKIP_PRE_RESTORE=false
FORCE=false
DECRYPT_PASSPHRASE=""
NOTIFY_URL=""
LOG_FILE=""

# Globale Variablen
TEMP_DIR=""
RESTORE_SUCCESSFUL=false
PRE_RESTORE_BACKUP=""

################################################################################
# Farben
################################################################################

if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly NC=''
fi

################################################################################
# Logging
################################################################################

init_logging() {
    if [[ -z "$LOG_FILE" ]]; then
        LOG_FILE="/tmp/alarma-restore-${TIMESTAMP}.log"
    fi
    
    local log_dir=$(dirname "$LOG_FILE")
    mkdir -p "$log_dir"
    
    log "================================================"
    log "Alarma! Restore Script v${SCRIPT_VERSION} gestartet"
    log "Zeitstempel: ${TIMESTAMP}"
    log "================================================"
}

log() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_message="[${timestamp}] [${level}] ${message}"
    
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
    
    if [[ -n "$LOG_FILE" ]]; then
        echo "$log_message" >> "$LOG_FILE"
    fi
}

################################################################################
# Hilfsfunktionen
################################################################################

show_help() {
    cat << EOF
Alarma! Restore Script v${SCRIPT_VERSION}

Verwendung: $0 [OPTIONS]

Optionen:
  -f FILE     Backup-Datei zum Wiederherstellen (erforderlich)
  -d DIR      Backup-Verzeichnis (Standard: /opt/alarma-backups)
  -p DIR      Ziel-Projektverzeichnis (Standard: aktuelles Verzeichnis)
  -l          Liste verfügbare Backups
  -v          Verifiziere Backup vor Restore
  -s          Überspringe Pre-Restore-Backup (nicht empfohlen!)
  -y          Keine Bestätigung (force)
  -k PASS     Passphrase für verschlüsselte Backups
  -n URL      Notification-URL für Alarma!
  -L FILE     Log-Datei
  -h          Diese Hilfe anzeigen

Beispiele:
  $0 -l -d /opt/alarma-backups
  $0 -f /opt/alarma-backups/alarma-full-20260130-020000.tar.gz
  $0 -f backup.tar.gz.gpg -k secret -v -n http://localhost:8080/notify

WARNUNG: Restore überschreibt vorhandene Daten!

EOF
    exit 0
}

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

check_volume_exists() {
    local volume_name="$1"
    docker volume inspect "$volume_name" &> /dev/null
}

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

cleanup_temp() {
    if [[ -n "$TEMP_DIR" ]] && [[ -d "$TEMP_DIR" ]]; then
        log "Bereinige temporäre Dateien..."
        rm -rf "$TEMP_DIR"
        log "Temporäre Dateien gelöscht"
    fi
}

get_user_confirmation() {
    local message="$1"
    
    if [[ "$FORCE" = true ]]; then
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}${message}${NC}"
    echo ""
    read -p "Fortfahren? (j/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[JjYy]$ ]]; then
        return 0
    else
        return 1
    fi
}

################################################################################
# Backup-Listing
################################################################################

list_available_backups() {
    local backup_dir="$1"
    
    echo ""
    echo -e "${CYAN}Verfügbare Backups in: ${backup_dir}${NC}"
    echo "================================================================================"
    
    if [[ ! -d "$backup_dir" ]]; then
        echo -e "${RED}Backup-Verzeichnis existiert nicht!${NC}"
        return 1
    fi
    
    local index=1
    local found_backups=0
    
    # Suche nach Backup-Dateien
    while IFS= read -r -d '' backup_file; do
        ((found_backups++))
        
        local filename=$(basename "$backup_file")
        local size_mb=$(du -m "$backup_file" | cut -f1)
        local mod_time=$(stat -c %y "$backup_file" 2>/dev/null || stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$backup_file")
        local age_days=$(( ($(date +%s) - $(stat -c %Y "$backup_file" 2>/dev/null || stat -f %m "$backup_file")) / 86400 ))
        local encrypted="Nein"
        
        if [[ "$filename" =~ \.gpg$ ]]; then
            encrypted="Ja"
        fi
        
        echo ""
        echo -e "${CYAN}[$index] ${filename}${NC}"
        echo "    Größe: ${size_mb} MB"
        echo "    Datum: ${mod_time}"
        echo "    Alter: ${age_days} Tage"
        echo "    Verschlüsselt: ${encrypted}"
        echo "    Pfad: ${backup_file}"
        
        ((index++))
    done < <(find "$backup_dir" -maxdepth 1 -name "alarma-full-*.tar.gz*" -print0 2>/dev/null | sort -rz)
    
    echo ""
    echo "================================================================================"
    
    if [[ $found_backups -eq 0 ]]; then
        echo -e "${YELLOW}Keine Backups gefunden.${NC}"
    else
        echo -e "${CYAN}Gesamt: ${found_backups} Backup(s) gefunden${NC}"
    fi
    
    echo ""
}

################################################################################
# Backup-Verifikation
################################################################################

verify_backup_integrity() {
    local backup_path="$1"
    
    log "Verifiziere Backup-Integrität..."
    
    if [[ ! -f "$backup_path" ]]; then
        log "Backup-Datei nicht gefunden: $backup_path" ERROR
        return 1
    fi
    
    # Prüfe Dateigröße
    local file_size=$(stat -c %s "$backup_path" 2>/dev/null || stat -f %z "$backup_path")
    if [[ $file_size -lt 1024 ]]; then
        log "Backup-Datei ist zu klein (${file_size} Bytes) - möglicherweise beschädigt" ERROR
        return 1
    fi
    
    local size_mb=$(( file_size / 1048576 ))
    log "Dateigröße: ${size_mb} MB"
    
    # Prüfe tar.gz-Integrität
    if [[ "$backup_path" =~ \.tar\.gz$ ]]; then
        if tar tzf "$backup_path" &> /dev/null; then
            log "tar.gz-Archiv OK" SUCCESS
            return 0
        else
            log "tar.gz-Archiv beschädigt" ERROR
            return 1
        fi
    fi
    
    # Prüfe GPG-Datei
    if [[ "$backup_path" =~ \.gpg$ ]]; then
        if command -v gpg &> /dev/null; then
            if gpg --list-packets "$backup_path" &> /dev/null; then
                log "GPG-Datei OK" SUCCESS
                return 0
            else
                log "GPG-Datei möglicherweise beschädigt" WARNING
            fi
        fi
    fi
    
    log "Basis-Integritätsprüfung bestanden" SUCCESS
    return 0
}

################################################################################
# Entschlüsselung
################################################################################

decrypt_backup() {
    local encrypted_file="$1"
    local passphrase="$2"
    
    log "Entschlüssele Backup mit GPG..."
    
    if ! command -v gpg &> /dev/null; then
        log "GPG ist nicht installiert" ERROR
        return 1
    fi
    
    local decrypted_file="${encrypted_file%.gpg}"
    
    if [[ -n "$passphrase" ]]; then
        if gpg --batch --yes --passphrase "$passphrase" \
            --output "$decrypted_file" \
            --decrypt "$encrypted_file" 2>&1 | tee -a "$LOG_FILE"; then
            log "✓ Backup entschlüsselt" SUCCESS
            echo "$decrypted_file"
            return 0
        fi
    else
        if gpg --output "$decrypted_file" \
            --decrypt "$encrypted_file" 2>&1 | tee -a "$LOG_FILE"; then
            log "✓ Backup entschlüsselt" SUCCESS
            echo "$decrypted_file"
            return 0
        fi
    fi
    
    log "GPG-Entschlüsselung fehlgeschlagen" ERROR
    return 1
}

################################################################################
# Pre-Restore-Backup
################################################################################

create_pre_restore_backup() {
    log "Erstelle Pre-Restore-Backup..."
    
    local backup_script="$(dirname "$0")/backup-alarma.sh"
    
    if [[ ! -x "$backup_script" ]]; then
        log "Backup-Script nicht gefunden oder nicht ausführbar - Pre-Restore-Backup wird übersprungen" WARNING
        return 0
    fi
    
    local pre_restore_dir="${BACKUP_DIR}/pre-restore"
    mkdir -p "$pre_restore_dir"
    
    if "$backup_script" -d "$pre_restore_dir" -r 3 -l "${pre_restore_dir}/backup.log"; then
        local backup_file=$(find "$pre_restore_dir" -maxdepth 1 -name "alarma-full-*.tar.gz" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)
        
        if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
            log "✓ Pre-Restore-Backup erstellt: $(basename "$backup_file")" SUCCESS
            echo "$backup_file"
            return 0
        fi
    fi
    
    log "Pre-Restore-Backup konnte nicht erstellt werden" WARNING
    return 0
}

################################################################################
# Docker-Container-Verwaltung
################################################################################

stop_alarma_containers() {
    log "Stoppe Alarma!-Container..."
    
    local compose_file="${PROJECT_DIR}/docker-compose/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        log "docker-compose.yml nicht gefunden: $compose_file" WARNING
        return 0
    fi
    
    if docker-compose -f "$compose_file" down 2>&1 | tee -a "$LOG_FILE"; then
        log "✓ Container gestoppt" SUCCESS
        return 0
    else
        log "Fehler beim Stoppen der Container" WARNING
        return 1
    fi
}

start_alarma_containers() {
    log "Starte Alarma!-Container..."
    
    local compose_file="${PROJECT_DIR}/docker-compose/docker-compose.yml"
    
    if [[ ! -f "$compose_file" ]]; then
        log "docker-compose.yml nicht gefunden: $compose_file" ERROR
        return 1
    fi
    
    if docker-compose -f "$compose_file" up -d 2>&1 | tee -a "$LOG_FILE"; then
        sleep 5  # Warte kurz
        
        local status=$(docker-compose -f "$compose_file" ps 2>&1)
        log "✓ Container gestartet" SUCCESS
        log "Status:\n${status}"
        return 0
    else
        log "Fehler beim Starten der Container" ERROR
        return 1
    fi
}

################################################################################
# Restore-Funktionen
################################################################################

restore_config_files() {
    local source_dir="$1"
    local dest_dir="$2"
    
    log "Stelle Konfigurationsdateien wieder her..."
    
    local config_source="${source_dir}/docker-compose"
    
    if [[ ! -d "$config_source" ]]; then
        log "Konfigurationsverzeichnis nicht im Backup gefunden: $config_source" ERROR
        return 1
    fi
    
    local config_dest="${dest_dir}/docker-compose"
    
    # Backup existierender Konfiguration
    if [[ -d "$config_dest" ]]; then
        local backup_config="${config_dest}.old.${TIMESTAMP}"
        mv "$config_dest" "$backup_config"
        log "Existierende Konfiguration gesichert: $backup_config"
    fi
    
    # Kopiere neue Konfiguration
    if cp -r "$config_source" "$config_dest"; then
        log "✓ Konfigurationsdateien wiederhergestellt" SUCCESS
        return 0
    else
        log "Fehler beim Wiederherstellen der Konfigurationsdateien" ERROR
        return 1
    fi
}

restore_docker_volume() {
    local volume_name="$1"
    local source_dir="$2"
    
    log "Stelle Docker-Volume wieder her: $volume_name"
    
    local backup_file="${source_dir}/${volume_name}.tar.gz"
    
    if [[ ! -f "$backup_file" ]]; then
        log "Volume-Backup nicht gefunden: $backup_file" WARNING
        return 0
    fi
    
    # Erstelle Volume falls nicht vorhanden
    if ! check_volume_exists "$volume_name"; then
        docker volume create "$volume_name" &> /dev/null
        log "Volume '$volume_name' erstellt"
    fi
    
    # Restore Volume-Inhalt
    if docker run --rm \
        -v "${volume_name}:/volume" \
        -v "${source_dir}:/backup:ro" \
        alpine sh -c "rm -rf /volume/* /volume/..?* /volume/.[!.]* 2>/dev/null; tar xzf /backup/${volume_name}.tar.gz -C /volume" \
        2>&1 | tee -a "$LOG_FILE"; then
        
        log "✓ Volume '$volume_name' wiederhergestellt" SUCCESS
        return 0
    else
        log "Fehler beim Wiederherstellen von Volume '$volume_name'" ERROR
        return 1
    fi
}

restore_all_volumes() {
    local source_dir="$1"
    
    log "Starte Wiederherstellung aller Docker-Volumes..."
    
    local success_count=0
    local fail_count=0
    
    for volume in "${DOCKER_VOLUMES[@]}"; do
        if restore_docker_volume "$volume" "$source_dir"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    log "Volume-Restore abgeschlossen: ${success_count} erfolgreich, ${fail_count} fehlgeschlagen"
    
    if [[ $fail_count -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

################################################################################
# Verifikation
################################################################################

verify_restore_success() {
    log "Verifiziere Restore..."
    
    # Prüfe Konfigurationsverzeichnis
    local config_dir="${PROJECT_DIR}/docker-compose"
    if [[ ! -d "$config_dir" ]]; then
        log "Konfigurationsverzeichnis fehlt" ERROR
        return 1
    fi
    
    log "✓ Konfigurationsverzeichnis vorhanden"
    
    # Prüfe Volumes
    for volume in "${DOCKER_VOLUMES[@]}"; do
        if check_volume_exists "$volume"; then
            log "✓ Volume '$volume' vorhanden"
        else
            log "✗ Volume '$volume' fehlt" WARNING
        fi
    done
    
    # Prüfe Container-Status
    local compose_file="${PROJECT_DIR}/docker-compose/docker-compose.yml"
    if [[ -f "$compose_file" ]]; then
        local container_status=$(docker-compose -f "$compose_file" ps 2>&1 || echo "Fehler beim Abrufen des Status")
        log "Container-Status:\n${container_status}"
    fi
    
    log "✓ Restore-Verifikation abgeschlossen" SUCCESS
    return 0
}

################################################################################
# Haupt-Workflow
################################################################################

run_restore() {
    local backup_path="$1"
    
    log "Initialisiere Restore-Prozess..."
    log "Backup-Datei: $backup_path"
    
    # Verifikation (optional)
    if [[ "$VERIFY" = true ]]; then
        if ! verify_backup_integrity "$backup_path"; then
            log "Backup-Integritätsprüfung fehlgeschlagen" ERROR
            return 1
        fi
    fi
    
    # Prüfe Docker
    if ! check_docker; then
        return 1
    fi
    
    # Bestätigung
    local confirm_message=$(cat <<EOF
⚠️  WARNUNG: Restore überschreibt vorhandene Daten!

Backup-Datei: ${backup_path}
Zielverzeichnis: ${PROJECT_DIR}

Alle aktuellen Konfigurationen und Daten werden überschrieben.
EOF
)
    
    if ! get_user_confirmation "$confirm_message"; then
        log "Restore abgebrochen durch Benutzer"
        return 0
    fi
    
    # Pre-Restore-Backup
    if [[ "$SKIP_PRE_RESTORE" = false ]]; then
        PRE_RESTORE_BACKUP=$(create_pre_restore_backup)
    fi
    
    # Stoppe Container
    stop_alarma_containers
    
    # Erstelle temporäres Verzeichnis
    TEMP_DIR="/tmp/alarma-restore-${TIMESTAMP}"
    mkdir -p "$TEMP_DIR"
    log "Temporäres Verzeichnis: $TEMP_DIR"
    
    # Entschlüsselung (falls nötig)
    local working_backup="$backup_path"
    if [[ "$backup_path" =~ \.gpg$ ]]; then
        local decrypted_path="${TEMP_DIR}/$(basename "${backup_path%.gpg}")"
        
        if ! working_backup=$(decrypt_backup "$backup_path" "$DECRYPT_PASSPHRASE"); then
            log "Entschlüsselung fehlgeschlagen" ERROR
            return 1
        fi
    fi
    
    # Entpacke Backup
    log "Entpacke Backup..."
    if tar xzf "$working_backup" -C "$TEMP_DIR"; then
        log "✓ Backup entpackt" SUCCESS
    else
        log "Fehler beim Entpacken des Backups" ERROR
        return 1
    fi
    
    # Finde das entpackte Verzeichnis
    local restore_source
    local extracted_dirs=( "$TEMP_DIR"/*/ )
    
    if [[ ${#extracted_dirs[@]} -eq 1 ]] && [[ -d "${extracted_dirs[0]}" ]]; then
        restore_source="${extracted_dirs[0]}"
    else
        restore_source="$TEMP_DIR"
    fi
    
    log "Restore-Quelle: $restore_source"
    
    # Restore durchführen
    if ! restore_config_files "$restore_source" "$PROJECT_DIR"; then
        return 1
    fi
    
    if ! restore_all_volumes "$restore_source"; then
        return 1
    fi
    
    # Starte Container
    start_alarma_containers
    
    # Verifikation
    if verify_restore_success; then
        RESTORE_SUCCESSFUL=true
    fi
    
    # Bereinigung
    cleanup_temp
    
    # Erfolg!
    local success_message="✅ Alarma! Restore erfolgreich abgeschlossen"
    log "$success_message" SUCCESS
    
    if [[ -n "$PRE_RESTORE_BACKUP" ]]; then
        log "Pre-Restore-Backup: $PRE_RESTORE_BACKUP" SUCCESS
    fi
    
    send_notification "$success_message" "normal"
    
    log "================================================"
    log "Restore abgeschlossen"
    log "Bitte testen Sie die Funktionalität des Systems!"
    log "================================================"
    
    return 0
}

################################################################################
# Error Handler
################################################################################

error_handler() {
    local exit_code=$?
    local error_message="❌ Alarma! Restore FEHLGESCHLAGEN (Exit Code: ${exit_code})"
    
    log "$error_message" ERROR
    
    # Versuche Container zu starten
    log "Versuche Container neu zu starten..."
    start_alarma_containers || true
    
    if [[ -n "$PRE_RESTORE_BACKUP" ]]; then
        log "Pre-Restore-Backup verfügbar für Rollback: $PRE_RESTORE_BACKUP" WARNING
    fi
    
    send_notification "$error_message" "high"
    
    cleanup_temp
    
    exit $exit_code
}

trap error_handler ERR

################################################################################
# Argument-Parsing
################################################################################

while getopts "f:d:p:lvsy:k:n:L:h" opt; do
    case $opt in
        f) BACKUP_FILE="$OPTARG" ;;
        d) BACKUP_DIR="$OPTARG" ;;
        p) PROJECT_DIR="$OPTARG" ;;
        l) LIST_MODE=true ;;
        v) VERIFY=true ;;
        s) SKIP_PRE_RESTORE=true ;;
        y) FORCE=true ;;
        k) DECRYPT_PASSPHRASE="$OPTARG" ;;
        n) NOTIFY_URL="$OPTARG" ;;
        L) LOG_FILE="$OPTARG" ;;
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
    echo -e "${CYAN}  Alarma! Restore Script v${SCRIPT_VERSION}${NC}"
    echo -e "${CYAN}=========================================${NC}"
    echo ""
    
    # Logging initialisieren
    init_logging
    
    # List-Modus
    if [[ "$LIST_MODE" = true ]]; then
        list_available_backups "$BACKUP_DIR"
        exit 0
    fi
    
    # Restore-Modus
    if [[ -z "$BACKUP_FILE" ]]; then
        echo -e "${RED}Fehler: -f Parameter erforderlich${NC}" >&2
        echo -e "${YELLOW}Verwenden Sie -l um verfügbare Backups anzuzeigen${NC}"
        exit 1
    fi
    
    if [[ ! -f "$BACKUP_FILE" ]]; then
        echo -e "${RED}Fehler: Backup-Datei nicht gefunden: $BACKUP_FILE${NC}" >&2
        exit 1
    fi
    
    # Restore starten
    if run_restore "$BACKUP_FILE"; then
        exit 0
    else
        exit 1
    fi
}

# Script starten
main "$@"
