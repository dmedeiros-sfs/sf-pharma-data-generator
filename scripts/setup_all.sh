#!/bin/bash
#
# setup_all.sh - Complete setup for the Starfish demo data generator
#
# Prompts for which dataset(s) to build (pharma / education / both), then for
# each selected dataset runs: create users -> generate home data ->
# generate shared zone data -> configure Starfish -> archive demo.
#
# Options:
#   --dataset NAME     pharma | education | both  (skips the interactive prompt)
#   --skip-users       Skip user creation
#   --skip-data        Skip data generation
#   --skip-starfish    Skip Starfish configuration (and archive demo)
#   --clean-first      Run cleanup for the selected dataset(s) before setup
#   --agent-address U  Agent URL for volume creation (when running on agent)
#   --server           Running on Starfish server (skip agent prompt)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
LOG_FILE="$SCRIPT_DIR/../output/setup_all.log"
mkdir -p "$SCRIPT_DIR/../output"

SKIP_USERS=false
SKIP_DATA=false
SKIP_STARFISH=false
CLEAN_FIRST=false
AGENT_ADDRESS=""
IS_SERVER=false
DATASET_CHOICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dataset) DATASET_CHOICE="$2"; shift 2 ;;
        --skip-users) SKIP_USERS=true; shift ;;
        --skip-data) SKIP_DATA=true; shift ;;
        --skip-starfish) SKIP_STARFISH=true; shift ;;
        --clean-first) CLEAN_FIRST=true; shift ;;
        --agent-address) AGENT_ADDRESS="$2"; shift 2 ;;
        --server) IS_SERVER=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dataset NAME        pharma | education | both (skips prompt)"
            echo "  --skip-users          Skip user creation"
            echo "  --skip-data           Skip data generation"
            echo "  --skip-starfish       Skip Starfish configuration"
            echo "  --clean-first         Run cleanup before setup"
            echo "  --agent-address URL   Agent URL for volume creation"
            echo "  --server              Running on the Starfish server"
            echo "  -h, --help            Show this help"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

cat <<'BANNER'
+==============================================================================+
|                                                                              |
|                    STARFISH DEMO DATA GENERATOR                              |
|                                                                              |
+==============================================================================+
BANNER

# ---- Choose dataset(s) ------------------------------------------------------
if [ -z "$DATASET_CHOICE" ]; then
    echo ""
    echo "Which dataset would you like to generate?"
    echo "  1) pharma     - Pharmaceutical research (8 users, 3 zones)"
    echo "  2) education  - University research computing (8 users, 3 zones)"
    echo "  3) both       - Generate both datasets side by side"
    echo ""
    read -p "Select [1/2/3] (default 1): " ds_input
    case "$ds_input" in
        2|education|edu) DATASET_CHOICE="education" ;;
        3|both)          DATASET_CHOICE="both" ;;
        *)               DATASET_CHOICE="pharma" ;;
    esac
fi

case "$DATASET_CHOICE" in
    pharma)    DATASETS=(pharma) ;;
    education) DATASETS=(education) ;;
    both)      DATASETS=(pharma education) ;;
    *)
        # Allow an explicit config path/name too
        if [ -n "$(dataset_config_path "$DATASET_CHOICE")" ]; then
            DATASETS=("$DATASET_CHOICE")
        else
            echo "Unknown dataset: $DATASET_CHOICE (use pharma|education|both)"; exit 1
        fi
        ;;
esac

echo "" | tee -a "$LOG_FILE"
echo "=== Setup Started: $(date) ===" | tee -a "$LOG_FILE"
echo "Datasets: ${DATASETS[*]}" | tee -a "$LOG_FILE"

# ---- Agent / server question (asked once for all datasets) ------------------
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
        AGENT_ADDRESS=""; IS_SERVER=true
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

# Helper to pass agent/server consistently to sub-scripts
sf_target_args() {
    if [ -n "$AGENT_ADDRESS" ]; then
        echo "--agent-address $AGENT_ADDRESS"
    else
        echo "--server"
    fi
}

# ---- Run pipeline per dataset ----------------------------------------------
for ds in "${DATASETS[@]}"; do
    cfg_path="$(dataset_config_path "$ds")"

    echo "" | tee -a "$LOG_FILE"
    echo "###############################################################################" | tee -a "$LOG_FILE"
    echo "# DATASET: $ds   ($cfg_path)" | tee -a "$LOG_FILE"
    echo "###############################################################################" | tee -a "$LOG_FILE"

    if [ "$CLEAN_FIRST" = true ]; then
        echo "Running cleanup for $ds first..." | tee -a "$LOG_FILE"
        "$SCRIPT_DIR/cleanup.sh" --dataset "$ds" --all -y
        echo "" | tee -a "$LOG_FILE"
    fi

    if [ "$SKIP_USERS" = false ]; then
        echo "=== STEP 1 [$ds]: Creating Users ===" | tee -a "$LOG_FILE"
        "$SCRIPT_DIR/create_users.sh" --dataset "$ds"
    else
        echo "Skipping user creation (--skip-users)" | tee -a "$LOG_FILE"
    fi

    if [ "$SKIP_DATA" = false ]; then
        echo "=== STEP 2 [$ds]: Generating User Home Data ===" | tee -a "$LOG_FILE"
        "$SCRIPT_DIR/generate_data.sh" --dataset "$ds"
        echo "=== STEP 3 [$ds]: Generating Shared Zone Data ===" | tee -a "$LOG_FILE"
        "$SCRIPT_DIR/generate_shared_data.sh" --dataset "$ds"
    else
        echo "Skipping data generation (--skip-data)" | tee -a "$LOG_FILE"
    fi

    if [ "$SKIP_STARFISH" = false ]; then
        echo "=== STEP 4 [$ds]: Configuring Starfish ===" | tee -a "$LOG_FILE"
        "$SCRIPT_DIR/configure_starfish.sh" --dataset "$ds" $(sf_target_args)
        echo "=== STEP 5 [$ds]: Archive Demo ===" | tee -a "$LOG_FILE"
        "$SCRIPT_DIR/setup_archive_demo.sh" --dataset "$ds" $(sf_target_args)
    else
        echo "Skipping Starfish configuration (--skip-starfish)" | tee -a "$LOG_FILE"
    fi
done

echo "" | tee -a "$LOG_FILE"
echo "===============================================================================" | tee -a "$LOG_FILE"
echo "SETUP COMPLETE - datasets: ${DATASETS[*]}" | tee -a "$LOG_FILE"
echo "===============================================================================" | tee -a "$LOG_FILE"
echo "Run scripts/stats.sh --dataset <name> for a status summary." | tee -a "$LOG_FILE"
echo "=== Setup Completed: $(date) ===" | tee -a "$LOG_FILE"
