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

# Helper function to resolve LFS pointers using direct download if they are still pointers
resolve_lfs_pointers() {
    local need_lfs_resolve=false
    if is_lfs_pointer "server.jar" || is_lfs_pointer "minecraft_server.1.7.10.jar"; then
        need_lfs_resolve=true
    elif [ -d .git ] && ! git lfs version >/dev/null 2>&1; then
        need_lfs_resolve=true
    fi

    if [ "$need_lfs_resolve" = true ]; then
        echo "Resolving Git LFS pointers..."
        
        # Determine the raw URL dynamically based on git remote
        local REPO_RAW_URL="https://github.com/THOMASS47/NTNH-Server-Digamma/raw/main"
        if [ -d .git ]; then
            local git_url=$(git remote get-url origin 2>/dev/null || git remote get-url upstream 2>/dev/null || echo "")
            if [ -n "$git_url" ]; then
                local clean_url=$(echo "$git_url" | sed -E 's|git@github.com:|https://github.com/|; s|\.git$||')
                local git_branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
                REPO_RAW_URL="${clean_url}/raw/${git_branch}"
            fi
        fi
        echo "Using source raw URL: $REPO_RAW_URL"

        # Find and download all pointer files
        find . -type f -not -path './.git/*' | while read -r pointer; do
            if is_lfs_pointer "$pointer"; then
                local rel="${pointer#./}"
                echo "  Downloading: $rel"
                local encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$rel'))" 2>/dev/null || echo "$rel")
                curl -sL -o "$pointer" "${REPO_RAW_URL}/${encoded}" || echo "  FAILED: $rel"
            fi
        done
    fi
}

# Helper function to check and apply updates
check_and_update() {
    echo "Checking for repository updates..."
    git fetch origin main 2>/dev/null || true
    
    local HEAD_HASH=$(git rev-parse HEAD 2>/dev/null || echo "1")
    local REMOTE_HASH=$(git rev-parse origin/main 2>/dev/null || echo "2")
    
    if [ "$HEAD_HASH" != "$REMOTE_HASH" ]; then
        echo "New updates found! Applying updates..."
        git reset --hard origin/main 2>/dev/null || true
        git lfs pull 2>/dev/null || true
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

# Check default java command if not overridden
if [ -z "$JAVA_EXEC" ]; then
    if command -v java >/dev/null 2>&1; then
        if java -version 2>&1 | grep -q "1.8"; then
            JAVA_EXEC="java"
        fi
    fi
fi

# Auto-detect Java 8 in common Linux directories if default java isn't Java 8
if [ -z "$JAVA_EXEC" ]; then
    for candidate in \
        /usr/lib/jvm/java-8-openjdk-amd64/bin/java \
        /usr/lib/jvm/java-8-openjdk/bin/java \
        /usr/lib/jvm/java-1.8.0-openjdk/bin/java \
        /usr/lib/jvm/jre-1.8.0/bin/java \
        /usr/lib/jvm/java-8-oracle/bin/java \
        /usr/java/latest/bin/java; do
        if [ -x "$candidate" ] && "$candidate" -version 2>&1 | grep -q "1.8"; then
            JAVA_EXEC="$candidate"
            echo "Auto-detected Java 8 at: $JAVA_EXEC"
            break
        fi
    done
fi

# Fallback to searching /usr/lib/jvm/ for any Java 8 installation
if [ -z "$JAVA_EXEC" ]; then
    for jvm_dir in /usr/lib/jvm/*; do
        if [ -d "$jvm_dir" ] && [ -x "$jvm_dir/bin/java" ]; then
            if "$jvm_dir/bin/java" -version 2>&1 | grep -q "1.8"; then
                JAVA_EXEC="$jvm_dir/bin/java"
                echo "Auto-detected Java 8 at: $JAVA_EXEC"
                break
            fi
        fi
    done
fi

# Error out if Java 8 is not found
if [ -z "$JAVA_EXEC" ]; then
    echo "ERROR: Java 8 is required. None was found."
    if command -v java >/dev/null 2>&1; then
        echo "Current system java version:"
        java -version 2>&1 | head -n1
    fi
    echo "Please set JAVA_CMD, JAVA_PATH, or JAVA_HOME to point to your Java 8 installation."
    exit 1
fi

# 3. Pull LFS objects (ensures binaries like server.jar are real files, not LFS pointers)
if [ -d .git ]; then
    git lfs pull 2>/dev/null || true
fi

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
        "$JAVA_EXEC" $JVM_OPTS "$@"
    else
        if [ $# -eq 0 ]; then
            "$JAVA_EXEC" $JVM_OPTS -jar server.jar nogui
        else
            "$JAVA_EXEC" $JVM_OPTS -jar server.jar "$@"
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
