# Kiro hook (PostTaskExec): emails the crew when a spec task completes.
# Reads the hook event JSON from stdin. Never fails the agent: always exit 0.

$ErrorActionPreference = 'Continue'
try {
    . "$PSScriptRoot\..\lib\Common.ps1"
    $raw = [Console]::In.ReadToEnd()

    # Keep the last events for debugging hook payloads (gitignored).
    $log = Join-Path $script:LocalDir 'hook-events.log'
    if (-not (Test-Path $script:LocalDir)) { New-Item -ItemType Directory -Path $script:LocalDir -Force | Out-Null }
    $snippet = if ($raw.Length -gt 4000) { $raw.Substring(0, 4000) } else { $raw }
    Add-Content -Path $log -Value ("{0} PostTaskExec {1}" -f (Get-Date -Format o), $snippet)

    $evt = $null
    try { $evt = $raw | ConvertFrom-Json } catch { }

    # The payload shape is not documented; look for the first task-like text.
    function Find-Text($node, [int]$depth = 0) {
        if ($null -eq $node -or $depth -gt 4) { return $null }
        if ($node -is [string]) { return $null }
        foreach ($key in 'task_description', 'taskDescription', 'task_name', 'taskName', 'title', 'description', 'name', 'task') {
            $prop = $node.PSObject.Properties[$key]
            if ($prop -and $prop.Value -is [string] -and $prop.Value.Trim()) { return $prop.Value.Trim() }
        }
        foreach ($prop in $node.PSObject.Properties) {
            if ($prop.Value -and $prop.Value -isnot [string] -and $prop.Value -isnot [ValueType]) {
                $found = Find-Text $prop.Value ($depth + 1)
                if ($found) { return $found }
            }
        }
        return $null
    }

    $task = if ($evt) { Find-Text $evt } else { $null }
    if (-not $task) { $task = 'a spec task' }
    $app = Get-ActiveApp
    $where = if ($app) { " ($app)" } else { '' }
    $shortTask = if ($task.Length -gt 60) { $task.Substring(0, 57) + '...' } else { $task }

    $sent = Send-CrewAlert "Kiro finished a task$where" ("Kiro completed: {0}`nApp: {1}`nTime: {2}" -f $task, $(if ($app) { $app } else { '(none active)' }), (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    if ($sent) { Write-Output "Crew alert sent for: $shortTask" } else { Write-Output "Crew alert not sent for: $shortTask" }
} catch {
    Write-Output "Task alert skipped: $($_.Exception.Message)"
}
exit 0
