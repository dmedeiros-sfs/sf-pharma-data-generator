#!/bin/bash
#
# stats.sh - Display statistics about generated data and Starfish configuration
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/pharma_config.json"

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "            STARFISH PHARMA DEMO - CURRENT STATUS"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""

# Users
echo "USERS"
echo "─────"
if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
    users=$(jq -r '.users[] | .username' "$CONFIG_FILE")
    for user in $users; do
        if id "$user" &>/dev/null; then
            full_name=$(jq -r ".users[] | select(.username==\"$user\") | .full_name" "$CONFIG_FILE")
            status="✓"
        else
            full_name=$(jq -r ".users[] | select(.username==\"$user\") | .full_name" "$CONFIG_FILE")
            status="✗"
        fi
        printf "  [%s] %-12s - %s\n" "$status" "$user" "$full_name"
    done
else
    for user in dthompson mwatson sleung jbaker nromero kpatel akim rmorgan; do
        if id "$user" &>/dev/null; then
            echo "  [✓] $user"
        else
            echo "  [✗] $user (not created)"
        fi
    done
fi
echo ""

# User Home Data
echo "USER HOME DATA"
echo "──────────────"
total_home_size=0
total_home_files=0

if command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ]; then
    users=$(jq -r '.users[] | .username' "$CONFIG_FILE")
else
    users="dthompson mwatson sleung jbaker nromero kpatel akim rmorgan"
fi

for user in $users; do
    research_dir="/home/$user/research"
    if [ -d "$research_dir" ]; then
        size=$(du -sh "$research_dir" 2>/dev/null | cut -f1)
        files=$(find "$research_dir" -type f 2>/dev/null | wc -l)
        printf "  %-12s %8s  (%d files)\n" "$user:" "$size" "$files"
        total_home_files=$((total_home_files + files))
    fi
done

if [ -d "/home" ]; then
    total_home=$(du -sh /home 2>/dev/null | cut -f1)
    echo "  ────────────────────────────────"
    printf "  %-12s %8s  (%d total files)\n" "TOTAL:" "$total_home" "$total_home_files"
fi
echo ""

# Shared Zone Data
echo "SHARED ZONE DATA"
echo "────────────────"
zones="clinical_trials drug_discovery regulatory"

for zone in $zones; do
    zone_dir="/mnt/efs/$zone"
    if [ -d "$zone_dir" ]; then
        size=$(du -sh "$zone_dir" 2>/dev/null | cut -f1)
        files=$(find "$zone_dir" -type f 2>/dev/null | wc -l)
        dirs=$(find "$zone_dir" -type d 2>/dev/null | wc -l)
        printf "  %-20s %8s  (%d files, %d dirs)\n" "$zone:" "$size" "$files" "$dirs"
    else
        printf "  %-20s %8s\n" "$zone:" "[not created]"
    fi
done

if [ -d "/mnt/efs" ]; then
    total_shared=$(du -sh /mnt/efs 2>/dev/null | cut -f1)
    total_shared_files=$(find /mnt/efs -type f 2>/dev/null | wc -l)
    echo "  ────────────────────────────────────"
    printf "  %-20s %8s  (%d total files)\n" "TOTAL:" "$total_shared" "$total_shared_files"
fi
echo ""

# Starfish Configuration
echo "STARFISH CONFIGURATION"
echo "──────────────────────"
if command -v sf &> /dev/null; then
    echo "  Zones:"
    sf zone list 2>/dev/null | head -20 || echo "    (unable to list zones)"
    echo ""
    echo "  Tag Sets:"
    sf tagset list 2>/dev/null | head -20 || echo "    (unable to list tagsets)"
else
    echo "  [sf command not available - configuration status unknown]"
    echo ""
    echo "  Expected configuration:"
    echo "    Zones:    clinical_trials, drug_discovery, regulatory"
    echo "    Tag Sets: document_status, confidentiality, therapeutic_area"
fi
echo ""

# Directory Structure Sample
echo "DIRECTORY STRUCTURE SAMPLE"
echo "──────────────────────────"
if [ -d "/mnt/efs/clinical_trials" ]; then
    echo "  /mnt/efs/clinical_trials/"
    ls -la /mnt/efs/clinical_trials/ 2>/dev/null | head -8 | sed 's/^/    /'
fi
if [ -d "/mnt/efs/drug_discovery" ]; then
    echo ""
    echo "  /mnt/efs/drug_discovery/"
    ls -la /mnt/efs/drug_discovery/ 2>/dev/null | head -8 | sed 's/^/    /'
fi
echo ""

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "End of status report - $(date)"
echo "═══════════════════════════════════════════════════════════════════════════════"
