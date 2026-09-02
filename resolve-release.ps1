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

$pointers = @()
foreach ($path in $candidatePaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        continue
    }
    $firstLine = Get-Content -LiteralPath $path -TotalCount 1 -ErrorAction SilentlyContinue
    if ($firstLine -eq $pointerMarker) {
        $pointers += (Resolve-Path -LiteralPath $path).Path
    }
}

if ($pointers.Count -eq 0) {
    exit 0
}

$versionPath = Join-Path $serverRoot ".ntnh-version"
if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    throw "Missing .ntnh-version; cannot select the matching release."
}

$version = (Get-Content -LiteralPath $versionPath -Raw).Trim()
if ($env:NTNH_VERSION) {
    $version = $env:NTNH_VERSION
}
$repo = "NTNewHorizons/NTNH-Server"
if ($env:NTNH_RELEASE_REPO) {
    $repo = $env:NTNH_RELEASE_REPO
}
$zipUrl = "https://github.com/$repo/releases/download/$version/ntnh-server-$version.zip"
if ($env:NTNH_RELEASE_ZIP_URL) {
    $zipUrl = $env:NTNH_RELEASE_ZIP_URL
}
$sumUrl = "$zipUrl.sha256"
if ($env:NTNH_RELEASE_SUM_URL) {
    $sumUrl = $env:NTNH_RELEASE_SUM_URL
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ntnh-release-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
$archivePath = Join-Path $tempRoot "ntnh-server-$version.zip"

function Copy-OrDownload([string]$Source, [string]$Destination) {
    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        Copy-Item -LiteralPath $Source -Destination $Destination
    }
    else {
        Invoke-WebRequest -UseBasicParsing -Uri $Source -OutFile $Destination
    }
}

try {
    Write-Host "Downloading NTNH Server $version release..."
    Copy-OrDownload $zipUrl $archivePath

    if (Test-Path -LiteralPath $sumUrl -PathType Leaf) {
        $sumContent = Get-Content -LiteralPath $sumUrl -Raw
    }
    else {
        $sumContent = (Invoke-WebRequest -UseBasicParsing -Uri $sumUrl).Content
    }
    $expectedArchiveHash = (($sumContent -split "\s+")[0]).ToLowerInvariant()
    $actualArchiveHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
    if (-not $expectedArchiveHash -or $expectedArchiveHash -ne $actualArchiveHash) {
        throw "Release archive checksum mismatch."
    }
    Write-Host "Release checksum verified."

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        foreach ($pointerPath in $pointers) {
            $relativePath = $pointerPath.Substring($serverRoot.Length + 1).Replace("\", "/")
            $entry = $archive.Entries | Where-Object FullName -eq $relativePath | Select-Object -First 1
            if (-not $entry) {
                throw "Release archive does not contain $relativePath"
            }

            $pointerLines = Get-Content -LiteralPath $pointerPath
            $expectedOid = (($pointerLines | Where-Object { $_ -like "oid sha256:*" } | Select-Object -First 1) -replace "^oid sha256:", "").Trim()
            $expectedSize = [int64](($pointerLines | Where-Object { $_ -like "size *" } | Select-Object -First 1) -replace "^size ", "")
            $downloadPath = "$pointerPath.download"

            $sourceStream = $entry.Open()
            $destinationStream = [System.IO.File]::Create($downloadPath)
            try {
                $sourceStream.CopyTo($destinationStream)
            }
            finally {
                $destinationStream.Dispose()
                $sourceStream.Dispose()
            }

            $actualOid = (Get-FileHash -Algorithm SHA256 -LiteralPath $downloadPath).Hash.ToLowerInvariant()
            $actualSize = (Get-Item -LiteralPath $downloadPath).Length
            if ($expectedOid -ne $actualOid -or $expectedSize -ne $actualSize) {
                throw "Release copy of $relativePath does not match its pointer."
            }

            Move-Item -LiteralPath $downloadPath -Destination $pointerPath -Force
            Write-Host "Materialized $relativePath"
        }
    }
    finally {
        $archive.Dispose()
    }
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
