param(
    [string]$ForgePath,
    [string]$DeckPath,
    [int]$Games = 40
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ForgePath)) {
    throw "Forge path not found: $ForgePath"
}
if (-not (Test-Path $DeckPath)) {
    throw "Decklist not found: $DeckPath"
}

$Args = @("--ai-sim", $DeckPath, "--games", $Games)
if ($ForgePath.ToLower().EndsWith(".jar")) {
    & java -jar $ForgePath @Args
} else {
    & $ForgePath @Args
}
