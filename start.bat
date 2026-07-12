@echo off
setlocal enabledelayedexpansion

rem NTNH Server — single entry point (Windows)
rem First run: git clone <url> && start.bat
rem Update:    start.bat --update
rem Normal:    start.bat

rem Determine if script should pause on exit/error (disables pause in headless environments like Crafty/Pterodactyl)
set "should_pause=1"
if not "%CRAFTY%"=="" set "should_pause=0"
if not "%PTERODACTYL%"=="" set "should_pause=0"
if not "%NO_PAUSE%"=="" set "should_pause=0"
if not "%NON_INTERACTIVE%"=="" set "should_pause=0"

if "%1"=="--update" (
    git fetch origin main
    git reset --hard origin/main
    echo Updated to latest version. Run start.bat to start.
    if "%should_pause%"=="1" pause
    exit /b 0
)

rem 1. Determine Java executable path (can be overridden by JAVA_CMD, JAVA_PATH, or JAVA_HOME)
set "JAVA_EXEC="
if not "%JAVA_CMD%"=="" (
    set "JAVA_EXEC=%JAVA_CMD%"
    goto :check_java
)
if not "%JAVA_PATH%"=="" (
    set "JAVA_EXEC=%JAVA_PATH%"
    goto :check_java
)
if not "%JAVA_HOME%"=="" (
    if exist "%JAVA_HOME%\bin\java.exe" (
        set "JAVA_EXEC=%JAVA_HOME%\bin\java.exe"
        goto :check_java
    )
)

rem 2. Check default java command in PATH first
java -version 2>&1 | findstr "1.8" >nul
if not errorlevel 1 (
    set "JAVA_EXEC=java"
    goto :java_found
)

rem 3. Search paths from 'where java'
for /f "delims=" %%I in ('where java 2^>nul') do (
    "%%I" -version 2>&1 | findstr "1.8" >nul
    if not errorlevel 1 (
        set "JAVA_EXEC=%%I"
        goto :java_found
    )
)

rem 4. Auto-detect Java 8 in common directories
for /d %%D in (
    "C:\Program Files\Java\jdk1.8.*"
    "C:\Program Files\Java\jre1.8.*"
    "C:\Program Files\AdoptOpenJDK\jdk-8.*"
    "C:\Program Files\Eclipse Adoptium\jdk-8.*"
    "C:\Program Files (x86)\Java\jre1.8.*"
) do (
    if exist "%%D\bin\java.exe" (
        "%%D\bin\java.exe" -version 2>&1 | findstr "1.8" >nul
        if not errorlevel 1 (
            set "JAVA_EXEC=%%D\bin\java.exe"
            goto :java_found
        )
    )
)

:check_java
if not "%JAVA_EXEC%"=="" (
    "%JAVA_EXEC%" -version 2>&1 | findstr "1.8" >nul
    if not errorlevel 1 goto :java_found
)

echo ERROR: Java 8 is required. None was found.
if exist "%JAVA_EXEC%" (
    echo Selected Java version:
    "%JAVA_EXEC%" -version 2>&1
) else (
    java -version 2>&1
)
echo Please set JAVA_CMD, JAVA_PATH, or JAVA_HOME to point to your Java 8 installation.
if "%should_pause%"=="1" pause
exit /b 1

:java_found
rem Accept EULA
echo eula=true > eula.txt

rem 5. Resolve LFS pointers using direct download if they are still pointers
set "need_lfs_resolve=0"
if not exist .git (
    rem Check if server.jar is a pointer file
    powershell -NoProfile -Command "if ((Get-Content -Path 'server.jar' -Head 1 -ErrorAction SilentlyContinue) -like 'version https://git-lfs.github.com/spec/v1*') { exit 1 } else { exit 0 }"
    if errorlevel 1 set "need_lfs_resolve=1"
) else (
    git lfs version >nul 2>&1
    if errorlevel 1 (
        set "need_lfs_resolve=1"
    ) else (
        git lfs pull 2>nul || true
    )
)

if "%need_lfs_resolve%"=="1" (
    echo Resolving Git LFS pointers...
    powershell -NoProfile -Command ^
      "$repo_url = 'https://github.com/THOMASS47/NTNH-Server-Digamma/raw/main'; ^
       if (Test-Path .git) { ^
           $git_url = (git remote get-url origin 2>$null); ^
           if ($git_url) { ^
               $clean_url = $git_url -replace 'git@github.com:', 'https://github.com/' -replace '\.git$', ''; ^
               $git_branch = (git branch --show-current 2>$null); ^
               if (-not $git_branch) { $git_branch = (git rev-parse --abbrev-ref HEAD 2>$null) }; ^
               if (-not $git_branch) { $git_branch = 'main' }; ^
               $repo_url = \"${clean_url}/raw/${git_branch}\" ^
           } ^
       }; ^
       Write-Host \"Using source raw URL: $repo_url\"; ^
       Get-ChildItem -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git' } | ForEach-Object { ^
           $content = [System.IO.File]::ReadAllText($_.FullName); ^
           if ($content.Split([char]10)[0].Trim() -match 'version https://git-lfs.github.com/spec/v1') { ^
               $rel = $_.FullName.Substring((Get-Location).Path.Length + 1); ^
               Write-Host ('  Downloading: ' + $rel); ^
               $enc = [System.Uri]::EscapeDataString($rel); ^
               try { ^
                   Invoke-WebRequest -Uri ($repo_url + '/' + $enc) -OutFile $_.FullName -ErrorAction Stop ^
               } catch { ^
                   Write-Host ('  FAILED: ' + $rel) ^
               } ^
           } ^
       }"
)

:start_server
rem JVM options from server-args.txt (can be overridden via JVM_OPTS env var)
if exist server-args.txt (
    for /f "usebackq delims=" %%A in ("server-args.txt") do set JVM_OPTS=%%A
)

rem Check if "-jar" is already in the arguments
set "has_jar=0"
if not "%~1"=="" (
    for %%x in (%*) do (
        if "%%x"=="-jar" set "has_jar=1"
    )
)

if "%has_jar%"=="1" (
    "%JAVA_EXEC%" %JVM_OPTS% %*
) else (
    if "%~1"=="" (
        "%JAVA_EXEC%" %JVM_OPTS% -jar server.jar nogui
    ) else (
        "%JAVA_EXEC%" %JVM_OPTS% -jar server.jar %*
    )
)

if "%should_pause%"=="1" pause
