$ErrorActionPreference = "Stop"

function Get-RootPath {
    if (Test-Path "C:\\BrownEyeCortex") {
        return "C:\\BrownEyeCortex"
    }

    $current = Split-Path -Parent $PSCommandPath
    while ($true) {
        if ((Split-Path $current -Leaf) -eq "BrownEyeCortex") {
            return $current
        }
        $parent = Split-Path -Parent $current
        if ([string]::IsNullOrWhiteSpace($parent) -or ($parent -eq $current)) {
            break
        }
        $current = $parent
    }

    return (Split-Path -Parent $PSCommandPath)
}

$root = Get-RootPath
$reportPath = Join-Path $root "_moneyfarm\\dashboard_real\\report.html"
Start-Process $reportPath
