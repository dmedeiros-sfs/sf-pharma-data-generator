#!/bin/bash
#
# setup_archive_demo.sh - Create simulated archive targets and run demo jobs
#
# The simulated archive volumes (sim-nfs/sim-lustre/sim-s3) and their targets
# (atg-sim-*) are shared infrastructure - created once and reused by any dataset.
# The archive/restore *source* users come from the dataset config's
# archive_demo.sources block, so the jobs reference the right users.
#
# Options:
#   --dataset NAME        pharma | education (default: pharma)
#   --config PATH         Explicit path to a dataset config JSON
#   --agent-address URL   Use this agent address for volume creation
#   --server              Running on the Starfish server (no agent)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

#############################################################################
# Shared simulated archive mount points (dataset-independent)
#############################################################################
SIM_NFS_MOUNT="/mnt/sim-nfs"
SIM_LUSTRE_MOUNT="/mnt/sim-lustre"
SIM_S3_MOUNT="/mnt/sim-s3"

AGENT_ADDRESS=""
IS_SERVER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset) CONFIG_FILE="$(dataset_config_path "$2")"; shift 2 ;;
        --config)  CONFIG_FILE="$2"; shift 2 ;;
        --agent-address) AGENT_ADDRESS="$2"; shift 2 ;;
        --server) IS_SERVER=true; shift ;;
        *) echo "Unknown option: $1"; echo "Usage: $0 [--dataset NAME|--config PATH] [--agent-address URL] [--server]"; exit 1 ;;
    esac
done
[ -f "$CONFIG_FILE" ] || { echo "Error: config not found: $CONFIG_FILE"; exit 1; }

LOG_FILE="$SCRIPT_DIR/../output/archive_demo.log"
mkdir -p "$SCRIPT_DIR/../output"
echo "=== Archive Demo Setup Started: $(date) ===" | tee -a "$LOG_FILE"
echo "Dataset config: $CONFIG_FILE ($(cfg_label))" | tee -a "$LOG_FILE"

# If no agent address provided and not explicitly server, ask user
if [ -z "$AGENT_ADDRESS" ] && [ "$IS_SERVER" = false ]; then
    suggested_url="https://$(hostname -f):30002"
    echo ""
    echo "Running on agent or server?"
    echo "  - Press Enter to use agent: $suggested_url"
    echo "  - Type a different agent URL"
    echo "  - Type 'server' or 's' if running on the Starfish server"
    echo ""
    read -p "[$suggested_url]: " user_input

    if [[ "$user_input" =~ ^[Ss](erver)?$ ]]; then
        AGENT_ADDRESS=""
    elif [ -z "$user_input" ]; then
        AGENT_ADDRESS="$suggested_url"
    else
        AGENT_ADDRESS="$user_input"
    fi
fi

if [ -n "$AGENT_ADDRESS" ]; then
    echo "Agent address: $AGENT_ADDRESS" | tee -a "$LOG_FILE"
else
    echo "Running on server (no agent address)" | tee -a "$LOG_FILE"
fi

if ! command -v sf &> /dev/null; then
    echo "Error: 'sf' command not found. Is Starfish installed?"
    exit 1
fi
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required."
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 1: Creating Simulated Archive Target Directories" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for mount_dir in "$SIM_NFS_MOUNT" "$SIM_LUSTRE_MOUNT" "$SIM_S3_MOUNT"; do
    if [ ! -d "$mount_dir" ]; then
        echo "Creating directory: $mount_dir" | tee -a "$LOG_FILE"
        mkdir -p "$mount_dir"
    else
        echo "Directory already exists: $mount_dir" | tee -a "$LOG_FILE"
    fi
done

mkdir -p "$SIM_NFS_MOUNT/archives"
mkdir -p "$SIM_LUSTRE_MOUNT/archives"
mkdir -p "$SIM_S3_MOUNT/archives"

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 2: Creating Simulated Archive Volumes" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

wait_for_pending_scans() {
    echo "  Waiting for pending scans to complete..." | tee -a "$LOG_FILE"
    while true; do
        pending_output=$(sf scan pending 2>/dev/null || true)
        pending=$(echo "$pending_output" | grep -cE "RUNNING|PENDING" || echo "0")
        pending=$(echo "$pending" | head -1 | tr -d '[:space:]')
        if [ -z "$pending" ] || [ "$pending" -eq 0 ] 2>/dev/null; then
            break
        fi
        echo "    $pending scan(s) still running, waiting..." | tee -a "$LOG_FILE"
        sleep 5
    done
    echo "  No pending scans" | tee -a "$LOG_FILE"
}

run_diff_scan() {
    local vol_name="$1"
    echo "  Running diff scan on '$vol_name'..." | tee -a "$LOG_FILE"
    sf scan start -t diff "$vol_name:" --wait 2>&1 | tee -a "$LOG_FILE" || true
    echo "  Scan complete for '$vol_name'" | tee -a "$LOG_FILE"
}

add_volume() {
    local vol_name="$1"
    local vol_mount="$2"
    if [ -n "$AGENT_ADDRESS" ]; then
        sf volume add "$vol_name" "$vol_mount" --agent-address "$AGENT_ADDRESS" --no-cron 2>&1 | tee -a "$LOG_FILE" || true
    else
        sf volume add "$vol_name" "$vol_mount" --no-cron 2>&1 | tee -a "$LOG_FILE" || true
    fi
}

declare -A SIM_VOLUMES=(
    ["sim-nfs"]="$SIM_NFS_MOUNT"
    ["sim-lustre"]="$SIM_LUSTRE_MOUNT"
    ["sim-s3"]="$SIM_S3_MOUNT"
)

for vol_name in "${!SIM_VOLUMES[@]}"; do
    vol_mount="${SIM_VOLUMES[$vol_name]}"
    if sf volume show "$vol_name" &>/dev/null; then
        echo "Volume '$vol_name' already exists" | tee -a "$LOG_FILE"
    else
        echo "Creating volume '$vol_name' at '$vol_mount'" | tee -a "$LOG_FILE"
        add_volume "$vol_name" "$vol_mount"
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "Waiting for auto-triggered scans to complete..." | tee -a "$LOG_FILE"
wait_for_pending_scans

echo "" | tee -a "$LOG_FILE"
echo "Running diff scans on archive volumes..." | tee -a "$LOG_FILE"
for vol_name in "${!SIM_VOLUMES[@]}"; do
    run_diff_scan "$vol_name"
done

echo "" | tee -a "$LOG_FILE"
echo "All archive volume scans complete." | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 3: Creating Archive Targets" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

create_target() {
    local name="$1" dst_vol="$2"
    echo "Creating archive target: $name" | tee -a "$LOG_FILE"
    if sf archive-target show "$name" &>/dev/null; then
        echo "  Archive target '$name' already exists" | tee -a "$LOG_FILE"
    else
        sf archive-target add "$name" volume dst_volume="$dst_vol" dst_path=archives 2>&1 | tee -a "$LOG_FILE" || true
    fi
}

create_target atg-sim-nfs    sim-nfs
create_target atg-sim-lustre sim-lustre
create_target atg-sim-s3     sim-s3

echo "" | tee -a "$LOG_FILE"
echo "Archive targets:" | tee -a "$LOG_FILE"
sf archive-target list 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 4: Ensuring Source Volumes Are Scanned" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Read source jobs from the dataset config: user|target|mode
mapfile -t SOURCES < <(cfg '.archive_demo.sources[] | "\(.user)|\(.target)|\(.mode)"')

if [ ${#SOURCES[@]} -eq 0 ]; then
    echo "No archive_demo.sources in config; skipping archive jobs." | tee -a "$LOG_FILE"
    echo "=== Archive Demo Setup Completed: $(date) ===" | tee -a "$LOG_FILE"
    exit 0
fi

echo "Verifying source volumes are scanned..." | tee -a "$LOG_FILE"
for entry in "${SOURCES[@]}"; do
    src_vol="${entry%%|*}"
    echo "  Checking volume: $src_vol" | tee -a "$LOG_FILE"
    if ! sf query "$src_vol:/" --limit 1 &>/dev/null; then
        echo "    Volume needs scanning, waiting for pending scans..." | tee -a "$LOG_FILE"
        wait_for_pending_scans
        run_diff_scan "$src_vol"
    else
        echo "    Volume $src_vol already has data indexed" | tee -a "$LOG_FILE"
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 5: Running Archive Jobs" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

MIGRATED_SOURCES=()
job_num=0
for entry in "${SOURCES[@]}"; do
    IFS='|' read -r src_vol target mode <<< "$entry"
    job_num=$((job_num + 1))
    echo "" | tee -a "$LOG_FILE"
    if [ "$mode" = "migrate" ]; then
        echo "--- Archive Job $job_num: Migrate (move) $src_vol to $target ---" | tee -a "$LOG_FILE"
        echo "  \$ sf archive start --migrate --wait $src_vol:/ $target" | tee -a "$LOG_FILE"
        sf archive start --migrate --wait "$src_vol:/" "$target" 2>&1 | tee -a "$LOG_FILE" || true
        MIGRATED_SOURCES+=("$src_vol")
    else
        echo "--- Archive Job $job_num: Copy $src_vol to $target ---" | tee -a "$LOG_FILE"
        echo "  \$ sf archive start --wait $src_vol:/ $target" | tee -a "$LOG_FILE"
        sf archive start --wait "$src_vol:/" "$target" 2>&1 | tee -a "$LOG_FILE" || true
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 6: Running Restore Jobs (for migrated sources)" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for src_vol in "${MIGRATED_SOURCES[@]}"; do
    echo "" | tee -a "$LOG_FILE"
    echo "--- Restore Job: Restore $src_vol ---" | tee -a "$LOG_FILE"
    echo "  \$ sf restore start --wait $src_vol:/" | tee -a "$LOG_FILE"
    sf restore start --wait "$src_vol:/" 2>&1 | tee -a "$LOG_FILE" || true
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 7: Listing All Jobs" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Archive Jobs:" | tee -a "$LOG_FILE"
sf archive list 2>&1 | tee -a "$LOG_FILE" || true
echo "" | tee -a "$LOG_FILE"
echo "Restore Jobs:" | tee -a "$LOG_FILE"
sf restore list 2>&1 | tee -a "$LOG_FILE" || true

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "=== Archive Demo Setup Completed: $(date) ===" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "SUMMARY ($(cfg_label)):" | tee -a "$LOG_FILE"
echo "Archive jobs run:" | tee -a "$LOG_FILE"
for entry in "${SOURCES[@]}"; do
    IFS='|' read -r src_vol target mode <<< "$entry"
    echo "  - $src_vol -> $target (${mode^^})" | tee -a "$LOG_FILE"
done
echo "" | tee -a "$LOG_FILE"
echo "Check the Starfish GUI to see all job records!" | tee -a "$LOG_FILE"
