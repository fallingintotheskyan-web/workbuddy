# Serves the real web build (client/build/web) on http://127.0.0.1:8080/
# Windows PowerShell only, no Python/Node required.
$ErrorActionPreference = 'Stop'

$root = Join-Path $PSScriptRoot 'build\web'
$port = 8080

if (-not (Test-Path (Join-Path $root 'index.html'))) {
    Write-Host "build\web\index.html not found. Run 'flutter build web' first."
    Read-Host "Press Enter to exit"
    exit 1
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
try {
    $listener.Start()
} catch {
    Write-Host "Port $port is already in use. Close the other program and try again."
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Classroom Notes (real web): http://127.0.0.1:$port/"
Write-Host "Keep this window open. Close it to stop the server."
Start-Process "http://127.0.0.1:$port/"

$mime = @{
    '.html' = 'text/html; charset=utf-8'
    '.htm'  = 'text/html; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.mjs'  = 'application/javascript; charset=utf-8'
    '.wasm' = 'application/wasm'
    '.json' = 'application/json; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.gif'  = 'image/gif'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
    '.mp4'  = 'video/mp4'
    '.webm' = 'video/webm'
    '.ttf'  = 'font/ttf'
    '.otf'  = 'font/otf'
    '.woff' = 'font/woff'
    '.woff2' = 'font/woff2'
    '.map'  = 'application/json; charset=utf-8'
    '.bin'  = 'application/octet-stream'
    '.txt'  = 'text/plain; charset=utf-8'
    '.md'   = 'text/plain; charset=utf-8'
}

while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $stream.ReadTimeout = 3000
        $stream.WriteTimeout = 10000

        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
        $requestLine = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($requestLine)) { continue }

        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line -or $line -eq '') { break }
        }

        $parts = $requestLine.Split(' ')
        if ($parts.Length -lt 2) { continue }
        $method = $parts[0].ToUpperInvariant()
        $rawPath = $parts[1]
        $path = $rawPath.Split('?')[0]
        $decoded = [System.Uri]::UnescapeDataString($path)
        if ([string]::IsNullOrEmpty($decoded) -or $decoded -eq '/') { $decoded = '/index.html' }

        $relative = $decoded.TrimStart('/') -replace '/', '\'
        $file = Join-Path $root $relative
        if (Test-Path -LiteralPath $file -PathType Container) {
            $file = Join-Path $file 'index.html'
        }

        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            $status = '404 Not Found'
            $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $decoded")
            $contentType = 'text/plain; charset=utf-8'
        } else {
            $status = '200 OK'
            $body = [System.IO.File]::ReadAllBytes($file)
            $ext = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
            $contentType = $mime[$ext]
            if (-not $contentType) { $contentType = 'application/octet-stream' }
        }

        $header = "HTTP/1.1 $status`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nCache-Control: no-store`r`n`r`n"
        $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        if ($method -ne 'HEAD') {
            $stream.Write($body, 0, $body.Length)
        }
        $stream.Flush()
    } catch {
    } finally {
        try { $client.Close() } catch { }
    }
}
