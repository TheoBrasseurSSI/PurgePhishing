Clear-Host

$banner = @"
__________                          __________.__    .__       .__    .__                
\______   \__ _________  ____   ____\______   \  |__ |__| _____|  |__ |__| ____    ____  
 |     ___/  |  \_  __ \/ ___\_/ __ \|     ___/  |  \|  |/  ___/  |  \|  |/    \  / ___\ 
 |    |   |  |  /|  | \/ /_/  >  ___/|    |   |   Y  \  |\___ \|   Y  \  |   |  \/ /_/  >
 |____|   |____/ |__|  \___  / \___  >____|   |___|  /__/____  >___|  /__|___|  /\___  / 
                      /_____/      \/              \/        \/     \/        \//_____/  
"@

Write-Host $banner -ForegroundColor Cyan
Write-Host "[Exchange Online - Suppression des emails de phishing sur le tenant]" -ForegroundColor DarkGray
Write-Host ""

# =========================
# Preparation environnement
# =========================
Write-Host "Preparation de l'environnement PowerShell..." -ForegroundColor Yellow

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "Installation du fournisseur NuGet..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Installation du module ExchangeOnlineManagement..."
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber
}

Import-Module ExchangeOnlineManagement

# =========================
# Connexion
# =========================
Write-Host "Connexion au centre de conformite..." -ForegroundColor Yellow

try {
    Connect-IPPSSession -EnableSearchOnlySession -ErrorAction Stop
}
catch {
    Write-Host "Erreur : impossible de se connecter au centre de conformite. Verifiez vos droits." -ForegroundColor Red
    Write-Host ""
    Write-Host "Appuyez sur ESPACE pour quitter"
    do { $key = [System.Console]::ReadKey($true) } until ($key.Key -eq "Spacebar")
    exit
}

# =========================
# Saisie expéditeur + date
# =========================
$expediteur = Read-Host "Entrez l'adresse email de l'expediteur"
if ([string]::IsNullOrWhiteSpace($expediteur)) {
    Write-Host "Expediteur non valide - arret du script" -ForegroundColor Red
    return
}

$dateDebut = Read-Host "Entrez la date de debut (jj/mm/aaaa)"
if (-not ($dateDebut -as [datetime])) {
    Write-Host "Format de date invalide - arret du script" -ForegroundColor Red
    return
}

# Conversion en format ISO pour AQS
$dateISO = (Get-Date $dateDebut -Format "yyyy-MM-ddT00:00:00Z")

# Construction de la requête
$contentQuery = "(from:`"$expediteur`") AND (received>=$dateISO)"

# =========================
# Nom automatique + initialisation log
# =========================
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$searchName = "Purge_$timestamp"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $scriptDir "..\logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$logFile = Join-Path $logDir "Purge_$timestamp.log"

function Write-Log {
    param([string]$message)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $message"
    Add-Content -Path $script:logFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue
}

Write-Host "Nom de la recherche : $searchName" -ForegroundColor Green

Write-Log "=== Nouvelle session de purge ==="
Write-Log "Compte admin     : $($env:USERNAME)"
Write-Log "Expediteur cible : $expediteur"
Write-Log "Date de debut    : $dateDebut"
Write-Log "Nom recherche    : $searchName"

# =========================
# Recherche
# =========================
Write-Host "Creation de la recherche..."

try {
    New-ComplianceSearch `
        -Name $searchName `
        -ExchangeLocation All `
        -ContentMatchQuery $contentQuery `
        -ErrorAction Stop | Out-Null
}
catch {
    Write-Host "Erreur lors de la création de la recherche." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor DarkRed
    Write-Log "ERREUR creation recherche : $($_.Exception.Message)"
    return
}

Start-ComplianceSearch -Identity $searchName

Write-Host "Recherche en cours" -NoNewline

do {
    Start-Sleep -Seconds 5
    $status = (Get-ComplianceSearch -Identity $searchName).Status
    Write-Host "." -NoNewline
} while ($status -ne "Completed")

Write-Host ""
Write-Host "Recherche terminee" -ForegroundColor Green

# =========================
# Verification des resultats
# =========================
$results = (Get-ComplianceSearch -Identity $searchName).Items

if ($results -eq 0) {
    Write-Host "Aucun email trouve avec ces criteres. Arret de la procedure de purge." -ForegroundColor Red
    Write-Log "Aucun email trouve - purge annulee"
    Remove-ComplianceSearch -Identity $searchName -Confirm:$false
    Write-Host ""
    Write-Host "Appuyez sur ESPACE pour quitter"
    do { $key = [System.Console]::ReadKey($true) } until ($key.Key -eq "Spacebar")
    exit
}

Write-Host "Nombre d'elements trouves : $results" -ForegroundColor Green
Write-Log "Emails trouves   : $results"

# =========================
# Confirmation manuelle avant purge
# =========================
Write-Host ""
Write-Host "ATTENTION : $results email(s) vont etre definitivement supprimes de toutes les boites du tenant." -ForegroundColor Red
Write-Host "Cette action est IRREVERSIBLE." -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Confirmer la suppression ? (OUI pour confirmer, toute autre valeur pour annuler)"
if ($confirm -ne "OUI") {
    Write-Host "Suppression annulee." -ForegroundColor Yellow
    Write-Log "Suppression annulee par l'operateur"
    Remove-ComplianceSearch -Identity $searchName -Confirm:$false
    return
}

Write-Log "Suppression confirmee par l'operateur"

# =========================
# Purge
# =========================
Write-Host "Lancement du HardDelete" -NoNewline

New-ComplianceSearchAction `
    -SearchName $searchName `
    -Purge `
    -PurgeType HardDelete `
    -Confirm:$false | Out-Null

do {
    Start-Sleep -Seconds 5
    $actionStatus = (Get-ComplianceSearchAction -Identity "${searchName}_Purge").Status
    Write-Host "." -NoNewline
} while ($actionStatus -ne "Completed")

Write-Host ""
Write-Host "Purge terminee" -ForegroundColor Green
Write-Log "Purge HardDelete terminee avec succes"
Write-Log "=== Fin de session ==="

Write-Host "" 
Write-Host "Appuyez sur ESPACE pour quitter"

do {
    $key = [System.Console]::ReadKey($true)
} until ($key.Key -eq "Spacebar")

exit