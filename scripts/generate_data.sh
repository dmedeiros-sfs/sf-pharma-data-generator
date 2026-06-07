#!/bin/bash
#
# generate_data.sh - Generate dummy user-home data for a dataset
# ~700MB total across all users, varied file sizes (5KB - 10MB)
#
# Options:
#   --dataset NAME    pharma | education (default: pharma)
#   --config PATH     Explicit path to a dataset config JSON
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset) CONFIG_FILE="$(dataset_config_path "$2")"; shift 2 ;;
        --config)  CONFIG_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done
[ -f "$CONFIG_FILE" ] || { echo "Error: config not found: $CONFIG_FILE"; exit 1; }

LOG_FILE="$SCRIPT_DIR/../output/data_generation.log"
mkdir -p "$SCRIPT_DIR/../output"
echo "=== Data Generation Started: $(date) ===" | tee -a "$LOG_FILE"
echo "Dataset config: $CONFIG_FILE ($(cfg_label))" | tee -a "$LOG_FILE"

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq"
    exit 1
fi

HOME_SUBDIR="$(cfg_home_subdir)"
HOME_KEY="$(cfg_home_key)"

random_range() {
    local min=$1
    local max=$2
    echo $((min + RANDOM % (max - min + 1)))
}

generate_filename() {
    local template=$1
    local id=$2
    local num=$3
    local date=$(date +%Y%m%d)

    filename="$template"
    filename="${filename//\{id\}/$id}"
    filename="${filename//\{num\}/$num}"
    filename="${filename//\{date\}/$date}"

    echo "$filename"
}

create_file() {
    local filepath=$1
    local size_kb=$2

    # Sparse allocation: gives Starfish the right size/metadata to scan at
    # ~zero CPU/IO. Avoids hammering /dev/urandom, which pins a core on small
    # instances (r8i.large) and helps lock the box up during data gen.
    truncate -s ${size_kb}K "$filepath" 2>/dev/null || \
    dd if=/dev/zero of="$filepath" bs=1K count=$size_kb status=none 2>/dev/null
}

total_size=0
MAX_TOTAL_KB=716800  # ~700MB for user homes

echo "Creating user home directories data..." | tee -a "$LOG_FILE"

# Get users + compute a per-user budget from the user count
users=$(cfg '.users[] | .username')
num_users=$(cfg '.users | length')
[ -z "$num_users" ] || [ "$num_users" -lt 1 ] 2>/dev/null && num_users=1
MAX_USER_KB=$((MAX_TOTAL_KB / num_users))

# Load the home template set + directory list once
mapfile -t home_templates < <(cfg ".file_templates.${HOME_KEY}[]")
mapfile -t home_dirs < <(cfg ".directories.${HOME_KEY}[]")

if [ ${#home_templates[@]} -eq 0 ] || [ ${#home_dirs[@]} -eq 0 ]; then
    echo "Error: no file_templates/directories under key '${HOME_KEY}' in config" | tee -a "$LOG_FILE"
    exit 1
fi

for username in $users; do
    if [ $total_size -ge $MAX_TOTAL_KB ]; then
        echo "  Reached max total size limit" | tee -a "$LOG_FILE"
        break
    fi

    if ! id "$username" &>/dev/null; then
        echo "  Skipping $username - user doesn't exist" | tee -a "$LOG_FILE"
        continue
    fi

    echo "  Processing user: $username" | tee -a "$LOG_FILE"

    user_home="/home/$username"
    user_size=0

    for dir in "${home_dirs[@]}"; do
        [ -z "$dir" ] && continue
        [ $user_size -ge $MAX_USER_KB ] && break

        dir_path="$user_home/$HOME_SUBDIR/$dir"
        mkdir -p "$dir_path"

        # 5-10 files per directory
        num_files=$(random_range 5 10)

        for ((i=1; i<=num_files; i++)); do
            [ $user_size -ge $MAX_USER_KB ] && break

            template="${home_templates[$((RANDOM % ${#home_templates[@]}))]}"
            filename=$(generate_filename "$template" "$RANDOM" "$i")
            filepath="$dir_path/$filename"

            # Varied file sizes:
            # 60% small (5KB - 100KB)
            # 30% medium (100KB - 2MB)
            # 10% large (2MB - 10MB)
            roll=$((RANDOM % 100))
            if [ $roll -lt 60 ]; then
                size_kb=$(random_range 5 100)
            elif [ $roll -lt 90 ]; then
                size_kb=$(random_range 100 2048)
            else
                size_kb=$(random_range 2048 10240)
            fi

            create_file "$filepath" $size_kb
            user_size=$((user_size + size_kb))
            total_size=$((total_size + size_kb))
        done

        chown -R "$username:$username" "$dir_path" 2>/dev/null || true
    done

    echo "    Created ~$((user_size / 1024))MB for $username" | tee -a "$LOG_FILE"
done

echo "" | tee -a "$LOG_FILE"
echo "Total user home data: ~$((total_size / 1024))MB" | tee -a "$LOG_FILE"
echo "=== User Home Data Generation Completed: $(date) ===" | tee -a "$LOG_FILE"
