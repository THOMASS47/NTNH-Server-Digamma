$ErrorActionPreference = "Stop"
$serverRoot = $PSScriptRoot
if ($env:NTNH_SERVER_ROOT) {
    $serverRoot = [System.IO.Path]::GetFullPath($env:NTNH_SERVER_ROOT)
}
Set-Location $serverRoot

$pointerMarker = "version https://git-lfs.github.com/spec/v1"
$clientRepo = if ($env:NTNH_CLIENT_REPO) { $env:NTNH_CLIENT_REPO } else { "NTNewHorizons/NTNH" }

$candidatePaths = @(
    "forge-1.7.10-10.13.4.1614-1.7.10-universal.jar",
    "minecraft_server.1.7.10.jar"
)
$candidatePaths += @(Get-ChildItem -Path "mods\HBM-*.jar" -File -ErrorAction SilentlyContinue | ForEach-Object FullName)

function Copy-OrDownload([string]$Source, [string]$Destination) {
    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        Copy-Item -LiteralPath $Source -Destination $Destination
    }
    else {
        Invoke-WebRequest -UseBasicParsing -Uri $Source -OutFile $Destination
    }
}

foreach ($path in $candidatePaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        continue
    }
    if ((Get-Content -LiteralPath $path -TotalCount 1 -ErrorAction SilentlyContinue) -ne $pointerMarker) {
        continue
    }

    $relativePath = [System.IO.Path]::GetFullPath($path).Substring($serverRoot.Length + 1).Replace("\", "/")
    switch -Wildcard ($relativePath) {
        "forge-1.7.10-10.13.4.1614-1.7.10-universal.jar" {
            $source = if ($env:NTNH_FORGE_URL) { $env:NTNH_FORGE_URL } else { "https://maven.minecraftforge.net/net/minecraftforge/forge/1.7.10-10.13.4.1614-1.7.10/forge-1.7.10-10.13.4.1614-1.7.10-universal.jar" }
        }
        "minecraft_server.1.7.10.jar" {
            $source = if ($env:NTNH_MINECRAFT_SERVER_URL) { $env:NTNH_MINECRAFT_SERVER_URL } else { "https://launcher.mojang.com/v1/objects/952438ac4e01b4d115c5fc38f891710c4941df29/server.jar" }
        }
        "mods/HBM-*.jar" {
            if ($env:NTNH_HBM_URL) {
                $source = $env:NTNH_HBM_URL
            }
            else {
                $versionPath = Join-Path $serverRoot ".ntnh-version"
                if (-not $env:NTNH_VERSION -and -not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
                    throw "Missing .ntnh-version; cannot select the matching HBM jar."
                }
                $version = if ($env:NTNH_VERSION) { $env:NTNH_VERSION } else { (Get-Content -LiteralPath $versionPath -Raw).Trim() }
                $source = "https://media.githubusercontent.com/media/$clientRepo/$version/$relativePath"
            }
        }
        default {
            throw "No download source configured for $relativePath"
        }
    }

    $pointerLines = Get-Content -LiteralPath $path
    $expectedOid = (($pointerLines | Where-Object { $_ -like "oid sha256:*" } | Select-Object -First 1) -replace "^oid sha256:", "").Trim()
    $expectedSize = [int64](($pointerLines | Where-Object { $_ -like "size *" } | Select-Object -First 1) -replace "^size ", "")
    $downloadPath = "$path.download"

    try {
        Write-Host "Downloading $relativePath from its upstream source..."
        Copy-OrDownload $source $downloadPath

        $actualOid = (Get-FileHash -Algorithm SHA256 -LiteralPath $downloadPath).Hash.ToLowerInvariant()
        $actualSize = (Get-Item -LiteralPath $downloadPath).Length
        if (-not $expectedOid -or $expectedOid -ne $actualOid -or $expectedSize -ne $actualSize) {
            throw "Downloaded $relativePath does not match its Git LFS pointer."
        }

        Move-Item -LiteralPath $downloadPath -Destination $path -Force
        Write-Host "Downloaded and verified $relativePath"
    }
    finally {
        Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
    }
}
