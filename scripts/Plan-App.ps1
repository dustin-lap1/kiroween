<#
.SYNOPSIS
  Plans an app's infrastructure and prints the impact summary. Never applies.

.DESCRIPTION
  Writes backend.hcl and local.auto.tfvars from the app's account record,
  runs terraform init and plan -out=tfplan, then summarizes every create,
  update, delete, and replace with a risk level. Present the summary to the
  human; only after an explicit "yes" run Apply-App.ps1, which applies exactly
  this saved plan.

.EXAMPLE
  .\scripts\Plan-App.ps1 -Name ghost-guestbook
  .\scripts\Plan-App.ps1 -Name ghost-guestbook -Target aws_lambda_function.api
#>
param(
    [Parameter(Mandatory)][string]$Name,
    [string[]]$Target
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\Common.ps1"

Assert-AppName $Name
$cfg = Get-SkeletonConfig
$infra = Get-AppInfraDir $Name
$record = Get-AppRecord $Name
if (-not $record -or -not $record.stateBucket) {
    throw "No account for '$Name'. Run .\scripts\New-AppAccount.ps1 -Name $Name first."
}
$tf = $cfg.TerraformBinary

Write-Step '1/3' "Writing backend and variables for account $($record.accountId)"
Write-Utf8File (Join-Path $infra 'backend.hcl') @"
bucket         = "$($record.stateBucket)"
key            = "app/terraform.tfstate"
region         = "$($script:Region)"
dynamodb_table = "$($record.lockTable)"
encrypt        = true
profile        = "$($record.profile)"
"@
Write-Utf8File (Join-Path $infra 'local.auto.tfvars') @"
account_id  = "$($record.accountId)"
aws_profile = "$($record.profile)"
alert_email = "$($cfg.AlertEmail)"
"@
Write-Ok 'backend.hcl and local.auto.tfvars written (gitignored)'

Write-Step '2/3' 'terraform init + plan'
Invoke-Streamed $tf (@("-chdir=$infra") + (Get-TerraformArgsInit $cfg))
$planArgs = @("-chdir=$infra", 'plan', '-input=false', '-out=tfplan')
foreach ($t in @($Target)) { if ($t) { $planArgs += "-target=$t" } }
Invoke-Streamed $tf $planArgs

Write-Step '3/3' 'Impact summary'
$s = Get-PlanSummary $cfg $infra
$targetText = if ($Target) { ($Target | ForEach-Object { "-target=$_" }) -join ' ' } else { '(full stack)' }
$summary = @"

TERRAFORM OPERATION
COMMAND:  .\scripts\Apply-App.ps1 -Name $Name   (applies saved plan apps\$Name\infra\tfplan; $targetText)
ACCOUNT:  $($record.accountId) via profile $($record.profile), region $($script:Region)
CREATE:   $(Format-List $s.create)
MODIFY:   $(Format-List $s.update)
DESTROY:  $(Format-List $s.delete)
REPLACE:  $(Format-List $s.replace)
RISK LEVEL: $($s.risk)
ROLLBACK: revert the change in git, re-plan, re-apply. Saved plans cannot drift: Terraform rejects a stale plan.
Proceed? (awaiting explicit "yes")
"@
Write-Host $summary -ForegroundColor White

Save-AppRecord $Name @{ lastPlan = @{
        at = (Get-Date).ToUniversalTime().ToString('o'); risk = $s.risk
        create = $s.create.Count; update = $s.update.Count; delete = $s.delete.Count; replace = $s.replace.Count
    }
}
Set-ActiveApp $Name

if ($s.risk -eq 'NONE') { Write-Ok 'No changes. Nothing to apply.' }
elseif ($s.delete.Count -or $s.replace.Count) {
    Write-Host 'This plan DELETES or REPLACES resources. Apply-App.ps1 will refuse it unless a human runs it with -AllowDestroy.' -ForegroundColor Red
}
