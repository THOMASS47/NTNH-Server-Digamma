#!/bin/bash
set -e

# NTNH Server — single entry point
# First run: git clone <url> && ./start.sh
# Update:    ./start.sh --update
# Normal:    ./start.sh

if [ "$1" = "--update" ]; then
    git fetch origin main
    git reset --hard origin/main
    echo "Updated to latest version. Run ./start.sh to start."
    exit 0
fi

# Java 8 (Minecraft 1.7.10 requires exactly Java 8)
java -version 2>&1 | grep -q "1.8" || {
    echo "ERROR: Java 8 is required."
    java -version 2>&1 | head -n1
    exit 1
}

# Accept EULA
echo "eula=true" > eula.txt

# Resolve LFS pointers if Git LFS is not available
if [ -d .git ] && ! git lfs version >/dev/null 2>&1; then
    echo "Resolving LFS pointers (install git-lfs for faster clones)..."
    find mods -name "HBM-*.jar" -type f | while read -r pointer; do
        if head -n1 "$pointer" | grep -q "version https://git-lfs.github.com/spec/v1"; then
            filename=$(basename "$pointer")
            echo "  Downloading: $filename"
            encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$filename'))" 2>/dev/null || echo "$filename")
            curl -sL -o "$pointer" "https://github.com/NTNewHorizons/NTNH-Server/raw/main/mods/$encoded" || echo "  FAILED: $filename"
        fi
    done
fi

# JVM options — override via JVM_OPTS env var (e.g. Docker)
: "${JVM_OPTS:=-Xms4G -Xmx8G -XX:+UseG1GC -XX:+UnlockExperimentalVMOptions -XX:MaxGCPauseMillis=100}"

exec java $JVM_OPTS -jar server.jar nogui
