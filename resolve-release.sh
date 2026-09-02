#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
cd "${NTNH_SERVER_ROOT:-$script_dir}"

is_lfs_pointer() {
    [ -f "$1" ] && head -n1 "$1" 2>/dev/null | grep -q "version https://git-lfs.github.com/spec/v1"
}

pointers=()
for file in \
    "forge-1.7.10-10.13.4.1614-1.7.10-universal.jar" \
    "minecraft_server.1.7.10.jar" \
    mods/HBM-*.jar; do
    if is_lfs_pointer "$file"; then
        pointers+=("$file")
    fi
done

if [ ${#pointers[@]} -eq 0 ]; then
    exit 0
fi

for command in curl unzip sha256sum; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: required command '$command' is missing." >&2
        exit 1
    fi
done

if [ ! -f .ntnh-version ]; then
    echo "ERROR: missing .ntnh-version; cannot select the matching release." >&2
    exit 1
fi

version="${NTNH_VERSION:-$(tr -d '\r\n' < .ntnh-version)}"
repo="${NTNH_RELEASE_REPO:-NTNewHorizons/NTNH-Server}"
zip_url="${NTNH_RELEASE_ZIP_URL:-https://github.com/$repo/releases/download/$version/ntnh-server-$version.zip}"
sum_url="${NTNH_RELEASE_SUM_URL:-${zip_url}.sha256}"
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
archive="$temp_dir/ntnh-server-$version.zip"
stage="$temp_dir/stage"

fetch_file() {
    local source="$1"
    local destination="$2"
    if [ -f "$source" ]; then
        cp "$source" "$destination"
    else
        curl -fL --retry 3 --retry-delay 2 -o "$destination" "$source"
    fi
}

echo "Downloading NTNH Server $version release..."
fetch_file "$zip_url" "$archive"

sum_file="$temp_dir/release.sha256"
fetch_file "$sum_url" "$sum_file"
expected="$(awk '{print $1}' "$sum_file")"
actual="$(sha256sum "$archive" | awk '{print $1}')"
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
    echo "ERROR: release archive checksum mismatch." >&2
    exit 1
fi
echo "Release checksum verified."

mkdir -p "$stage"
unzip -q "$archive" -d "$stage"

for pointer in "${pointers[@]}"; do
    source_file="$stage/$pointer"
    if [ ! -f "$source_file" ]; then
        echo "ERROR: release archive does not contain $pointer" >&2
        exit 1
    fi

    expected_oid="$(awk '/^oid sha256:/{sub(/^oid sha256:/, ""); print; exit}' "$pointer")"
    expected_size="$(awk '/^size /{print $2; exit}' "$pointer")"
    actual_oid="$(sha256sum "$source_file" | awk '{print $1}')"
    actual_size="$(wc -c < "$source_file" | tr -d ' ')"
    if [ "$expected_oid" != "$actual_oid" ] || [ "$expected_size" != "$actual_size" ]; then
        echo "ERROR: release copy of $pointer does not match its pointer." >&2
        exit 1
    fi

    temp_file="${pointer}.download"
    cp "$source_file" "$temp_file"
    mv -f "$temp_file" "$pointer"
    echo "Materialized $pointer"
done
