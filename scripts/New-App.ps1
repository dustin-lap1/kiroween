<#
.SYNOPSIS
  Creates a new app from the skeleton: apps\<Name>, its own AWS account, and
  local wiring. Then: Plan-App, Apply-App, Publish-App.

.EXAMPLE
  .\scripts\New-App.ps1 -Name ghost-guestbook -DisplayName "Ghost Guestbook" `
      -Description "Leave a message for the spirits." -Theme ghost
#>
param(
    [Parameter(Mandatory)][string]$Name,
    [string]$DisplayName,
    [Parameter(Mandatory)][string]$Description,
    [ValidateSet('pumpkin', 'ghost', 'slime', 'blood')][string]$Theme = 'pumpkin',
    [string]$AccountId,
    [switch]$SkipAccount,
    [switch]$SkipInstall
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\Common.ps1"

Assert-AppName $Name
if (-not $DisplayName) {
    $DisplayName = (($Name -split '-') | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ' '
}
$appDir = Join-Path $script:AppsDir $Name
if (Test-Path $appDir) { throw "apps\$Name already exists. Pick another name or delete that folder first." }

# --- 1. Copy the skeleton ------------------------------------------------------
Write-Step '1/5' "Copying skeleton to apps\$Name"
$skip = '\\(node_modules|dist|\.terraform|\.build)(\\|$)'
$source = $script:SkeletonDir
Get-ChildItem $source -Recurse -File -Force | Where-Object {
    $_.FullName.Substring($source.Length) -notmatch $skip -and
    $_.Name -notin @('backend.hcl', 'local.auto.tfvars', 'tfplan', '.terraform.lock.hcl', 'terraform.tfstate')
} | ForEach-Object {
    $dest = Join-Path $appDir $_.FullName.Substring($source.Length + 1)
    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
    Copy-Item $_.FullName $dest
}
Write-Ok 'Skeleton copied'

# --- 2. Fill in the tokens -------------------------------------------------------
Write-Step '2/5' 'Personalizing the app'
function ConvertTo-JsonText([string]$Value) { $q = ConvertTo-Json $Value; return $q.Substring(1, $q.Length - 2) }
$html = { param($v) [System.Net.WebUtility]::HtmlEncode($v) }
$tokens = [ordered]@{
    '__APP_DISPLAY_NAME_HTML__' = (& $html $DisplayName)
    '__APP_DESCRIPTION_HTML__'  = (& $html $Description)
}
$jsonTokens = [ordered]@{
    '__APP_NAME__'         = $Name
    '__APP_DISPLAY_NAME__' = (ConvertTo-JsonText $DisplayName)
    '__APP_DESCRIPTION__'  = (ConvertTo-JsonText $Description)
    '__APP_THEME__'        = $Theme
}
$plainTokens = [ordered]@{ '__APP_NAME__' = $Name; '__APP_DISPLAY_NAME__' = $DisplayName; '__APP_DESCRIPTION__' = $Description }

$files = @{
    'app.config.json' = $jsonTokens
    'index.html'      = $tokens
    'README.md'       = $plainTokens
}
foreach ($file in $files.Keys) {
    $path = Join-Path $appDir $file
    $text = [System.IO.File]::ReadAllText($path)
    foreach ($t in $files[$file].GetEnumerator()) { $text = $text.Replace($t.Key, $t.Value) }
    Write-Utf8File $path $text
}
$pkgPath = Join-Path $appDir 'package.json'
Write-Utf8File $pkgPath ([System.IO.File]::ReadAllText($pkgPath).Replace('"name": "skeleton-app"', "`"name`": `"$Name`""))
# Fail fast if the generated config is not valid JSON.
Get-Content (Join-Path $appDir 'app.config.json') -Raw | ConvertFrom-Json | Out-Null
Write-Ok "$DisplayName ($Theme theme)"

# --- 3. Account ------------------------------------------------------------------
Write-Step '3/5' 'AWS account'
$record = Get-AppRecord $Name
if ($SkipAccount) {
    Write-Info 'Skipped (-SkipAccount). Run .\scripts\New-AppAccount.ps1 before Plan-App.'
} elseif ($record -and $record.stateBucket) {
    Write-Ok "Using pre-provisioned account $($record.accountId)"
} else {
    $accountArgs = @{ Name = $Name }
    if ($AccountId) { $accountArgs.AccountId = $AccountId }
    & "$PSScriptRoot\New-AppAccount.ps1" @accountArgs
}
Set-ActiveApp $Name

# --- 4. Dependencies -------------------------------------------------------------
Write-Step '4/5' 'Installing frontend dependencies'
if ($SkipInstall) {
    Write-Info 'Skipped (-SkipInstall)'
} else {
    Push-Location $appDir
    try { Invoke-Streamed 'npm.cmd' @('install', '--no-fund', '--no-audit') } finally { Pop-Location }
    Write-Ok 'npm install done'
}

# --- 5. Done ---------------------------------------------------------------------
Write-Step '5/5' 'Ready'
Send-CrewAlert "Skeleton Crew: $Name scaffolded" "New app '$DisplayName' was created from the skeleton at apps\$Name.`nNext: Plan-App, Apply-App, Publish-App." | Out-Null

Write-Host "`n$DisplayName is ready at apps\$Name" -ForegroundColor Magenta
Write-Host '  Next:' -ForegroundColor Yellow
Write-Host "    .\scripts\Plan-App.ps1    -Name $Name" -ForegroundColor Gray
Write-Host "    .\scripts\Apply-App.ps1   -Name $Name   (after you review the plan and say yes)" -ForegroundColor Gray
Write-Host "    .\scripts\Publish-App.ps1 -Name $Name" -ForegroundColor Gray
