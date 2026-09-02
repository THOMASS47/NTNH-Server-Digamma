@echo off
setlocal enabledelayedexpansion
set "GIT_LFS_SKIP_SMUDGE=1"

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

set "auto_update=0"
if "%AUTO_UPDATE%"=="true" set "auto_update=1"

rem Filter out --auto-update from arguments
set "filtered_args="
if not "%~1"=="" (
    for %%x in (%*) do (
        if "%%x"=="--auto-update" (
            set "auto_update=1"
        ) else (
            if "!filtered_args!"=="" (
                set "filtered_args=%%x"
            ) else (
                set "filtered_args=!filtered_args! %%x"
            )
        )
    )
)

if "%auto_update%"=="1" (
    echo Updating repository...
    git fetch origin main 2>nul
    git reset --hard origin/main 2>nul
)

if "%1"=="--update" (
    git fetch origin main
    git reset --hard origin/main
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resolve-release.ps1"
    if errorlevel 1 (
        if "%should_pause%"=="1" pause
        exit /b 1
    )
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
powershell -NoProfile -Command "$v=(java -version 2>&1 | Select-String 'version \"(.*?)\"').Matches.Groups[1].Value; $m=if($v.StartsWith('1.')){$v.Split('.')[1]}else{$v.Split('.')[0]}; if([int]$m -ge 17){exit 0}else{exit 1}" >nul 2>&1
if not errorlevel 1 (
    set "JAVA_EXEC=java"
    goto :java_found
)

rem 3. Search paths from 'where java'
for /f "delims=" %%I in ('where java 2^>nul') do (
    powershell -NoProfile -Command "$v=('%%I' -version 2>&1 | Select-String 'version \"(.*?)\"').Matches.Groups[1].Value; $m=if($v.StartsWith('1.')){$v.Split('.')[1]}else{$v.Split('.')[0]}; if([int]$m -ge 17){exit 0}else{exit 1}" >nul 2>&1
    if not errorlevel 1 (
        set "JAVA_EXEC=%%I"
        goto :java_found
    )
)

rem 4. Auto-detect Java 17/21 in common directories
for /d %%D in (
    "C:\Program Files\Java\jdk-21*"
    "C:\Program Files\Java\jdk-17*"
    "C:\Program Files\Eclipse Adoptium\jdk-21*"
    "C:\Program Files\Eclipse Adoptium\jdk-17*"
    "C:\Program Files\AdoptOpenJDK\jdk-21*"
    "C:\Program Files\AdoptOpenJDK\jdk-17*"
    "C:\Program Files\Java\jdk17*"
    "C:\Program Files\Java\jdk21*"
    "C:\Program Files\Java\jdk-*"
    "C:\Program Files\Eclipse Adoptium\jdk-*"
) do (
    if exist "%%D\bin\java.exe" (
        powershell -NoProfile -Command "$v=('%%D\bin\java.exe' -version 2>&1 | Select-String 'version \"(.*?)\"').Matches.Groups[1].Value; $m=if($v.StartsWith('1.')){$v.Split('.')[1]}else{$v.Split('.')[0]}; if([int]$m -ge 17){exit 0}else{exit 1}" >nul 2>&1
        if not errorlevel 1 (
            set "JAVA_EXEC=%%D\bin\java.exe"
            goto :java_found
        )
    )
)

:check_java
if not "%JAVA_EXEC%"=="" (
    powershell -NoProfile -Command "$v=(& '%JAVA_EXEC%' -version 2>&1 | Select-String 'version \"(.*?)\"').Matches.Groups[1].Value; $m=if($v.StartsWith('1.')){$v.Split('.')[1]}else{$v.Split('.')[0]}; if([int]$m -ge 17){exit 0}else{exit 1}" >nul 2>&1
    if not errorlevel 1 goto :java_found
)

echo ERROR: Java 17 or higher is required for LWJGL3ify. None was found.
if exist "%JAVA_EXEC%" (
    echo Selected Java version:
    "%JAVA_EXEC%" -version 2>&1
) else (
    java -version 2>&1
)
echo Please set JAVA_CMD, JAVA_PATH, or JAVA_HOME to point to your Java 17+ / 21+ installation.
if "%should_pause%"=="1" pause
exit /b 1

:java_found
rem Accept EULA
echo eula=true > eula.txt

rem 5. Materialize large-file pointers from the checksum-verified NTNH release.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0resolve-release.ps1"
if errorlevel 1 (
    if "%should_pause%"=="1" pause
    exit /b 1
)

:start_server
rem JVM options from server-args.txt (can be overridden via JVM_OPTS env var)
if exist server-args.txt (
    for /f "usebackq delims=" %%A in ("server-args.txt") do set JVM_OPTS=%%A
)

rem Check if "-jar" is already in the filtered arguments
set "has_jar=0"
if not "!filtered_args!"=="" (
    for %%x in (!filtered_args!) do (
        if "%%x"=="-jar" set "has_jar=1"
    )
)

if "%has_jar%"=="1" (
    "%JAVA_EXEC%" %JVM_OPTS% @java9args.txt !filtered_args!
) else (
    if "!filtered_args!"=="" (
        "%JAVA_EXEC%" %JVM_OPTS% @java9args.txt -jar lwjgl3ify-forgePatches.jar nogui
    ) else (
        "%JAVA_EXEC%" %JVM_OPTS% @java9args.txt -jar lwjgl3ify-forgePatches.jar !filtered_args!
    )
)

if "%should_pause%"=="1" pause
