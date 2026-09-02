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
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0download-files.ps1"
    if errorlevel 1 (
        if "%should_pause%"=="1" pause
        exit /b 1
    )
    echo Updated to latest version. Run start.bat to start.
    if "%should_pause%"=="1" pause
    exit /b 0
)


rem Find the first Java 17+ override or PATH entry.
set "JAVA_EXEC="
if defined JAVA_CMD call :try_java "%JAVA_CMD%"
if defined JAVA_EXEC goto :java_found
if defined JAVA_PATH call :try_java "%JAVA_PATH%"
if defined JAVA_EXEC goto :java_found
if defined JAVA_HOME call :try_java "%JAVA_HOME%\bin\java.exe"
if defined JAVA_EXEC goto :java_found

for /f "delims=" %%I in ('where java 2^>nul') do (
    if not defined JAVA_EXEC call :try_java "%%I"
)
if defined JAVA_EXEC goto :java_found

echo ERROR: Java 17 or higher is required for LWJGL3ify. None was found.
echo Add Java 17+ to PATH or set JAVA_CMD, JAVA_PATH, or JAVA_HOME.
if "%should_pause%"=="1" pause
exit /b 1

:try_java
if not exist "%~1" exit /b 0
powershell -NoProfile -Command "$v=((& '%~1' -version 2>&1 | Select-Object -First 1) -split [char]34)[1].Split('.'); $major=if ($v[0] -eq '1') { [int]$v[1] } else { [int]$v[0] }; if ($major -ge 17) { exit 0 } else { exit 1 }" >nul 2>&1
if not errorlevel 1 set "JAVA_EXEC=%~1"
exit /b 0

:java_found
rem Accept EULA
echo eula=true > eula.txt

rem Download large files from their upstream sources.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0download-files.ps1"
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
