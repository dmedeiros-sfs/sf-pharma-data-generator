#!/bin/bash
#
# cleanup_archive_demo.sh - Remove archive demo configuration
#
# This script removes:
# - Archive targets (atg-sim-nfs, atg-sim-lustre, atg-sim-s3)
# - Simulated archive volumes (sim-nfs, sim-lustre, sim-s3)
# - Simulated archive directories (/mnt/sim-*)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../output/archive_cleanup.log"

mkdir -p "$SCRIPT_DIR/../output"
echo "=== Archive Demo Cleanup Started: $(date) ===" | tee -a "$LOG_FILE"

# Parse arguments
FORCE_YES=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--yes)
            FORCE_YES=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-y|--yes]"
            exit 1
            ;;
    esac
done

# Confirmation
if [ "$FORCE_YES" = false ]; then
    echo ""
    echo "This will remove:"
    echo "  - Archive targets: atg-sim-nfs, atg-sim-lustre, atg-sim-s3"
    echo "  - Volumes: sim-nfs, sim-lustre, sim-s3"
    echo "  - Directories: /mnt/sim-nfs, /mnt/sim-lustre, /mnt/sim-s3"
    echo ""
    read -p "Are you sure you want to proceed? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
fi

# Check for sf command
SF_AVAILABLE=false
if command -v sf &> /dev/null; then
    SF_AVAILABLE=true
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "Removing Archive Targets" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

if [ "$SF_AVAILABLE" = true ]; then
    for target in atg-sim-nfs atg-sim-lustre atg-sim-s3; do
        echo "Removing archive target: $target" | tee -a "$LOG_FILE"
        sf archive-target delete "$target" -y 2>&1 | tee -a "$LOG_FILE" || true
    done
else
    echo "WARNING: 'sf' command not found. Skipping archive target removal." | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "Removing Simulated Archive Volumes" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

if [ "$SF_AVAILABLE" = true ]; then
    for vol in sim-nfs sim-lustre sim-s3; do
        echo "Removing volume: $vol" | tee -a "$LOG_FILE"
        sf volume delete "$vol" -y 2>&1 | tee -a "$LOG_FILE" || true
    done
else
    echo "WARNING: 'sf' command not found. Skipping volume removal." | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "Removing Simulated Archive Directories" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for dir in /mnt/sim-nfs /mnt/sim-lustre /mnt/sim-s3; do
    if [ -d "$dir" ]; then
        echo "Removing directory: $dir" | tee -a "$LOG_FILE"
        rm -rf "$dir" 2>&1 | tee -a "$LOG_FILE" || true
    else
        echo "Directory does not exist: $dir" | tee -a "$LOG_FILE"
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "=== Archive Demo Cleanup Completed: $(date) ===" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
