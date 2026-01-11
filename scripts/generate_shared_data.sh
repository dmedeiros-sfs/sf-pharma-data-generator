#!/bin/bash
#
# generate_shared_data.sh - Generate shared data for zones
# Creates data in /mnt/efs/{clinical_trials,drug_discovery,regulatory}
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/pharma_config.json"
LOG_FILE="$SCRIPT_DIR/../output/shared_data_generation.log"

mkdir -p "$SCRIPT_DIR/../output"
echo "=== Shared Data Generation Started: $(date) ===" | tee -a "$LOG_FILE"

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq"
    exit 1
fi

random_range() {
    local min=$1
    local max=$2
    echo $((min + RANDOM % (max - min + 1)))
}

generate_filename() {
    local template=$1
    local id=$2
    local num=$3
    local date=$(date +%Y%m%d)
    
    filename="$template"
    filename="${filename//\{id\}/$id}"
    filename="${filename//\{num\}/$num}"
    filename="${filename//\{date\}/$date}"
    
    echo "$filename"
}

create_small_file() {
    local filepath=$1
    local size_kb=$2
    
    dd if=/dev/urandom of="$filepath" bs=1K count=$size_kb status=none 2>/dev/null || \
    truncate -s ${size_kb}K "$filepath"
}

# Create zone directories
echo "Creating zone directories..." | tee -a "$LOG_FILE"
mkdir -p /mnt/efs/{clinical_trials,drug_discovery,regulatory}

total_size=0
MAX_TOTAL_KB=2048  # 2MB for shared data

# ============================================================================
# CLINICAL TRIALS ZONE (Zone 1)
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "=== Creating Clinical Trials Zone Data ===" | tee -a "$LOG_FILE"

mapfile -t clinical_templates < <(jq -r '.file_templates.clinical[]' "$CONFIG_FILE")
mapfile -t clinical_dirs < <(jq -r '.directories.clinical[]' "$CONFIG_FILE")

# Get zone1 members for ownership
zone1_users=$(jq -r '.users[] | select(.zone_admin[] == "clinical_trials" or .zone_member[] == "clinical_trials") | .username' "$CONFIG_FILE")
zone1_array=($zone1_users)

for dir in "${clinical_dirs[@]}"; do
    [ -z "$dir" ] && continue
    [ $total_size -ge $MAX_TOTAL_KB ] && break
    
    dir_path="/mnt/efs/clinical_trials/$dir"
    mkdir -p "$dir_path"
    
    num_files=$(random_range 2 4)
    echo "  Creating $dir ($num_files files)..." | tee -a "$LOG_FILE"
    
    for ((i=1; i<=num_files; i++)); do
        [ $total_size -ge $MAX_TOTAL_KB ] && break
        
        template="${clinical_templates[$((RANDOM % ${#clinical_templates[@]}))]}"
        filename=$(generate_filename "$template" "$RANDOM" "$i")
        filepath="$dir_path/$filename"
        
        size_kb=$(random_range 20 150)
        create_small_file "$filepath" $size_kb
        total_size=$((total_size + size_kb))
        
        # Assign to random zone member
        if [ ${#zone1_array[@]} -gt 0 ]; then
            owner="${zone1_array[$((RANDOM % ${#zone1_array[@]}))]}"
            chown "$owner:$owner" "$filepath" 2>/dev/null || true
        fi
    done
done

chmod -R 755 /mnt/efs/clinical_trials
echo "  ✓ Clinical trials zone data created" | tee -a "$LOG_FILE"

# ============================================================================
# DRUG DISCOVERY ZONE (Zone 2)
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "=== Creating Drug Discovery Zone Data ===" | tee -a "$LOG_FILE"

mapfile -t discovery_templates < <(jq -r '.file_templates.discovery[]' "$CONFIG_FILE")
mapfile -t discovery_dirs < <(jq -r '.directories.discovery[]' "$CONFIG_FILE")

zone2_users=$(jq -r '.users[] | select(.zone_admin[] == "drug_discovery" or .zone_member[] == "drug_discovery") | .username' "$CONFIG_FILE")
zone2_array=($zone2_users)

for dir in "${discovery_dirs[@]}"; do
    [ -z "$dir" ] && continue
    [ $total_size -ge $MAX_TOTAL_KB ] && break
    
    dir_path="/mnt/efs/drug_discovery/$dir"
    mkdir -p "$dir_path"
    
    num_files=$(random_range 2 4)
    echo "  Creating $dir ($num_files files)..." | tee -a "$LOG_FILE"
    
    for ((i=1; i<=num_files; i++)); do
        [ $total_size -ge $MAX_TOTAL_KB ] && break
        
        template="${discovery_templates[$((RANDOM % ${#discovery_templates[@]}))]}"
        filename=$(generate_filename "$template" "$RANDOM" "$i")
        filepath="$dir_path/$filename"
        
        size_kb=$(random_range 20 150)
        create_small_file "$filepath" $size_kb
        total_size=$((total_size + size_kb))
        
        if [ ${#zone2_array[@]} -gt 0 ]; then
            owner="${zone2_array[$((RANDOM % ${#zone2_array[@]}))]}"
            chown "$owner:$owner" "$filepath" 2>/dev/null || true
        fi
    done
done

chmod -R 755 /mnt/efs/drug_discovery
echo "  ✓ Drug discovery zone data created" | tee -a "$LOG_FILE"

# ============================================================================
# REGULATORY ZONE (Zone 3)
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "=== Creating Regulatory Zone Data ===" | tee -a "$LOG_FILE"

mapfile -t regulatory_templates < <(jq -r '.file_templates.regulatory[]' "$CONFIG_FILE")
mapfile -t regulatory_dirs < <(jq -r '.directories.regulatory[]' "$CONFIG_FILE")

zone3_users=$(jq -r '.users[] | select(.zone_admin[] == "regulatory" or .zone_member[] == "regulatory") | .username' "$CONFIG_FILE")
zone3_array=($zone3_users)

for dir in "${regulatory_dirs[@]}"; do
    [ -z "$dir" ] && continue
    [ $total_size -ge $MAX_TOTAL_KB ] && break
    
    dir_path="/mnt/efs/regulatory/$dir"
    mkdir -p "$dir_path"
    
    num_files=$(random_range 2 4)
    echo "  Creating $dir ($num_files files)..." | tee -a "$LOG_FILE"
    
    for ((i=1; i<=num_files; i++)); do
        [ $total_size -ge $MAX_TOTAL_KB ] && break
        
        template="${regulatory_templates[$((RANDOM % ${#regulatory_templates[@]}))]}"
        filename=$(generate_filename "$template" "$RANDOM" "$i")
        filepath="$dir_path/$filename"
        
        size_kb=$(random_range 20 150)
        create_small_file "$filepath" $size_kb
        total_size=$((total_size + size_kb))
        
        if [ ${#zone3_array[@]} -gt 0 ]; then
            owner="${zone3_array[$((RANDOM % ${#zone3_array[@]}))]}"
            chown "$owner:$owner" "$filepath" 2>/dev/null || true
        fi
    done
done

chmod -R 755 /mnt/efs/regulatory
echo "  ✓ Regulatory zone data created" | tee -a "$LOG_FILE"

# ============================================================================
# Summary
# ============================================================================
echo "" | tee -a "$LOG_FILE"
echo "=== Shared Storage Summary ===" | tee -a "$LOG_FILE"
echo "clinical_trials: $(du -sh /mnt/efs/clinical_trials 2>/dev/null | cut -f1)" | tee -a "$LOG_FILE"
echo "drug_discovery:  $(du -sh /mnt/efs/drug_discovery 2>/dev/null | cut -f1)" | tee -a "$LOG_FILE"
echo "regulatory:      $(du -sh /mnt/efs/regulatory 2>/dev/null | cut -f1)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Total shared data: ~${total_size}KB" | tee -a "$LOG_FILE"
echo "=== Shared Data Generation Completed: $(date) ===" | tee -a "$LOG_FILE"
