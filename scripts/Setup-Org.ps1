<#
.SYNOPSIS
  One-time (idempotent) Organization setup for the project: the project OU
  and its project-only SCP. Run with the management profile.

.DESCRIPTION
  1. Creates the OU (OrgUnitName, default "Kiroween-2026") under the root.
  2. Creates or updates the SCP (ScpName) from platform\org\kiroween-guardrails.scp.json.
  3. Attaches the SCP to that OU only. Nothing else in the Organization changes.
  4. Records the ids in .local\org.json.

  Accounts in the OU still inherit any SCPs on the root; this policy adds to
  them. New-AppAccount.ps1 moves each app account into the OU.

  The SCP (in addition to whatever the root enforces):
  - us-east-1 only, with no role exemptions (root policies often exempt
    OrganizationAccountAccessRole);
  - no IAM users, access keys, or console passwords (roles only);
  - the skeleton-deployer role can only be changed by OrganizationAccountAccessRole;
  - Terraform state buckets and the lock table cannot be deleted, and old
    state versions cannot be purged, except by OrganizationAccountAccessRole.
#>
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\Common.ps1"

$cfg = Get-SkeletonConfig
$mgmt = $cfg.ManagementProfile
$ouName = if ($cfg.OrgUnitName) { $cfg.OrgUnitName } else { 'Kiroween-2026' }
$scpName = if ($cfg.ScpName) { $cfg.ScpName } else { 'Kiroween2026Guardrails' }
$scpPath = Join-Path $script:RepoRoot 'platform\org\kiroween-guardrails.scp.json'
$p = @('--profile', $mgmt)

Write-Step '1/4' "Ensuring OU $ouName"
$rootId = (Invoke-AwsJson (@('organizations', 'list-roots') + $p)).Roots[0].Id
$ous = Invoke-AwsJson (@('organizations', 'list-organizational-units-for-parent', '--parent-id', $rootId) + $p)
$ou = @($ous.OrganizationalUnits) | Where-Object { $_.Name -eq $ouName } | Select-Object -First 1
if (-not $ou) {
    $ou = (Invoke-AwsJson (@('organizations', 'create-organizational-unit', '--parent-id', $rootId, '--name', $ouName,
                '--tags', 'Key=project,Value=kiroween-skeleton-crew') + $p)).OrganizationalUnit
    Write-Ok "Created $($ou.Id)"
} else {
    Write-Ok "Exists: $($ou.Id)"
}

Write-Step '2/4' "Ensuring SCP $scpName"
# Minify: SCPs are limited to 5,120 characters.
$minified = Get-Content $scpPath -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 10 -Compress
$tmp = Join-Path $env:TEMP "kiroween-scp-$([guid]::NewGuid().ToString('N')).json"
Write-Utf8File $tmp $minified
try {
    $policies = Invoke-AwsJson (@('organizations', 'list-policies', '--filter', 'SERVICE_CONTROL_POLICY') + $p)
    $policy = @($policies.Policies) | Where-Object { $_.Name -eq $scpName } | Select-Object -First 1
    $description = "Kiroween 2026 Skeleton Crew guardrails (attached to OU $ouName only)"
    if (-not $policy) {
        $policy = (Invoke-AwsJson (@('organizations', 'create-policy', '--name', $scpName, '--type', 'SERVICE_CONTROL_POLICY',
                    '--description', $description, '--content', "file://$tmp",
                    '--tags', 'Key=project,Value=kiroween-skeleton-crew') + $p)).Policy.PolicySummary
        Write-Ok "Created $($policy.Id) ($($minified.Length) chars)"
    } else {
        Invoke-Native aws (@('organizations', 'update-policy', '--policy-id', $policy.Id, '--description', $description,
                '--content', "file://$tmp") + $p) | Out-Null
        Write-Ok "Updated $($policy.Id) ($($minified.Length) chars)"
    }
} finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
}

Write-Step '3/4' "Attaching $scpName to $ouName only"
$targets = Invoke-AwsJson (@('organizations', 'list-targets-for-policy', '--policy-id', $policy.Id) + $p)
$others = @($targets.Targets) | Where-Object { $_.TargetId -ne $ou.Id }
if ($others) { Write-Info "Note: the SCP is also attached to: $(($others | ForEach-Object { $_.Name }) -join ', '). Not changing that." }
if (-not (@($targets.Targets) | Where-Object { $_.TargetId -eq $ou.Id })) {
    Invoke-Native aws (@('organizations', 'attach-policy', '--policy-id', $policy.Id, '--target-id', $ou.Id) + $p) | Out-Null
    Write-Ok 'Attached'
} else {
    Write-Ok 'Already attached'
}

Write-Step '4/4' 'Verifying the OU policies'
$attached = Invoke-AwsJson (@('organizations', 'list-policies-for-target', '--target-id', $ou.Id, '--filter', 'SERVICE_CONTROL_POLICY') + $p)
$names = @($attached.Policies | ForEach-Object { $_.Name })
Write-Ok "OU $ouName has: $($names -join ', ')"
if ($names -notcontains 'FullAWSAccess') {
    Write-Info 'FullAWSAccess is not attached to the OU, so accounts in it would be denied everything. Attach it before moving accounts in.'
}

Write-Utf8File (Join-Path $script:LocalDir 'org.json') (@{ rootId = $rootId; ouId = $ou.Id; ouName = $ouName; scpId = $policy.Id; scpName = $scpName } | ConvertTo-Json)
Write-Host "`nOrganization ready: OU $ouName ($($ou.Id)), SCP $scpName ($($policy.Id))" -ForegroundColor Magenta
