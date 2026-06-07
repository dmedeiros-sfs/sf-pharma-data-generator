#!/bin/bash
#
# generate_shared_data.sh - Generate shared zone data for a dataset
# Iterates every zone in the config and fills it from that zone's template_key.
# Creates data under <shared_volume.mount>/<zone> for each zone.
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

LOG_FILE="$SCRIPT_DIR/../output/shared_data_generation.log"
mkdir -p "$SCRIPT_DIR/../output"
echo "=== Shared Data Generation Started: $(date) ===" | tee -a "$LOG_FILE"
echo "Dataset config: $CONFIG_FILE ($(cfg_label))" | tee -a "$LOG_FILE"

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq"
    exit 1
fi

SHARED_MOUNT="$(cfg_shared_vol_mount)"

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

# Per-zone budget derived from the zone count (~400MB shared total)
zones=$(cfg '.zones[] | .name')
num_zones=$(cfg '.zones | length')
[ -z "$num_zones" ] || [ "$num_zones" -lt 1 ] 2>/dev/null && num_zones=1
MAX_TOTAL_KB=409600
MAX_ZONE_KB=$((MAX_TOTAL_KB / num_zones))

total_size=0

for zone in $zones; do
    template_key="$(cfg_zone_template_key "$zone")"

    echo "" | tee -a "$LOG_FILE"
    echo "=== Creating Zone Data: $zone (templates: $template_key) ===" | tee -a "$LOG_FILE"

    mapfile -t zone_templates < <(cfg ".file_templates.${template_key}[]")
    mapfile -t zone_dirs < <(cfg ".directories.${template_key}[]")

    if [ ${#zone_templates[@]} -eq 0 ] || [ ${#zone_dirs[@]} -eq 0 ]; then
        echo "  WARNING: no templates/dirs under key '${template_key}', skipping zone" | tee -a "$LOG_FILE"
        continue
    fi

    # Users who can own files in this zone (admins + members).
    # Uses (.zone_admin + .zone_member) so members are not dropped when a user
    # has an empty zone_admin array.
    mapfile -t zone_users < <(cfg ".users[] | select((.zone_admin + .zone_member) | index(\"$zone\")) | .username")

    zone_root="${SHARED_MOUNT}/${zone}"
    mkdir -p "$zone_root"
    zone_size=0

    for dir in "${zone_dirs[@]}"; do
        [ -z "$dir" ] && continue
        [ $zone_size -ge $MAX_ZONE_KB ] && break

        dir_path="$zone_root/$dir"
        mkdir -p "$dir_path"

        num_files=$(random_range 8 15)
        echo "  Creating $dir ($num_files files)..." | tee -a "$LOG_FILE"

        for ((i=1; i<=num_files; i++)); do
            [ $zone_size -ge $MAX_ZONE_KB ] && break

            template="${zone_templates[$((RANDOM % ${#zone_templates[@]}))]}"
            filename=$(generate_filename "$template" "$RANDOM" "$i")
            filepath="$dir_path/$filename"

            roll=$((RANDOM % 100))
            if [ $roll -lt 60 ]; then
                size_kb=$(random_range 5 100)
            elif [ $roll -lt 90 ]; then
                size_kb=$(random_range 100 2048)
            else
                size_kb=$(random_range 2048 10240)
            fi

            create_file "$filepath" $size_kb
            zone_size=$((zone_size + size_kb))
            total_size=$((total_size + size_kb))

            # Assign to a random zone member if any exist
            if [ ${#zone_users[@]} -gt 0 ]; then
                owner="${zone_users[$((RANDOM % ${#zone_users[@]}))]}"
                chown "$owner:$owner" "$filepath" 2>/dev/null || true
            fi
        done
    done

    chmod -R 755 "$zone_root"
    echo "  Done: $zone ~$((zone_size / 1024))MB" | tee -a "$LOG_FILE"
done

echo "" | tee -a "$LOG_FILE"
echo "=== Shared Storage Summary ===" | tee -a "$LOG_FILE"
for zone in $zones; do
    zdir="${SHARED_MOUNT}/${zone}"
    echo "$zone: $(du -sh "$zdir" 2>/dev/null | cut -f1)" | tee -a "$LOG_FILE"
done
echo "" | tee -a "$LOG_FILE"
echo "Total shared data: ~$((total_size / 1024))MB" | tee -a "$LOG_FILE"
echo "=== Shared Data Generation Completed: $(date) ===" | tee -a "$LOG_FILE"
