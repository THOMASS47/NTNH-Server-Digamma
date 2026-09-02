#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
cd "${NTNH_SERVER_ROOT:-$script_dir}"

pointer_marker="version https://git-lfs.github.com/spec/v1"
client_repo="${NTNH_CLIENT_REPO:-NTNewHorizons/NTNH}"

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
    [ "$(head -n1 "$file" 2>/dev/null)" = "$pointer_marker" ] || continue

    case "$file" in
        forge-1.7.10-10.13.4.1614-1.7.10-universal.jar)
            source="${NTNH_FORGE_URL:-https://maven.minecraftforge.net/net/minecraftforge/forge/1.7.10-10.13.4.1614-1.7.10/forge-1.7.10-10.13.4.1614-1.7.10-universal.jar}"
            ;;
        minecraft_server.1.7.10.jar)
            source="${NTNH_MINECRAFT_SERVER_URL:-https://launcher.mojang.com/v1/objects/952438ac4e01b4d115c5fc38f891710c4941df29/server.jar}"
            ;;
        mods/HBM-*.jar)
            if [ -z "${NTNH_VERSION:-}" ] && [ ! -f .ntnh-version ]; then
                echo "ERROR: missing .ntnh-version; cannot select the matching HBM jar." >&2
                exit 1
            fi
            version="${NTNH_VERSION:-$(tr -d '\r\n' < .ntnh-version)}"
            source="${NTNH_HBM_URL:-https://media.githubusercontent.com/media/$client_repo/$version/$file}"
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
