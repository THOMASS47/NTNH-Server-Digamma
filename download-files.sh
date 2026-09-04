#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
cd "${NTNH_SERVER_ROOT:-$script_dir}"

pointer_marker="version https://git-lfs.github.com/spec/v1"

is_lfs_pointer() {
    local file="$1"
    [ -f "$file" ] &&
        [ "$(wc -c < "$file")" -le 4096 ] &&
        [ "$(head -n1 "$file" 2>/dev/null)" = "$pointer_marker" ]
}

fetch_file() {
    local source="$1"
    local destination="$2"
    if [ -f "$source" ]; then
        cp "$source" "$destination"
    else
        curl --globoff -fL --retry 3 --retry-delay 2 -o "$destination" "$source"
    fi
}

for file in \
    "forge-1.7.10-10.13.4.1614-1.7.10-universal.jar" \
    "minecraft_server.1.7.10.jar" \
    mods/HBM-*.jar; do
    [ -f "$file" ] || continue
    is_lfs_pointer "$file" || continue

    case "$file" in
        mods/HBM-*.jar)
            if ! command -v git >/dev/null 2>&1 || ! git lfs version >/dev/null 2>&1; then
                echo "ERROR: Git LFS is required to download $file." >&2
                exit 1
            fi

            echo "Downloading $file with Git LFS..."
            git lfs pull --include="$file" --exclude=""
            if [ ! -f "$file" ] || is_lfs_pointer "$file"; then
                echo "ERROR: Git LFS left $file as a pointer." >&2
                exit 1
            fi
            echo "Downloaded and verified $file"
            continue
            ;;
        forge-1.7.10-10.13.4.1614-1.7.10-universal.jar)
            source="${NTNH_FORGE_URL:-https://maven.minecraftforge.net/net/minecraftforge/forge/1.7.10-10.13.4.1614-1.7.10/forge-1.7.10-10.13.4.1614-1.7.10-universal.jar}"
            ;;
        minecraft_server.1.7.10.jar)
            source="${NTNH_MINECRAFT_SERVER_URL:-https://launcher.mojang.com/v1/objects/952438ac4e01b4d115c5fc38f891710c4941df29/server.jar}"
            ;;
        *)
            echo "ERROR: no download source configured for $file" >&2
            exit 1
            ;;
    esac

    expected_oid="$(awk '/^oid sha256:/{sub(/^oid sha256:/, ""); print; exit}' "$file")"
    expected_size="$(awk '/^size /{print $2; exit}' "$file")"
    download="${file}.download"
    trap 'rm -f "$download"' EXIT

    echo "Downloading $file from its upstream source..."
    fetch_file "$source" "$download"

    actual_oid="$(sha256sum "$download" | awk '{print $1}')"
    actual_size="$(wc -c < "$download" | tr -d ' ')"
    if [ -z "$expected_oid" ] || [ "$expected_oid" != "$actual_oid" ] || [ "$expected_size" != "$actual_size" ]; then
        echo "ERROR: downloaded $file does not match its Git LFS pointer." >&2
        exit 1
    fi

    mv -f "$download" "$file"
    trap - EXIT
    echo "Downloaded and verified $file"
done
