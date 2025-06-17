# Draw Things Community Server Setup

This directory contains scripts and configuration for running the Draw Things Community server on Linux with GPU acceleration.

## Overview

Draw Things is an AI image generation application. This setup allows you to run the Draw Things gRPC server as a self-hosted solution using Docker with NVIDIA GPU acceleration.

## Directory Structure

```
~/Development/
├── repos/
│   └── draw-things-community/     # Source code repository
└── draw-things-server/
    ├── models/                    # AI models directory
    ├── logs/                      # Server logs
    ├── scripts/                   # Management scripts
    │   ├── setup.sh              # Initial setup script
    │   ├── start-server.sh       # One-click server start
    │   └── server-control.sh     # Server management
    └── README.md                 # This file
```

## Requirements

- Linux (tested on Ubuntu)
- NVIDIA GPU with drivers installed
- Docker with NVIDIA Container Toolkit
- At least 8GB of VRAM (more recommended)
- Internet connection for Docker image downloads

## Quick Start

### 1. Initial Setup

Run the setup script to install dependencies and configure the environment:

```bash
~/Development/draw-things-server/scripts/setup.sh
# To compile a native server binary as well:
~/Development/draw-things-server/scripts/setup.sh --build-native
```

This script will:
- Check system requirements
- Install Docker and NVIDIA Container Toolkit (if needed)
- Clone the Draw Things Community repository
- Pull the latest Docker image
- Test GPU access
- Optionally build gRPCServerCLI natively with `--build-native`

### 2. Add AI Models

Place your AI models in the models directory:

```bash
~/Development/draw-things-server/models/
```

Supported model formats include Stable Diffusion models (.ckpt, .safetensors, etc.).

### 3. Start the Server

Use the one-click start script:

```bash
~/Development/draw-things-server/scripts/start-server.sh
```

Or for background operation:

```bash
~/Development/draw-things-server/scripts/start-server.sh --background
```

## Server Management

Use the server control script for easy management:

```bash
# Start server
~/Development/draw-things-server/scripts/server-control.sh start

# Check status
~/Development/draw-things-server/scripts/server-control.sh status

# View logs
~/Development/draw-things-server/scripts/server-control.sh logs

# Stop server
~/Development/draw-things-server/scripts/server-control.sh stop

# Restart server
~/Development/draw-things-server/scripts/server-control.sh restart

# Update Docker image
~/Development/draw-things-server/scripts/server-control.sh update
```

## Configuration Options

### Configuration File

You can set default options in `server.conf` to avoid specifying them every time:

```bash
# Edit configuration
vim ~/Development/draw-things-server/server.conf
```

Example configuration:
```bash
# Enable model browser (allows clients to browse available models)
MODEL_BROWSER=true

# Set weights cache for better performance (defaults to 50% of RAM if unset)
WEIGHTS_CACHE=4

# Enable supervised mode (auto-restart on crashes)
SUPERVISED=true

# Optional: Set shared secret for security
SHARED_SECRET=your_secret_here
```

### Server Start Options

**Basic Options:**
- `--background, -b`: Run server in background
- `--interactive, -i`: Run in interactive mode
- `--port PORT`: Custom port (default: 7859)
- `--cpu-only`: Force CPU-only mode (no GPU acceleration)

**Performance Options:**
- `--no-flash-attention`: Disable FlashAttention (required for RTX 20xx cards)
- `--weights-cache SIZE`: Set weights cache size in GiB (default: 50% of RAM)
- `--cpu-offload`: Enable CPU offloading for large models

**Feature Options:**
- `--no-model-browser`: Disable model browsing (enabled by default)
- `--debug`: Enable debug logging
- `--no-supervised`: Disable supervised mode (enabled by default)

**Security Options:**
- `--shared-secret SECRET`: Set shared secret for server security

### Examples

```bash
# Start normally (attached mode)
./scripts/start-server.sh

# Start in background
./scripts/start-server.sh --background

# Start without FlashAttention (for older GPUs)
./scripts/start-server.sh --no-flash-attention

# Start on custom port
./scripts/start-server.sh --port 8080

# Start with CPU only
./scripts/start-server.sh --cpu-only

# Start with larger weights cache (override auto-sized default)
./scripts/start-server.sh --weights-cache 8

# Start with CPU offloading for large models
./scripts/start-server.sh --cpu-offload

# Start with debug logging
./scripts/start-server.sh --debug

# Start with shared secret for security
./scripts/start-server.sh --shared-secret mySecretKey123
```

## Accessing the Server

Once started, the server will be available at:

- **Local access**: `http://localhost:7859`
- **Network access**: `http://YOUR_IP:7859`

The server uses gRPC protocol and is designed to work with Draw Things client applications.

## Troubleshooting

### GPU Not Detected

1. Check NVIDIA drivers:
   ```bash
   nvidia-smi
   ```

2. Test Docker GPU access:
   ```bash
   docker run --rm --gpus all nvidia/cuda:12.4-base-ubuntu22.04 nvidia-smi
   ```

3. Check NVIDIA Container Toolkit installation:
   ```bash
   nvidia-ctk --version
   ```

### Container Won't Start

1. Check logs:
   ```bash
   ./scripts/server-control.sh logs
   ```

2. Check Docker daemon:
   ```bash
   sudo systemctl status docker
   ```

3. Restart Docker:
   ```bash
   sudo systemctl restart docker
   ```

### Memory Issues

- Ensure you have enough VRAM for your models
- Consider using smaller models or reducing batch sizes
- Use `--cpu-only` mode if necessary

### Port Conflicts

- Check if port 7859 is in use:
  ```bash
  netstat -tulpn | grep 7859
  ```
- Use a different port:
  ```bash
  ./scripts/start-server.sh --port 8080
  ```

## Model Management

### Supported Formats

- Stable Diffusion models (.ckpt, .safetensors)
- LoRA models
- VAE models
- Embeddings

### Model Organization

Organize your models in the models directory:

```
models/
├── checkpoints/
│   ├── sd15_model.safetensors
│   └── sdxl_model.safetensors
├── lora/
│   └── style_lora.safetensors
├── vae/
│   └── vae_model.safetensors
└── embeddings/
    └── negative_embedding.pt
```

## Performance Tips

1. **Use SSD storage** for models directory
2. **Sufficient VRAM**: 8GB minimum, 12GB+ recommended
3. **FlashAttention**: Enable for RTX 30xx/40xx cards
4. **Model optimization**: Use .safetensors format when possible
5. **Background mode**: Use for production deployments

## Security Considerations

- The server runs on your local network
- Consider firewall rules for network access
- Models directory is mounted read-only in the container
- Logs are stored locally for debugging

## Updating

To update to the latest version:

```bash
# Update Docker image
./scripts/server-control.sh update

# Update repository
cd ~/Development/repos/draw-things-community
git pull
```

## Support

- **Draw Things Community**: https://github.com/drawthingsai/draw-things-community
- **Docker Hub**: https://hub.docker.com/r/drawthingsai/draw-things-grpc-server-cli
- **Issues**: Report issues to the Draw Things Community repository

## License

This setup follows the Draw Things Community license (GPL-v3).

