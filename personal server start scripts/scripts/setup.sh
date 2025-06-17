#!/bin/bash

# Draw Things Community Server Setup Script
# This script sets up the Draw Things Community server environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Project directories
PROJECT_ROOT="$HOME/Development"
REPO_DIR="$PROJECT_ROOT/repos/draw-things-community"
SERVER_DIR="$PROJECT_ROOT/draw-things-server"
MODELS_DIR="$SERVER_DIR/models"
LOGS_DIR="$SERVER_DIR/logs"
SCRIPTS_DIR="$SERVER_DIR/scripts"

log "Starting Draw Things Community Server Setup..."

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script should not be run as root. Please run as regular user."
   exit 1
fi

# Check system requirements
log "Checking system requirements..."

# Check if NVIDIA GPU is available
if ! command -v nvidia-smi &> /dev/null; then
    error "nvidia-smi not found. Please install NVIDIA drivers."
    exit 1
fi

# Check NVIDIA driver version
NVIDIA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -n1)
log "NVIDIA Driver Version: $NVIDIA_VERSION"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    error "Docker not found. Please install Docker."
    exit 1
fi

# Check if user is in docker group
if ! groups $USER | grep -q "\bdocker\b"; then
    warn "User not in docker group. You may need to log out and back in."
fi

# Check if NVIDIA Container Toolkit is installed
if ! docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi &> /dev/null; then
    error "NVIDIA Container Toolkit not properly configured."
    exit 1
fi

log "System requirements check passed!"

# Create directory structure
log "Creating directory structure..."
mkdir -p "$REPO_DIR" "$MODELS_DIR" "$LOGS_DIR" "$SCRIPTS_DIR"

# Clone or update repository
if [ -d "$REPO_DIR/.git" ]; then
    log "Updating existing repository..."
    cd "$REPO_DIR"
    git pull
else
    log "Cloning Draw Things Community repository..."
    cd "$PROJECT_ROOT/repos"
    git clone https://github.com/drawthingsai/draw-things-community.git
fi

# Pull the latest Docker image
log "Pulling latest Draw Things gRPC Server Docker image..."
docker pull drawthingsai/draw-things-grpc-server-cli:latest

# Test Docker image
log "Testing Docker image with GPU access..."
if docker run --rm --gpus all drawthingsai/draw-things-grpc-server-cli:latest nvidia-smi > "$LOGS_DIR/gpu-test.log" 2>&1; then
    log "GPU test successful! Check $LOGS_DIR/gpu-test.log for details."
else
    error "GPU test failed. Check $LOGS_DIR/gpu-test.log for errors."
    exit 1
fi

# Create models directory with proper permissions
chmod 755 "$MODELS_DIR"

log "Setup completed successfully!"
log "Repository location: $REPO_DIR"
log "Server directory: $SERVER_DIR"
log "Models directory: $MODELS_DIR"
log "Logs directory: $LOGS_DIR"

log "Next steps:"
log "1. Place your AI models in: $MODELS_DIR"
log "2. Run the server with: $SCRIPTS_DIR/start-server.sh"

log "Setup complete! 🚀"

