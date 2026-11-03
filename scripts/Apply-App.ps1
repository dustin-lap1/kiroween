<#
.SYNOPSIS
  Applies exactly the plan that Plan-App.ps1 saved. Run only after the human
  reviewed the impact summary and said "yes".

.DESCRIPTION
  Guardrails:
  - Refuses if there is no saved plan, or it is older than 60 minutes.
  - Refuses any plan that deletes or replaces resources unless -AllowDestroy
    (the PreToolUse hook blocks the agent from passing it: a human runs it).
  - Applies the saved plan file, so what runs is what was reviewed.
  Then saves the outputs to .local\apps\<Name>.json and sends a crew alert.
#>
param(
    [Parameter(Mandatory)][string]$Name,
    [switch]$AllowDestroy
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\Common.ps1"

Assert-AppName $Name
$cfg = Get-SkeletonConfig
$infra = Get-AppInfraDir $Name
$tf = $cfg.TerraformBinary
$planFile = Join-Path $infra 'tfplan'

if (-not (Test-Path $planFile)) { throw "No saved plan. Run .\scripts\Plan-App.ps1 -Name $Name and review it first." }
$age = (Get-Date) - (Get-Item $planFile).LastWriteTime
if ($age.TotalMinutes -gt 60) { throw "The saved plan is $([int]$age.TotalMinutes) minutes old. Re-run Plan-App.ps1 and review it again." }

Write-Step '1/3' 'Checking the saved plan'
$s = Get-PlanSummary $cfg $infra
if (($s.delete.Count -or $s.replace.Count) -and -not $AllowDestroy) {
    throw "Refusing: the plan deletes [$($s.delete -join ', ')] and replaces [$($s.replace -join ', ')]. A human must review it and run Apply-App.ps1 -AllowDestroy."
}
Write-Ok "Risk $($s.risk): +$($s.create.Count) ~$($s.update.Count) -$($s.delete.Count) replace $($s.replace.Count)"

if ($s.risk -ne 'NONE') {
    Write-Step '2/3' 'terraform apply tfplan'
    Invoke-Streamed $tf @("-chdir=$infra", 'apply', '-input=false', 'tfplan')
} else {
    Write-Step '2/3' 'No changes in the plan; skipping apply'
}
Remove-Item $planFile -ErrorAction SilentlyContinue

Write-Step '3/3' 'Saving outputs'
$raw = Invoke-Native -Exe $tf -Arguments @("-chdir=$infra", 'output', '-json')
$outputs = @{}
$parsed = $raw.Out | ConvertFrom-Json
foreach ($p in $parsed.PSObject.Properties) { $outputs[$p.Name] = $p.Value.value }
Save-AppRecord $Name @{ outputs = $outputs; lastApplyAt = (Get-Date).ToUniversalTime().ToString('o') }
Set-ActiveApp $Name
Write-Ok "Site: $($outputs.site_url)"

Send-CrewAlert "Skeleton Crew: $Name infrastructure applied" ("Applied plan for {0}: +{1} ~{2} -{3}.`nSite: {4}" -f $Name, $s.create.Count, $s.update.Count, $s.delete.Count, $outputs.site_url) | Out-Null
