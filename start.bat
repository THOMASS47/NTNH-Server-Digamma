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
    exit /b 0
)

rem Java 8 (Minecraft 1.7.10 requires exactly Java 8)
java -version 2>&1 | findstr "1.8" >nul
if errorlevel 1 (
    echo ERROR: Java 8 is required.
    java -version 2>&1
    exit /b 1
)

rem Accept EULA
echo eula=true > eula.txt

rem Resolve LFS pointers if Git LFS is not available
if exist .git (
    git lfs version >nul 2>&1
    if errorlevel 1 (
        echo Resolving LFS pointers (install git-lfs for faster clones)...
        for /r . %%f in (*) do (
            echo %%f | findstr /i /c:"\.git" >nul && set "skip=1" || set "skip="
            if not defined skip (
                set "firstline="
                set /p firstline=<"%%f"
                if defined firstline (
                    echo !firstline! | findstr /c:"version https://git-lfs.github.com/spec/v1" >nul
                    if not errorlevel 1 (
                        set "rel=%%f"
                        set "rel=!rel:%CD%\=!"
                        echo   Downloading: !rel!
                        for /f "delims=" %%e in ('powershell -Command "[System.Uri]::EscapeDataString('!rel!')" 2^>nul') do set "encoded=%%e"
                        if not defined encoded set "encoded=!rel!"
                        curl -sL -o "%%f" "https://github.com/NTNewHorizons/NTNH-Server/raw/main/!encoded!" || echo   FAILED: !rel!
                    )
                )
            )
        )
    )
)

rem JVM options from server-args.txt (can be overridden via JVM_OPTS env var)
if exist server-args.txt (
    set /p JVM_OPTS=<server-args.txt
)

java %JVM_OPTS% -jar server.jar nogui
