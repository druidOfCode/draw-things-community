#!/bin/bash

# Manage individual model configurations in custom.json
# This script helps add/update/remove specific model configurations

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_DIR="$HOME/Development/draw-things-server"
MODELS_DIR="$SERVER_DIR/models"
CUSTOM_JSON="$MODELS_DIR/custom.json"
CUSTOM_CONFIGS_DIR="$MODELS_DIR/custom_configs"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to show help
show_help() {
    cat << EOF
Draw Things Model Configuration Manager

Usage: $0 COMMAND [OPTIONS]

Commands:
  list                    List all configured models
  add MODEL_FILE          Add/update a model configuration
  remove MODEL_NAME       Remove a model configuration
  backup                  Create backup of current custom.json
  restore                 Restore from backup
  validate               Validate custom.json syntax

Options for 'add':
  --name NAME             Custom model name (default: filename)
  --version VERSION       Model version (sd_v1.5, sdxl_base_v0.9, flux1)
  --scale SCALE           Default scale (default: 16)
  --prefix PREFIX         Text prefix
  --config-file FILE      Use custom JSON config file

Examples:
  $0 list
  $0 add my_model.ckpt --name "My Custom Model" --version flux1
  $0 remove my_model
  $0 validate

Custom Configuration Files:
You can create custom configurations in: $CUSTOM_CONFIGS_DIR/
Example: $CUSTOM_CONFIGS_DIR/my_model.json

EOF
}

# Function to validate JSON
validate_json() {
    local file="$1"
    if command -v jq >/dev/null 2>&1; then
        jq empty "$file" 2>/dev/null
    else
        python3 -m json.tool "$file" >/dev/null 2>&1
    fi
}

# Function to list models
list_models() {
    if [ ! -f "$CUSTOM_JSON" ]; then
        warn "custom.json not found. Run update-custom-json.sh first."
        return 1
    fi
    
    log "Configured models:"
    if command -v jq >/dev/null 2>&1; then
        jq -r '.[] | "  - " + .name + " (" + .file + ")"' "$CUSTOM_JSON"
    else
        info "Install 'jq' for better output formatting"
        grep '"name":' "$CUSTOM_JSON" | sed 's/.*"name": "\([^"]*\)".*/  - \1/'
    fi
}

# Function to add/update model
add_model() {
    local model_file="$1"
    local model_name="${2:-$(basename "$model_file" .ckpt)}"
    local version="${3:-auto}"
    local scale="${4:-16}"
    local prefix="${5:-}"
    local config_file="${6:-}"
    
    if [ ! -f "$MODELS_DIR/$model_file" ]; then
        error "Model file not found: $MODELS_DIR/$model_file"
        return 1
    fi
    
    # Check for custom config file
    if [ -n "$config_file" ] && [ -f "$config_file" ]; then
        log "Using custom configuration from: $config_file"
        # TODO: Implement custom config merging
        warn "Custom config file support not yet implemented"
    fi
    
    log "Adding/updating model: $model_name"
    info "This is a placeholder - full implementation would modify custom.json"
    info "For now, run update-custom-json.sh to regenerate the file"
}

# Function to remove model
remove_model() {
    local model_name="$1"
    
    log "Removing model: $model_name"
    info "This is a placeholder - full implementation would modify custom.json"
    info "For now, manually edit custom.json or run update-custom-json.sh"
}

# Function to backup custom.json
backup_config() {
    if [ ! -f "$CUSTOM_JSON" ]; then
        warn "custom.json not found"
        return 1
    fi
    
    local backup_file="$CUSTOM_JSON.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CUSTOM_JSON" "$backup_file"
    log "Backup created: $backup_file"
}

# Function to restore from backup
restore_config() {
    local backup_file="$CUSTOM_JSON.backup"
    
    if [ ! -f "$backup_file" ]; then
        error "Backup file not found: $backup_file"
        return 1
    fi
    
    cp "$backup_file" "$CUSTOM_JSON"
    log "Configuration restored from backup"
}

# Function to validate configuration
validate_config() {
    if [ ! -f "$CUSTOM_JSON" ]; then
        error "custom.json not found"
        return 1
    fi
    
    log "Validating custom.json..."
    if validate_json "$CUSTOM_JSON"; then
        log "✓ custom.json is valid JSON"
    else
        error "✗ custom.json has syntax errors"
        return 1
    fi
    
    # Additional validation could go here
    # - Check required fields
    # - Verify file references
    # - Validate version strings
    
    log "✓ Configuration validation passed"
}

# Main script logic
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    list)
        list_models
        ;;
    add)
        if [ $# -eq 0 ]; then
            error "Model file required for 'add' command"
            exit 1
        fi
        add_model "$@"
        ;;
    remove)
        if [ $# -eq 0 ]; then
            error "Model name required for 'remove' command"
            exit 1
        fi
        remove_model "$1"
        ;;
    backup)
        backup_config
        ;;
    restore)
        restore_config
        ;;
    validate)
        validate_config
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac

