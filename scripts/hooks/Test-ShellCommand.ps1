# Kiro hook (PreToolUse, shell tools): blocks infrastructure commands that
# must go through the reviewed pipeline or a human.
#   exit 0 = allow, exit 2 = block (stderr goes back to the agent).

$ErrorActionPreference = 'Continue'
$raw = [Console]::In.ReadToEnd()
$text = $raw
try {
    $evt = $raw | ConvertFrom-Json
    if ($evt.tool_input) { $text = $evt.tool_input | ConvertTo-Json -Depth 8 -Compress }
} catch { }

# Normalize JSON escapes so patterns see the command as typed.
$cmd = $text -replace '\\\\', '\' -replace '\\"', '"'

$rules = @(
    @{ Pattern = 'terraform(\.exe)?["'']?\s[^|;&\r\n]*?\bdestroy\b'
       Why = 'terraform destroy is never run by the agent. Explain what would be destroyed and let the human decide and run it.' },
    @{ Pattern = '-auto-approve'
       Why = '-auto-approve skips review. Run .\scripts\Plan-App.ps1, present the impact summary, and wait for an explicit yes.' },
    @{ Pattern = 'terraform(\.exe)?["'']?\s[^|;&\r\n]*?\bapply\b'
       Why = 'Direct terraform apply is blocked. Use .\scripts\Plan-App.ps1, present the plan, wait for an explicit yes, then .\scripts\Apply-App.ps1 (it applies exactly the saved plan).' },
    @{ Pattern = 'terraform(\.exe)?["'']?\s[^|;&\r\n]*?\b(state\s+(rm|push|mv)|force-unlock|import|taint)\b'
       Why = 'Terraform state surgery needs a human. Describe the problem and the exact command; do not run it.' },
    @{ Pattern = 'Apply-App\.ps1[^|;&\r\n]*-AllowDestroy'
       Why = '-AllowDestroy is for a human only, after reviewing the deletes and replaces in the plan.' },
    @{ Pattern = '\baws(\.exe)?\s+(s3\s+rb\b|s3\s+rm\b[^|;&\r\n]*--recursive|dynamodb\s+delete-table|organizations\s+(close-account|remove-account-from-organization|detach-policy|delete-policy|delete-organizational-unit)|cloudfront\s+delete-distribution|iam\s+delete-role\b)'
       Why = 'Destructive AWS CLI commands are blocked. Make infrastructure changes through Terraform and the pipeline scripts.' }
)

foreach ($rule in $rules) {
    if ($cmd -match $rule.Pattern) {
        [Console]::Error.WriteLine("BLOCKED by the Skeleton Crew guardrail hook: $($rule.Why)")
        exit 2
    }
}
exit 0
