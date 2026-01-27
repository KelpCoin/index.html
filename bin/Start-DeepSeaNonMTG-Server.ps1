param(
    [switch]$Once
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-ModuleRoot {
    if (Test-Path 'D:\') {
        return 'D:\BrownEyeCortex_moneyfarm\DeepSeaNonMTG'
    }
    return 'C:\BrownEyeCortex_moneyfarm\DeepSeaNonMTG'
}

$moduleRoot = Get-ModuleRoot
$publicDir = Join-Path $moduleRoot 'public'
$outDir = Join-Path $moduleRoot 'out'
$prefix = 'http://127.0.0.1:8787/'

function Get-ContentType($path) {
    switch ([IO.Path]::GetExtension($path).ToLowerInvariant()) {
        '.html' { return 'text/html' }
        '.json' { return 'application/json' }
        '.zip' { return 'application/zip' }
        '.txt' { return 'text/plain' }
        '.css' { return 'text/css' }
        '.js' { return 'application/javascript' }
        default { return 'application/octet-stream' }
    }
}

function Resolve-SafePath($baseDir, $relativePath) {
    $fullBase = [IO.Path]::GetFullPath($baseDir)
    $combined = [IO.Path]::GetFullPath((Join-Path $baseDir $relativePath))
    if (-not $combined.StartsWith($fullBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    return $combined
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serving $publicDir at $prefix"
Write-Host 'Press Ctrl+C to stop.'

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $requestPath = $context.Request.Url.AbsolutePath
        if ([string]::IsNullOrWhiteSpace($requestPath) -or $requestPath -eq '/') {
            $requestPath = '/index.html'
        }

        $relative = $requestPath.TrimStart('/')
        if ($relative.StartsWith('out/')) {
            $relative = $relative.Substring(4)
            $filePath = Resolve-SafePath $outDir $relative
        } else {
            $filePath = Resolve-SafePath $publicDir $relative
        }

        if ($null -ne $filePath -and (Test-Path $filePath)) {
            $bytes = [IO.File]::ReadAllBytes($filePath)
            $context.Response.ContentType = Get-ContentType $filePath
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.StatusCode = 200
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $message = 'Not Found'
            $buffer = [Text.Encoding]::UTF8.GetBytes($message)
            $context.Response.StatusCode = 404
            $context.Response.ContentType = 'text/plain'
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        $context.Response.OutputStream.Close()

        if ($Once) {
            break
        }
    }
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
}
