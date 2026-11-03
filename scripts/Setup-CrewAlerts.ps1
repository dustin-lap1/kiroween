<#
.SYNOPSIS
  Creates the "crew alerts" SNS topic that the Kiro hooks and pipeline
  scripts email you through, and subscribes your email. Idempotent.

.DESCRIPTION
  The topic lives in one member account (CrewAlertsProfile in
  config.local.psd1, normally a small "crew" account made with
  New-AppAccount.ps1 -Name crew). AWS emails a confirmation link: click it
  once. Use -Test to send a test message after confirming.

.EXAMPLE
  .\scripts\New-AppAccount.ps1 -Name crew
  .\scripts\Setup-CrewAlerts.ps1
  .\scripts\Setup-CrewAlerts.ps1 -Test
#>
param(
    [string]$AwsProfile,
    [string]$Email,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\Common.ps1"

$cfg = Get-SkeletonConfig
if (-not $AwsProfile) { $AwsProfile = $cfg.CrewAlertsProfile }
if (-not $Email) { $Email = $cfg.AlertEmail }
if (-not $AwsProfile -or -not $Email) { throw 'Set CrewAlertsProfile and AlertEmail in scripts\config.local.psd1 (or pass -AwsProfile and -Email).' }
$p = @('--profile', $AwsProfile, '--region', $script:Region)

Write-Step '1/3' "Ensuring topic kiroween-crew-alerts ($AwsProfile)"
$topicArn = (Invoke-AwsJson (@('sns', 'create-topic', '--name', 'kiroween-crew-alerts',
            '--tags', 'Key=project,Value=kiroween-skeleton-crew') + $p)).TopicArn
Write-Ok $topicArn

Write-Step '2/3' "Ensuring email subscription for $Email"
$subs = Invoke-AwsJson (@('sns', 'list-subscriptions-by-topic', '--topic-arn', $topicArn) + $p)
$sub = @($subs.Subscriptions) | Where-Object { $_.Protocol -eq 'email' -and $_.Endpoint -eq $Email } | Select-Object -First 1
if (-not $sub) {
    Invoke-Native aws (@('sns', 'subscribe', '--topic-arn', $topicArn, '--protocol', 'email', '--notification-endpoint', $Email) + $p) | Out-Null
    Write-Info "Subscription requested: open the AWS Notification email at $Email and click Confirm."
} elseif ($sub.SubscriptionArn -eq 'PendingConfirmation') {
    Write-Info "Still pending: click Confirm in the AWS Notification email at $Email."
} else {
    Write-Ok 'Subscription confirmed'
}

Write-Step '3/3' 'Saving .local\crew-alerts.json'
Write-Utf8File (Join-Path $script:LocalDir 'crew-alerts.json') (@{ topicArn = $topicArn; profile = $AwsProfile; email = $Email } | ConvertTo-Json)
Write-Ok 'Saved'

if ($Test) {
    Send-CrewAlert 'Skeleton Crew: test alert' 'If you can read this, Kiro hooks can reach you. Happy Kiroween.' | Out-Null
}
