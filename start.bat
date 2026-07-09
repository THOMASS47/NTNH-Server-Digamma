@echo off
setlocal enabledelayedexpansion

rem NTNH Server — single entry point (Windows)
rem First run: git clone <url> && start.bat
rem Update:    start.bat --update
rem Normal:    start.bat

if "%1"=="--update" (
    git fetch origin main
    git reset --hard origin/main
    echo Updated to latest version. Run start.bat to start.
    pause
    exit /b 0
)

rem Java 8 (Minecraft 1.7.10 requires exactly Java 8)
java -version 2>&1 | findstr "1.8" >nul
if errorlevel 1 (
    echo ERROR: Java 8 is required.
    java -version 2>&1
    pause
    exit /b 1
)

rem Accept EULA
echo eula=true > eula.txt

rem Resolve LFS pointers if Git LFS is not available
if not exist .git goto :start_server
git lfs version >nul 2>&1
if not errorlevel 1 goto :start_server

echo Resolving LFS pointers (install git-lfs for faster clones)...
powershell -NoProfile -Command ^
  "Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git' } | ForEach-Object { $content = [System.IO.File]::ReadAllText($_.FullName); if ($content.Split([char]10)[0].Trim() -match 'version https://git-lfs.github.com/spec/v1') { $rel = $_.FullName.Substring((Get-Location).Path.Length + 1); Write-Host ('  Downloading: ' + $rel); $enc = [System.Uri]::EscapeDataString($rel); try { Invoke-WebRequest -Uri ('https://github.com/NTNewHorizons/NTNH-Server/raw/main/' + $enc) -OutFile $_.FullName -ErrorAction Stop } catch { Write-Host ('  FAILED: ' + $rel) } } }"

:start_server
rem JVM options from server-args.txt (can be overridden via JVM_OPTS env var)
if exist server-args.txt (
    for /f "usebackq delims=" %%A in ("server-args.txt") do set JVM_OPTS=%%A
)

java %JVM_OPTS% -jar server.jar nogui
pause
