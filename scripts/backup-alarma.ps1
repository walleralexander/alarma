<#
.SYNOPSIS
    Alarma! Backup Script für Windows
    
.DESCRIPTION
    Erstellt vollständige Backups des Alarma!-Systems inklusive:
    - Docker-Compose-Konfigurationsdateien
    - Alle Docker-Volumes (apprise-config, sms-data, whatsapp-data, signal-data, ntfy)
    - Erstellt komprimierte und optional verschlüsselte Archive
    - Bereinigt alte Backups basierend auf Retention-Policy
    - Sendet Benachrichtigungen über Alarma! bei Erfolg/Fehler
    - Umfassendes Logging aller Operationen
    
.PARAMETER BackupDir
    Verzeichnis, in dem Backups gespeichert werden (Standard: C:\Alarma!-Backups)
    
.PARAMETER ProjectDir
    Alarma!-Projektverzeichnis (Standard: aktuelles Verzeichnis)
    
.PARAMETER RetentionDays
    Anzahl Tage, wie lange Backups aufbewahrt werden (Standard: 7)
    
.PARAMETER Encrypt
    Backup mit GPG verschlüsseln (erfordert GPG-Installation)
    
.PARAMETER EncryptionKey
    Pfad zur GPG-Public-Key-Datei oder Email der Key-ID
    
.PARAMETER NotifyUrl
    URL des Alarma!-Notification-Endpunkts für Status-Benachrichtigungen
    
.PARAMETER SkipVolumes
    Docker-Volume-Backup überspringen (nur Konfigurationsdateien sichern)
    
.PARAMETER Compress
    Backup komprimieren (Standard: $true)
    
.PARAMETER LogFile
    Pfad zur Log-Datei (Standard: BackupDir\backup.log)
    
.EXAMPLE
    .\backup-alarma.ps1
    
    Erstellt ein Standard-Backup mit 7 Tagen Retention
    
.EXAMPLE
    .\backup-alarma.ps1 -BackupDir "D:\Backups\Alarma!" -RetentionDays 14
    
    Backup in angegebenem Verzeichnis mit 14 Tagen Retention
    
.EXAMPLE
    .\backup-alarma.ps1 -Encrypt -EncryptionKey "backup@example.com" -NotifyUrl "http://localhost:8080/notify"
    
    Verschlüsseltes Backup mit Benachrichtigung
    
.NOTES
    Autor: Alarma! Project
    Version: 1.0
    Datum: 2026-01-30
    Erfordert: Docker Desktop, PowerShell 5.1+, optional GPG für Verschlüsselung
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$BackupDir = "C:\Alarma!-Backups",
    
    [Parameter(Mandatory=$false)]
    [string]$ProjectDir = (Get-Location).Path,
    
    [Parameter(Mandatory=$false)]
    [int]$RetentionDays = 7,
    
    [Parameter(Mandatory=$false)]
    [switch]$Encrypt,
    
    [Parameter(Mandatory=$false)]
    [string]$EncryptionKey = "",
    
    [Parameter(Mandatory=$false)]
    [string]$NotifyUrl = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipVolumes,
    
    [Parameter(Mandatory=$false)]
    [bool]$Compress = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = ""
)

# Fehlerbehandlung aktivieren
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Konstanten
$SCRIPT_VERSION = "1.0"
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"
$BACKUP_NAME = "alarma-full-$TIMESTAMP"

# Docker-Volumes, die gesichert werden sollen
$DOCKER_VOLUMES = @(
    "apprise-config",
    "sms-data",
    "whatsapp-data",
    "signal-data",
    "ntfy"
)

# Globale Variablen
$script:TempDir = ""
$script:BackupCreated = $false
$script:LogFileHandle = $null

#region Logging-Funktionen

<#
.SYNOPSIS
    Initialisiert das Logging-System
#>
function Initialize-Logging {
    param([string]$LogPath)
    
    if (-not $LogPath) {
        $LogPath = Join-Path $BackupDir "backup.log"
    }
    
    # Stelle sicher, dass das Log-Verzeichnis existiert
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $script:LogFileHandle = $LogPath
    
    Write-Log "================================================"
    Write-Log "Alarma! Backup Script v$SCRIPT_VERSION gestartet"
    Write-Log "Zeitstempel: $TIMESTAMP"
    Write-Log "================================================"
}

<#
.SYNOPSIS
    Schreibt eine Nachricht ins Log und auf die Konsole
#>
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Konsolenausgabe mit Farben
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }
    
    # In Datei schreiben
    if ($script:LogFileHandle) {
        Add-Content -Path $script:LogFileHandle -Value $logMessage
    }
}

#endregion

#region Hilfsfunktionen

<#
.SYNOPSIS
    Prüft, ob Docker läuft
#>
function Test-DockerRunning {
    try {
        $null = docker ps 2>&1
        return $?
    }
    catch {
        return $false
    }
}

<#
.SYNOPSIS
    Prüft, ob ein Docker-Volume existiert
#>
function Test-DockerVolume {
    param([string]$VolumeName)
    
    $volumes = docker volume ls --format "{{.Name}}" 2>&1
    return $volumes -contains $VolumeName
}

<#
.SYNOPSIS
    Sendet eine Benachrichtigung über Alarma!
#>
function Send-Notification {
    param(
        [string]$Message,
        [ValidateSet("low", "normal", "high")]
        [string]$Priority = "normal"
    )
    
    if (-not $NotifyUrl) {
        return
    }
    
    try {
        $body = @{
            message = $Message
            priority = $Priority
        } | ConvertTo-Json
        
        $params = @{
            Uri = $NotifyUrl
            Method = "POST"
            Body = $body
            ContentType = "application/json"
            TimeoutSec = 10
        }
        
        Invoke-RestMethod @params | Out-Null
        Write-Log "Benachrichtigung gesendet: $Message"
    }
    catch {
        Write-Log "Fehler beim Senden der Benachrichtigung: $_" -Level WARNING
    }
}

<#
.SYNOPSIS
    Bereinigt temporäre Dateien
#>
function Clear-TempFiles {
    if ($script:TempDir -and (Test-Path $script:TempDir)) {
        Write-Log "Bereinige temporäre Dateien..."
        try {
            Remove-Item -Path $script:TempDir -Recurse -Force
            Write-Log "Temporäre Dateien gelöscht"
        }
        catch {
            Write-Log "Fehler beim Löschen temporärer Dateien: $_" -Level WARNING
        }
    }
}

<#
.SYNOPSIS
    Bereinigt alte Backups basierend auf Retention-Policy
#>
function Remove-OldBackups {
    param([string]$BackupDirectory, [int]$Days)
    
    Write-Log "Bereinige Backups älter als $Days Tage..."
    
    $cutoffDate = (Get-Date).AddDays(-$Days)
    $pattern = "alarma-full-*.zip"
    
    if ($Encrypt) {
        $pattern = "alarma-full-*.zip.gpg"
    }
    
    $oldBackups = Get-ChildItem -Path $BackupDirectory -Filter $pattern | 
                  Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    if ($oldBackups) {
        foreach ($backup in $oldBackups) {
            try {
                Remove-Item -Path $backup.FullName -Force
                Write-Log "Gelöscht: $($backup.Name)" -Level SUCCESS
            }
            catch {
                Write-Log "Fehler beim Löschen von $($backup.Name): $_" -Level WARNING
            }
        }
        Write-Log "Alte Backups bereinigt: $($oldBackups.Count) Dateien gelöscht"
    }
    else {
        Write-Log "Keine alten Backups zum Löschen gefunden"
    }
}

#endregion

#region Backup-Funktionen

<#
.SYNOPSIS
    Sichert Konfigurationsdateien
#>
function Backup-ConfigFiles {
    param([string]$DestinationDir)
    
    Write-Log "Sichere Konfigurationsdateien..."
    
    $configSource = Join-Path $ProjectDir "docker-compose"
    
    if (-not (Test-Path $configSource)) {
        throw "Docker-Compose-Verzeichnis nicht gefunden: $configSource"
    }
    
    $configDest = Join-Path $DestinationDir "docker-compose"
    
    try {
        Copy-Item -Path $configSource -Destination $configDest -Recurse -Force
        
        # Prüfe, ob .env-Datei existiert (wichtig!)
        $envFile = Join-Path $configDest ".env"
        if (Test-Path $envFile) {
            Write-Log "✓ .env-Datei gesichert (enthält Secrets!)" -Level SUCCESS
        }
        else {
            Write-Log ".env-Datei nicht gefunden - möglicherweise keine Secrets vorhanden" -Level WARNING
        }
        
        Write-Log "Konfigurationsdateien erfolgreich gesichert" -Level SUCCESS
    }
    catch {
        throw "Fehler beim Sichern der Konfigurationsdateien: $_"
    }
}

<#
.SYNOPSIS
    Sichert ein Docker-Volume
#>
function Backup-DockerVolume {
    param(
        [string]$VolumeName,
        [string]$DestinationDir
    )
    
    Write-Log "Sichere Docker-Volume: $VolumeName"
    
    # Prüfe, ob Volume existiert
    if (-not (Test-DockerVolume -VolumeName $VolumeName)) {
        Write-Log "Volume '$VolumeName' existiert nicht - überspringe" -Level WARNING
        return
    }
    
    $backupFile = Join-Path $DestinationDir "$VolumeName.tar.gz"
    
    try {
        # Verwende Alpine-Container zum Erstellen des Volume-Backups
        $dockerCmd = "docker run --rm " +
                    "-v ${VolumeName}:/volume:ro " +
                    "-v `"${DestinationDir}:/backup`" " +
                    "alpine tar czf /backup/$VolumeName.tar.gz -C /volume ."
        
        Write-Log "Führe aus: $dockerCmd"
        
        $output = Invoke-Expression $dockerCmd 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Docker-Befehl fehlgeschlagen: $output"
        }
        
        # Prüfe, ob Backup-Datei erstellt wurde
        if (Test-Path $backupFile) {
            $size = (Get-Item $backupFile).Length / 1MB
            Write-Log "✓ Volume '$VolumeName' gesichert (${size:N2} MB)" -Level SUCCESS
        }
        else {
            throw "Backup-Datei wurde nicht erstellt: $backupFile"
        }
    }
    catch {
        throw "Fehler beim Sichern von Volume '$VolumeName': $_"
    }
}

<#
.SYNOPSIS
    Sichert alle Docker-Volumes
#>
function Backup-AllVolumes {
    param([string]$DestinationDir)
    
    Write-Log "Starte Backup aller Docker-Volumes..."
    
    $successCount = 0
    $failCount = 0
    
    foreach ($volume in $DOCKER_VOLUMES) {
        try {
            Backup-DockerVolume -VolumeName $volume -DestinationDir $DestinationDir
            $successCount++
        }
        catch {
            Write-Log "Fehler bei Volume '$volume': $_" -Level ERROR
            $failCount++
        }
    }
    
    Write-Log "Volume-Backup abgeschlossen: $successCount erfolgreich, $failCount fehlgeschlagen"
    
    if ($failCount -gt 0) {
        throw "Einige Volume-Backups sind fehlgeschlagen"
    }
}

<#
.SYNOPSIS
    Erstellt ein komprimiertes Archiv
#>
function Create-Archive {
    param(
        [string]$SourceDir,
        [string]$DestinationFile
    )
    
    Write-Log "Erstelle komprimiertes Archiv..."
    
    try {
        # Verwende Compress-Archive für ZIP
        Compress-Archive -Path "$SourceDir\*" -DestinationPath $DestinationFile -CompressionLevel Optimal -Force
        
        $size = (Get-Item $DestinationFile).Length / 1MB
        Write-Log "✓ Archiv erstellt: $DestinationFile (${size:N2} MB)" -Level SUCCESS
    }
    catch {
        throw "Fehler beim Erstellen des Archivs: $_"
    }
}

<#
.SYNOPSIS
    Verschlüsselt das Backup mit GPG
#>
function Encrypt-Backup {
    param(
        [string]$BackupFile,
        [string]$KeyId
    )
    
    Write-Log "Verschlüssele Backup mit GPG..."
    
    # Prüfe, ob GPG verfügbar ist
    try {
        $null = gpg --version 2>&1
    }
    catch {
        throw "GPG ist nicht installiert. Bitte installieren Sie GPG4Win von https://www.gpg4win.org/"
    }
    
    try {
        $outputFile = "$BackupFile.gpg"
        
        if ($KeyId) {
            # Verschlüsseln mit Public Key
            $gpgCmd = "gpg --encrypt --recipient `"$KeyId`" --output `"$outputFile`" `"$BackupFile`""
        }
        else {
            # Symmetrische Verschlüsselung (Passphrase erforderlich)
            $gpgCmd = "gpg --symmetric --cipher-algo AES256 --output `"$outputFile`" `"$BackupFile`""
        }
        
        Write-Log "Führe aus: $gpgCmd"
        Invoke-Expression $gpgCmd
        
        if ($LASTEXITCODE -ne 0) {
            throw "GPG-Verschlüsselung fehlgeschlagen"
        }
        
        # Lösche unverschlüsseltes Backup
        Remove-Item -Path $BackupFile -Force
        
        $size = (Get-Item $outputFile).Length / 1MB
        Write-Log "✓ Backup verschlüsselt (${size:N2} MB)" -Level SUCCESS
        
        return $outputFile
    }
    catch {
        throw "Fehler bei der Verschlüsselung: $_"
    }
}

<#
.SYNOPSIS
    Erstellt Backup-Metadaten
#>
function Create-BackupMetadata {
    param(
        [string]$DestinationDir,
        [string]$BackupFilePath
    )
    
    Write-Log "Erstelle Backup-Metadaten..."
    
    $metadata = @{
        timestamp = $TIMESTAMP
        date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        version = $SCRIPT_VERSION
        hostname = $env:COMPUTERNAME
        user = $env:USERNAME
        backup_file = Split-Path $BackupFilePath -Leaf
        backup_size_mb = [math]::Round((Get-Item $BackupFilePath).Length / 1MB, 2)
        project_dir = $ProjectDir
        volumes_backed_up = $DOCKER_VOLUMES
        encrypted = $Encrypt.IsPresent
        compression = $Compress
    }
    
    $metadataFile = Join-Path $DestinationDir "backup-metadata.json"
    $metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataFile
    
    Write-Log "Metadaten gespeichert: $metadataFile"
}

#endregion

#region Haupt-Workflow

<#
.SYNOPSIS
    Hauptfunktion für den Backup-Prozess
#>
function Start-BackupProcess {
    try {
        # Initialisierung
        Write-Log "Initialisiere Backup-Prozess..."
        
        # Erstelle Backup-Verzeichnis
        if (-not (Test-Path $BackupDir)) {
            New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
            Write-Log "Backup-Verzeichnis erstellt: $BackupDir"
        }
        
        # Prüfe Docker
        if (-not (Test-DockerRunning)) {
            throw "Docker läuft nicht oder ist nicht verfügbar"
        }
        Write-Log "Docker ist verfügbar"
        
        # Erstelle temporäres Verzeichnis
        $script:TempDir = Join-Path $BackupDir $BACKUP_NAME
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        Write-Log "Temporäres Verzeichnis: $script:TempDir"
        
        # Backup-Schritte
        Backup-ConfigFiles -DestinationDir $script:TempDir
        
        if (-not $SkipVolumes) {
            Backup-AllVolumes -DestinationDir $script:TempDir
        }
        else {
            Write-Log "Volume-Backup übersprungen (SkipVolumes aktiv)" -Level WARNING
        }
        
        # Erstelle Archiv
        $archiveFile = Join-Path $BackupDir "$BACKUP_NAME.zip"
        
        if ($Compress) {
            Create-Archive -SourceDir $script:TempDir -DestinationFile $archiveFile
        }
        else {
            # Ohne Komprimierung einfach umbenennen
            Move-Item -Path $script:TempDir -Destination $archiveFile -Force
        }
        
        # Erstelle Metadaten im Archiv
        Create-BackupMetadata -DestinationDir $script:TempDir -BackupFilePath $archiveFile
        
        # Verschlüsselung (optional)
        $finalBackupFile = $archiveFile
        if ($Encrypt) {
            $finalBackupFile = Encrypt-Backup -BackupFile $archiveFile -KeyId $EncryptionKey
        }
        
        $script:BackupCreated = $true
        
        # Bereinigung
        Clear-TempFiles
        Remove-OldBackups -BackupDirectory $BackupDir -Days $RetentionDays
        
        # Erfolg!
        $backupSize = (Get-Item $finalBackupFile).Length / 1MB
        $successMessage = "✅ Alarma! Backup erfolgreich erstellt: $BACKUP_NAME (${backupSize:N2} MB)"
        Write-Log $successMessage -Level SUCCESS
        
        Send-Notification -Message $successMessage -Priority "low"
        
        Write-Log "================================================"
        Write-Log "Backup abgeschlossen"
        Write-Log "Datei: $finalBackupFile"
        Write-Log "Größe: ${backupSize:N2} MB"
        Write-Log "================================================"
        
        return 0
    }
    catch {
        $errorMessage = "❌ Alarma! Backup FEHLGESCHLAGEN: $_"
        Write-Log $errorMessage -Level ERROR
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
        
        Send-Notification -Message $errorMessage -Priority "high"
        
        Clear-TempFiles
        
        return 1
    }
}

#endregion

#region Script-Ausführung

try {
    # Banner
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  Alarma! Backup Script v$SCRIPT_VERSION" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Logging initialisieren
    if (-not $LogFile) {
        $LogFile = Join-Path $BackupDir "backup.log"
    }
    Initialize-Logging -LogPath $LogFile
    
    # Parameter ausgeben
    Write-Log "Backup-Verzeichnis: $BackupDir"
    Write-Log "Projekt-Verzeichnis: $ProjectDir"
    Write-Log "Retention: $RetentionDays Tage"
    Write-Log "Verschlüsselung: $($Encrypt.IsPresent)"
    Write-Log "Volumes überspringen: $($SkipVolumes.IsPresent)"
    Write-Log "Benachrichtigungs-URL: $(if($NotifyUrl){$NotifyUrl}else{'Nicht konfiguriert'})"
    
    # Backup starten
    $exitCode = Start-BackupProcess
    
    exit $exitCode
}
catch {
    Write-Host "Kritischer Fehler: $_" -ForegroundColor Red
    exit 1
}
finally {
    # Cleanup
    if ($script:TempDir -and (Test-Path $script:TempDir)) {
        Clear-TempFiles
    }
}

#endregion
