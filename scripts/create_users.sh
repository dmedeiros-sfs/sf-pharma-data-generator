#!/bin/bash
#
# create_users.sh - Create users for a Starfish demo dataset
# Uses chroot-compatible user creation with password = username
#
# Options:
#   --dataset NAME    pharma | education (default: pharma)
#   --config PATH     Explicit path to a dataset config JSON
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"

# Parse args (sets CONFIG_FILE)
while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset) CONFIG_FILE="$(dataset_config_path "$2")"; shift 2 ;;
        --config)  CONFIG_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: config file not found: $CONFIG_FILE"; exit 1
fi

LOG_FILE="$SCRIPT_DIR/../output/user_creation.log"
mkdir -p "$SCRIPT_DIR/../output"
echo "=== User Creation Started: $(date) ===" | tee -a "$LOG_FILE"
echo "Dataset config: $CONFIG_FILE ($(cfg_label))" | tee -a "$LOG_FILE"

# Check for required tools
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required. Install with: sudo apt-get install jq" | tee -a "$LOG_FILE"
    exit 1
fi

if ! command -v openssl &> /dev/null; then
    echo "Error: openssl is required for password hashing" | tee -a "$LOG_FILE"
    exit 1
fi

# Ensure starfish group exists
if ! getent group starfish &>/dev/null; then
    echo "Creating 'starfish' group..." | tee -a "$LOG_FILE"
    groupadd starfish
fi

# Get all users from config
users=$(cfg '.users[] | .username')

for username in $users; do
    full_name=$(cfg ".users[] | select(.username==\"$username\") | .full_name")
    role=$(cfg ".users[] | select(.username==\"$username\") | .role")
    department=$(cfg ".users[] | select(.username==\"$username\") | .department")

    if id "$username" &>/dev/null; then
        echo "User $username already exists, skipping creation..." | tee -a "$LOG_FILE"
        # Ensure home directory exists
        if [ ! -d "/home/$username" ]; then
            mkdir -p "/home/$username"
            chown "$username:$username" "/home/$username"
            chmod 755 "/home/$username"
            echo "  Created missing home directory for $username" | tee -a "$LOG_FILE"
        fi
        # Ensure user is in starfish group
        if ! groups "$username" | grep -q '\bstarfish\b'; then
            usermod -aG starfish "$username"
            echo "  Added $username to starfish group" | tee -a "$LOG_FILE"
        fi
        continue
    fi

    echo "Creating user: $username ($full_name)" | tee -a "$LOG_FILE"

    # Create user and add to starfish group (chroot-compatible method)
    useradd -m -s /bin/bash -c "$full_name" -G starfish "$username"

    # Set password = username using openssl (chroot-compatible)
    # This avoids interactive password prompts
    HASHED_PW=$(openssl passwd -6 "$username")
    sed -i "s|^${username}:[^:]*:|${username}:${HASHED_PW}:|" /etc/shadow

    # Create user info file
    cat > "/home/$username/USER_INFO.txt" <<USERINFO
==================================================
Starfish Demo - User Information ($(cfg_label))
==================================================
Name: $full_name
Username: $username
Password: $username
Department: $department
Role: $role
Created: $(date)
==================================================
USERINFO

    chown "$username:$username" "/home/$username/USER_INFO.txt"
    chmod 600 "/home/$username/USER_INFO.txt"

    echo "  Created user: $username" | tee -a "$LOG_FILE"
done

echo "" | tee -a "$LOG_FILE"
echo "=== User Creation Completed: $(date) ===" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Summary: All users created with password = username" | tee -a "$LOG_FILE"
echo "Users are members of the 'starfish' group for GUI access" | tee -a "$LOG_FILE"
