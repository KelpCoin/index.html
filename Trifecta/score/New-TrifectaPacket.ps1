Set-StrictMode -Version Latest

function New-TrifectaPacket {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Subject,

        [Parameter(Mandatory = $true)]
        [ValidateSet('idea', 'revenue_cell', 'prompt', 'module', 'decision', 'offer', 'other')]
        [string]$SubjectType,

        [Parameter(Mandatory = $true)]
        [hashtable]$SignalA,

        [Parameter(Mandatory = $true)]
        [hashtable]$SignalB,

        [Parameter(Mandatory = $true)]
        [hashtable]$SignalC,

        [Parameter()]
        [hashtable]$Context = @{},

        [Parameter()]
        [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\\examples\\packets')
    )

    if (-not (Test-Path -Path $OutputDirectory)) {
        New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
    }

    $createdUtc = [DateTime]::UtcNow.ToString('s') + 'Z'

    $signals = [ordered]@{
        A = [ordered]@{
            label = [string]$SignalA.label
            strength = [double]$SignalA.strength
            confidence = [double]$SignalA.confidence
            evidence = @($SignalA.evidence)
        }
        B = [ordered]@{
            label = [string]$SignalB.label
            strength = [double]$SignalB.strength
            confidence = [double]$SignalB.confidence
            evidence = @($SignalB.evidence)
        }
        C = [ordered]@{
            label = [string]$SignalC.label
            strength = [double]$SignalC.strength
            confidence = [double]$SignalC.confidence
            evidence = @($SignalC.evidence)
            mode = [string]$SignalC.mode
            orientation = [string]$SignalC.orientation
            veto = [bool]$SignalC.veto
        }
    }

    $fingerprintSource = [ordered]@{
        subject = $Subject
        subject_type = $SubjectType
        signals = $signals
        context = $Context
    }

    $json = $fingerprintSource | ConvertTo-Json -Depth 8 -Compress
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json))
    }
    finally {
        $sha.Dispose()
    }
    $packetHash = ([BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
    $packetId = 'trifecta-' + $packetHash.Substring(0, 16)

    $packet = [ordered]@{
        packet_id = $packetId
        subject = $Subject
        subject_type = $SubjectType
        created_utc = $createdUtc
        context = $Context
        signals = $signals
    }

    $packetPath = Join-Path $OutputDirectory ($packetId + '.json')
    $packet | ConvertTo-Json -Depth 8 | Set-Content -Path $packetPath -Encoding ascii

    [pscustomobject]@{
        packet = $packet
        packet_path = $packetPath
    }
}
