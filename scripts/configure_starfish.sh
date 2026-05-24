#!/bin/bash
#
# configure_starfish.sh - Configure Starfish zones, tag sets, and permissions
#                         for a dataset.
#
# Reads the dataset config for: per-user volumes, shared volume, zones (with
# template_key -> path), tag sets, zone members/admins, and the global tagging
# role. All sf object names come from the config so multiple datasets coexist.
#
# Options:
#   --dataset NAME        pharma | education (default: pharma)
#   --config PATH         Explicit path to a dataset config JSON
#   --agent-address URL   Use this agent address for volume creation
#   --server              Running on the Starfish server (no agent)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

AGENT_ADDRESS=""
IS_SERVER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset) CONFIG_FILE="$(dataset_config_path "$2")"; shift 2 ;;
        --config)  CONFIG_FILE="$2"; shift 2 ;;
        --agent-address) AGENT_ADDRESS="$2"; shift 2 ;;
        --server) IS_SERVER=true; shift ;;
        *) echo "Unknown option: $1"; echo "Usage: $0 [--dataset NAME|--config PATH] [--agent-address URL] [--server]"; exit 1 ;;
    esac
done
[ -f "$CONFIG_FILE" ] || { echo "Error: config not found: $CONFIG_FILE"; exit 1; }

LOG_FILE="$SCRIPT_DIR/../output/starfish_config.log"
mkdir -p "$SCRIPT_DIR/../output"

SHARED_VOLUME_NAME="$(cfg_shared_vol_name)"
SHARED_VOLUME_MOUNT="$(cfg_shared_vol_mount)"
GLOBAL_ROLE="$(cfg_global_role_name)"
GLOBAL_ROLE_CAP="$(cfg_global_role_cap)"

echo "=== Starfish Configuration Started: $(date) ===" | tee -a "$LOG_FILE"
echo "Dataset config: $CONFIG_FILE ($(cfg_label))" | tee -a "$LOG_FILE"
echo "Shared volume: $SHARED_VOLUME_NAME ($SHARED_VOLUME_MOUNT)" | tee -a "$LOG_FILE"

# If no agent address provided and not explicitly server, ask user
if [ -z "$AGENT_ADDRESS" ] && [ "$IS_SERVER" = false ]; then
    suggested_url="https://$(hostname -f):30002"
    echo ""
    echo "Running on agent or server?"
    echo "  - Press Enter to use agent: $suggested_url"
    echo "  - Type a different agent URL"
    echo "  - Type 'server' or 's' if running on the Starfish server"
    echo ""
    read -p "[$suggested_url]: " user_input

    if [[ "$user_input" =~ ^[Ss](erver)?$ ]]; then
        AGENT_ADDRESS=""
    elif [ -z "$user_input" ]; then
        AGENT_ADDRESS="$suggested_url"
    else
        AGENT_ADDRESS="$user_input"
    fi
fi

if [ -n "$AGENT_ADDRESS" ]; then
    echo "Agent address: $AGENT_ADDRESS" | tee -a "$LOG_FILE"
else
    echo "Running on server (no agent address)" | tee -a "$LOG_FILE"
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq"
    exit 1
fi

if ! command -v sf &> /dev/null; then
    echo "Error: 'sf' command not found. Is Starfish installed?"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 0: Creating Volumes" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

wait_for_pending_scans() {
    echo "    Waiting for pending scans to complete..." | tee -a "$LOG_FILE"
    while true; do
        pending_output=$(sf scan pending 2>/dev/null || true)
        pending=$(echo "$pending_output" | grep -cE "RUNNING|PENDING" || echo "0")
        pending=$(echo "$pending" | head -1 | tr -d '[:space:]')
        if [ -z "$pending" ] || [ "$pending" -eq 0 ] 2>/dev/null; then
            break
        fi
        echo "      $pending scan(s) still running, waiting..." | tee -a "$LOG_FILE"
        sleep 5
    done
    echo "    No pending scans" | tee -a "$LOG_FILE"
}

run_diff_scan() {
    local vol_name="$1"
    echo "    Running diff scan on '$vol_name'..." | tee -a "$LOG_FILE"
    sf scan start -t diff "$vol_name:" --wait 2>&1 | tee -a "$LOG_FILE" || true
    echo "    Scan complete for '$vol_name'" | tee -a "$LOG_FILE"
}

add_volume() {
    local vol_name="$1"
    local vol_mount="$2"
    if [ -n "$AGENT_ADDRESS" ]; then
        sf volume add "$vol_name" "$vol_mount" --agent-address "$AGENT_ADDRESS" --no-cron 2>&1 | tee -a "$LOG_FILE" || true
    else
        sf volume add "$vol_name" "$vol_mount" --no-cron 2>&1 | tee -a "$LOG_FILE" || true
    fi
}

# Create per-user volumes
echo "" | tee -a "$LOG_FILE"
echo "Creating per-user volumes..." | tee -a "$LOG_FILE"

users=$(cfg '.users[] | .username')
declare -a ALL_VOLUMES=()

for username in $users; do
    vol_name="${username}"
    vol_mount="/home/${username}"

    if sf volume show "$vol_name" &>/dev/null; then
        echo "  Volume '$vol_name' already exists" | tee -a "$LOG_FILE"
    else
        echo "  Creating volume '$vol_name' at '$vol_mount'" | tee -a "$LOG_FILE"
        add_volume "$vol_name" "$vol_mount"
    fi
    ALL_VOLUMES+=("$vol_name")
done

# Create shared volume for zones
echo "" | tee -a "$LOG_FILE"
echo "Creating shared volume for zones..." | tee -a "$LOG_FILE"

if sf volume show "$SHARED_VOLUME_NAME" &>/dev/null; then
    echo "  Volume '$SHARED_VOLUME_NAME' already exists" | tee -a "$LOG_FILE"
else
    echo "  Creating volume '$SHARED_VOLUME_NAME' at '$SHARED_VOLUME_MOUNT'" | tee -a "$LOG_FILE"
    add_volume "$SHARED_VOLUME_NAME" "$SHARED_VOLUME_MOUNT"
fi
ALL_VOLUMES+=("$SHARED_VOLUME_NAME")

echo "" | tee -a "$LOG_FILE"
echo "Waiting for auto-triggered scans to complete..." | tee -a "$LOG_FILE"
wait_for_pending_scans

echo "" | tee -a "$LOG_FILE"
echo "Running diff scans on all volumes..." | tee -a "$LOG_FILE"
for vol_name in "${ALL_VOLUMES[@]}"; do
    run_diff_scan "$vol_name"
done

echo "" | tee -a "$LOG_FILE"
echo "All volume scans complete." | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 1: Creating Tag Sets" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

tagsets=$(cfg '.tagsets[] | .name')

for tagset in $tagsets; do
    description=$(cfg ".tagsets[] | select(.name==\"$tagset\") | .description")

    echo "" | tee -a "$LOG_FILE"
    echo "Creating tag set: $tagset" | tee -a "$LOG_FILE"

    if sf tagset show "$tagset" &>/dev/null; then
        echo "  Tag set '$tagset' already exists, skipping creation" | tee -a "$LOG_FILE"
    else
        sf tagset add "$tagset" --description "$description" --pinnable --inheritable 2>&1 | tee -a "$LOG_FILE" || true
    fi

    tags=$(cfg ".tagsets[] | select(.name==\"$tagset\") | .tags[]")
    for tag in $tags; do
        echo "  Adding tag: $tag" | tee -a "$LOG_FILE"
        sf tagset tag add "$tagset" "$tag" 2>&1 | tee -a "$LOG_FILE" || true
    done
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 2: Creating Zones" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

zones=$(cfg '.zones[] | .name')

for zone in $zones; do
    description=$(cfg ".zones[] | select(.name==\"$zone\") | .description")

    echo "" | tee -a "$LOG_FILE"
    echo "Creating zone: $zone" | tee -a "$LOG_FILE"

    if sf zone show "$zone" &>/dev/null; then
        echo "  Zone '$zone' already exists, skipping creation" | tee -a "$LOG_FILE"
    else
        sf zone add "$zone" --description "$description" 2>&1 | tee -a "$LOG_FILE" || true
    fi

    echo "  Adding path: $SHARED_VOLUME_NAME:/$zone" | tee -a "$LOG_FILE"
    sf zone path add "$zone" "$SHARED_VOLUME_NAME:/$zone" 2>&1 | tee -a "$LOG_FILE" || true

    echo "  Adding capabilities: TagApplier, RecoverExecutor" | tee -a "$LOG_FILE"
    sf zone capability add "$zone" TagApplier --delegable 2>&1 | tee -a "$LOG_FILE" || true
    sf zone capability add "$zone" RecoverExecutor --delegable 2>&1 | tee -a "$LOG_FILE" || true
done

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 3: Assigning Zone Admins" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for user in $users; do
    admin_zones=$(cfg ".users[] | select(.username==\"$user\") | .zone_admin[]" 2>/dev/null || echo "")
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
    member_zones=$(cfg ".users[] | select(.username==\"$user\") | .zone_member[]" 2>/dev/null || echo "")
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
    bound_zones=$(cfg ".tagsets[] | select(.name==\"$tagset\") | .zones[]")
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
echo "Creating global role '$GLOBAL_ROLE' for all zone users" | tee -a "$LOG_FILE"

if sf role global show "$GLOBAL_ROLE" &>/dev/null; then
    echo "  Global role '$GLOBAL_ROLE' already exists" | tee -a "$LOG_FILE"
else
    sf role global add "$GLOBAL_ROLE" 2>&1 | tee -a "$LOG_FILE" || true
fi
sf role global grant "$GLOBAL_ROLE" "$GLOBAL_ROLE_CAP" 2>&1 | tee -a "$LOG_FILE" || true
sf role global zone add "$GLOBAL_ROLE" --all-zones 2>&1 | tee -a "$LOG_FILE" || true

echo "" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"
echo "STEP 7: Creating Zone Roles for Recovery" | tee -a "$LOG_FILE"
echo "============================================================================" | tee -a "$LOG_FILE"

for zone in $zones; do
    echo "" | tee -a "$LOG_FILE"
    echo "Creating recovery role for zone: $zone" | tee -a "$LOG_FILE"

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
echo "SUMMARY ($(cfg_label)):" | tee -a "$LOG_FILE"
echo "--------" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Volumes created:" | tee -a "$LOG_FILE"
for username in $users; do
    echo "  - $username (/home/$username)" | tee -a "$LOG_FILE"
done
echo "  - $SHARED_VOLUME_NAME ($SHARED_VOLUME_MOUNT) [shared zones]" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Zones created:    $(echo "$zones" | tr '\n' ' ')" | tee -a "$LOG_FILE"
echo "Tag sets created: $(echo "$tagsets" | tr '\n' ' ')" | tee -a "$LOG_FILE"
echo "Global role:      $GLOBAL_ROLE (grants $GLOBAL_ROLE_CAP on all zones)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Zone Admins:" | tee -a "$LOG_FILE"
for zone in $zones; do
    admins=$(cfg ".users[] | select(.zone_admin | index(\"$zone\")) | .username" | tr '\n' ' ')
    echo "  - $zone: $admins" | tee -a "$LOG_FILE"
done
echo "" | tee -a "$LOG_FILE"
echo "Zone Members (non-admin):" | tee -a "$LOG_FILE"
for zone in $zones; do
    members=$(cfg ".users[] | select(.zone_member | index(\"$zone\")) | .username" | tr '\n' ' ')
    echo "  - $zone: $members" | tee -a "$LOG_FILE"
done
echo "" | tee -a "$LOG_FILE"
no_zone=$(cfg '.users[] | select((.zone_admin | length)==0 and (.zone_member | length)==0) | .username' | tr '\n' ' ')
echo "Users with no zone access (personal files only): $no_zone" | tee -a "$LOG_FILE"
