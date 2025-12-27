param(
    [Parameter(Mandatory=$false)][string]$Command = "status",
    [Parameter(Mandatory=$false)][string]$Subsystem = "all",
    [Parameter(Mandatory=$false)][string]$ApprovedBy = "operator",
    [Parameter(Mandatory=$false)][string]$To = "last-known-good"
)

function Invoke-Supervisor {
    param(
        [string]$Args
    )
    python -m supervisor.cli $Args
}

switch ($Command) {
    "status" { Invoke-Supervisor "status" }
    "freeze" { Invoke-Supervisor "freeze $Subsystem" }
    "unfreeze" { Invoke-Supervisor "freeze $Subsystem --unfreeze" }
    "rollback" { Invoke-Supervisor "rollback $Subsystem --to $To --approved-by $ApprovedBy" }
    "resume" { Invoke-Supervisor "resume $Subsystem --approved-by $ApprovedBy" }
    default { Write-Output "Unknown command. Use status|freeze|unfreeze|rollback|resume." }
}
