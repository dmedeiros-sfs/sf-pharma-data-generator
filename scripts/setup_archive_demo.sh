#!/bin/bash
#
# setup_archive_demo.sh - Create simulated archive targets and run demo jobs
#
# This script:
# 1. Creates 3 volumes to simulate archive destinations (sim-nfs, sim-lustre, sim-s3)
# 2. Creates 3 archive-targets pointing to these volumes
# 3. Runs archive jobs (copy and migrate)
# 4. Runs a restore job
#
# The purpose is to create job records visible in the Starfish GUI
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../output/archive_demo.log"

mkdir -p "$SCRIPT_DIR/../output"
echo "=== Archive Demo Setup Started: $(date) ===" | tee -a "$LOG_FILE"

#############################################################################
# CONFIGURATION
#############################################################################
# Simulated archive target mount points
SIM_NFS_MOUNT="/mnt/sim-nfs"
SIM_LUSTRE_MOUNT="/mnt/sim-lustre"
SIM_S3_MOUNT="/mnt/sim-s3"

# Source volumes for archive jobs (user home volumes)
# We'll archive from these users' data
ARCHIVE_TO_NFS_SOURCE="dthompson"      # Copy to NFS
ARCHIVE_TO_LUSTRE_SOURCE="mwatson"     # Copy to Lustre
ARCHIVE_TO_S3_SOURCE="sleung"          # Migrate (move) to S3
#############################################################################

if ! command -v sf &> /dev/null; then
    echo "Error: 'sf' command not found. Is Starfish installed?"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 1: Creating Simulated Archive Target Directories" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Create mount point directories
for mount_dir in "$SIM_NFS_MOUNT" "$SIM_LUSTRE_MOUNT" "$SIM_S3_MOUNT"; do
    if [ ! -d "$mount_dir" ]; then
        echo "Creating directory: $mount_dir" | tee -a "$LOG_FILE"
        mkdir -p "$mount_dir"
    else
        echo "Directory already exists: $mount_dir" | tee -a "$LOG_FILE"
    fi
done

# Create subdirectories for archive destinations
mkdir -p "$SIM_NFS_MOUNT/archives"
mkdir -p "$SIM_LUSTRE_MOUNT/archives"
mkdir -p "$SIM_S3_MOUNT/archives"

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 2: Creating Simulated Archive Volumes" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Create volumes for archive targets
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
        sf volume add "$vol_name" "$vol_mount" 2>&1 | tee -a "$LOG_FILE" || true
    fi
done

# Wait a moment for volumes to be ready
echo "" | tee -a "$LOG_FILE"
echo "Waiting for volumes to initialize..." | tee -a "$LOG_FILE"
sleep 5

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 3: Creating Archive Targets" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Archive target format: sf archive-target add NAME volume dst_volume=VOL dst_path=PATH

# atg-sim-nfs -> sim-nfs:/archives
echo "Creating archive target: atg-sim-nfs" | tee -a "$LOG_FILE"
if sf archive-target show atg-sim-nfs &>/dev/null; then
    echo "  Archive target 'atg-sim-nfs' already exists" | tee -a "$LOG_FILE"
else
    sf archive-target add atg-sim-nfs volume dst_volume=sim-nfs dst_path=archives 2>&1 | tee -a "$LOG_FILE" || true
fi

# atg-sim-lustre -> sim-lustre:/archives
echo "Creating archive target: atg-sim-lustre" | tee -a "$LOG_FILE"
if sf archive-target show atg-sim-lustre &>/dev/null; then
    echo "  Archive target 'atg-sim-lustre' already exists" | tee -a "$LOG_FILE"
else
    sf archive-target add atg-sim-lustre volume dst_volume=sim-lustre dst_path=archives 2>&1 | tee -a "$LOG_FILE" || true
fi

# atg-sim-s3 -> sim-s3:/archives
echo "Creating archive target: atg-sim-s3" | tee -a "$LOG_FILE"
if sf archive-target show atg-sim-s3 &>/dev/null; then
    echo "  Archive target 'atg-sim-s3' already exists" | tee -a "$LOG_FILE"
else
    sf archive-target add atg-sim-s3 volume dst_volume=sim-s3 dst_path=archives 2>&1 | tee -a "$LOG_FILE" || true
fi

echo "" | tee -a "$LOG_FILE"
echo "Archive targets created:" | tee -a "$LOG_FILE"
sf archive-target list 2>&1 | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 4: Running Initial Scans on Source Volumes" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Make sure source volumes have been scanned
echo "Checking if source volumes have been scanned..." | tee -a "$LOG_FILE"

for src_vol in "$ARCHIVE_TO_NFS_SOURCE" "$ARCHIVE_TO_LUSTRE_SOURCE" "$ARCHIVE_TO_S3_SOURCE"; do
    echo "  Checking volume: $src_vol" | tee -a "$LOG_FILE"
    # Try to query the volume - if it fails, run a scan
    if ! sf query "$src_vol:/" --limit 1 &>/dev/null; then
        echo "    Running scan on $src_vol..." | tee -a "$LOG_FILE"
        sf scan start -t diff "$src_vol:" --wait 2>&1 | tee -a "$LOG_FILE" || true
    else
        echo "    Volume $src_vol has data, skipping scan" | tee -a "$LOG_FILE"
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 5: Running Archive Jobs" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "--- Archive Job 1: Copy $ARCHIVE_TO_NFS_SOURCE to atg-sim-nfs ---" | tee -a "$LOG_FILE"
echo "  $ sf archive start --wait $ARCHIVE_TO_NFS_SOURCE:/ atg-sim-nfs" | tee -a "$LOG_FILE"
sf archive start --wait "$ARCHIVE_TO_NFS_SOURCE:/" atg-sim-nfs 2>&1 | tee -a "$LOG_FILE" || true

echo "" | tee -a "$LOG_FILE"
echo "--- Archive Job 2: Copy $ARCHIVE_TO_LUSTRE_SOURCE to atg-sim-lustre ---" | tee -a "$LOG_FILE"
echo "  $ sf archive start --wait $ARCHIVE_TO_LUSTRE_SOURCE:/ atg-sim-lustre" | tee -a "$LOG_FILE"
sf archive start --wait "$ARCHIVE_TO_LUSTRE_SOURCE:/" atg-sim-lustre 2>&1 | tee -a "$LOG_FILE" || true

echo "" | tee -a "$LOG_FILE"
echo "--- Archive Job 3: Migrate (move) $ARCHIVE_TO_S3_SOURCE to atg-sim-s3 ---" | tee -a "$LOG_FILE"
echo "  $ sf archive start --migrate --wait $ARCHIVE_TO_S3_SOURCE:/ atg-sim-s3" | tee -a "$LOG_FILE"
sf archive start --migrate --wait "$ARCHIVE_TO_S3_SOURCE:/" atg-sim-s3 2>&1 | tee -a "$LOG_FILE" || true

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 6: Running Restore Job from atg-sim-s3" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "--- Restore Job: Restore $ARCHIVE_TO_S3_SOURCE from atg-sim-s3 ---" | tee -a "$LOG_FILE"
echo "  $ sf restore start --wait $ARCHIVE_TO_S3_SOURCE:/" | tee -a "$LOG_FILE"
sf restore start --wait "$ARCHIVE_TO_S3_SOURCE:/" 2>&1 | tee -a "$LOG_FILE" || true

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
echo "SUMMARY:" | tee -a "$LOG_FILE"
echo "--------" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Simulated Archive Volumes:" | tee -a "$LOG_FILE"
echo "  - sim-nfs    ($SIM_NFS_MOUNT)" | tee -a "$LOG_FILE"
echo "  - sim-lustre ($SIM_LUSTRE_MOUNT)" | tee -a "$LOG_FILE"
echo "  - sim-s3     ($SIM_S3_MOUNT)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Archive Targets:" | tee -a "$LOG_FILE"
echo "  - atg-sim-nfs    -> sim-nfs:/archives" | tee -a "$LOG_FILE"
echo "  - atg-sim-lustre -> sim-lustre:/archives" | tee -a "$LOG_FILE"
echo "  - atg-sim-s3     -> sim-s3:/archives" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Archive Jobs Run:" | tee -a "$LOG_FILE"
echo "  1. $ARCHIVE_TO_NFS_SOURCE -> atg-sim-nfs (COPY)" | tee -a "$LOG_FILE"
echo "  2. $ARCHIVE_TO_LUSTRE_SOURCE -> atg-sim-lustre (COPY)" | tee -a "$LOG_FILE"
echo "  3. $ARCHIVE_TO_S3_SOURCE -> atg-sim-s3 (MIGRATE/MOVE)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Restore Jobs Run:" | tee -a "$LOG_FILE"
echo "  1. $ARCHIVE_TO_S3_SOURCE restored from atg-sim-s3" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Check the Starfish GUI to see all job records!" | tee -a "$LOG_FILE"
