#!/bin/bash
#
# setup_all.sh - Complete setup script for Starfish Pharma Demo
#
# This script runs all setup steps in sequence:
# 1. Create users
# 2. Generate user home data
# 3. Generate shared zone data
# 4. Configure Starfish (zones, tagsets, permissions)
#
# Options:
#   --skip-users       Skip user creation
#   --skip-data        Skip data generation
#   --skip-starfish    Skip Starfish configuration
#   --clean-first      Run cleanup before setup
#   --agent-address    Agent URL for volume creation (when running on agent)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../output/setup_all.log"

mkdir -p "$SCRIPT_DIR/../output"

# Parse arguments
SKIP_USERS=false
SKIP_DATA=false
SKIP_STARFISH=false
CLEAN_FIRST=false
AGENT_ADDRESS=""
IS_SERVER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-users)
            SKIP_USERS=true
            shift
            ;;
        --skip-data)
            SKIP_DATA=true
            shift
            ;;
        --skip-starfish)
            SKIP_STARFISH=true
            shift
            ;;
        --clean-first)
            CLEAN_FIRST=true
            shift
            ;;
        --agent-address)
            AGENT_ADDRESS="$2"
            shift 2
            ;;
        --server)
            IS_SERVER=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-users          Skip user creation"
            echo "  --skip-data           Skip data generation"
            echo "  --skip-starfish       Skip Starfish configuration"
            echo "  --clean-first         Run cleanup before setup"
            echo "  --agent-address URL   Agent URL for volume creation (when running on agent)"
            echo "  --server              Running on Starfish server (skip agent prompt)"
            echo "  -h, --help            Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

cat <<'BANNER'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ███████╗████████╗ █████╗ ██████╗ ███████╗██╗███████╗██╗  ██╗                ║
║   ██╔════╝╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║██╔════╝██║  ██║                ║
║   ███████╗   ██║   ███████║██████╔╝█████╗  ██║███████╗███████║                ║
║   ╚════██║   ██║   ██╔══██║██╔══██╗██╔══╝  ██║╚════██║██╔══██║                ║
║   ███████║   ██║   ██║  ██║██║  ██║██║     ██║███████║██║  ██║                ║
║   ╚══════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝                ║
║                                                                               ║
║                     PHARMA DEMO DATA GENERATOR                                ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
BANNER

echo "" | tee -a "$LOG_FILE"
echo "=== Setup Started: $(date) ===" | tee -a "$LOG_FILE"

# If not skipping Starfish and no agent address provided, ask user
if [ "$SKIP_STARFISH" = false ] && [ -z "$AGENT_ADDRESS" ] && [ "$IS_SERVER" = false ]; then
    echo ""
    suggested_url="https://$(hostname -f):30002"
    echo "Running on agent or server?"
    echo "  - Press Enter to use agent: $suggested_url"
    echo "  - Type a different agent URL"
    echo "  - Type 'server' or 's' if running on the Starfish server"
    echo ""
    read -p "[$suggested_url]: " user_input
    
    if [[ "$user_input" =~ ^[Ss](erver)?$ ]]; then
        # Running on server
        AGENT_ADDRESS=""
        IS_SERVER=true
    elif [ -z "$user_input" ]; then
        # Empty input = use suggested URL (default)
        AGENT_ADDRESS="$suggested_url"
    else
        # User provided a URL
        AGENT_ADDRESS="$user_input"
    fi
fi

if [ -n "$AGENT_ADDRESS" ]; then
    echo "Agent address: $AGENT_ADDRESS" | tee -a "$LOG_FILE"
else
    echo "Running on server (no agent address)" | tee -a "$LOG_FILE"
fi
echo "" | tee -a "$LOG_FILE"

# Clean first if requested
if [ "$CLEAN_FIRST" = true ]; then
    echo "Running cleanup first..." | tee -a "$LOG_FILE"
    "$SCRIPT_DIR/cleanup.sh" --all -y
    echo "" | tee -a "$LOG_FILE"
fi

# Step 1: Create Users
if [ "$SKIP_USERS" = false ]; then
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "STEP 1: Creating Users" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    "$SCRIPT_DIR/create_users.sh"
    echo "" | tee -a "$LOG_FILE"
else
    echo "Skipping user creation (--skip-users)" | tee -a "$LOG_FILE"
fi

# Step 2: Generate User Home Data
if [ "$SKIP_DATA" = false ]; then
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "STEP 2: Generating User Home Data" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    "$SCRIPT_DIR/generate_data.sh"
    echo "" | tee -a "$LOG_FILE"
    
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "STEP 3: Generating Shared Zone Data" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    "$SCRIPT_DIR/generate_shared_data.sh"
    echo "" | tee -a "$LOG_FILE"
else
    echo "Skipping data generation (--skip-data)" | tee -a "$LOG_FILE"
fi

# Step 3: Configure Starfish
if [ "$SKIP_STARFISH" = false ]; then
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "STEP 4: Configuring Starfish (Zones, Tag Sets, Permissions)" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    if [ -n "$AGENT_ADDRESS" ]; then
        "$SCRIPT_DIR/configure_starfish.sh" --agent-address "$AGENT_ADDRESS"
    else
        "$SCRIPT_DIR/configure_starfish.sh" --server
    fi
    echo "" | tee -a "$LOG_FILE"
else
    echo "Skipping Starfish configuration (--skip-starfish)" | tee -a "$LOG_FILE"
fi

# Step 4: Setup Archive Demo
if [ "$SKIP_STARFISH" = false ]; then
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    echo "STEP 5: Setting Up Archive Demo (Archive Targets and Jobs)" | tee -a "$LOG_FILE"
    echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
    if [ -n "$AGENT_ADDRESS" ]; then
        "$SCRIPT_DIR/setup_archive_demo.sh" --agent-address "$AGENT_ADDRESS"
    else
        "$SCRIPT_DIR/setup_archive_demo.sh" --server
    fi
    echo "" | tee -a "$LOG_FILE"
fi

# Final Summary
echo "" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
echo "SETUP COMPLETE" | tee -a "$LOG_FILE"
echo "═══════════════════════════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Users Created (password = username):" | tee -a "$LOG_FILE"
echo "  dthompson  - Dr. Diana Thompson (Clinical Research Director) - Zone Admin: clinical_trials" | tee -a "$LOG_FILE"
echo "  mwatson    - Dr. Michael Watson (Drug Discovery Lead)        - Zone Admin: drug_discovery, regulatory" | tee -a "$LOG_FILE"
echo "  sleung     - Dr. Sarah Leung (Pharmacovigilance Manager)     - Zone Member: clinical_trials" | tee -a "$LOG_FILE"
echo "  jbaker     - Dr. James Baker (Manufacturing QA Lead)         - Zone Member: drug_discovery" | tee -a "$LOG_FILE"
echo "  nromero    - Dr. Nina Romero (Regulatory Affairs Director)   - Zone Member: regulatory" | tee -a "$LOG_FILE"
echo "  kpatel     - Dr. Kiran Patel (Senior Biostatistician)        - Zone Member: clinical_trials, drug_discovery" | tee -a "$LOG_FILE"
echo "  akim       - Dr. Amy Kim (Medical Writer)                    - Zone Member: drug_discovery, regulatory" | tee -a "$LOG_FILE"
echo "  rmorgan    - Dr. Robert Morgan (Research Associate)          - NO ZONE (personal files only)" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Zones:" | tee -a "$LOG_FILE"
echo "  clinical_trials  - /mnt/efs/clinical_trials  (Clinical trial data)" | tee -a "$LOG_FILE"
echo "  drug_discovery   - /mnt/efs/drug_discovery   (Drug discovery research)" | tee -a "$LOG_FILE"
echo "  regulatory       - /mnt/efs/regulatory       (Regulatory submissions)" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Tag Sets:" | tee -a "$LOG_FILE"
echo "  document_status   - Tags: draft, in_review, approved, archived, superseded" | tee -a "$LOG_FILE"
echo "  confidentiality   - Tags: public, internal, confidential, restricted, top_secret" | tee -a "$LOG_FILE"
echo "  therapeutic_area  - Tags: oncology, cardiology, neurology, immunology, infectious_disease, rare_disease" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Data Locations:" | tee -a "$LOG_FILE"
echo "  User homes:    /home/{username}/research/" | tee -a "$LOG_FILE"
echo "  Shared zones:  /mnt/efs/{clinical_trials,drug_discovery,regulatory}/" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "Archive Targets:" | tee -a "$LOG_FILE"
echo "  atg-sim-nfs     -> sim-nfs:/archives" | tee -a "$LOG_FILE"
echo "  atg-sim-lustre  -> sim-lustre:/archives" | tee -a "$LOG_FILE"
echo "  atg-sim-s3      -> sim-s3:/archives" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=== Setup Completed: $(date) ===" | tee -a "$LOG_FILE"
