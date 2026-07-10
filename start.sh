#!/bin/bash
set -e

# NTNH Server — single entry point
# First run: git clone <url> && ./start.sh
# Update:    ./start.sh --update
# Normal:    ./start.sh

if [ "$1" = "--update" ]; then
    git fetch origin main
    git reset --hard origin/main
    git lfs pull
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

# Pull LFS objects (ensures binaries like server.jar are real files, not LFS pointers)
git lfs pull 2>/dev/null || true

# Resolve LFS pointers if Git LFS is not available
if [ -d .git ] && ! git lfs version >/dev/null 2>&1; then
    echo "Resolving LFS pointers (install git-lfs for faster clones)..."
    find . -type f -not -path './.git/*' | while read -r pointer; do
        if head -n1 "$pointer" 2>/dev/null | grep -q "version https://git-lfs.github.com/spec/v1"; then
            rel="${pointer#./}"
            echo "  Downloading: $rel"
            encoded=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$rel'))" 2>/dev/null || echo "$rel")
            curl -sL -o "$pointer" "https://github.com/NTNewHorizons/NTNH-Server/raw/main/$encoded" || echo "  FAILED: $rel"
        fi
    done
fi

# JVM options from server-args.txt (can be overridden via JVM_OPTS env var)
if [ -f server-args.txt ] && [ -z "${JVM_OPTS+set}" ]; then
    JVM_OPTS=$(tr '\n' ' ' < server-args.txt)
fi

exec java $JVM_OPTS -jar server.jar nogui
