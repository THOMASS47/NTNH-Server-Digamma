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

    expected_oid="$(awk '/^oid sha256:/{sub(/^oid sha256:/, ""); print; exit}' "$file")"
    expected_size="$(awk '/^size /{print $2; exit}' "$file")"
    source_label="its upstream source"

    case "$file" in
        mods/HBM-*.jar)
            if ! command -v git >/dev/null 2>&1; then
                echo "WARNING: Git is unavailable; using the repository LFS media fallback for $file." >&2
            elif ! git lfs version >/dev/null 2>&1; then
                echo "WARNING: Git LFS is unavailable ('git lfs version' failed); using the repository LFS media fallback for $file." >&2
            else
                echo "Downloading $file with Git LFS..."
                if ! git lfs pull --include="$file" --exclude=""; then
                    echo "WARNING: 'git lfs pull' failed; using the repository LFS media fallback for $file." >&2
                elif is_lfs_pointer "$file"; then
                    echo "WARNING: Git LFS left $file unresolved; using the repository LFS media fallback." >&2
                else
                    echo "Downloaded and verified $file"
                    continue
                fi
            fi

            revision="${NTNH_REVISION:-}"
            if [ -z "$revision" ] && command -v git >/dev/null 2>&1; then
                revision="$(git rev-parse HEAD 2>/dev/null || true)"
            fi
            revision="${revision:-main}"
            server_repo="${NTNH_SERVER_REPO:-THOMASS47/NTNH-Server-Digamma}"
            source="${NTNH_HBM_URL:-https://media.githubusercontent.com/media/$server_repo/$revision/$file}"
            source_label="the repository LFS media fallback"
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

    download="${file}.download"
    trap 'rm -f "$download"' EXIT

    echo "Downloading $file from $source_label..."
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
