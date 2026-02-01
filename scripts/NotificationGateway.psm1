# NotificationGateway PowerShell Module
# Version 1.0 - Stadt Hohenems
# Created: 29.01.2026

<#
.SYNOPSIS
    PowerShell Module für Multi-Channel Notification Gateway
    
.DESCRIPTION
    Dieses Modul ermöglicht das Versenden von Benachrichtigungen über SMS, WhatsApp,
    Microsoft Teams und E-Mail über ein zentrales Apprise API Gateway.
    
.NOTES
    Author: Alexander - Stadt Hohenems IT
    Date: 29.01.2026
    Version: 1.0
#>

# Globale Konfiguration
$Script:NotificationServer = "notification-server"
$Script:NotificationPort = 8000
$Script:NotificationBaseUrl = "http://${Script:NotificationServer}:${Script:NotificationPort}"

<#
.SYNOPSIS
    Setzt die Notification Server Konfiguration
    
.PARAMETER Server
    Hostname oder IP des Notification Servers
    
.PARAMETER Port
    Port des Apprise API (Standard: 8000)
    
.EXAMPLE
    Set-NotificationServer -Server "192.168.1.100" -Port 8000
#>
function Set-NotificationServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Server,
        
        [Parameter(Mandatory=$false)]
        [int]$Port = 8000
    )
    
    $Script:NotificationServer = $Server
    $Script:NotificationPort = $Port
    $Script:NotificationBaseUrl = "http://${Server}:${Port}"
    
    Write-Verbose "Notification Server gesetzt auf: $Script:NotificationBaseUrl"
}

<#
.SYNOPSIS
    Sendet eine Benachrichtigung über das Gateway
    
.PARAMETER Tags
    Komma-separierte Liste von Tags (z.B. "sms,kritisch")
    
.PARAMETER Title
    Titel der Benachrichtigung
    
.PARAMETER Body
    Text der Benachrichtigung
    
.PARAMETER Timeout
    Timeout in Sekunden (Standard: 30)
    
.EXAMPLE
    Send-Notification -Tags "sms,whatsapp" -Title "Server Alert" -Body "CPU hoch"
    
.EXAMPLE
    Send-Notification -Tags "teams" -Title "Info" -Body "Backup abgeschlossen"
#>
function Send-Notification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Tags,
        
        [Parameter(Mandatory=$false)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Body,
        
        [Parameter(Mandatory=$false)]
        [int]$Timeout = 30
    )
    
    try {
        $notification = @{
            urls = "tag=$Tags"
            body = $Body
        }
        
        if ($Title) {
            $notification.title = $Title
        }
        
        $jsonBody = $notification | ConvertTo-Json
        
        Write-Verbose "Sende Notification an: $Script:NotificationBaseUrl/notify"
        Write-Verbose "Tags: $Tags"
        Write-Verbose "Body: $Body"
        
        $response = Invoke-RestMethod `
            -Uri "$Script:NotificationBaseUrl/notify" `
            -Method Post `
            -Body $jsonBody `
            -ContentType "application/json" `
            -TimeoutSec $Timeout `
            -ErrorAction Stop
        
        Write-Verbose "Notification erfolgreich gesendet"
        return $response
    }
    catch {
        Write-Error "Fehler beim Senden der Notification: $_"
        throw
    }
}

<#
.SYNOPSIS
    Sendet eine kritische Benachrichtigung (SMS + WhatsApp + Teams)
    
.PARAMETER Title
    Titel der Benachrichtigung
    
.PARAMETER Body
    Text der Benachrichtigung
    
.EXAMPLE
    Send-CriticalAlert -Title "Firewall Down" -Body "Palo Alto nicht erreichbar"
#>
function Send-CriticalAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Body
    )
    
    Send-Notification -Tags "kritisch" -Title "🚨 $Title" -Body $Body
}

<#
.SYNOPSIS
    Sendet eine Warn-Benachrichtigung (WhatsApp + Teams)
    
.PARAMETER Title
    Titel der Benachrichtigung
    
.PARAMETER Body
    Text der Benachrichtigung
    
.EXAMPLE
    Send-WarningAlert -Title "CPU Hoch" -Body "Server DC01: CPU bei 85%"
#>
function Send-WarningAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Body
    )
    
    Send-Notification -Tags "warnung,whatsapp,teams" -Title "⚠️ $Title" -Body $Body
}

<#
.SYNOPSIS
    Sendet eine Info-Nachricht (WhatsApp + Teams)
    
.PARAMETER Title
    Titel der Benachrichtigung
    
.PARAMETER Body
    Text der Benachrichtigung
    
.EXAMPLE
    Send-InfoMessage -Title "Backup erfolgreich" -Body "Nightly Backup abgeschlossen"
#>
function Send-InfoMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Body
    )
    
    Send-Notification -Tags "info,whatsapp,teams" -Title "ℹ️ $Title" -Body $Body
}

<#
.SYNOPSIS
    Sendet eine SMS-Benachrichtigung
    
.PARAMETER Body
    Text der SMS (max. 160 Zeichen empfohlen)
    
.EXAMPLE
    Send-SMSAlert -Body "Server DC01 nicht erreichbar"
#>
function Send-SMSAlert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateLength(1,160)]
        [string]$Body
    )
    
    Send-Notification -Tags "sms" -Body $Body
}

<#
.SYNOPSIS
    Sendet eine WhatsApp-Nachricht
    
.PARAMETER Title
    Titel der Nachricht
    
.PARAMETER Body
    Text der Nachricht
    
.EXAMPLE
    Send-WhatsAppMessage -Title "Team Info" -Body "Wartungsfenster heute 20:00 Uhr"
#>
function Send-WhatsAppMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Body
    )
    
    if ($Title) {
        Send-Notification -Tags "whatsapp" -Title $Title -Body $Body
    } else {
        Send-Notification -Tags "whatsapp" -Body $Body
    }
}

<#
.SYNOPSIS
    Sendet eine Teams-Nachricht
    
.PARAMETER Title
    Titel der Nachricht
    
.PARAMETER Body
    Text der Nachricht
    
.EXAMPLE
    Send-TeamsMessage -Title "Deployment" -Body "Neues Release deployed"
#>
function Send-TeamsMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Body
    )
    
    Send-Notification -Tags "teams" -Title $Title -Body $Body
}

<#
.SYNOPSIS
    Sendet eine E-Mail-Benachrichtigung
    
.PARAMETER Title
    Betreff der E-Mail
    
.PARAMETER Body
    Text der E-Mail
    
.EXAMPLE
    Send-EmailNotification -Title "Monatsbericht" -Body "Der IT-Bericht steht bereit"
#>
function Send-EmailNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Body
    )
    
    Send-Notification -Tags "email" -Title $Title -Body $Body
}

<#
.SYNOPSIS
    Sendet eine benutzerdefinierte Benachrichtigung
    
.PARAMETER Tags
    Komma-separierte Liste von Tags
    
.PARAMETER Title
    Titel der Benachrichtigung
    
.PARAMETER Body
    Text der Benachrichtigung
    
.EXAMPLE
    Send-CustomNotification -Tags "teams,email" -Title "Report" -Body "Wochenreport"
#>
function Send-CustomNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Tags,
        
        [Parameter(Mandatory=$false)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Body
    )
    
    if ($Title) {
        Send-Notification -Tags $Tags -Title $Title -Body $Body
    } else {
        Send-Notification -Tags $Tags -Body $Body
    }
}

<#
.SYNOPSIS
    Testet die Verbindung zum Notification Gateway
    
.EXAMPLE
    Test-NotificationGateway
#>
function Test-NotificationGateway {
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "Teste Verbindung zu: $Script:NotificationBaseUrl" -ForegroundColor Cyan
        
        $response = Invoke-RestMethod `
            -Uri $Script:NotificationBaseUrl `
            -Method Get `
            -TimeoutSec 10 `
            -ErrorAction Stop
        
        Write-Host "✓ Verbindung erfolgreich" -ForegroundColor Green
        Write-Host "Gateway läuft und ist erreichbar" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Verbindung fehlgeschlagen" -ForegroundColor Red
        Write-Host "Fehler: $_" -ForegroundColor Red
        return $false
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Set-NotificationServer',
    'Send-Notification',
    'Send-CriticalAlert',
    'Send-WarningAlert',
    'Send-InfoMessage',
    'Send-SMSAlert',
    'Send-WhatsAppMessage',
    'Send-TeamsMessage',
    'Send-EmailNotification',
    'Send-CustomNotification',
    'Test-NotificationGateway'
)

# Module initialization
Write-Verbose "NotificationGateway Module geladen"
Write-Verbose "Standard Server: $Script:NotificationBaseUrl"
