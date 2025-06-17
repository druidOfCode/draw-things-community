# Automatic custom.json Management

This document explains the automatic `custom.json` update system that keeps your model configuration in sync with the actual models in your directory.

## Problem Solved

Previously, the `custom.json` file manually listed available models, but when clients uploaded new models to the server, this file would become out of sync. This meant new models wouldn't be visible to clients even though they existed on the server.

## Solution Overview

The solution automatically scans your models directory and regenerates `custom.json` every time the server starts. This ensures that:

1. **All available models are exposed** to clients
2. **New models are automatically detected** when added to the directory
3. **Removed models are automatically excluded** from the configuration
4. **Model type detection** happens automatically based on filename patterns

## How It Works

### Automatic Integration

The `start-server.sh` script now includes an automatic call to `update-custom-json.sh` before starting the Docker container:

```bash
# Update custom.json with available models
log "Updating custom.json with available models..."
"$SERVER_DIR/scripts/update-custom-json.sh"
```

### Model Detection Logic

The script automatically detects model types based on filename patterns:

- **Flux models**: Files containing "flux" or "chroma" → configured as `flux1`
- **SDXL models**: Files containing "xl" or "sdxl" → configured as `sdxl_base_v0.9`  
- **SD 1.5 models**: Everything else → configured as `sd_v1.5`

### File Filtering

The script intelligently filters model files:

- ✅ **Includes**: Main model files (`.ckpt`, `.safetensors`)
- ❌ **Excludes**: Auxiliary files (VAE, encoders, embeddings, LoRA)
- ❌ **Excludes**: Split files (with `-tensordata` suffix)

## Scripts Provided

### 1. `update-custom-json.sh`

**Purpose**: Main script that scans models and regenerates `custom.json`

**Usage**:
```bash
./scripts/update-custom-json.sh
```

**Features**:
- Automatically backs up existing `custom.json`
- Scans models directory for all model files
- Generates appropriate configuration for each model type
- Provides summary of discovered models

### 2. `manage-model-configs.sh` 

**Purpose**: Helper script for managing individual model configurations

**Usage**:
```bash
# List all configured models
./scripts/manage-model-configs.sh list

# Validate custom.json syntax
./scripts/manage-model-configs.sh validate

# Create backup
./scripts/manage-model-configs.sh backup

# Restore from backup
./scripts/manage-model-configs.sh restore
```

## Usage Examples

### Normal Startup (Automatic)

Just start your server as usual:

```bash
./scripts/start-server.sh
```

The `custom.json` will be automatically updated before the server starts.

### Manual Update

If you want to update `custom.json` without restarting the server:

```bash
./scripts/update-custom-json.sh
```

### Check What Models Are Configured

```bash
./scripts/manage-model-configs.sh list
```

### Validate Configuration

```bash
./scripts/manage-model-configs.sh validate
```

## Backup and Recovery

### Automatic Backups

Every time `update-custom-json.sh` runs, it automatically creates a backup:
- **Location**: `models/custom.json.backup`
- **Contains**: Previous version of `custom.json`

### Manual Backups

Create timestamped backups:

```bash
./scripts/manage-model-configs.sh backup
```

This creates: `models/custom.json.backup.YYYYMMDD_HHMMSS`

### Restore from Backup

```bash
./scripts/manage-model-configs.sh restore
```

## Customization

### Model Type Detection

If the automatic detection doesn't work for your models, you can:

1. **Edit the detection logic** in `update-custom-json.sh`
2. **Manually edit `custom.json`** after generation (will be overwritten on next update)
3. **Use custom configuration files** (future enhancement)

### Detection Patterns

Current patterns in `generate_model_config()` function:

```bash
# SDXL detection
if [[ "$model_name" =~ .*xl.* ]] || [[ "$model_name" =~ .*sdxl.* ]]; then

# Flux detection  
elif [[ "$model_name" =~ .*flux.* ]] || [[ "$model_name" =~ .*chroma.* ]]; then

# Default to SD 1.5
else
```

### Adding New Model Types

To add support for new model types, edit the `generate_model_config()` function in `update-custom-json.sh`:

```bash
elif [[ "$model_name" =~ .*your_pattern.* ]]; then
    cat << EOF
,
    "version": "your_version",
    "text_encoder": "your_encoder.ckpt",
    "autoencoder": "your_vae.ckpt"
EOF
```

## Troubleshooting

### Models Not Detected

1. **Check file extensions**: Only `.ckpt` and `.safetensors` are scanned
2. **Check filtering**: Ensure filenames don't contain `vae`, `clip`, `encoder`, `embed`, or `lora`
3. **Run manually**: `./scripts/update-custom-json.sh` to see detailed output

### Wrong Model Type Detected

1. **Check filename patterns**: The script uses filename patterns for detection
2. **Manually edit**: Edit `custom.json` after generation (temporary fix)
3. **Update patterns**: Modify detection logic in `update-custom-json.sh`

### JSON Syntax Errors

```bash
# Validate syntax
./scripts/manage-model-configs.sh validate

# Check for backup
ls -la models/custom.json.backup*

# Restore if needed
./scripts/manage-model-configs.sh restore
```

### Script Permissions

If you get permission errors:

```bash
chmod +x scripts/*.sh
```

## Benefits of This Approach

1. **Zero Configuration**: Works automatically with no manual setup
2. **Always In Sync**: Models directory and `custom.json` stay synchronized  
3. **Safe**: Creates backups before making changes
4. **Smart Detection**: Automatically configures different model types
5. **Easy Integration**: Integrates seamlessly with existing startup process
6. **Backwards Compatible**: Doesn't break existing workflows

## Future Enhancements

- **Custom configuration files**: Per-model JSON config files
- **Manual override system**: Preserve specific manual configurations
- **Model metadata detection**: Parse model files for automatic configuration
- **Web interface**: Manage configurations through a web UI
- **Model validation**: Verify model files are valid and complete

## Technical Details

### File Locations

- **Main script**: `scripts/update-custom-json.sh`
- **Helper script**: `scripts/manage-model-configs.sh`
- **Configuration**: `models/custom.json`
- **Backups**: `models/custom.json.backup*`
- **Server startup**: `scripts/start-server.sh` (modified)

### Dependencies

- **Required**: `bash`, `find`, `grep`
- **Optional**: `jq` (for prettier JSON formatting)
- **Optional**: `python3` (for JSON validation fallback)

### Security Considerations

- Scripts run with user permissions (not root)
- Only modifies files in the models directory
- Creates backups before making changes
- No network access required

This solution provides a robust, automatic way to keep your `custom.json` file synchronized with your actual model files, eliminating the sync issues you were experiencing.

