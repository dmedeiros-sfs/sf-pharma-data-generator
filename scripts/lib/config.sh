#!/bin/bash
#
# lib/config.sh - Shared dataset/config resolution for the demo data generator.
#
# Source this from any script:  source "$SCRIPT_DIR/lib/config.sh"
#
# It provides:
#   dataset_config_path NAME   -> echoes the config path for a dataset name
#   resolve_config_arg ARG VAL -> handles --config / --dataset during arg parsing
#   cfg QUERY                  -> jq -r QUERY against the resolved $CONFIG_FILE
#   cfg_*                      -> accessors for config values with sane defaults
#
# After parsing args, $CONFIG_FILE points at the active config. If neither
# --config nor --dataset was given it defaults to pharma_config.json, which
# preserves the original single-dataset behaviour.

# Directory that holds the config/ folder (one level up from scripts/)
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(cd "$_LIB_DIR/../../config" && pwd)"

# Default config (backward compatible)
CONFIG_FILE="${CONFIG_FILE:-$CONFIG_DIR/pharma_config.json}"

# Map a friendly dataset name to a config file path.
dataset_config_path() {
    local name="$1"
    case "$name" in
        pharma|pharmaceutical)  echo "$CONFIG_DIR/pharma_config.json" ;;
        education|edu|academic|university) echo "$CONFIG_DIR/education_config.json" ;;
        *)
            # Allow passing an explicit path or a bare config name in config/
            if [ -f "$name" ]; then
                echo "$name"
            elif [ -f "$CONFIG_DIR/$name" ]; then
                echo "$CONFIG_DIR/$name"
            elif [ -f "$CONFIG_DIR/${name}_config.json" ]; then
                echo "$CONFIG_DIR/${name}_config.json"
            else
                echo ""
            fi
            ;;
    esac
}

# jq accessor against the active config file.
cfg() {
    jq -r "$1" "$CONFIG_FILE" 2>/dev/null
}

# ---- Config accessors with defaults (so older configs still work) ----------

# Dataset label, used in banners/summaries only.
cfg_label() {
    local v; v=$(cfg '.dataset.label // empty')
    [ -n "$v" ] && echo "$v" || echo "Demo"
}

# Shared volume name + mount for zone data.
cfg_shared_vol_name() {
    local v; v=$(cfg '.shared_volume.name // empty')
    [ -n "$v" ] && echo "$v" || echo "efs"
}
cfg_shared_vol_mount() {
    local v; v=$(cfg '.shared_volume.mount // empty')
    [ -n "$v" ] && echo "$v" || echo "/mnt/efs"
}

# Global role used to grant TagApplier to all zone users.
cfg_global_role_name() {
    local v; v=$(cfg '.global_role.name // empty')
    [ -n "$v" ] && echo "$v" || echo "DemoTaggers"
}
cfg_global_role_cap() {
    local v; v=$(cfg '.global_role.capability // empty')
    [ -n "$v" ] && echo "$v" || echo "TagApplier"
}

# Home-directory data: subdir under /home/<user> and the template/dir key to use.
cfg_home_subdir() {
    local v; v=$(cfg '.home.subdir // empty')
    [ -n "$v" ] && echo "$v" || echo "research"
}
cfg_home_key() {
    local v; v=$(cfg '.home.template_key // empty')
    [ -n "$v" ] && echo "$v" || echo "research"
}

# For a zone name, the key under file_templates/directories that feeds it.
# Falls back to the zone name itself if no template_key is declared.
cfg_zone_template_key() {
    local zone="$1"
    local v
    v=$(cfg ".zones[] | select(.name==\"$zone\") | .template_key // empty")
    [ -n "$v" ] && echo "$v" || echo "$zone"
}
