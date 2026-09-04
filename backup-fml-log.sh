#!/usr/bin/env bash

# Forge 1.7.10 overwrites fml-server-latest.log on startup. Archive the old
# log first, using the same dated, gzip-compressed style as Minecraft's logs.
set -u

source_log="${FML_LOG_FILE:-logs/fml-server-latest.log}"
archive_dir="${FML_LOG_ARCHIVE_DIR:-logs}"

# A missing log is normal on the first server start.
if [ ! -f "$source_log" ]; then
    exit 0
fi

if ! command -v gzip >/dev/null 2>&1; then
    echo "ERROR: Cannot back up $source_log because gzip is not installed." >&2
    exit 1
fi

if ! mkdir -p "$archive_dir"; then
    echo "ERROR: Cannot create FML log archive directory: $archive_dir" >&2
    exit 1
fi

archive_date=$(date +%Y-%m-%d)
archive_number=1
while [ -e "$archive_dir/fml-server-$archive_date-$archive_number.log.gz" ]; do
    archive_number=$((archive_number + 1))
done

archive="$archive_dir/fml-server-$archive_date-$archive_number.log.gz"
temporary_archive="$archive.tmp.$$"

cleanup() {
    rm -f -- "$temporary_archive"
}
trap cleanup EXIT HUP INT TERM

if ! gzip -c -- "$source_log" > "$temporary_archive"; then
    echo "ERROR: Failed to compress $source_log; the original was left untouched." >&2
    exit 1
fi

if ! mv -- "$temporary_archive" "$archive"; then
    echo "ERROR: Failed to save $archive; the original was left untouched." >&2
    exit 1
fi

trap - EXIT HUP INT TERM
echo "Archived a copy of $source_log as $archive; original retained"
