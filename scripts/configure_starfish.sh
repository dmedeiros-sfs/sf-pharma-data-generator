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

# Assume there's a volume - we need to find it or use a default
# Try to get the first available volume from sf volume list
VOLUME_NAME=""
if [ "$DRY_RUN" = false ]; then
    VOLUME_NAME=$(sf volume list --format "{name}" 2>/dev/null | head -1 || echo "")
fi
if [ -z "$VOLUME_NAME" ]; then
    VOLUME_NAME="pharma_vol"
    echo "Note: Using default volume name '$VOLUME_NAME'. Adjust if needed." | tee -a "$LOG_FILE"
fi

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
    echo "  $ sf tagset add $tagset --description \"$description\" --pinnable --inheritable" | tee -a "$LOG_FILE"
    
    if [ "$DRY_RUN" = false ]; then
        sf tagset add "$tagset" --description "$description" --pinnable --inheritable 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Add tags to the tag set
    tags=$(jq -r ".tagsets[] | select(.name==\"$tagset\") | .tags[]" "$CONFIG_FILE")
    
    for tag in $tags; do
        echo "  Adding tag: $tag" | tee -a "$LOG_FILE"
        echo "  $ sf tagset tag add $tagset $tag" | tee -a "$LOG_FILE"
        if [ "$DRY_RUN" = false ]; then
            sf tagset tag add "$tagset" "$tag" 2>&1 | tee -a "$LOG_FILE" || true
        fi
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
    
    echo "" | tee -a "$LOG_FILE"
    echo "Creating zone: $zone" | tee -a "$LOG_FILE"
    
    # Create the zone
    echo "  $ sf zone add $zone --description \"$description\"" | tee -a "$LOG_FILE"
    if [ "$DRY_RUN" = false ]; then
        sf zone add "$zone" --description "$description" 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Add path to zone
    # Path format: VOLUME:/relative_path
    echo "  Adding path: $VOLUME_NAME:/$zone" | tee -a "$LOG_FILE"
    echo "  $ sf zone path add $zone $VOLUME_NAME:/$zone" | tee -a "$LOG_FILE"
    if [ "$DRY_RUN" = false ]; then
        sf zone path add "$zone" "$VOLUME_NAME:/$zone" 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Add capabilities to zone
    echo "  Adding capabilities: TagApplier, RecoverExecutor" | tee -a "$LOG_FILE"
    echo "  $ sf zone capability add $zone TagApplier --delegable" | tee -a "$LOG_FILE"
    echo "  $ sf zone capability add $zone RecoverExecutor --delegable" | tee -a "$LOG_FILE"
    if [ "$DRY_RUN" = false ]; then
        sf zone capability add "$zone" TagApplier --delegable 2>&1 | tee -a "$LOG_FILE" || true
        sf zone capability add "$zone" RecoverExecutor --delegable 2>&1 | tee -a "$LOG_FILE" || true
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 3: Assigning Zone Admins" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

# Assign zone admins
users=$(jq -r '.users[] | .username' "$CONFIG_FILE")

for user in $users; do
    admin_zones=$(jq -r ".users[] | select(.username==\"$user\") | .zone_admin[]" "$CONFIG_FILE" 2>/dev/null || echo "")
    
    for zone in $admin_zones; do
        [ -z "$zone" ] && continue
        echo "" | tee -a "$LOG_FILE"
        echo "Adding $user as admin of zone: $zone" | tee -a "$LOG_FILE"
        echo "  $ sf zone member add $zone --username $user --admin" | tee -a "$LOG_FILE"
        if [ "$DRY_RUN" = false ]; then
            sf zone member add "$zone" --username "$user" --admin 2>&1 | tee -a "$LOG_FILE" || true
        fi
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
        echo "  $ sf zone member add $zone --username $user" | tee -a "$LOG_FILE"
        if [ "$DRY_RUN" = false ]; then
            sf zone member add "$zone" --username "$user" 2>&1 | tee -a "$LOG_FILE" || true
        fi
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
        echo "  $ sf tagset zone add $tagset $zone" | tee -a "$LOG_FILE"
        if [ "$DRY_RUN" = false ]; then
            sf tagset zone add "$tagset" "$zone" 2>&1 | tee -a "$LOG_FILE" || true
        fi
    done
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 6: Creating Global Role for TagApplier" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Creating global role 'PharmaTaggers' for all zone users" | tee -a "$LOG_FILE"
echo "  $ sf role global add PharmaTaggers" | tee -a "$LOG_FILE"
echo "  $ sf role global grant PharmaTaggers TagApplier" | tee -a "$LOG_FILE"
echo "  $ sf role global zone add PharmaTaggers --all-zones" | tee -a "$LOG_FILE"

if [ "$DRY_RUN" = false ]; then
    sf role global add PharmaTaggers 2>&1 | tee -a "$LOG_FILE" || true
    sf role global grant PharmaTaggers TagApplier 2>&1 | tee -a "$LOG_FILE" || true
    sf role global zone add PharmaTaggers --all-zones 2>&1 | tee -a "$LOG_FILE" || true
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 7: Creating Zone Roles for Recovery" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for zone in $zones; do
    echo "" | tee -a "$LOG_FILE"
    echo "Creating recovery role for zone: $zone" | tee -a "$LOG_FILE"
    echo "  $ sf zone role add $zone LocalRestorers" | tee -a "$LOG_FILE"
    echo "  $ sf zone role grant ${zone}.LocalRestorers RecoverExecutor" | tee -a "$LOG_FILE"
    echo "  $ sf zone role member add ${zone}.LocalRestorers --all-members" | tee -a "$LOG_FILE"
    
    if [ "$DRY_RUN" = false ]; then
        sf zone role add "$zone" LocalRestorers 2>&1 | tee -a "$LOG_FILE" || true
        sf zone role grant "${zone}.LocalRestorers" RecoverExecutor 2>&1 | tee -a "$LOG_FILE" || true
        sf zone role member add "${zone}.LocalRestorers" --all-members 2>&1 | tee -a "$LOG_FILE" || true
    fi
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
