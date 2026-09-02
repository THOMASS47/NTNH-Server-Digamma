#!/bin/bash
set -e

# Configure stop trigger (used when server shuts down cleanly with exit code 0)
# If the server stops cleanly, it will only stop if this string is found in the logs.
# Otherwise, it will automatically restart.
STOP_STRING="${STOP_STRING:-jarvisnukethisshit}"
LOG_FILE="${LOG_FILE:-logs/latest.log}"

# List of users allowed to trigger the stop string
# e.g., AUTHORIZED_USERS=("THOMASS47" "AnotherUser")
AUTHORIZED_USERS=("THOMASS47")

# NTNH Server — single entry point
# First run: git clone <url> && ./start.sh
# Update:    ./start.sh --update
# Normal:    ./start.sh

# Filter out --auto-update argument to avoid passing it to Java
auto_update=false
new_args=()
for arg in "$@"; do
    if [ "$arg" = "--auto-update" ]; then
        auto_update=true
    else
        new_args+=("$arg")
    fi
done
set -- "${new_args[@]}"

# Helper function to check if a file is an LFS pointer
is_lfs_pointer() {
    [ -f "$1" ] && head -n1 "$1" 2>/dev/null | grep -q "version https://git-lfs.github.com/spec/v1"
}

# Download any large-file pointers without requiring Git LFS.
download_lfs_files() {
    local pointer
    for pointer in \
        "forge-1.7.10-10.13.4.1614-1.7.10-universal.jar" \
        "minecraft_server.1.7.10.jar" \
        mods/HBM-*.jar; do
        if is_lfs_pointer "$pointer"; then
            bash ./download-files.sh
            return
        fi
    done
}

# Helper function to check and apply updates
check_and_update() {
    echo "Checking for repository updates..."
    git fetch origin main 2>/dev/null || true
    
    local HEAD_HASH=$(git rev-parse HEAD 2>/dev/null || echo "1")
    local REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null || echo "2")
    
    if [ "$HEAD_HASH" != "$REMOTE_HASH" ]; then
        echo "New updates found! Applying updates..."
        GIT_LFS_SKIP_SMUDGE=1 git reset --hard origin/main 2>/dev/null || true
        download_lfs_files
    else
        echo "Repository is already up to date."
    fi
}

# Perform update if requested
if [ "$auto_update" = "true" ] || [ "$AUTO_UPDATE" = "true" ] || [ "$1" = "--update" ]; then
    check_and_update
    if [ "$1" = "--update" ]; then
        echo "Update check complete. Run ./start.sh to start."
        exit 0
    fi
fi

# Find the first Java 17+ override or PATH entry.
is_java_17_plus() {
    local java="$1" version major
    [ -x "$java" ] || command -v "$java" >/dev/null 2>&1 || return 1
    version=$("$java" -version 2>&1 | head -n1)
    version="${version#*\"}"
    version="${version%%\"*}"
    major="${version%%.*}"
    if [ "$major" = "1" ]; then
        version="${version#*.}"
        major="${version%%.*}"
    fi
    case "$major" in
        ''|*[!0-9]*) return 1 ;;
    esac
    [ "$major" -ge 17 ]
}

JAVA_EXEC=""
for candidate in \
    "${JAVA_CMD:-}" \
    "${JAVA_PATH:-}" \
    "${JAVA_HOME:+$JAVA_HOME/bin/java}"; do
    if [ -n "$candidate" ] && is_java_17_plus "$candidate"; then
        JAVA_EXEC="$candidate"
        break
    fi
done

if [ -z "$JAVA_EXEC" ]; then
    while IFS= read -r candidate; do
        if is_java_17_plus "$candidate"; then
            JAVA_EXEC="$candidate"
            break
        fi
    done < <(type -aP java 2>/dev/null)
fi

if [ -z "$JAVA_EXEC" ]; then
    echo "ERROR: Java 17 or higher is required for LWJGL3ify. None was found."
    echo "Add Java 17+ to PATH or set JAVA_CMD, JAVA_PATH, or JAVA_HOME."
    exit 1
fi

# Download large files from their upstream sources when necessary.
download_lfs_files

# JVM options from server-args.txt (can be overridden via JVM_OPTS env var)
if [ -f server-args.txt ] && [ -z "${JVM_OPTS+set}" ]; then
    JVM_OPTS=$(tr '\n' ' ' < server-args.txt)
fi

# Check if "-jar" is already in the arguments
has_jar=false
for arg in "$@"; do
    if [ "$arg" = "-jar" ]; then
        has_jar=true
        break
    fi
done

# 5. Execute java in a controlled loop (handling auto-restart)
while true; do
    if [ "$has_jar" = true ]; then
        "$JAVA_EXEC" $JVM_OPTS @java9args.txt "$@"
    else
        if [ $# -eq 0 ]; then
            "$JAVA_EXEC" $JVM_OPTS @java9args.txt -jar lwjgl3ify-forgePatches.jar nogui
        else
            "$JAVA_EXEC" $JVM_OPTS @java9args.txt -jar lwjgl3ify-forgePatches.jar "$@"
        fi
    fi
    exit_code=$?
    
    echo "Server exited with code $exit_code."
    
    # Determine if we should restart
    should_restart=false
    restart_reason=""
    if [ $exit_code -ne 0 ]; then
        echo "Server crashed! Restarting..."
        should_restart=true
        restart_reason="crash"
    else
        # Exit code is 0. Check if stop string is in the logs.
        if [ -z "$STOP_STRING" ]; then
            echo "STOP_STRING not configured. Exiting cleanly."
            should_restart=false
        elif [ ! -f "$LOG_FILE" ]; then
            echo "Log file missing. Exiting cleanly."
            should_restart=false
        else
            echo "Checking $LOG_FILE for stop trigger '$STOP_STRING'..."
            stop_triggered=false
            if tail -n 100 "$LOG_FILE" | grep -Fq "$STOP_STRING"; then
                # Check if the stop string was said by an authorized user or the server console
                # Enforce log format to prevent spoofing: ^\[HH:MM:SS\] \[Server thread/INFO\]: <User>  or [Server]
                for user in "${AUTHORIZED_USERS[@]}"; do
                    if tail -n 100 "$LOG_FILE" | grep -E "^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\] \[Server thread/INFO\]: <$user> " | grep -Fq "$STOP_STRING"; then
                        stop_triggered=true
                        break
                    fi
                done

                # Also allow the server itself (e.g., via /say command or console)
                if [ "$stop_triggered" = false ]; then
                    if tail -n 100 "$LOG_FILE" | grep -E "^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\] \[Server thread/INFO\]: \[Server\] " | grep -Fq "$STOP_STRING"; then
                        stop_triggered=true
                    fi
                fi
            fi

            if [ "$stop_triggered" = true ]; then
                echo "Stop trigger '$STOP_STRING' found in logs from an authorized user. Exiting cleanly."
                should_restart=false
            else
                echo "Stop trigger '$STOP_STRING' NOT found in logs from an authorized user. Restarting..."
                should_restart=true
                restart_reason="stop"
            fi
        fi
    fi
    
    if [ "$should_restart" = "true" ]; then
        echo "Restarting in 5 seconds... (Stop the server in Crafty to cancel)"
        sleep 5
        if [ "$restart_reason" = "stop" ] && { [ "$auto_update" = "true" ] || [ "$AUTO_UPDATE" = "true" ]; }; then
            check_and_update
        fi
    else
        echo "Clean stop detected. Exiting."
        exit 0
    fi
done
