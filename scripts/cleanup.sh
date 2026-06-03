#!/bin/bash
#
# cleanup.sh - Remove generated data and Starfish configuration for a dataset
#
# Options:
#   --dataset NAME   pharma | education | both   (default: pharma)
#   --config PATH    Explicit path to a dataset config JSON
#   --data-only      Only remove data (users, files), keep Starfish config
#   --starfish-only  Only remove Starfish config (zones, tagsets, volumes, role)
#   --archive-demo   Also remove the shared archive demo infra (sim volumes/targets)
#   --all            Remove everything for the dataset(s) (default if no scope given)
#   -y, --yes        Non-interactive mode, skip confirmation
#
# Note: the simulated archive volumes/targets (sim-nfs/-lustre/-s3, atg-sim-*)
# are SHARED across datasets. They are only removed with --archive-demo or --all.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
LOG_FILE="$SCRIPT_DIR/../output/cleanup.log"
mkdir -p "$SCRIPT_DIR/../output"

CLEAN_DATA=false
CLEAN_STARFISH=false
CLEAN_ARCHIVE_DEMO=false
FORCE_YES=false
DATASET_CHOICE="pharma"
EXPLICIT_CONFIG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset) DATASET_CHOICE="$2"; shift 2 ;;
        --config)  EXPLICIT_CONFIG="$2"; shift 2 ;;
        --data-only) CLEAN_DATA=true; shift ;;
        --starfish-only) CLEAN_STARFISH=true; shift ;;
        --archive-demo) CLEAN_ARCHIVE_DEMO=true; shift ;;
        --all) CLEAN_DATA=true; CLEAN_STARFISH=true; CLEAN_ARCHIVE_DEMO=true; shift ;;
        -y|--yes) FORCE_YES=true; shift ;;
        *) echo "Unknown option: $1"; echo "Usage: $0 [--dataset NAME|--config PATH] [--data-only|--starfish-only|--archive-demo|--all] [-y]"; exit 1 ;;
    esac
done

# Default scope = all
if [ "$CLEAN_DATA" = false ] && [ "$CLEAN_STARFISH" = false ] && [ "$CLEAN_ARCHIVE_DEMO" = false ]; then
    CLEAN_DATA=true; CLEAN_STARFISH=true; CLEAN_ARCHIVE_DEMO=true
fi

# Resolve dataset list
if [ -n "$EXPLICIT_CONFIG" ]; then
    CONFIGS=("$EXPLICIT_CONFIG")
elif [ "$DATASET_CHOICE" = "both" ]; then
    CONFIGS=("$(dataset_config_path pharma)" "$(dataset_config_path education)")
else
    CONFIGS=("$(dataset_config_path "$DATASET_CHOICE")")
fi

echo "=== Cleanup Script ===" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "Datasets: ${CONFIGS[*]}" | tee -a "$LOG_FILE"

if [ "$FORCE_YES" = false ]; then
    echo ""
    echo "This will remove the selected resources for: ${CONFIGS[*]}"
    [ "$CLEAN_ARCHIVE_DEMO" = true ] && echo "(including the SHARED simulated archive volumes/targets)"
    read -p "Are you sure? (type 'yes' to confirm): " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo "Cleanup cancelled." | tee -a "$LOG_FILE"; exit 0
    fi
fi

SF_AVAILABLE=false
command -v sf &> /dev/null && SF_AVAILABLE=true

HAVE_JQ=false
command -v jq &> /dev/null && HAVE_JQ=true

clean_one_dataset() {
    local cfg_file="$1"
    CONFIG_FILE="$cfg_file"   # so cfg() reads this dataset

    local label shared_name shared_mount global_role
    if [ "$HAVE_JQ" = true ] && [ -f "$CONFIG_FILE" ]; then
        label="$(cfg_label)"
        shared_name="$(cfg_shared_vol_name)"
        shared_mount="$(cfg_shared_vol_mount)"
        global_role="$(cfg_global_role_name)"
        users=$(cfg '.users[] | .username')
        zones=$(cfg '.zones[] | .name')
        tagsets=$(cfg '.tagsets[] | .name')
    else
        echo "WARNING: jq or config missing for $cfg_file; skipping." | tee -a "$LOG_FILE"
        return
    fi

    echo "" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"
    echo "CLEANUP: $label  ($CONFIG_FILE)" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"

    # ---- Starfish config ----
    if [ "$CLEAN_STARFISH" = true ]; then
        echo "" | tee -a "$LOG_FILE"
        echo "Removing global role: $global_role" | tee -a "$LOG_FILE"
        [ "$SF_AVAILABLE" = true ] && sf role global delete "$global_role" -y 2>&1 | tee -a "$LOG_FILE" || true

        echo "Removing tag sets..." | tee -a "$LOG_FILE"
        for tagset in $tagsets; do
            echo "  - $tagset" | tee -a "$LOG_FILE"
            [ "$SF_AVAILABLE" = true ] && sf tagset delete "$tagset" -y 2>&1 | tee -a "$LOG_FILE" || true
        done

        echo "Removing zones..." | tee -a "$LOG_FILE"
        for zone in $zones; do
            echo "  - $zone" | tee -a "$LOG_FILE"
            [ "$SF_AVAILABLE" = true ] && sf zone delete "$zone" -y 2>&1 | tee -a "$LOG_FILE" || true
        done

        echo "Removing per-user volumes..." | tee -a "$LOG_FILE"
        for username in $users; do
            echo "  - $username" | tee -a "$LOG_FILE"
            [ "$SF_AVAILABLE" = true ] && sf volume delete "$username" -y 2>&1 | tee -a "$LOG_FILE" || true
        done

        echo "Removing shared volume: $shared_name" | tee -a "$LOG_FILE"
        [ "$SF_AVAILABLE" = true ] && sf volume delete "$shared_name" -y 2>&1 | tee -a "$LOG_FILE" || true
        echo "Starfish config cleanup done for $label" | tee -a "$LOG_FILE"
    fi

    # ---- Data (users + files) ----
    if [ "$CLEAN_DATA" = true ]; then
        echo "" | tee -a "$LOG_FILE"
        echo "Removing users..." | tee -a "$LOG_FILE"
        for username in $users; do
            if id "$username" &>/dev/null; then
                echo "  Deleting user: $username" | tee -a "$LOG_FILE"
                userdel -r "$username" 2>/dev/null || rm -rf "/home/$username" 2>/dev/null || true
            else
                echo "  User $username not found, skipping..." | tee -a "$LOG_FILE"
            fi
        done

        echo "Cleaning shared storage under $shared_mount ..." | tee -a "$LOG_FILE"
        for zone in $zones; do
            if [ -d "$shared_mount/$zone" ]; then
                echo "  Removing $shared_mount/$zone" | tee -a "$LOG_FILE"
                rm -rf "$shared_mount/$zone"
            fi
        done
        # Remove the shared mount dir itself if now empty
        rmdir "$shared_mount" 2>/dev/null || true
        echo "Data cleanup done for $label" | tee -a "$LOG_FILE"
    fi
}

for cfg_file in "${CONFIGS[@]}"; do
    clean_one_dataset "$cfg_file"
done

# ---- Shared archive demo infra (dataset-independent) ----
if [ "$CLEAN_ARCHIVE_DEMO" = true ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"
    echo "CLEANING SHARED ARCHIVE DEMO INFRASTRUCTURE" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"
    if [ "$SF_AVAILABLE" = true ]; then
        for target in atg-sim-nfs atg-sim-lustre atg-sim-s3; do
            echo "  Removing archive target: $target" | tee -a "$LOG_FILE"
            sf archive-target delete "$target" -y 2>&1 | tee -a "$LOG_FILE" || true
        done
        for vol in sim-nfs sim-lustre sim-s3; do
            echo "  Removing volume: $vol" | tee -a "$LOG_FILE"
            sf volume delete "$vol" -y 2>&1 | tee -a "$LOG_FILE" || true
        done
    else
        echo "WARNING: 'sf' not found. Skipping archive infra cleanup." | tee -a "$LOG_FILE"
    fi
    for dir in /mnt/sim-nfs /mnt/sim-lustre /mnt/sim-s3; do
        if [ -d "$dir" ]; then
            echo "  Removing $dir" | tee -a "$LOG_FILE"
            rm -rf "$dir" 2>&1 | tee -a "$LOG_FILE" || true
        fi
    done
    echo "Archive demo cleanup completed" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "=== Cleanup Completed: $(date) ===" | tee -a "$LOG_FILE"
