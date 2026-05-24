#!/bin/bash
#
# stats.sh - Display statistics about generated data and Starfish config
#
# Options:
#   --dataset NAME   pharma | education (default: pharma)
#   --config PATH    Explicit path to a dataset config JSON
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset) CONFIG_FILE="$(dataset_config_path "$2")"; shift 2 ;;
        --config)  CONFIG_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

HAVE_JQ=false
command -v jq &> /dev/null && [ -f "$CONFIG_FILE" ] && HAVE_JQ=true

label="Demo"
shared_mount="/mnt/efs"
home_subdir="research"
if [ "$HAVE_JQ" = true ]; then
    label="$(cfg_label)"
    shared_mount="$(cfg_shared_vol_mount)"
    home_subdir="$(cfg_home_subdir)"
fi

echo "==============================================================================="
echo "            STARFISH DEMO - CURRENT STATUS ($label)"
echo "==============================================================================="
echo ""

echo "USERS"
echo "-----"
if [ "$HAVE_JQ" = true ]; then
    users=$(cfg '.users[] | .username')
    for user in $users; do
        full_name=$(cfg ".users[] | select(.username==\"$user\") | .full_name")
        if id "$user" &>/dev/null; then status="x"; else status=" "; fi
        printf "  [%s] %-12s - %s\n" "$status" "$user" "$full_name"
    done
else
    echo "  [jq/config unavailable]"
fi
echo ""

echo "USER HOME DATA"
echo "--------------"
total_home_files=0
if [ "$HAVE_JQ" = true ]; then users=$(cfg '.users[] | .username'); else users=""; fi
for user in $users; do
    research_dir="/home/$user/$home_subdir"
    if [ -d "$research_dir" ]; then
        size=$(du -sh "$research_dir" 2>/dev/null | cut -f1)
        files=$(find "$research_dir" -type f 2>/dev/null | wc -l)
        printf "  %-12s %8s  (%d files)\n" "$user:" "$size" "$files"
        total_home_files=$((total_home_files + files))
    fi
done
printf "  %-12s (%d total files)\n" "TOTAL:" "$total_home_files"
echo ""

echo "SHARED ZONE DATA ($shared_mount)"
echo "----------------"
if [ "$HAVE_JQ" = true ]; then zones=$(cfg '.zones[] | .name'); else zones=""; fi
for zone in $zones; do
    zone_dir="$shared_mount/$zone"
    if [ -d "$zone_dir" ]; then
        size=$(du -sh "$zone_dir" 2>/dev/null | cut -f1)
        files=$(find "$zone_dir" -type f 2>/dev/null | wc -l)
        dirs=$(find "$zone_dir" -type d 2>/dev/null | wc -l)
        printf "  %-20s %8s  (%d files, %d dirs)\n" "$zone:" "$size" "$files" "$dirs"
    else
        printf "  %-20s %8s\n" "$zone:" "[not created]"
    fi
done
echo ""

echo "STARFISH CONFIGURATION"
echo "----------------------"
if command -v sf &> /dev/null; then
    echo "  Zones:"
    sf zone list 2>/dev/null | head -20 || echo "    (unable to list zones)"
    echo ""
    echo "  Tag Sets:"
    sf tagset list 2>/dev/null | head -20 || echo "    (unable to list tagsets)"
else
    echo "  [sf command not available]"
    if [ "$HAVE_JQ" = true ]; then
        echo "  Expected zones:    $(echo "$zones" | tr '\n' ' ')"
        echo "  Expected tag sets: $(cfg '.tagsets[] | .name' | tr '\n' ' ')"
    fi
fi
echo ""
echo "==============================================================================="
echo "End of status report - $(date)"
echo "==============================================================================="
