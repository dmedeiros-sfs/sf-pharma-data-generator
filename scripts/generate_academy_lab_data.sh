#!/bin/bash
#
# generate_academy_lab_data.sh - Create deterministic Starfish Academy lab
# fixtures in the pharma users' personal volumes.
#
# Run this after the standard archive demo so the archive/recovery lab starts
# without pre-existing archive history on its source files. Existing Starfish
# user volumes are scanned after the fixtures are created.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/media.sh"

HOME_ROOT="${ACADEMY_HOME_ROOT:-/home}"
LOG_FILE="${ACADEMY_LOG_FILE:-$SCRIPT_DIR/../output/academy_lab_data.log}"
ACADEMY_USERS=(rmorgan sleung akim kpatel mwatson jbaker)

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

create_random_file() {
    local filepath="$1"
    local size_mb="$2"
    local target_bytes=$((size_mb * 1024 * 1024))
    local current_bytes=0

    mkdir -p "$(dirname "$filepath")"
    [ -f "$filepath" ] && current_bytes=$(stat -c %s "$filepath")
    if [ "$current_bytes" -ne "$target_bytes" ]; then
        dd if=/dev/urandom of="$filepath" bs=1M count="$size_mb" status=none
    fi
}

create_sparse_file() {
    local filepath="$1"
    local size="$2"
    mkdir -p "$(dirname "$filepath")"
    truncate -s "$size" "$filepath"
}

log "=== Academy Lab Data Generation Started: $(date) ==="

# SF02 Lab 2 - Copy with Verification
mkdir -p "$HOME_ROOT/rmorgan/lab-scratch/src"
for i in 1 2 3 4 5; do
    create_random_file "$HOME_ROOT/rmorgan/lab-scratch/src/file${i}.bin" 2
done

# SF02 Lab 3 - Archive and Recover
mkdir -p "$HOME_ROOT/sleung/lab-scratch/cold"
for i in 1 2 3; do
    create_random_file "$HOME_ROOT/sleung/lab-scratch/cold/cold${i}.bin" 3
done

# SF02 Lab 4 - Duplicates and Metadata Extraction
dups_dir="$HOME_ROOT/akim/lab-scratch/dups"
mkdir -p "$dups_dir"
create_random_file "$dups_dir/original.bin" 12
cp "$dups_dir/original.bin" "$dups_dir/copy1.bin"
cp "$dups_dir/original.bin" "$dups_dir/copy2.bin"
create_random_file "$dups_dir/unique.bin" 12
create_media_file "$dups_dir/metadata-sample.jpg" 64
create_media_file "$dups_dir/metadata-sample.mp4" 512

# SF02 Lab 5 - Define and Run a Custom Job
custom_dir="$HOME_ROOT/kpatel/lab-scratch/custom"
mkdir -p "$custom_dir"
for i in 1 2 3 4; do
    printf 'lab line one for file %s\nsecond line\n' "$i" \
        > "$custom_dir/note${i}.txt"
done

# SF02 Lab 6 - Sync and Verify a Migration
mkdir -p "$HOME_ROOT/mwatson/lab-scratch/migsrc"
mkdir -p "$HOME_ROOT/mwatson/lab-scratch/migdst"
for i in 1 2 3 4 5; do
    create_random_file "$HOME_ROOT/mwatson/lab-scratch/migsrc/data${i}.bin" 2
done

# SF03 Lab 3 - Metadata-Emitting Custom Job
sf03_jobs_dir="$HOME_ROOT/kpatel/lab-scratch/sf03-jobs"
mkdir -p "$sf03_jobs_dir"
for i in 1 2 3 4; do
    printf 'alpha bravo charlie\nsecond line %s\nthird line\n' "$i" \
        > "$sf03_jobs_dir/note${i}.txt"
done

# SF03 Lab 5 - Drive a Scan and an Async Query Over the API
sf03_api_dir="$HOME_ROOT/jbaker/lab-scratch/sf03-api"
mkdir -p "$sf03_api_dir"
for i in 1 2 3; do
    create_sparse_file "$sf03_api_dir/big${i}.dat" 1500M
done
printf 'small report\n' > "$sf03_api_dir/report1.txt"

# Match each personal volume's normal ownership when the users exist.
for username in "${ACADEMY_USERS[@]}"; do
    if id "$username" &>/dev/null; then
        chown -R "$username:$username" "$HOME_ROOT/$username/lab-scratch"
    fi
done

# setup_all.sh runs this after the archive demo. Refresh any already-configured
# personal volumes so the Academy labs can start without manual setup scans.
if command -v sf &>/dev/null; then
    for username in "${ACADEMY_USERS[@]}"; do
        if sf volume show "$username" &>/dev/null; then
            log "Scanning Academy fixtures in $username:"
            sf scan start -t diff "$username:" --wait 2>&1 | tee -a "$LOG_FILE"
        fi
    done
fi

log "=== Academy Lab Data Generation Completed: $(date) ==="
