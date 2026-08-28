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

# Materialize any large-file pointers without requiring Git LFS.
resolve_lfs_pointers() {
    local pointer
    for pointer in \
        "forge-1.7.10-10.13.4.1614-1.7.10-universal.jar" \
        "minecraft_server.1.7.10.jar" \
        mods/HBM-*.jar; do
        if is_lfs_pointer "$pointer"; then
            echo "Resolving large-file pointers from the NTNH release archive..."
            ./resolve-release.sh
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
        resolve_lfs_pointers
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

# 1. Determine Java executable path (can be overridden by JAVA_CMD, JAVA_PATH, or JAVA_HOME)
JAVA_EXEC=""
if [ -n "$JAVA_CMD" ]; then
    JAVA_EXEC="$JAVA_CMD"
elif [ -n "$JAVA_PATH" ]; then
    JAVA_EXEC="$JAVA_PATH"
elif [ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ]; then
    JAVA_EXEC="$JAVA_HOME/bin/java"
fi

is_java_17_plus() {
    local j_exec="$1"
    [ -x "$j_exec" ] || command -v "$j_exec" >/dev/null 2>&1 || return 1
    local version_str
    version_str=$("$j_exec" -version 2>&1 | head -n1)
    local ver
    ver=$(echo "$version_str" | sed -E 's/.*version "([^"]+)".*/\1/')
    if [[ "$ver" =~ ^1\. ]]; then
        ver=$(echo "$ver" | cut -d. -f2)
    else
        ver=$(echo "$ver" | cut -d. -f1)
    fi
    [ -n "$ver" ] && [ "$ver" -ge 17 ] 2>/dev/null
}

if [ -n "$JAVA_EXEC" ]; then
    if ! is_java_17_plus "$JAVA_EXEC"; then
        JAVA_EXEC=""
    fi
fi

# Check default java command if not overridden
if [ -z "$JAVA_EXEC" ]; then
    if command -v java >/dev/null 2>&1; then
        if is_java_17_plus "java"; then
            JAVA_EXEC="java"
        fi
    fi
fi

# Auto-detect Java 17/21 in common Linux directories if default java isn't Java 17+
if [ -z "$JAVA_EXEC" ]; then
    for candidate in \
        /usr/lib/jvm/java-21-openjdk-amd64/bin/java \
        /usr/lib/jvm/java-21-openjdk/bin/java \
        /usr/lib/jvm/java-17-openjdk-amd64/bin/java \
        /usr/lib/jvm/java-17-openjdk/bin/java \
        /usr/lib/jvm/java-21-oracle/bin/java \
        /usr/lib/jvm/java-17-oracle/bin/java \
        /usr/java/latest/bin/java; do
        if is_java_17_plus "$candidate"; then
            JAVA_EXEC="$candidate"
            echo "Auto-detected Java 17+ at: $JAVA_EXEC"
            break
        fi
    done
fi

# Fallback to searching /usr/lib/jvm/ for any Java 17+ installation
if [ -z "$JAVA_EXEC" ]; then
    for jvm_dir in /usr/lib/jvm/*; do
        if [ -d "$jvm_dir" ] && is_java_17_plus "$jvm_dir/bin/java"; then
            JAVA_EXEC="$jvm_dir/bin/java"
            echo "Auto-detected Java 17+ at: $JAVA_EXEC"
            break
        fi
    done
fi

# Error out if Java 17+ is not found
if [ -z "$JAVA_EXEC" ]; then
    echo "ERROR: Java 17 or higher is required for LWJGL3ify. None was found."
    if command -v java >/dev/null 2>&1; then
        echo "Current system java version:"
        java -version 2>&1 | head -n1
    fi
    echo "Please set JAVA_CMD, JAVA_PATH, or JAVA_HOME to point to your Java 17+ / 21+ installation."
    exit 1
fi

# 3. Materialize large files from the matching release when necessary.
resolve_lfs_pointers

# 4. JVM options from server-args.txt (can be overridden via JVM_OPTS env var)
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
