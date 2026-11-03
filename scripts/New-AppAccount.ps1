<#
.SYNOPSIS
  Vends a dedicated AWS account for one app in your Organization and wires up
  local access to it. Safe to re-run: every step is idempotent.

.DESCRIPTION
  1. Creates the member account (or reuses one with the same email, or -AccountId)
     and moves it into the project OU (Setup-Org.ps1), where the project SCP applies.
  2. Creates the "skeleton-deployer" role in it, trusted by your management
     principal only. This role is bound by the Organization's SCPs.
  3. Adds a local AWS CLI profile "<ProfilePrefix><Name>" that assumes that role
     (no long-lived access keys).
  4. Creates the Terraform state bucket (versioned, private) and lock table.
  5. Records everything in .local\apps\<Name>.json (gitignored).

.EXAMPLE
  .\scripts\New-AppAccount.ps1 -Name ghost-guestbook
  .\scripts\New-AppAccount.ps1 -Name crew
#>
param(
    [Parameter(Mandatory)][string]$Name,
    [string]$AccountId,
    [string]$Email
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\lib\Common.ps1"

Assert-AppName $Name
$cfg = Get-SkeletonConfig
$mgmt = $cfg.ManagementProfile
$appProfile = "$($cfg.ProfilePrefix)$Name"
$roleName = $cfg.DeployerRoleName

$record = Get-AppRecord $Name
if (-not $AccountId -and $record -and $record.accountId) {
    $AccountId = $record.accountId
    Write-Info "Reusing account $AccountId from .local\apps\$Name.json"
}

# --- 1. Management access ----------------------------------------------------
Write-Step '1/5' "Checking management access ($mgmt)"
$me = Invoke-AwsJson @('sts', 'get-caller-identity', '--profile', $mgmt)
$principal = $me.Arn
if ($principal -match '^arn:aws:sts::(\d{12}):assumed-role/([^/]+)/') {
    # Trust the role, not the session.
    $principal = "arn:aws:iam::$($Matches[1]):role/$($Matches[2])"
}
Write-Ok "Management principal: $principal"

# --- 2. Account ----------------------------------------------------------------
Write-Step '2/5' 'Ensuring the app account exists'
if (-not $AccountId) {
    if (-not $Email) { $Email = $cfg.AccountEmailTemplate.Replace('{name}', $Name) }
    $accounts = Invoke-AwsJson @('organizations', 'list-accounts', '--profile', $mgmt)
    $existing = @($accounts.Accounts) | Where-Object { $_.Email -eq $Email -and $_.Status -eq 'ACTIVE' } | Select-Object -First 1
    if ($existing) {
        $AccountId = $existing.Id
        Write-Ok "Found existing account $AccountId ($Email)"
    } else {
        $accountName = "$($cfg.AccountNamePrefix)$Name"
        Write-Info "Creating account '$accountName' <$Email> (usually 1-4 minutes)"
        $create = Invoke-AwsJson @('organizations', 'create-account', '--email', $Email, '--account-name', $accountName,
            '--tags', 'Key=project,Value=kiroween-skeleton-crew', "Key=app,Value=$Name", '--profile', $mgmt)
        $requestId = $create.CreateAccountStatus.Id
        for ($i = 1; $i -le 60; $i++) {
            Start-Sleep -Seconds 10
            $status = (Invoke-AwsJson @('organizations', 'describe-create-account-status',
                    '--create-account-request-id', $requestId, '--profile', $mgmt)).CreateAccountStatus
            Write-Host "    $($status.State) ($($i * 10)s)" -ForegroundColor DarkGray
            if ($status.State -eq 'SUCCEEDED') { $AccountId = $status.AccountId; break }
            if ($status.State -eq 'FAILED') { throw "Account creation failed: $($status.FailureReason)" }
        }
        if (-not $AccountId) { throw "Account creation did not finish in 10 minutes (request $requestId). Re-run later." }
        Write-Ok "Created account $AccountId"
    }
}
if ($AccountId -notmatch '^\d{12}$') { throw "Invalid account id '$AccountId'." }
$accountValues = @{ name = $Name; accountId = $AccountId; profile = $appProfile; region = $script:Region }
if ($Email) { $accountValues.accountEmail = $Email }
Save-AppRecord $Name $accountValues

# Move the account into the project OU so the project SCP applies to it
# (and only project accounts get it).
$orgPath = Join-Path $script:LocalDir 'org.json'
if (-not (Test-Path $orgPath)) { throw 'Project OU not set up. Run .\scripts\Setup-Org.ps1 first.' }
$org = Get-Content $orgPath -Raw | ConvertFrom-Json
$parent = (Invoke-AwsJson @('organizations', 'list-parents', '--child-id', $AccountId, '--profile', $mgmt)).Parents[0]
if ($parent.Id -ne $org.ouId) {
    Invoke-Native aws @('organizations', 'move-account', '--account-id', $AccountId, '--source-parent-id', $parent.Id,
        '--destination-parent-id', $org.ouId, '--profile', $mgmt) | Out-Null
    Write-Ok "Moved into OU $($org.ouName) ($($org.ouId))"
} else {
    Write-Ok "Already in OU $($org.ouName)"
}
Save-AppRecord $Name @{ ouId = $org.ouId }

# --- 3. Deployer role (via OrganizationAccountAccessRole, once) ----------------
Write-Step '3/5' "Ensuring role $roleName in $AccountId"
$adminRoleArn = "arn:aws:iam::${AccountId}:role/OrganizationAccountAccessRole"
$creds = $null
for ($i = 1; $i -le 18 -and -not $creds; $i++) {
    $assumed = Invoke-AwsJson -AllowFailure @('sts', 'assume-role', '--role-arn', $adminRoleArn,
        '--role-session-name', "skeleton-setup-$Name", '--duration-seconds', '900', '--profile', $mgmt)
    if ($assumed) { $creds = $assumed.Credentials } else { Write-Host '    waiting for the new account roles...' -ForegroundColor DarkGray; Start-Sleep -Seconds 10 }
}
if (-not $creds) { throw "Could not assume $adminRoleArn. If the account is brand new, wait a minute and re-run." }

$trustPath = Join-Path $env:TEMP "skeleton-trust-$Name-$([guid]::NewGuid().ToString('N')).json"
$trust = @{
    Version   = '2012-10-17'
    Statement = @(@{ Effect = 'Allow'; Principal = @{ AWS = $principal }; Action = 'sts:AssumeRole' })
} | ConvertTo-Json -Depth 6
Write-Utf8File $trustPath $trust

$saved = @{ profile = $env:AWS_PROFILE; key = $env:AWS_ACCESS_KEY_ID; secret = $env:AWS_SECRET_ACCESS_KEY; token = $env:AWS_SESSION_TOKEN }
try {
    Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
    $env:AWS_ACCESS_KEY_ID = $creds.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $creds.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $creds.SessionToken

    $role = Invoke-AwsJson -AllowFailure @('iam', 'get-role', '--role-name', $roleName)
    if ($role) {
        Invoke-Native aws @('iam', 'update-assume-role-policy', '--role-name', $roleName, '--policy-document', "file://$trustPath") | Out-Null
        Write-Ok 'Role exists; trust policy refreshed'
    } else {
        Invoke-Native aws @('iam', 'create-role', '--role-name', $roleName, '--assume-role-policy-document', "file://$trustPath",
            '--max-session-duration', '3600', '--description', 'Terraform deployer for the Skeleton Crew pipeline (bound by SCPs)',
            '--tags', 'Key=project,Value=kiroween-skeleton-crew') | Out-Null
        Write-Ok 'Role created'
    }
    # Admin inside the account; the Organization's SCPs still bound it
    # (us-east-1 only, approved serverless services only).
    Invoke-Native aws @('iam', 'attach-role-policy', '--role-name', $roleName, '--policy-arn', 'arn:aws:iam::aws:policy/AdministratorAccess') | Out-Null
} finally {
    if ($saved.profile) { $env:AWS_PROFILE = $saved.profile } else { Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue }
    foreach ($pair in @(@('AWS_ACCESS_KEY_ID', $saved.key), @('AWS_SECRET_ACCESS_KEY', $saved.secret), @('AWS_SESSION_TOKEN', $saved.token))) {
        if ($pair[1]) { Set-Item "Env:$($pair[0])" $pair[1] } else { Remove-Item "Env:$($pair[0])" -ErrorAction SilentlyContinue }
    }
    Remove-Item $trustPath -ErrorAction SilentlyContinue
}

# --- 4. Local profile ----------------------------------------------------------
Write-Step '4/5' "Configuring local profile $appProfile"
$roleArn = "arn:aws:iam::${AccountId}:role/$roleName"
Invoke-Native aws @('configure', 'set', 'role_arn', $roleArn, '--profile', $appProfile) | Out-Null
Invoke-Native aws @('configure', 'set', 'source_profile', $mgmt, '--profile', $appProfile) | Out-Null
Invoke-Native aws @('configure', 'set', 'region', $script:Region, '--profile', $appProfile) | Out-Null
Invoke-Native aws @('configure', 'set', 'role_session_name', "skeleton-$Name", '--profile', $appProfile) | Out-Null

$verified = $null
for ($i = 1; $i -le 12 -and -not $verified; $i++) {
    $verified = Invoke-AwsJson -AllowFailure @('sts', 'get-caller-identity', '--profile', $appProfile)
    if (-not $verified) { Start-Sleep -Seconds 5 }
}
if (-not $verified -or $verified.Account -ne $AccountId) { throw "Profile $appProfile does not reach account $AccountId yet. Wait a few seconds and re-run." }
Write-Ok "Profile works: $($verified.Arn)"

# --- 5. Terraform state ----------------------------------------------------------
Write-Step '5/5' 'Ensuring Terraform state bucket and lock table'
$bucket = "$Name-tfstate-$AccountId"
$lockTable = 'terraform-locks'
$p = @('--profile', $appProfile, '--region', $script:Region)

$head = Invoke-Native aws (@('s3api', 'head-bucket', '--bucket', $bucket) + $p) -AllowFailure
if ($head.ExitCode -ne 0) {
    Invoke-Native aws (@('s3api', 'create-bucket', '--bucket', $bucket) + $p) | Out-Null
    Write-Ok "Created s3://$bucket"
}
Invoke-Native aws (@('s3api', 'put-bucket-versioning', '--bucket', $bucket, '--versioning-configuration', 'Status=Enabled') + $p) | Out-Null
Invoke-Native aws (@('s3api', 'put-public-access-block', '--bucket', $bucket, '--public-access-block-configuration',
        'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true') + $p) | Out-Null

$table = Invoke-AwsJson -AllowFailure (@('dynamodb', 'describe-table', '--table-name', $lockTable) + $p)
if (-not $table) {
    Invoke-Native aws (@('dynamodb', 'create-table', '--table-name', $lockTable,
            '--attribute-definitions', 'AttributeName=LockID,AttributeType=S',
            '--key-schema', 'AttributeName=LockID,KeyType=HASH', '--billing-mode', 'PAY_PER_REQUEST') + $p) | Out-Null
    Invoke-Native aws (@('dynamodb', 'wait', 'table-exists', '--table-name', $lockTable) + $p) | Out-Null
    Write-Ok "Created lock table $lockTable"
}
Write-Ok "State: s3://$bucket (versioned, private), lock table $lockTable"

Save-AppRecord $Name @{ stateBucket = $bucket; lockTable = $lockTable; deployerRoleArn = $roleArn }

Write-Host "`nAccount ready: $AccountId  profile: $appProfile" -ForegroundColor Magenta
