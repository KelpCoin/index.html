# Navigate to project root
Set-Location -Path "$PSScriptRoot"

try {
    python src/main.py
} catch {
    Write-Host "Error running MTG Arbiter: $_"
}

Write-Host "Run complete. Press Enter to close."
[void][System.Console]::ReadLine()
