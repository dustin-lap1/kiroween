# Shared helpers for the Skeleton Crew pipeline scripts.
# Windows PowerShell 5.1 compatible (no pwsh-only syntax).

$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$script:LocalDir = Join-Path $script:RepoRoot '.local'
$script:AppsDir = Join-Path $script:RepoRoot 'apps'
$script:SkeletonDir = Join-Path $script:RepoRoot 'skeleton'
$script:Region = 'us-east-1'

function Write-Step([string]$Step, [string]$Message) { Write-Host "`n[$Step] $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "  > $Message" -ForegroundColor Green }
function Write-Info([string]$Message) { Write-Host "  - $Message" -ForegroundColor Yellow }

function Get-SkeletonConfig {
    $path = Join-Path $script:RepoRoot 'scripts\config.local.psd1'
    if (-not (Test-Path $path)) {
        throw "Missing scripts\config.local.psd1. Copy scripts\config.example.psd1 to scripts\config.local.psd1 and fill it in."
    }
    $cfg = Import-PowerShellDataFile $path
    foreach ($key in 'ManagementProfile', 'AccountEmailTemplate', 'ProfilePrefix', 'DeployerRoleName', 'TerraformBinary') {
        if (-not $cfg[$key]) { throw "scripts\config.local.psd1 is missing '$key'." }
    }
    return $cfg
}

function Assert-AppName([string]$Name) {
    if ($Name -notmatch '^[a-z][a-z0-9-]{2,20}$' -or $Name.EndsWith('-')) {
        throw "App name '$Name' must be 3-21 chars of lowercase letters, digits, and dashes, starting with a letter."
    }
}

function Write-Utf8File([string]$Path, [string]$Content) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

# Runs a native command without letting stderr turn into a terminating error
# (Windows PowerShell 5.1 behavior), and returns exit code, stdout, stderr.
function Invoke-Native {
    param([Parameter(Mandatory)][string]$Exe, [string[]]$Arguments, [switch]$AllowFailure)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Exe @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    $stdout = @($output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" }) -join "`n"
    $stderr = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" }) -join "`n"
    if ($code -ne 0 -and -not $AllowFailure) {
        $shown = ($Arguments | Select-Object -First 3) -join ' '
        throw "$Exe $shown failed (exit $code): $stderr"
    }
    return [pscustomobject]@{ ExitCode = $code; Out = $stdout; Err = $stderr }
}

function Invoke-AwsJson {
    param([string[]]$Arguments, [switch]$AllowFailure)
    $result = Invoke-Native -Exe 'aws' -Arguments ($Arguments + @('--output', 'json')) -AllowFailure:$AllowFailure
    if ($result.ExitCode -ne 0) { return $null }
    if (-not $result.Out.Trim()) { return $null }
    return $result.Out | ConvertFrom-Json
}

# Streams a native command to the console (for terraform and npm) and fails on non-zero exit.
function Invoke-Streamed {
    param([Parameter(Mandatory)][string]$Exe, [string[]]$Arguments)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Exe @Arguments
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($code -ne 0) { throw "$Exe $($Arguments -join ' ') failed (exit $code)." }
}

# ---- Per-app local records (.local/apps/<name>.json, gitignored) ----------

function Get-AppRecordPath([string]$Name) { Join-Path $script:LocalDir "apps\$Name.json" }

function Get-AppRecord([string]$Name) {
    $path = Get-AppRecordPath $Name
    if (-not (Test-Path $path)) { return $null }
    return Get-Content $path -Raw | ConvertFrom-Json
}

function Save-AppRecord([string]$Name, [hashtable]$Values) {
    $merged = [ordered]@{}
    $existing = Get-AppRecord $Name
    if ($existing) {
        foreach ($p in $existing.PSObject.Properties) { $merged[$p.Name] = $p.Value }
    }
    foreach ($k in $Values.Keys) { $merged[$k] = $Values[$k] }
    $merged['updatedAt'] = (Get-Date).ToUniversalTime().ToString('o')
    Write-Utf8File (Get-AppRecordPath $Name) ($merged | ConvertTo-Json -Depth 8)
}

function Set-ActiveApp([string]$Name) { Write-Utf8File (Join-Path $script:LocalDir 'active-app') $Name }

function Get-ActiveApp {
    $path = Join-Path $script:LocalDir 'active-app'
    if (Test-Path $path) { return (Get-Content $path -Raw).Trim() }
    return ''
}

function Get-AppInfraDir([string]$Name) {
    $dir = Join-Path $script:AppsDir "$Name\infra"
    if (-not (Test-Path $dir)) { throw "No app at apps\$Name. Run .\scripts\New-App.ps1 first." }
    return $dir
}

# ---- Terraform ------------------------------------------------------------

function Get-TerraformArgsInit([hashtable]$Config) {
    $initArgs = @('init', '-input=false', '-reconfigure', '-backend-config=backend.hcl')
    if ($Config.TerraformPluginDir -and (Test-Path $Config.TerraformPluginDir)) {
        $initArgs += "-plugin-dir=$($Config.TerraformPluginDir)"
    }
    return $initArgs
}

# Summarizes a saved plan (terraform show -json) into create/update/delete/replace lists.
function Get-PlanSummary([hashtable]$Config, [string]$InfraDir) {
    $show = Invoke-Native -Exe $Config.TerraformBinary -Arguments @("-chdir=$InfraDir", 'show', '-json', 'tfplan')
    $plan = $show.Out | ConvertFrom-Json
    $summary = [ordered]@{ create = @(); update = @(); delete = @(); replace = @() }
    foreach ($rc in @($plan.resource_changes)) {
        if (-not $rc) { continue }
        $actions = @($rc.change.actions) -join ','
        switch ($actions) {
            'create' { $summary.create += $rc.address }
            'update' { $summary.update += $rc.address }
            'delete' { $summary.delete += $rc.address }
            'delete,create' { $summary.replace += $rc.address }
            'create,delete' { $summary.replace += $rc.address }
        }
    }
    $risk = 'NONE'
    if ($summary.create.Count) { $risk = 'LOW' }
    if ($summary.update.Count) { $risk = 'MEDIUM' }
    if ($summary.replace.Count) { $risk = 'HIGH' }
    if ($summary.delete.Count) { $risk = 'CRITICAL' }
    $summary['risk'] = $risk
    return $summary
}

function Format-List([object[]]$Items) {
    if (-not $Items -or $Items.Count -eq 0) { return '(none)' }
    return ($Items -join "`n          ")
}

# ---- Crew alerts (the email the hooks and scripts send) --------------------

function Send-CrewAlert([string]$Subject, [string]$Message) {
    $path = Join-Path $script:LocalDir 'crew-alerts.json'
    if (-not (Test-Path $path)) {
        Write-Info "Crew alerts not set up (scripts\Setup-CrewAlerts.ps1); skipped: $Subject"
        return $false
    }
    $crew = Get-Content $path -Raw | ConvertFrom-Json
    # SNS subjects: ASCII, no newlines, at most 100 chars. Native argument
    # passing in Windows PowerShell mangles embedded double quotes.
    $cleanSubject = (($Subject -replace '[^\x20-\x7E]', '') -replace '"', "'")
    if ($cleanSubject.Length -gt 100) { $cleanSubject = $cleanSubject.Substring(0, 100) }
    $cleanMessage = $Message -replace '"', "'"
    $result = Invoke-Native -Exe 'aws' -AllowFailure -Arguments @(
        'sns', 'publish', '--topic-arn', $crew.topicArn, '--subject', $cleanSubject,
        '--message', $cleanMessage, '--profile', $crew.profile, '--region', $script:Region)
    if ($result.ExitCode -eq 0) { Write-Ok "Crew alert sent: $cleanSubject"; return $true }
    Write-Info "Crew alert failed: $($result.Err)"
    return $false
}
