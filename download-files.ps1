$ErrorActionPreference = "Stop"
$serverRoot = $PSScriptRoot
if ($env:NTNH_SERVER_ROOT) {
    $serverRoot = [System.IO.Path]::GetFullPath($env:NTNH_SERVER_ROOT)
}
Set-Location $serverRoot

$pointerMarker = "version https://git-lfs.github.com/spec/v1"

$candidatePaths = @(
    "forge-1.7.10-10.13.4.1614-1.7.10-universal.jar",
    "minecraft_server.1.7.10.jar"
)
$candidatePaths += @(Get-ChildItem -Path "mods\HBM-*.jar" -File -ErrorAction SilentlyContinue | ForEach-Object FullName)

function Test-LfsPointer([string]$Path) {
    return (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -le 4096 -and
        (Get-Content -LiteralPath $Path -TotalCount 1 -ErrorAction SilentlyContinue) -eq $pointerMarker
}

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
    if (-not (Test-LfsPointer $path)) {
        continue
    }

    $relativePath = [System.IO.Path]::GetFullPath($path).Substring($serverRoot.Length + 1).Replace("\", "/")
    $pointerLines = Get-Content -LiteralPath $path
    $expectedOid = (($pointerLines | Where-Object { $_ -like "oid sha256:*" } | Select-Object -First 1) -replace "^oid sha256:", "").Trim()
    $expectedSize = [int64](($pointerLines | Where-Object { $_ -like "size *" } | Select-Object -First 1) -replace "^size ", "")
    $sourceLabel = "its upstream source"

    if ($relativePath -like "mods/HBM-*.jar") {
        $gitCommand = Get-Command git -ErrorAction SilentlyContinue
        if (-not $gitCommand) {
            Write-Warning "Git is unavailable; using the repository LFS media fallback for $relativePath."
        }
        else {
            & git lfs version *> $null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Git LFS is unavailable ('git lfs version' failed); using the repository LFS media fallback for $relativePath."
            }
            else {
                Write-Host "Downloading $relativePath with Git LFS..."
                & git lfs pull "--include=$relativePath" "--exclude="
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "'git lfs pull' failed; using the repository LFS media fallback for $relativePath."
                }
                elseif (Test-LfsPointer $path) {
                    Write-Warning "Git LFS left $relativePath unresolved; using the repository LFS media fallback."
                }
                else {
                    Write-Host "Downloaded and verified $relativePath"
                    continue
                }
            }
        }

        $revision = $env:NTNH_REVISION
        if (-not $revision -and $gitCommand) {
            $revision = (& git rev-parse HEAD 2>$null | Select-Object -First 1)
        }
        if (-not $revision) {
            $revision = "main"
        }
        $serverRepo = if ($env:NTNH_SERVER_REPO) { $env:NTNH_SERVER_REPO } else { "THOMASS47/NTNH-Server-Digamma" }
        $source = if ($env:NTNH_HBM_URL) { $env:NTNH_HBM_URL } else { "https://media.githubusercontent.com/media/$serverRepo/$revision/$relativePath" }
        $sourceLabel = "the repository LFS media fallback"
    }
    else {
        switch -Wildcard ($relativePath) {
        "forge-1.7.10-10.13.4.1614-1.7.10-universal.jar" {
            $source = if ($env:NTNH_FORGE_URL) { $env:NTNH_FORGE_URL } else { "https://maven.minecraftforge.net/net/minecraftforge/forge/1.7.10-10.13.4.1614-1.7.10/forge-1.7.10-10.13.4.1614-1.7.10-universal.jar" }
        }
        "minecraft_server.1.7.10.jar" {
            $source = if ($env:NTNH_MINECRAFT_SERVER_URL) { $env:NTNH_MINECRAFT_SERVER_URL } else { "https://launcher.mojang.com/v1/objects/952438ac4e01b4d115c5fc38f891710c4941df29/server.jar" }
        }
        default {
            throw "No download source configured for $relativePath"
        }
        }
    }

    $downloadPath = "$path.download"

    try {
        Write-Host "Downloading $relativePath from $sourceLabel..."
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
