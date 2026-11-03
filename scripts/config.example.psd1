# Copy to scripts\config.local.psd1 (gitignored) and fill in your values.
@{
    # AWS CLI profile for your Organization's management account. It needs
    # organizations:CreateAccount/DescribeCreateAccountStatus/ListAccounts and
    # sts:AssumeRole on OrganizationAccountAccessRole in member accounts.
    ManagementProfile    = 'org-management'

    # Root email for each new app account. {name} becomes the app name.
    # Plus-addressing keeps every account on one inbox.
    AccountEmailTemplate = 'you+kw-{name}@example.com'

    # Account display name in Organizations: "<prefix><name>".
    AccountNamePrefix    = 'Kiroween '

    # Local AWS CLI profile per app: "<prefix><name>" (assumes the deployer role).
    ProfilePrefix        = 'kw-'

    # Role created in every app account for Terraform. It is NOT exempt from
    # your SCPs (OrganizationAccountAccessRole often is), so the guardrails hold.
    DeployerRoleName     = 'skeleton-deployer'

    # Project OU and its project-only SCP (scripts\Setup-Org.ps1). Every app
    # account is moved into this OU; the SCP is attached to it and nowhere else.
    OrgUnitName          = 'Kiroween-2026'
    ScpName              = 'Kiroween2026Guardrails'

    # Alarms, the cost budget, and crew alerts go here.
    AlertEmail           = 'you@example.com'

    # Terraform 1.7+ binary, and an optional local provider mirror
    # (leave empty to download providers from the registry).
    TerraformBinary      = 'terraform'
    TerraformPluginDir   = ''

    # Profile of the account that hosts the crew alerts SNS topic
    # (scripts\Setup-CrewAlerts.ps1). Typically a small "crew" account made
    # with New-AppAccount.ps1 -Name crew.
    CrewAlertsProfile    = 'kw-crew'

    # GitHub owner for the repo (used in docs and gh commands).
    GitHubOwner          = 'your-github-user'
}
