#!/bin/bash
#
# generate_data.sh - Generate dummy pharma data files
# Max 5MB total, various file types and sizes
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/pharma_config.json"
LOG_FILE="$SCRIPT_DIR/../output/data_generation.log"

mkdir -p "$SCRIPT_DIR/../output"
echo "=== Data Generation Started: $(date) ===" | tee -a "$LOG_FILE"

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq"
    exit 1
fi

# Random number in range
random_range() {
    local min=$1
    local max=$2
    echo $((min + RANDOM % (max - min + 1)))
}

# Generate filename from template
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

# Create a small file with random content
create_small_file() {
    local filepath=$1
    local size_kb=$2
    
    dd if=/dev/urandom of="$filepath" bs=1K count=$size_kb status=none 2>/dev/null || \
    head -c ${size_kb}K /dev/urandom > "$filepath" 2>/dev/null || \
    truncate -s ${size_kb}K "$filepath"
}

total_size=0
MAX_TOTAL_KB=5120  # 5MB max

echo "Creating user home directories data..." | tee -a "$LOG_FILE"

# Get users
users=$(jq -r '.users[] | .username' "$CONFIG_FILE")

for username in $users; do
    if [ $total_size -ge $MAX_TOTAL_KB ]; then
        echo "  Reached max total size limit" | tee -a "$LOG_FILE"
        break
    fi
    
    if ! id "$username" &>/dev/null; then
        echo "  Skipping $username - user doesn't exist" | tee -a "$LOG_FILE"
        continue
    fi
    
    echo "  Processing user: $username" | tee -a "$LOG_FILE"
    
    user_home="/home/$username"
    
    # Create 2 directories per user with 2-3 files each (small)
    mapfile -t research_templates < <(jq -r '.file_templates.research[]' "$CONFIG_FILE")
    mapfile -t research_dirs < <(jq -r '.directories.research[]' "$CONFIG_FILE" | head -2)
    
    for dir in "${research_dirs[@]}"; do
        [ -z "$dir" ] && continue
        
        dir_path="$user_home/research/$dir"
        mkdir -p "$dir_path"
        
        # 2-3 files per directory
        num_files=$(random_range 2 3)
        
        for ((i=1; i<=num_files; i++)); do
            [ $total_size -ge $MAX_TOTAL_KB ] && break
            
            template="${research_templates[$((RANDOM % ${#research_templates[@]}))]}"
            filename=$(generate_filename "$template" "$RANDOM" "$i")
            filepath="$dir_path/$filename"
            
            # Small files: 10KB - 100KB
            size_kb=$(random_range 10 100)
            create_small_file "$filepath" $size_kb
            total_size=$((total_size + size_kb))
        done
        
        chown -R "$username:$username" "$dir_path" 2>/dev/null || true
    done
    
    echo "    Created research directories for $username" | tee -a "$LOG_FILE"
done

echo "" | tee -a "$LOG_FILE"
echo "Total data created: ~${total_size}KB" | tee -a "$LOG_FILE"
echo "=== User Home Data Generation Completed: $(date) ===" | tee -a "$LOG_FILE"
