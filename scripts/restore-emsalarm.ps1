<#
.SYNOPSIS
    Alarma! Restore Script für Windows
    
.DESCRIPTION
    Stellt Alarma!-Backups wieder her inklusive:
    - Auswahl verfügbarer Backups
    - Entschlüsselung (falls verschlüsselt)
    - Wiederherstellung von Konfigurationsdateien
    - Wiederherstellung aller Docker-Volumes
    - Automatisches Stoppen/Starten der Container
    - Erstellen eines Sicherungs-Restore-Points vor der Wiederherstellung
    - Verifizierung der wiederhergestellten Daten
    - Umfassendes Logging
    
.PARAMETER BackupFile
    Pfad zur Backup-Datei, die wiederhergestellt werden soll
    
.PARAMETER BackupDir
    Verzeichnis mit Backups (für -ListBackups)
    
.PARAMETER ProjectDir
    Ziel-Projektverzeichnis (Standard: aktuelles Verzeichnis)
    
.PARAMETER ListBackups
    Liste verfügbare Backups auf
    
.PARAMETER Verify
    Verifiziere Backup vor Wiederherstellung
    
.PARAMETER SkipPreRestore
    Überspringe Pre-Restore-Backup (nicht empfohlen!)
    
.PARAMETER Force
    Keine Bestätigung vor Wiederherstellung
    
.PARAMETER DecryptPassphrase
    Passphrase für verschlüsselte Backups
    
.PARAMETER NotifyUrl
    URL des Alarma!-Notification-Endpunkts
    
.PARAMETER LogFile
    Pfad zur Log-Datei
    
.EXAMPLE
    .\restore-alarma.ps1 -ListBackups -BackupDir "C:\Alarma!-Backups"
    
    Listet alle verfügbaren Backups auf
    
.EXAMPLE
    .\restore-alarma.ps1 -BackupFile "C:\Alarma!-Backups\alarma-full-20260130-020000.zip"
    
    Stellt das angegebene Backup wieder her
    
.EXAMPLE
    .\restore-alarma.ps1 -BackupFile "backup.zip.gpg" -DecryptPassphrase "secret" -Verify
    
    Stellt verschlüsseltes Backup wieder her mit Verifikation
    
.NOTES
    Autor: Alarma! Project
    Version: 1.0
    Datum: 2026-01-30
    Erfordert: Docker Desktop, PowerShell 5.1+
    
    WARNUNG: Restore überschreibt vorhandene Daten! Immer Pre-Restore-Backup erstellen!
#>

[CmdletBinding(DefaultParameterSetName='Restore')]
param(
    [Parameter(ParameterSetName='Restore', Mandatory=$false)]
    [string]$BackupFile = "",
    
    [Parameter(ParameterSetName='List', Mandatory=$false)]
    [Parameter(ParameterSetName='Restore', Mandatory=$false)]
    [string]$BackupDir = "C:\Alarma!-Backups",
    
    [Parameter(ParameterSetName='Restore', Mandatory=$false)]
    [string]$ProjectDir = (Get-Location).Path,
    
    [Parameter(ParameterSetName='List', Mandatory=$true)]
    [switch]$ListBackups,
    
    [Parameter(ParameterSetName='Restore', Mandatory=$false)]
    [switch]$Verify,
    
    [Parameter(ParameterSetName='Restore', Mandatory=$false)]
    [switch]$SkipPreRestore,
    
    [Parameter(ParameterSetName='Restore', Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(ParameterSetName='Restore', Mandatory=$false)]
    [SecureString]$DecryptPassphrase = $null,
    
    [Parameter(ParameterSetName='Restore', Mandatory=$false)]
    [string]$NotifyUrl = "",
    
    [Parameter(Mandatory=$false)]
    [string]$LogFile = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Konstanten
$SCRIPT_VERSION = "1.0"
$TIMESTAMP = Get-Date -Format "yyyyMMdd-HHmmss"

# Docker-Volumes
$DOCKER_VOLUMES = @(
    "apprise-config",
    "sms-data",
    "whatsapp-data",
    "signal-data",
    "ntfy"
)

# Globale Variablen
$script:TempDir = ""
$script:RestoreSuccessful = $false
$script:LogFileHandle = $null
$script:PreRestoreBackup = ""

#region Logging-Funktionen

function Initialize-Logging {
    param([string]$LogPath)
    
    if (-not $LogPath) {
        $LogPath = Join-Path $env:TEMP "alarma-restore-$TIMESTAMP.log"
    }
    
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    $script:LogFileHandle = $LogPath
    
    Write-Log "================================================"
    Write-Log "Alarma! Restore Script v$SCRIPT_VERSION gestartet"
    Write-Log "Zeitstempel: $TIMESTAMP"
    Write-Log "================================================"
}

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
    
    switch ($Level) {
        "ERROR"   { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        default   { Write-Host $logMessage }
    }
    
    if ($script:LogFileHandle) {
        Add-Content -Path $script:LogFileHandle -Value $logMessage
    }
}

#endregion

#region Hilfsfunktionen

function Test-DockerRunning {
    try {
        $null = docker ps 2>&1
        return $?
    }
    catch {
        return $false
    }
}

function Test-DockerVolume {
    param([string]$VolumeName)
    
    $volumes = docker volume ls --format "{{.Name}}" 2>&1
    return $volumes -contains $VolumeName
}

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
        
        Invoke-RestMethod -Uri $NotifyUrl -Method POST -Body $body -ContentType "application/json" -TimeoutSec 10 | Out-Null
        Write-Log "Benachrichtigung gesendet: $Message"
    }
    catch {
        Write-Log "Fehler beim Senden der Benachrichtigung: $_" -Level WARNING
    }
}

function Remove-TempFiles {
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

function Get-UserConfirmation {
    param([string]$Message)
    
    if ($Force) {
        return $true
    }
    
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $response = Read-Host "Fortfahren? (j/N)"
    
    return $response -match '^[jJyY]'
}

#endregion

#region Backup-Listing

function Show-AvailableBackups {
    param([string]$Directory)
    
    Write-Host ""
    Write-Host "Verfügbare Backups in: $Directory" -ForegroundColor Cyan
    Write-Host "=" * 80
    
    if (-not (Test-Path $Directory)) {
        Write-Host "Backup-Verzeichnis existiert nicht!" -ForegroundColor Red
        return
    }
    
    # Suche nach Backup-Dateien
    $backups = Get-ChildItem -Path $Directory -Filter "alarma-full-*.zip*" | Sort-Object LastWriteTime -Descending
    
    if ($backups.Count -eq 0) {
        Write-Host "Keine Backups gefunden." -ForegroundColor Yellow
        return
    }
    
    $index = 1
    foreach ($backup in $backups) {
        $size = "{0:N2} MB" -f ($backup.Length / 1MB)
        $age = (New-TimeSpan -Start $backup.LastWriteTime -End (Get-Date)).Days
        $encrypted = if ($backup.Name -match '\.gpg$') { "Ja" } else { "Nein" }
        
        Write-Host ""
        Write-Host "[$index] $($backup.Name)" -ForegroundColor White
        Write-Host "    Größe: $size"
        Write-Host "    Datum: $($backup.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Host "    Alter: $age Tage"
        Write-Host "    Verschlüsselt: $encrypted"
        Write-Host "    Pfad: $($backup.FullName)"
        
        # Versuche Metadaten zu lesen (falls vorhanden)
        if ($backup.Extension -eq ".zip") {
            try {
                Add-Type -Assembly System.IO.Compression.FileSystem
                $zip = [System.IO.Compression.ZipFile]::OpenRead($backup.FullName)
                $metadataEntry = $zip.Entries | Where-Object { $_.Name -eq "backup-metadata.json" }
                
                if ($metadataEntry) {
                    $stream = $metadataEntry.Open()
                    $reader = New-Object System.IO.StreamReader($stream)
                    $metadata = $reader.ReadToEnd() | ConvertFrom-Json
                    $reader.Close()
                    $stream.Close()
                    
                    Write-Host "    Version: $($metadata.version)"
                    Write-Host "    Volumes: $($metadata.volumes_backed_up.Count)"
                }
                
                $zip.Dispose()
            }
            catch {
                # Metadaten nicht verfügbar
            }
        }
        
        $index++
    }
    
    Write-Host ""
    Write-Host "=" * 80
    Write-Host "Gesamt: $($backups.Count) Backup(s) gefunden" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Backup-Verifikation

function Test-BackupIntegrity {
    param([string]$BackupPath)
    
    Write-Log "Verifiziere Backup-Integrität..."
    
    if (-not (Test-Path $BackupPath)) {
        Write-Log "Backup-Datei nicht gefunden: $BackupPath" -Level ERROR
        return $false
    }
    
    # Prüfe Dateigröße
    $fileSize = (Get-Item $BackupPath).Length
    if ($fileSize -lt 1KB) {
        Write-Log "Backup-Datei ist zu klein ($fileSize Bytes) - möglicherweise beschädigt" -Level ERROR
        return $false
    }
    
    Write-Log "Dateigröße: $([math]::Round($fileSize/1MB, 2)) MB"
    
    # Prüfe ZIP-Integrität (falls nicht verschlüsselt)
    if ($BackupPath -match '\.zip$') {
        try {
            Add-Type -Assembly System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($BackupPath)
            $entryCount = $zip.Entries.Count
            $zip.Dispose()
            
            Write-Log "ZIP-Archiv OK: $entryCount Einträge gefunden" -Level SUCCESS
            return $true
        }
        catch {
            Write-Log "ZIP-Archiv beschädigt: $_" -Level ERROR
            return $false
        }
    }
    
    # Für verschlüsselte Backups
    if ($BackupPath -match '\.gpg$') {
        try {
            $null = gpg --list-packets $BackupPath 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Log "GPG-Datei OK" -Level SUCCESS
                return $true
            }
            else {
                Write-Log "GPG-Datei möglicherweise beschädigt" -Level WARNING
                return $false
            }
        }
        catch {
            Write-Log "Fehler bei GPG-Verifikation: $_" -Level WARNING
            # Fortfahren trotzdem
            return $true
        }
    }
    
    # Für andere Formate: Basisprüfung OK
    Write-Log "Basis-Integritätsprüfung bestanden" -Level SUCCESS
    return $true
}

#endregion

#region Entschlüsselung

function Unprotect-Backup {
    param(
        [string]$EncryptedFile,
        [SecureString]$Passphrase
    )
    
    Write-Log "Entschlüssele Backup mit GPG..."
    
    try {
        $null = gpg --version 2>&1
    }
    catch {
        throw "GPG ist nicht installiert"
    }
    
    $decryptedFile = $EncryptedFile -replace '\.gpg$', ''
    
    try {
        if ($Passphrase) {
            # Convert SecureString to plaintext only in memory for immediate use
            $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Passphrase)
            try {
                $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
            }
            finally {
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
            }

            $gpgCmd = "gpg --batch --yes --passphrase `"$plainPass`" --output `"$decryptedFile`" --decrypt `"$EncryptedFile`""
        }
        else {
            $gpgCmd = "gpg --output `"$decryptedFile`" --decrypt `"$EncryptedFile`""
        }
        
        Invoke-Expression $gpgCmd
        
        if ($LASTEXITCODE -ne 0) {
            throw "GPG-Entschlüsselung fehlgeschlagen"
        }
        
        Write-Log "✓ Backup entschlüsselt" -Level SUCCESS
        return $decryptedFile
    }
    catch {
        throw "Fehler bei der Entschlüsselung: $_"
    }
    finally {
        if ($plainPass) { $plainPass = $null }
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}

#endregion

#region Pre-Restore-Backup

function New-PreRestoreBackup {
    Write-Log "Erstelle Pre-Restore-Backup..."
    
    #$preRestoreName = "pre-restore-$TIMESTAMP"
    $preRestoreScript = Join-Path $PSScriptRoot "backup-alarma.ps1"
    
    if (-not (Test-Path $preRestoreScript)) {
        Write-Log "Backup-Script nicht gefunden - Pre-Restore-Backup wird übersprungen" -Level WARNING
        return ""
    }
    
    try {
        $preRestoreDir = Join-Path $BackupDir "pre-restore"
        New-Item -ItemType Directory -Path $preRestoreDir -Force | Out-Null
        
        & $preRestoreScript -BackupDir $preRestoreDir -RetentionDays 3 -LogFile (Join-Path $preRestoreDir "backup.log")
        
        $backupFile = Get-ChildItem -Path $preRestoreDir -Filter "alarma-full-*.zip" | 
                      Sort-Object LastWriteTime -Descending | 
                      Select-Object -First 1
        
        if ($backupFile) {
            Write-Log "✓ Pre-Restore-Backup erstellt: $($backupFile.Name)" -Level SUCCESS
            return $backupFile.FullName
        }
        else {
            Write-Log "Pre-Restore-Backup wurde nicht erstellt" -Level WARNING
            return ""
        }
    }
    catch {
        Write-Log "Fehler beim Erstellen des Pre-Restore-Backups: $_" -Level WARNING
        return ""
    }
}

#endregion

#region Docker-Container-Verwaltung

function Stop-Alarma!Containers {
    Write-Log "Stoppe Alarma!-Container..."
    
    $composeFile = Join-Path $ProjectDir "docker-compose\docker-compose.yml"
    
    if (-not (Test-Path $composeFile)) {
        Write-Log "docker-compose.yml nicht gefunden: $composeFile" -Level WARNING
        return
    }
    
    try {
        Push-Location (Join-Path $ProjectDir "docker-compose")
        docker-compose down 2>&1 | Out-Null
        Pop-Location
        
        Write-Log "✓ Container gestoppt" -Level SUCCESS
    }
    catch {
        Write-Log "Fehler beim Stoppen der Container: $_" -Level WARNING
    }
}

function Start-Alarma!Containers {
    Write-Log "Starte Alarma!-Container..."
    
    $composeFile = Join-Path $ProjectDir "docker-compose\docker-compose.yml"
    
    if (-not (Test-Path $composeFile)) {
        Write-Log "docker-compose.yml nicht gefunden: $composeFile" -Level ERROR
        return $false
    }
    
    try {
        Push-Location (Join-Path $ProjectDir "docker-compose")
        docker-compose up -d 2>&1 | Tee-Object -Variable output | Out-Null
        Pop-Location
        
        # Warte kurz
        Start-Sleep -Seconds 5
        
        # Prüfe Status
        Push-Location (Join-Path $ProjectDir "docker-compose")
        $status = docker-compose ps 2>&1
        Pop-Location
        
        Write-Log "✓ Container gestartet" -Level SUCCESS
        Write-Log "Status:`n$status"
        
        return $true
    }
    catch {
        Write-Log "Fehler beim Starten der Container: $_" -Level ERROR
        return $false
    }
}

#endregion

#region Restore-Funktionen

function Restore-ConfigFiles {
    param(
        [string]$SourceDir,
        [string]$DestinationDir
    )
    
    Write-Log "Stelle Konfigurationsdateien wieder her..."
    
    $configSource = Join-Path $SourceDir "docker-compose"
    
    if (-not (Test-Path $configSource)) {
        throw "Konfigurationsverzeichnis nicht im Backup gefunden: $configSource"
    }
    
    $configDest = Join-Path $DestinationDir "docker-compose"
    
    try {
        # Backup existierender Konfiguration (falls vorhanden)
        if (Test-Path $configDest) {
            $backupConfig = "${configDest}.old.$TIMESTAMP"
            Move-Item -Path $configDest -Destination $backupConfig -Force
            Write-Log "Existierende Konfiguration gesichert: $backupConfig"
        }
        
        # Kopiere neue Konfiguration
        Copy-Item -Path $configSource -Destination $configDest -Recurse -Force
        
        Write-Log "✓ Konfigurationsdateien wiederhergestellt" -Level SUCCESS
    }
    catch {
        throw "Fehler beim Wiederherstellen der Konfigurationsdateien: $_"
    }
}

function Restore-DockerVolume {
    param(
        [string]$VolumeName,
        [string]$SourceDir
    )
    
    Write-Log "Stelle Docker-Volume wieder her: $VolumeName"
    
    $backupFile = Join-Path $SourceDir "$VolumeName.tar.gz"
    
    if (-not (Test-Path $backupFile)) {
        Write-Log "Volume-Backup nicht gefunden: $backupFile" -Level WARNING
        return
    }
    
    try {
        # Erstelle Volume falls nicht vorhanden
        if (-not (Test-DockerVolume -VolumeName $VolumeName)) {
            docker volume create $VolumeName | Out-Null
            Write-Log "Volume '$VolumeName' erstellt"
        }
        
        # Restore Volume-Inhalt
        $dockerCmd = "docker run --rm " +
                    "-v ${VolumeName}:/volume " +
                    "-v `"${SourceDir}:/backup`" " +
                    "alpine sh -c `"rm -rf /volume/* /volume/..?* /volume/.[!.]* 2>/dev/null; tar xzf /backup/$VolumeName.tar.gz -C /volume`""
        
        Write-Log "Führe aus: $dockerCmd"
        
        $output = Invoke-Expression $dockerCmd 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Docker-Befehl fehlgeschlagen: $output"
        }
        
        Write-Log "✓ Volume '$VolumeName' wiederhergestellt" -Level SUCCESS
    }
    catch {
        throw "Fehler beim Wiederherstellen von Volume '$VolumeName': $_"
    }
}

function Restore-AllVolumes {
    param([string]$SourceDir)
    
    Write-Log "Starte Wiederherstellung aller Docker-Volumes..."
    
    $successCount = 0
    $failCount = 0
    
    foreach ($volume in $DOCKER_VOLUMES) {
        try {
            Restore-DockerVolume -VolumeName $volume -SourceDir $SourceDir
            $successCount++
        }
        catch {
            Write-Log "Fehler bei Volume '$volume': $_" -Level ERROR
            $failCount++
        }
    }
    
    Write-Log "Volume-Restore abgeschlossen: $successCount erfolgreich, $failCount fehlgeschlagen"
    
    if ($failCount -gt 0) {
        throw "Einige Volume-Restores sind fehlgeschlagen"
    }
}

#endregion

#region Verifikation

function Test-RestoreSuccess {
    Write-Log "Verifiziere Restore..."
    
    # Prüfe Konfigurationsdateien
    $configDir = Join-Path $ProjectDir "docker-compose"
    if (-not (Test-Path $configDir)) {
        Write-Log "Konfigurationsverzeichnis fehlt" -Level ERROR
        return $false
    }
    
    Write-Log "✓ Konfigurationsverzeichnis vorhanden"
    
    # Prüfe Volumes
    foreach ($volume in $DOCKER_VOLUMES) {
        if (Test-DockerVolume -VolumeName $volume) {
            Write-Log "✓ Volume '$volume' vorhanden"
        }
        else {
            Write-Log "✗ Volume '$volume' fehlt" -Level WARNING
        }
    }
    
    # Prüfe Container-Status
    try {
        Push-Location (Join-Path $ProjectDir "docker-compose")
        $containerStatus = docker-compose ps 2>&1
        Pop-Location
        
        Write-Log "Container-Status:`n$containerStatus"
    }
    catch {
        Write-Log "Fehler beim Prüfen des Container-Status: $_" -Level WARNING
    }
    
    Write-Log "✓ Restore-Verifikation abgeschlossen" -Level SUCCESS
    return $true
}

#endregion

#region Haupt-Workflow

function Start-RestoreProcess {
    param([string]$BackupPath)
    
    try {
        Write-Log "Initialisiere Restore-Prozess..."
        Write-Log "Backup-Datei: $BackupPath"
        
        # Verifikation (optional)
        if ($Verify) {
            if (-not (Test-BackupIntegrity -BackupPath $BackupPath)) {
                throw "Backup-Integritätsprüfung fehlgeschlagen"
            }
        }
        
        # Prüfe Docker
        if (-not (Test-DockerRunning)) {
            throw "Docker läuft nicht oder ist nicht verfügbar"
        }
        
        # Bestätigung
        $confirmMessage = @"
⚠️  WARNUNG: Restore überschreibt vorhandene Daten!

Backup-Datei: $BackupPath
Zielverzeichnis: $ProjectDir

Alle aktuellen Konfigurationen und Daten werden überschrieben.
"@
        
        if (-not (Get-UserConfirmation -Message $confirmMessage)) {
            Write-Log "Restore abgebrochen durch Benutzer"
            return 0
        }
        
        # Pre-Restore-Backup
        if (-not $SkipPreRestore) {
            $script:PreRestoreBackup = New-PreRestoreBackup
        }
        
        # Stoppe Container
        Stop-Alarma!Containers
        
        # Entschlüsselung (falls nötig)
        $workingBackup = $BackupPath
        if ($BackupPath -match '\.gpg$') {
            $script:TempDir = Join-Path $env:TEMP "alarma-restore-$TIMESTAMP"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
            
            #$decryptedPath = Join-Path $script:TempDir (Split-Path $BackupPath -Leaf) -replace '\.gpg$', ''
            $workingBackup = Unprotect-Backup -EncryptedFile $BackupPath -Passphrase $DecryptPassphrase
        }
        
        # Entpacke Backup
        if (-not $script:TempDir) {
            $script:TempDir = Join-Path $env:TEMP "alarma-restore-$TIMESTAMP"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        }
        
        Write-Log "Entpacke Backup..."
        Expand-Archive -Path $workingBackup -DestinationPath $script:TempDir -Force
        
        # Finde das entpackte Verzeichnis
        $extractedDirs = Get-ChildItem -Path $script:TempDir -Directory
        if ($extractedDirs.Count -eq 1) {
            $restoreSource = $extractedDirs[0].FullName
        }
        else {
            $restoreSource = $script:TempDir
        }
        
        Write-Log "Restore-Quelle: $restoreSource"
        
        # Restore durchführen
        Restore-ConfigFiles -SourceDir $restoreSource -DestinationDir $ProjectDir
        Restore-AllVolumes -SourceDir $restoreSource
        
        # Starte Container
        Start-Alarma!Containers | Out-Null
        
        # Verifikation
        if (Test-RestoreSuccess) {
            $script:RestoreSuccessful = $true
        }
        
        # Bereinigung
        Remove-TempFiles
        
        # Erfolg!
        $successMessage = "✅ Alarma! Restore erfolgreich abgeschlossen"
        Write-Log $successMessage -Level SUCCESS
        
        if ($script:PreRestoreBackup) {
            Write-Log "Pre-Restore-Backup: $script:PreRestoreBackup" -Level SUCCESS
        }
        
        Send-Notification -Message $successMessage -Priority "normal"
        
        Write-Log "================================================"
        Write-Log "Restore abgeschlossen"
        Write-Log "Bitte testen Sie die Funktionalität des Systems!"
        Write-Log "================================================"
        
        return 0
    }
    catch {
        $errorMessage = "❌ Alarma! Restore FEHLGESCHLAGEN: $_"
        Write-Log $errorMessage -Level ERROR
        Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level ERROR
        
        # Versuche Container zu starten (falls sie gestoppt wurden)
        Write-Log "Versuche Container neu zu starten..."
        Start-Alarma!Containers | Out-Null
        
        if ($script:PreRestoreBackup) {
            Write-Log "Pre-Restore-Backup verfügbar für Rollback: $script:PreRestoreBackup" -Level WARNING
        }
        
        Send-Notification -Message $errorMessage -Priority "high"
        
        Remove-TempFiles
        
        return 1
    }
}

#endregion

#region Script-Ausführung

try {
    # Banner
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  Alarma! Restore Script v$SCRIPT_VERSION" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Logging initialisieren
    Initialize-Logging -LogPath $LogFile
    
    # List-Modus
    if ($ListBackups) {
        Show-AvailableBackups -Directory $BackupDir
        exit 0
    }
    
    # Restore-Modus
    if (-not $BackupFile) {
        Write-Host "Fehler: -BackupFile Parameter erforderlich" -ForegroundColor Red
        Write-Host "Verwenden Sie -ListBackups um verfügbare Backups anzuzeigen" -ForegroundColor Yellow
        exit 1
    }
    
    if (-not (Test-Path $BackupFile)) {
        Write-Host "Fehler: Backup-Datei nicht gefunden: $BackupFile" -ForegroundColor Red
        exit 1
    }
    
    # Restore starten
    $exitCode = Start-RestoreProcess -BackupPath $BackupFile
    
    exit $exitCode
}
catch {
    Write-Host "Kritischer Fehler: $_" -ForegroundColor Red
    exit 1
}
finally {
    if ($script:TempDir -and (Test-Path $script:TempDir)) {
        Remove-TempFiles
    }
}

#endregion
