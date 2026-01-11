#!/bin/bash
#
# configure_starfish.sh - Configure Starfish zones, tag sets, and permissions
#
# This script:
# 1. Creates volume if needed
# 2. Creates 3 zones with paths
# 3. Creates 3 tag sets with tags
# 4. Assigns zone admins and members
# 5. Binds tag sets to zones
# 6. Sets up capabilities and roles
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/pharma_config.json"
LOG_FILE="$SCRIPT_DIR/../output/starfish_config.log"

#############################################################################
# CONFIGURATION - Edit these values for your environment
#############################################################################
VOLUME_NAME="efs"
VOLUME_MOUNT="/mnt/efs"
#############################################################################

mkdir -p "$SCRIPT_DIR/../output"
echo "=== Starfish Configuration Started: $(date) ===" | tee -a "$LOG_FILE"

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq"
    exit 1
fi

if ! command -v sf &> /dev/null; then
    echo "Error: 'sf' command not found. Is Starfish installed?"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "Configuration:" | tee -a "$LOG_FILE"
echo "  Volume name: $VOLUME_NAME" | tee -a "$LOG_FILE"
echo "  Volume mount: $VOLUME_MOUNT" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 0: Ensuring Volume Exists" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Check if volume exists
if sf volume show "$VOLUME_NAME" &>/dev/null; then
    echo "Volume '$VOLUME_NAME' already exists" | tee -a "$LOG_FILE"
else
    echo "Creating volume '$VOLUME_NAME' at '$VOLUME_MOUNT'..." | tee -a "$LOG_FILE"
    sf volume add "$VOLUME_NAME" "$VOLUME_MOUNT" 2>&1 | tee -a "$LOG_FILE"
    echo "Volume created. Note: Initial scan will run automatically." | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 1: Creating Tag Sets" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

tagsets=$(jq -r '.tagsets[] | .name' "$CONFIG_FILE")

for tagset in $tagsets; do
    description=$(jq -r ".tagsets[] | select(.name==\"$tagset\") | .description" "$CONFIG_FILE")
    
    echo "" | tee -a "$LOG_FILE"
    echo "Creating tag set: $tagset" | tee -a "$LOG_FILE"
    
    # Check if tagset already exists
    if sf tagset show "$tagset" &>/dev/null; then
        echo "  Tag set '$tagset' already exists, skipping creation" | tee -a "$LOG_FILE"
    else
        sf tagset add "$tagset" --description "$description" --pinnable --inheritable 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Add tags to the tag set
    tags=$(jq -r ".tagsets[] | select(.name==\"$tagset\") | .tags[]" "$CONFIG_FILE")
    
    for tag in $tags; do
        echo "  Adding tag: $tag" | tee -a "$LOG_FILE"
        sf tagset tag add "$tagset" "$tag" 2>&1 | tee -a "$LOG_FILE" || true
    done
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 2: Creating Zones" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

zones=$(jq -r '.zones[] | .name' "$CONFIG_FILE")

for zone in $zones; do
    description=$(jq -r ".zones[] | select(.name==\"$zone\") | .description" "$CONFIG_FILE")
    
    echo "" | tee -a "$LOG_FILE"
    echo "Creating zone: $zone" | tee -a "$LOG_FILE"
    
    # Check if zone already exists
    if sf zone show "$zone" &>/dev/null; then
        echo "  Zone '$zone' already exists, skipping creation" | tee -a "$LOG_FILE"
    else
        sf zone add "$zone" --description "$description" 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Add path to zone
    echo "  Adding path: $VOLUME_NAME:/$zone" | tee -a "$LOG_FILE"
    sf zone path add "$zone" "$VOLUME_NAME:/$zone" 2>&1 | tee -a "$LOG_FILE" || true
    
    # Add capabilities to zone
    echo "  Adding capabilities: TagApplier, RecoverExecutor" | tee -a "$LOG_FILE"
    sf zone capability add "$zone" TagApplier --delegable 2>&1 | tee -a "$LOG_FILE" || true
    sf zone capability add "$zone" RecoverExecutor --delegable 2>&1 | tee -a "$LOG_FILE" || true
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 3: Assigning Zone Admins" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

users=$(jq -r '.users[] | .username' "$CONFIG_FILE")

for user in $users; do
    admin_zones=$(jq -r ".users[] | select(.username==\"$user\") | .zone_admin[]" "$CONFIG_FILE" 2>/dev/null || echo "")
    
    for zone in $admin_zones; do
        [ -z "$zone" ] && continue
        echo "" | tee -a "$LOG_FILE"
        echo "Adding $user as admin of zone: $zone" | tee -a "$LOG_FILE"
        sf zone member add "$zone" --username "$user" --admin 2>&1 | tee -a "$LOG_FILE" || true
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
        sf zone member add "$zone" --username "$user" 2>&1 | tee -a "$LOG_FILE" || true
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
        sf tagset zone add "$tagset" "$zone" 2>&1 | tee -a "$LOG_FILE" || true
    done
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 6: Creating Global Role for TagApplier" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Creating global role 'PharmaTaggers' for all zone users" | tee -a "$LOG_FILE"

# Check if role exists
if sf role global show PharmaTaggers &>/dev/null; then
    echo "  Global role 'PharmaTaggers' already exists" | tee -a "$LOG_FILE"
else
    sf role global add PharmaTaggers 2>&1 | tee -a "$LOG_FILE" || true
fi
sf role global grant PharmaTaggers TagApplier 2>&1 | tee -a "$LOG_FILE" || true
sf role global zone add PharmaTaggers --all-zones 2>&1 | tee -a "$LOG_FILE" || true

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 7: Creating Zone Roles for Recovery" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for zone in $zones; do
    echo "" | tee -a "$LOG_FILE"
    echo "Creating recovery role for zone: $zone" | tee -a "$LOG_FILE"
    
    # Check if role exists
    if sf zone role show "${zone}.LocalRestorers" &>/dev/null; then
        echo "  Role '${zone}.LocalRestorers' already exists" | tee -a "$LOG_FILE"
    else
        sf zone role add "$zone" LocalRestorers 2>&1 | tee -a "$LOG_FILE" || true
    fi
    sf zone role grant "${zone}.LocalRestorers" RecoverExecutor 2>&1 | tee -a "$LOG_FILE" || true
    sf zone role member add "${zone}.LocalRestorers" --all-members 2>&1 | tee -a "$LOG_FILE" || true
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "=== Starfish Configuration Completed: $(date) ===" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "SUMMARY:" | tee -a "$LOG_FILE"
echo "--------" | tee -a "$LOG_FILE"
echo "Volume:            $VOLUME_NAME ($VOLUME_MOUNT)" | tee -a "$LOG_FILE"
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
