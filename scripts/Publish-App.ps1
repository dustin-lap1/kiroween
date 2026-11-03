<#
.SYNOPSIS
  Builds the frontend, uploads it to the app's bucket, invalidates CloudFront,
  smoke-tests the site and the API, and sends a crew alert.

.DESCRIPTION
  Frontend only. API (Lambda) and infrastructure changes ship through
  Plan-App.ps1 + Apply-App.ps1, because Terraform packages the Lambda code.
#>
param(
    [Parameter(Mandatory)][string]$Name,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\Common.ps1"

Assert-AppName $Name
$record = Get-AppRecord $Name
if (-not $record -or -not $record.outputs -or -not $record.outputs.site_bucket) {
    throw "No infrastructure outputs for '$Name'. Run Plan-App.ps1 and Apply-App.ps1 first."
}
$appDir = Join-Path $script:AppsDir $Name
$o = $record.outputs
$p = @('--profile', $record.profile, '--region', $script:Region)

Write-Step '1/4' 'Building'
if ($SkipBuild) { Write-Info 'Skipped (-SkipBuild)' } else {
    Push-Location $appDir
    try {
        if (-not (Test-Path 'node_modules')) { Invoke-Streamed 'npm.cmd' @('install', '--no-fund', '--no-audit') }
        Invoke-Streamed 'npm.cmd' @('run', 'build')
    } finally { Pop-Location }
}
$dist = Join-Path $appDir 'dist'
if (-not (Test-Path (Join-Path $dist 'index.html'))) { throw "No build at apps\$Name\dist." }

Write-Step '2/4' "Uploading to s3://$($o.site_bucket)"
# Hashed assets: cache for a year. Everything else (index.html, favicon): always revalidate.
Invoke-Native aws (@('s3', 'sync', (Join-Path $dist 'assets'), "s3://$($o.site_bucket)/assets", '--delete',
        '--cache-control', 'public,max-age=31536000,immutable') + $p) | Out-Null
Invoke-Native aws (@('s3', 'sync', $dist, "s3://$($o.site_bucket)", '--delete', '--exclude', 'assets/*',
        '--cache-control', 'no-cache') + $p) | Out-Null
Write-Ok 'Uploaded'

Write-Step '3/4' 'Invalidating CloudFront'
Invoke-Native aws (@('cloudfront', 'create-invalidation', '--distribution-id', $o.distribution_id, '--paths', '/*') + $p) | Out-Null
Write-Ok "Invalidation created for $($o.distribution_id)"

Write-Step '4/4' 'Smoke test'
function Test-Url([string]$Url, [string]$Expect) {
    for ($i = 1; $i -le 12; $i++) {
        try {
            $r = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 15
            if ($r.StatusCode -eq 200 -and $r.Content -match $Expect) { return $true }
        } catch { }
        Start-Sleep -Seconds 10
    }
    return $false
}
$siteOk = Test-Url "$($o.site_url)/?cb=$([guid]::NewGuid().ToString('N'))" '<div id="root">'
$apiOk = Test-Url "$($o.site_url)/api/health" '"ok":true'
if ($siteOk) { Write-Ok "Site OK: $($o.site_url)" } else { Write-Info "Site did not answer yet: $($o.site_url) (a new distribution can take a few minutes)" }
if ($apiOk) { Write-Ok 'API OK: /api/health' } else { Write-Info 'API health check did not pass yet' }

Save-AppRecord $Name @{ lastPublishAt = (Get-Date).ToUniversalTime().ToString('o') }
$status = if ($siteOk -and $apiOk) { 'live' } else { 'published (smoke test pending)' }
Send-CrewAlert "Skeleton Crew: $Name is $status" "App '$Name' was published.`nSite: $($o.site_url)`nAPI health: $(if ($apiOk) { 'ok' } else { 'not yet' })" | Out-Null

if (-not ($siteOk -and $apiOk)) { exit 1 }
Write-Host "`n$Name is live: $($o.site_url)" -ForegroundColor Magenta
