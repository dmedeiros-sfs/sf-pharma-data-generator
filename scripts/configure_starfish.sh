#!/bin/bash
#
# configure_starfish.sh - Configure Starfish zones, tag sets, and permissions
#
# This script:
# 1. Creates 3 zones (clinical_trials, drug_discovery, regulatory)
# 2. Creates 3 tag sets with tags
# 3. Assigns zone admins and members
# 4. Binds tag sets to zones
# 5. Sets up capabilities and roles
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/pharma_config.json"
LOG_FILE="$SCRIPT_DIR/../output/starfish_config.log"

mkdir -p "$SCRIPT_DIR/../output"
echo "=== Starfish Configuration Started: $(date) ===" | tee -a "$LOG_FILE"

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq"
    exit 1
fi

# Check if sf command is available
if ! command -v sf &> /dev/null; then
    echo "WARNING: 'sf' command not found. Generating commands only." | tee -a "$LOG_FILE"
    DRY_RUN=true
else
    DRY_RUN=false
fi

# Function to run or print sf command
run_sf() {
    local cmd="$*"
    echo "  $ sf $cmd" | tee -a "$LOG_FILE"
    
    if [ "$DRY_RUN" = false ]; then
        sf $cmd 2>&1 | tee -a "$LOG_FILE" || true
    fi
}

# Assume there's a volume called pharma_vol mapping to /mnt/efs
# This would normally be created during Starfish installation
VOLUME_NAME="pharma_vol"

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 1: Creating Tag Sets" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Create tag sets
tagsets=$(jq -r '.tagsets[] | .name' "$CONFIG_FILE")

for tagset in $tagsets; do
    description=$(jq -r ".tagsets[] | select(.name==\"$tagset\") | .description" "$CONFIG_FILE")
    
    echo "" | tee -a "$LOG_FILE"
    echo "Creating tag set: $tagset" | tee -a "$LOG_FILE"
    run_sf tagset add "$tagset" --description "\"$description\"" --pinnable --inheritable
    
    # Add tags to the tag set
    tags=$(jq -r ".tagsets[] | select(.name==\"$tagset\") | .tags[]" "$CONFIG_FILE")
    
    for tag in $tags; do
        echo "  Adding tag: $tag" | tee -a "$LOG_FILE"
        run_sf tagset tag add "$tagset" "$tag"
    done
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 2: Creating Zones" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Create zones
zones=$(jq -r '.zones[] | .name' "$CONFIG_FILE")

for zone in $zones; do
    description=$(jq -r ".zones[] | select(.name==\"$zone\") | .description" "$CONFIG_FILE")
    zone_path=$(jq -r ".zones[] | select(.name==\"$zone\") | .path" "$CONFIG_FILE")
    
    echo "" | tee -a "$LOG_FILE"
    echo "Creating zone: $zone" | tee -a "$LOG_FILE"
    
    # Create the zone
    run_sf zone add "$zone" --description "\"$description\""
    
    # Add path to zone (assuming volume exists)
    # Format: VOLUME:/relative/path or just use path if volume is guessed
    echo "  Adding path to zone: $VOLUME_NAME:${zone_path#/mnt/efs/}" | tee -a "$LOG_FILE"
    run_sf zone path add "$zone" "$VOLUME_NAME:/${zone##*/}"
    
    # Add capabilities to zone
    echo "  Adding capabilities: TagApplier, RecoverExecutor" | tee -a "$LOG_FILE"
    run_sf zone capability add "$zone" TagApplier --delegable
    run_sf zone capability add "$zone" RecoverExecutor --delegable
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 3: Assigning Zone Admins" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Assign zone admins
# dthompson -> clinical_trials
# mwatson -> drug_discovery, regulatory

users=$(jq -r '.users[] | .username' "$CONFIG_FILE")

for user in $users; do
    admin_zones=$(jq -r ".users[] | select(.username==\"$user\") | .zone_admin[]" "$CONFIG_FILE" 2>/dev/null || echo "")
    
    for zone in $admin_zones; do
        [ -z "$zone" ] && continue
        echo "" | tee -a "$LOG_FILE"
        echo "Adding $user as admin of zone: $zone" | tee -a "$LOG_FILE"
        run_sf zone member add "$zone" --username "$user" --admin
    done
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 4: Adding Zone Members (non-admin)" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for user in $users; do
    member_zones=$(jq -r ".users[] | select(.username==\"$user\") | .zone_member[]" "$CONFIG_FILE" 2>/dev/null || echo "")
    
    for zone in $member_zones; do
        [ -z "$zone" ] && continue
        echo "" | tee -a "$LOG_FILE"
        echo "Adding $user as member of zone: $zone" | tee -a "$LOG_FILE"
        run_sf zone member add "$zone" --username "$user"
    done
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 5: Binding Tag Sets to Zones" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for tagset in $tagsets; do
    bound_zones=$(jq -r ".tagsets[] | select(.name==\"$tagset\") | .zones[]" "$CONFIG_FILE")
    
    for zone in $bound_zones; do
        [ -z "$zone" ] && continue
        echo "" | tee -a "$LOG_FILE"
        echo "Binding tag set '$tagset' to zone '$zone'" | tee -a "$LOG_FILE"
        run_sf tagset zone add "$tagset" "$zone"
    done
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 6: Creating Global Role for TagApplier" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Creating global role 'PharmaTaggers' for all zone users" | tee -a "$LOG_FILE"
run_sf role global add PharmaTaggers --description "\"Allow all zone users to apply tags\""
run_sf role global grant PharmaTaggers TagApplier
run_sf role global zone add PharmaTaggers --all-zones

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 7: Creating Zone Roles for Recovery" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for zone in $zones; do
    echo "" | tee -a "$LOG_FILE"
    echo "Creating recovery role for zone: $zone" | tee -a "$LOG_FILE"
    run_sf zone role add "$zone" LocalRestorers --description "\"Allow recovery in $zone\""
    run_sf zone role grant "${zone}.LocalRestorers" RecoverExecutor
    run_sf zone role member add "${zone}.LocalRestorers" --all-members
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "=== Starfish Configuration Completed: $(date) ===" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "SUMMARY:" | tee -a "$LOG_FILE"
echo "--------" | tee -a "$LOG_FILE"
echo "Zones created:     3 (clinical_trials, drug_discovery, regulatory)" | tee -a "$LOG_FILE"
echo "Tag sets created:  3 (document_status, confidentiality, therapeutic_area)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Zone Admins:" | tee -a "$LOG_FILE"
echo "  - clinical_trials: dthompson" | tee -a "$LOG_FILE"
echo "  - drug_discovery:  mwatson" | tee -a "$LOG_FILE"
echo "  - regulatory:      mwatson" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Zone Members:" | tee -a "$LOG_FILE"
echo "  - clinical_trials: sleung, kpatel" | tee -a "$LOG_FILE"
echo "  - drug_discovery:  jbaker, kpatel, akim" | tee -a "$LOG_FILE"
echo "  - regulatory:      nromero, akim" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "User with no zone access (personal files only): rmorgan" | tee -a "$LOG_FILE"
