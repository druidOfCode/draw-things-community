#!/bin/bash

# Auto-generate custom.json from discovered models
# This script scans the models directory and updates custom.json with available models

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SERVER_DIR="$HOME/Development/draw-things-server"
MODELS_DIR="$SERVER_DIR/models"
SAFETENSORS_BACKUP_DIR="$MODELS_DIR/safetensors_backup"
CUSTOM_JSON="$MODELS_DIR/custom.json"
CUSTOM_JSON_BACKUP="$MODELS_DIR/custom.json.backup"

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

# Function to detect model type and generate basic config
generate_model_config() {
    local model_file="$1"
    local model_name=$(basename "$model_file" .ckpt)
    model_name=$(basename "$model_name" .safetensors)
    
    # Basic model configuration template
    # This is a simplified version - you may need to adjust based on your specific models
    cat << EOF
  {
    "name": "$model_name",
    "file": "$(basename "$model_file")",
    "default_scale": 16,
    "modifier": "none",
    "prefix": "",
    "upcast_attention": false
EOF
    
    # Try to detect model type based on name patterns and add appropriate config
    if [[ "$model_name" =~ .*xl.* ]] || [[ "$model_name" =~ .*sdxl.* ]]; then
        # SDXL model
        cat << EOF
,
    "version": "sdxl_base_v0.9",
    "text_encoder": "clip_vit_l14_f16.ckpt",
    "clip_encoder": "clip_vit_l14_f16.ckpt",
    "autoencoder": "sdxl_vae_v1.0_f16.ckpt"
EOF
    elif [[ "$model_name" =~ .*flux.* ]] || [[ "$model_name" =~ .*chroma.* ]]; then
        # Flux model
        cat << EOF
,
    "version": "flux1",
    "text_encoder": "t5_xxl_encoder_q6p.ckpt",
    "clip_encoder": "clip_vit_l14_f16.ckpt",
    "autoencoder": "flux_1_vae_f16.ckpt",
    "high_precision_autoencoder": true,
    "hires_fix_scale": 24,
    "noise_discretization": {
      "rf": {
        "_0": {
          "sigma_min": 0,
          "sigma_max": 1,
          "condition_scale": 1000
        }
      }
    },
    "objective": {
      "u": {
        "condition_scale": 1000
      }
    }
EOF
        
        # Add mmdit config for Chroma models
        if [[ "$model_name" =~ .*chroma.* ]]; then
            cat << EOF
,
    "mmdit": {
      "dual_attention_layers": [],
      "distilled_guidance_layers": 5,
      "qk_norm": true
    }
EOF
        fi
    else
        # Default/SD1.5 model
        cat << EOF
,
    "version": "sd_v1.5",
    "text_encoder": "clip_vit_l14_f16.ckpt",
    "autoencoder": "sd_vae_f16.ckpt"
EOF
    fi
    
    echo ""
    echo "  }"
}

# Function to scan models and generate custom.json
# Function to convert safetensors files to ckpt
convert_safetensors() {
    log "Checking for safetensors files to convert..."
    
    local safetensors_files=()
    while IFS= read -r -d '' file; do
        # Skip auxiliary files like VAE, text encoders, etc.
        local basename=$(basename "$file")
        if [[ ! "$basename" =~ (vae|clip|encoder|embed|lora).*\.safetensors$ ]]; then
            # Skip files with -tensordata suffix (these are split files)
            if [[ ! "$basename" =~ -tensordata$ ]]; then
                safetensors_files+=("$file")
            fi
        fi
    done < <(find "$MODELS_DIR" -maxdepth 1 -name "*.safetensors" -print0 2>/dev/null)
    
    if [ ${#safetensors_files[@]} -gt 0 ]; then
        log "Found ${#safetensors_files[@]} safetensors files to convert"
        
        # Create backup directory if it doesn't exist
        if [ ! -d "$SAFETENSORS_BACKUP_DIR" ]; then
            log "Creating backup directory: $SAFETENSORS_BACKUP_DIR"
            mkdir -p "$SAFETENSORS_BACKUP_DIR"
        fi
        
        # Run the model converter
        local converter_script="$SERVER_DIR/model_converter.py"
        if [ -f "$converter_script" ]; then
            log "Running model converter..."
            cd "$SERVER_DIR"
            python3 "$converter_script" --base_path "$MODELS_DIR"
            local conversion_result=$?
            cd - >/dev/null
            
            # If conversion was successful, backup and remove safetensors files
            if [ $conversion_result -eq 0 ]; then
                log "Backing up and cleaning up safetensors files..."
                local backed_up=0
                for file in "${safetensors_files[@]}"; do
                    local basename=$(basename "$file")
                    local ckpt_file="${file%.safetensors}.ckpt"
                    
                    # Only move if the corresponding .ckpt file exists (conversion succeeded)
                    if [ -f "$ckpt_file" ]; then
                        log "Moving $basename to backup directory"
                        mv "$file" "$SAFETENSORS_BACKUP_DIR/"
                        ((backed_up++))
                    else
                        warn "Skipping backup of $basename - no corresponding .ckpt file found"
                    fi
                done
                log "Backed up $backed_up safetensors files to $SAFETENSORS_BACKUP_DIR"
            else
                error "Model conversion failed - keeping safetensors files in place"
                return 1
            fi
        else
            error "Model converter not found: $converter_script"
            return 1
        fi
    else
        log "No safetensors files found to convert"
    fi
}

# Function to scan models and generate custom.json
generate_custom_json() {
    log "Scanning models directory: $MODELS_DIR"
    
    # Backup existing custom.json if it exists
    if [ -f "$CUSTOM_JSON" ]; then
        log "Backing up existing custom.json"
        cp "$CUSTOM_JSON" "$CUSTOM_JSON_BACKUP"
    fi
    
    # Convert any safetensors files first
    convert_safetensors
    
    # Find all .ckpt model files (main checkpoint files, not auxiliary files)
    local main_models=()
    while IFS= read -r -d '' file; do
        # Skip auxiliary files like VAE, text encoders, etc.
        local basename=$(basename "$file")
        if [[ ! "$basename" =~ (vae|clip|encoder|embed|lora).*\.ckpt$ ]]; then
            # Skip files with -tensordata suffix (these are split files)
            if [[ ! "$basename" =~ -tensordata$ ]]; then
                main_models+=("$file")
            fi
        fi
    done < <(find "$MODELS_DIR" -maxdepth 1 -name "*.ckpt" ! -path "*/safetensors_backup/*" -print0 2>/dev/null)
    
    if [ ${#main_models[@]} -eq 0 ]; then
        warn "No main model files found in $MODELS_DIR"
        echo "[]" > "$CUSTOM_JSON"
        return
    fi
    
    log "Found ${#main_models[@]} main model files"
    
    # Generate JSON
    echo "[" > "$CUSTOM_JSON"
    
    local first=true
    for model in "${main_models[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo "," >> "$CUSTOM_JSON"
        fi
        
        log "Processing: $(basename "$model")"
        generate_model_config "$model" >> "$CUSTOM_JSON"
    done
    
    echo "]" >> "$CUSTOM_JSON"
    
    log "Generated custom.json with ${#main_models[@]} models"
}

# Function to merge with existing custom.json (preserve manual configurations)
merge_with_existing() {
    if [ ! -f "$CUSTOM_JSON_BACKUP" ]; then
        return
    fi

    if ! command -v jq >/dev/null 2>&1; then
        warn "jq not found - skipping merge with existing custom.json"
        return
    fi

    log "Attempting to preserve manually configured models..."

    local merged
    if ! merged=$(jq -s '.[0] + .[1] | unique_by(.name)' "$CUSTOM_JSON" "$CUSTOM_JSON_BACKUP" 2>/dev/null); then
        error "Failed to merge JSON files"
        return
    fi

    echo "$merged" | jq '.' > "$CUSTOM_JSON"

    mapfile -t kept_names < <(echo "$merged" | jq -r '.[].name')
    log "Merged custom.json - keeping ${#kept_names[@]} entries:"
    for name in "${kept_names[@]}"; do
        log "  - $name"
    done
}

# Main execution
log "Starting custom.json update process"

# Check if models directory exists
if [ ! -d "$MODELS_DIR" ]; then
    error "Models directory not found: $MODELS_DIR"
    exit 1
fi

# Generate new custom.json
generate_custom_json

# Optionally merge with existing (commented out for safety)
# merge_with_existing

log "custom.json update completed"
log "File location: $CUSTOM_JSON"

# Show summary
if command -v jq >/dev/null 2>&1; then
    log "Model summary:"
    jq -r '.[] | "  - " + .name' "$CUSTOM_JSON" 2>/dev/null || cat "$CUSTOM_JSON"
else
    log "Install 'jq' for prettier output. Generated file:"
    head -20 "$CUSTOM_JSON"
fi

