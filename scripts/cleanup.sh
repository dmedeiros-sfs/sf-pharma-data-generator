#!/bin/bash
#
# cleanup.sh - Remove all generated data and Starfish configuration
#
# Options:
#   --data-only      Only remove data (users, files), keep Starfish config
#   --starfish-only  Only remove Starfish config (zones, tagsets)
#   --archive-demo   Also remove archive demo config (volumes, targets)
#   --all            Remove everything (default if no option given)
#   -y, --yes        Non-interactive mode, skip confirmation
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/pharma_config.json"
LOG_FILE="$SCRIPT_DIR/../output/cleanup.log"

mkdir -p "$SCRIPT_DIR/../output"

# Parse arguments
CLEAN_DATA=false
CLEAN_STARFISH=false
CLEAN_ARCHIVE_DEMO=false
FORCE_YES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --data-only)
            CLEAN_DATA=true
            shift
            ;;
        --starfish-only)
            CLEAN_STARFISH=true
            shift
            ;;
        --archive-demo)
            CLEAN_ARCHIVE_DEMO=true
            shift
            ;;
        --all)
            CLEAN_DATA=true
            CLEAN_STARFISH=true
            CLEAN_ARCHIVE_DEMO=true
            shift
            ;;
        -y|--yes)
            FORCE_YES=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--data-only|--starfish-only|--archive-demo|--all] [-y|--yes]"
            exit 1
            ;;
    esac
done

# Default to --all if no option specified
if [ "$CLEAN_DATA" = false ] && [ "$CLEAN_STARFISH" = false ] && [ "$CLEAN_ARCHIVE_DEMO" = false ]; then
    CLEAN_DATA=true
    CLEAN_STARFISH=true
    CLEAN_ARCHIVE_DEMO=true
fi

echo "=== Cleanup Script ===" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Show what will be cleaned
echo "The following will be removed:" | tee -a "$LOG_FILE"
if [ "$CLEAN_DATA" = true ]; then
    echo "  [DATA] All users and their home directories" | tee -a "$LOG_FILE"
    echo "  [DATA] Shared storage in /mnt/efs/{clinical_trials,drug_discovery,regulatory}" | tee -a "$LOG_FILE"
fi
if [ "$CLEAN_STARFISH" = true ]; then
    echo "  [STARFISH] Zones: clinical_trials, drug_discovery, regulatory" | tee -a "$LOG_FILE"
    echo "  [STARFISH] Tag sets: document_status, confidentiality, therapeutic_area" | tee -a "$LOG_FILE"
    echo "  [STARFISH] Global roles: PharmaTaggers" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# Confirmation
if [ "$FORCE_YES" = false ]; then
    read -p "Are you sure? (type 'yes' to confirm): " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo "Cleanup cancelled." | tee -a "$LOG_FILE"
        exit 0
    fi
fi

echo "" | tee -a "$LOG_FILE"
echo "Starting cleanup..." | tee -a "$LOG_FILE"

# Check for sf command
SF_AVAILABLE=false
if command -v sf &> /dev/null; then
    SF_AVAILABLE=true
fi

# Volume configuration - must match configure_starfish.sh
SHARED_VOLUME_NAME="efs"

# ============================================================================
# STARFISH CLEANUP
# ============================================================================
if [ "$CLEAN_STARFISH" = true ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"
    echo "CLEANING STARFISH CONFIGURATION" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"
    
    if [ "$SF_AVAILABLE" = false ]; then
        echo "WARNING: 'sf' command not found. Skipping Starfish cleanup." | tee -a "$LOG_FILE"
        echo "To clean Starfish manually, run these commands:" | tee -a "$LOG_FILE"
    fi
    
    # Remove global roles first
    echo "" | tee -a "$LOG_FILE"
    echo "Removing global roles..." | tee -a "$LOG_FILE"
    if [ "$SF_AVAILABLE" = true ]; then
        sf role global delete PharmaTaggers -y 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    # Remove tag sets (this also removes tags and zone bindings)
    echo "" | tee -a "$LOG_FILE"
    echo "Removing tag sets..." | tee -a "$LOG_FILE"
    
    if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
        tagsets=$(jq -r '.tagsets[] | .name' "$CONFIG_FILE" 2>/dev/null || echo "document_status confidentiality therapeutic_area")
    else
        tagsets="document_status confidentiality therapeutic_area"
    fi
    
    for tagset in $tagsets; do
        echo "  Removing tag set: $tagset" | tee -a "$LOG_FILE"
        if [ "$SF_AVAILABLE" = true ]; then
            sf tagset delete "$tagset" -y 2>&1 | tee -a "$LOG_FILE" || true
        fi
    done
    
    # Remove zones (this removes paths, members, roles)
    echo "" | tee -a "$LOG_FILE"
    echo "Removing zones..." | tee -a "$LOG_FILE"
    
    if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
        zones=$(jq -r '.zones[] | .name' "$CONFIG_FILE" 2>/dev/null || echo "clinical_trials drug_discovery regulatory")
    else
        zones="clinical_trials drug_discovery regulatory"
    fi
    
    for zone in $zones; do
        echo "  Removing zone: $zone" | tee -a "$LOG_FILE"
        if [ "$SF_AVAILABLE" = true ]; then
            sf zone delete "$zone" -y 2>&1 | tee -a "$LOG_FILE" || true
        fi
    done
    
    # Remove volumes
    echo "" | tee -a "$LOG_FILE"
    echo "Removing volumes..." | tee -a "$LOG_FILE"
    
    # Remove per-user volumes
    if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
        users=$(jq -r '.users[] | .username' "$CONFIG_FILE" 2>/dev/null || echo "dthompson mwatson sleung jbaker nromero kpatel akim rmorgan")
    else
        users="dthompson mwatson sleung jbaker nromero kpatel akim rmorgan"
    fi
    
    for username in $users; do
        echo "  Removing volume: $username" | tee -a "$LOG_FILE"
        if [ "$SF_AVAILABLE" = true ]; then
            sf volume delete "$username" -y 2>&1 | tee -a "$LOG_FILE" || true
        fi
    done
    
    # Remove shared volume
    echo "  Removing volume: $SHARED_VOLUME_NAME" | tee -a "$LOG_FILE"
    if [ "$SF_AVAILABLE" = true ]; then
        sf volume delete "$SHARED_VOLUME_NAME" -y 2>&1 | tee -a "$LOG_FILE" || true
    fi
    
    echo "" | tee -a "$LOG_FILE"
    echo "✓ Starfish configuration cleanup completed" | tee -a "$LOG_FILE"
fi

# ============================================================================
# DATA CLEANUP
# ============================================================================
if [ "$CLEAN_DATA" = true ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"
    echo "CLEANING DATA (Users and Files)" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"
    
    # Remove users
    echo "" | tee -a "$LOG_FILE"
    echo "Removing users..." | tee -a "$LOG_FILE"
    
    if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
        users=$(jq -r '.users[] | .username' "$CONFIG_FILE" 2>/dev/null || echo "")
    else
        users="dthompson mwatson sleung jbaker nromero kpatel akim rmorgan"
    fi
    
    for username in $users; do
        if id "$username" &>/dev/null; then
            echo "  Deleting user: $username" | tee -a "$LOG_FILE"
            userdel -r "$username" 2>/dev/null || {
                # Force remove home directory if user deletion partially failed
                rm -rf "/home/$username" 2>/dev/null || true
            }
            echo "    ✓ Deleted" | tee -a "$LOG_FILE"
        else
            echo "  User $username not found, skipping..." | tee -a "$LOG_FILE"
        fi
    done
    
    # Clean up shared storage
    echo "" | tee -a "$LOG_FILE"
    echo "Cleaning up shared storage..." | tee -a "$LOG_FILE"
    
    for dir in clinical_trials drug_discovery regulatory; do
        if [ -d "/mnt/efs/$dir" ]; then
            echo "  Removing /mnt/efs/$dir" | tee -a "$LOG_FILE"
            rm -rf "/mnt/efs/$dir"
            echo "    ✓ Removed" | tee -a "$LOG_FILE"
        fi
    done
    
    echo "" | tee -a "$LOG_FILE"
    echo "✓ Data cleanup completed" | tee -a "$LOG_FILE"
fi

# ============================================================================
# ARCHIVE DEMO CLEANUP
# ============================================================================
if [ "$CLEAN_ARCHIVE_DEMO" = true ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"
    echo "CLEANING ARCHIVE DEMO CONFIGURATION" | tee -a "$LOG_FILE"
    echo "============================================================================" | tee -a "$LOG_FILE"
    
    if [ "$SF_AVAILABLE" = true ]; then
        # Remove archive targets
        echo "" | tee -a "$LOG_FILE"
        echo "Removing archive targets..." | tee -a "$LOG_FILE"
        for target in atg-sim-nfs atg-sim-lustre atg-sim-s3; do
            echo "  Removing archive target: $target" | tee -a "$LOG_FILE"
            sf archive-target delete "$target" -y 2>&1 | tee -a "$LOG_FILE" || true
        done
        
        # Remove simulated archive volumes
        echo "" | tee -a "$LOG_FILE"
        echo "Removing simulated archive volumes..." | tee -a "$LOG_FILE"
        for vol in sim-nfs sim-lustre sim-s3; do
            echo "  Removing volume: $vol" | tee -a "$LOG_FILE"
            sf volume delete "$vol" -y 2>&1 | tee -a "$LOG_FILE" || true
        done
    else
        echo "WARNING: 'sf' command not found. Skipping Starfish archive cleanup." | tee -a "$LOG_FILE"
    fi
    
    # Remove simulated archive directories
    echo "" | tee -a "$LOG_FILE"
    echo "Removing simulated archive directories..." | tee -a "$LOG_FILE"
    for dir in /mnt/sim-nfs /mnt/sim-lustre /mnt/sim-s3; do
        if [ -d "$dir" ]; then
            echo "  Removing $dir" | tee -a "$LOG_FILE"
            rm -rf "$dir" 2>&1 | tee -a "$LOG_FILE" || true
        fi
    done
    
    echo "" | tee -a "$LOG_FILE"
    echo "✓ Archive demo cleanup completed" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "=== Cleanup Completed: $(date) ===" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
