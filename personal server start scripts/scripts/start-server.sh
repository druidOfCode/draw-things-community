#!/bin/bash

# Draw Things Community Server One-Click Start Script
# This script starts the Draw Things gRPC server using Docker

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVER_DIR="$HOME/Development/draw-things-server"
MODELS_DIR="$SERVER_DIR/models"
LOGS_DIR="$SERVER_DIR/logs"
CONTAINER_NAME="draw-things-server"
SERVER_PORT="7859"
HOST_IP="0.0.0.0"
CONFIG_FILE="$SERVER_DIR/server.conf"

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

# Function to check if container is running
container_running() {
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}" | grep -q "$CONTAINER_NAME"
}

# Function to stop existing container
stop_container() {
    if container_running; then
        log "Stopping existing container..."
        docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
    fi
    # Remove container if it exists (even if stopped)
    if docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}" | grep -q "$CONTAINER_NAME"; then
        log "Removing existing container..."
        docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
    fi
}

# Function to get local IP address
get_local_ip() {
    # Try multiple methods to get local IP
    local ip
    ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1) || \
    ip=$(hostname -I 2>/dev/null | awk '{print $1}') || \
    ip="localhost"
    echo "$ip"
}

# Parse command line arguments
EXTRA_ARGS=()
FLASH_ATTENTION=true
BACKGROUND=false
INTERACTIVE=false
FORCE_CPU=false
MODEL_BROWSER=true
WEIGHTS_CACHE=4
SUPERVISED=true
SHARED_SECRET=""
CPU_OFFLOAD=false
DEBUG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-flash-attention)
            FLASH_ATTENTION=false
            shift
            ;;
        --background|-b)
            BACKGROUND=true
            shift
            ;;
        --interactive|-i)
            INTERACTIVE=true
            shift
            ;;
        --cpu-only)
            FORCE_CPU=true
            shift
            ;;
        --port)
            SERVER_PORT="$2"
            shift 2
            ;;
        --no-model-browser)
            MODEL_BROWSER=false
            shift
            ;;
        --weights-cache)
            WEIGHTS_CACHE="$2"
            shift 2
            ;;
        --no-supervised)
            SUPERVISED=false
            shift
            ;;
        --shared-secret)
            SHARED_SECRET="$2"
            shift 2
            ;;
        --cpu-offload)
            CPU_OFFLOAD=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --no-flash-attention    Disable FlashAttention (required for RTX 20xx)"
            echo "  --background, -b        Run container in background"
            echo "  --interactive, -i       Run container interactively"
            echo "  --cpu-only              Force CPU-only mode (no GPU)"
            echo "  --port PORT             Server port (default: 7859)"
            echo "  --no-model-browser      Disable model browsing (enabled by default)"
            echo "  --weights-cache SIZE    Set weights cache size in GiB (default: 4)"
            echo "  --no-supervised         Disable supervised mode (enabled by default)"
            echo "  --shared-secret SECRET  Set shared secret for server security"
            echo "  --cpu-offload           Enable CPU offloading for large models"
            echo "  --debug                 Enable debug logging"
            echo "  --help, -h              Show this help message"
            exit 0
            ;;
        *)
            EXTRA_ARGS+=("$1")
            shift
            ;;
    esac
done

log "Starting Draw Things Community Server..."

# Load configuration file if it exists
if [ -f "$CONFIG_FILE" ]; then
    log "Loading configuration from $CONFIG_FILE"

    # Safer parser for simple KEY=value pairs
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        [[ -z "$line" || "$line" == \#* ]] && continue

        # Ensure the line matches KEY=value with no spaces around '='
        if [[ ! $line =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]][^#]*$ ]]; then
            warn "Ignoring invalid line in config: $line"
            continue
        fi

        # Reject shell metacharacters
        if [[ $line =~ [\`\$\(\)\{\}\[\]\|\&\;\<\>] ]]; then
            warn "Ignoring unsafe line in config: $line"
            continue
        fi

        key=${line%%=*}
        value=${line#*=}
        declare -g "$key"="$value"
    done < "$CONFIG_FILE"
fi

# Check if models directory exists and has content
if [ ! -d "$MODELS_DIR" ]; then
    error "Models directory not found: $MODELS_DIR"
    error "Please run setup.sh first or create the models directory"
    exit 1
fi

if [ -z "$(ls -A "$MODELS_DIR" 2>/dev/null)" ]; then
    warn "Models directory is empty: $MODELS_DIR"
    warn "Please add some AI models to this directory"
fi

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Update custom.json with available models
log "Updating custom.json with available models..."
"$SERVER_DIR/scripts/update-custom-json.sh"

# Always pull the latest Docker image to ensure we're up-to-date
log "Pulling latest Docker image..."
docker pull drawthingsai/draw-things-grpc-server-cli:latest

# Stop any existing container
stop_container

# Build Docker run command
DOCKER_CMD=("docker" "run")

# Add GPU support unless CPU-only mode is requested
if [ "$FORCE_CPU" = false ]; then
    DOCKER_CMD+=("--gpus" "all")
fi

# Container settings
DOCKER_CMD+=(
    "--name" "$CONTAINER_NAME"
    "-v" "$MODELS_DIR:/grpc-models"
    "-v" "$LOGS_DIR:/logs"
    "-p" "$SERVER_PORT:7859"
    "--restart" "unless-stopped"
)

# Run mode (background vs interactive)
if [ "$BACKGROUND" = true ]; then
    DOCKER_CMD+=("-d")
elif [ "$INTERACTIVE" = true ]; then
    DOCKER_CMD+=("-it")
else
    # Default: attached but not interactive
    DOCKER_CMD+=("-t")
fi

# Docker image
DOCKER_CMD+=("drawthingsai/draw-things-grpc-server-cli:latest")

# Server command and arguments
DOCKER_CMD+=("gRPCServerCLI" "/grpc-models")

# Add server configuration flags
if [ "$FLASH_ATTENTION" = false ]; then
    DOCKER_CMD+=("--no-flash-attention")
fi

if [ "$MODEL_BROWSER" = true ]; then
    DOCKER_CMD+=("--model-browser")
fi

if [ "$SUPERVISED" = true ]; then
    DOCKER_CMD+=("--supervised")
fi

if [ "$CPU_OFFLOAD" = true ]; then
    DOCKER_CMD+=("--cpu-offload")
fi

if [ "$DEBUG" = true ]; then
    DOCKER_CMD+=("--debug")
fi

if [ -n "$SHARED_SECRET" ]; then
    DOCKER_CMD+=("--shared-secret" "$SHARED_SECRET")
fi

if [ "$WEIGHTS_CACHE" != "0" ]; then
    DOCKER_CMD+=("--weights-cache" "$WEIGHTS_CACHE")
fi

# Add extra arguments
DOCKER_CMD+=("${EXTRA_ARGS[@]}")

log "Starting server with command:"
echo "  ${DOCKER_CMD[*]}"
log "Server will be available on port $SERVER_PORT"

# Get and display connection info
LOCAL_IP=$(get_local_ip)
log "Connection details:"
log "  Local:    http://localhost:$SERVER_PORT"
log "  Network:  http://$LOCAL_IP:$SERVER_PORT"
log "  Models:   $MODELS_DIR"
log "  Logs:     $LOGS_DIR"

if [ "$FORCE_CPU" = false ]; then
    log "GPU acceleration: ENABLED"
else
    log "GPU acceleration: DISABLED (CPU-only mode)"
fi

if [ "$FLASH_ATTENTION" = false ]; then
    log "FlashAttention: DISABLED"
else
    log "FlashAttention: ENABLED"
fi

if [ "$MODEL_BROWSER" = true ]; then
    log "Model Browser: ENABLED"
else
    log "Model Browser: DISABLED"
fi

if [ "$SUPERVISED" = true ]; then
    log "Supervised Mode: ENABLED (auto-restart on crashes)"
else
    log "Supervised Mode: DISABLED"
fi

if [ "$WEIGHTS_CACHE" != "0" ]; then
    log "Weights Cache: ${WEIGHTS_CACHE}GiB"
else
    log "Weights Cache: DISABLED"
fi

if [ "$CPU_OFFLOAD" = true ]; then
    log "CPU Offload: ENABLED"
fi

if [ "$DEBUG" = true ]; then
    log "Debug Logging: ENABLED"
fi

if [ -n "$SHARED_SECRET" ]; then
    log "Shared Secret: CONFIGURED"
fi

# Function to cleanup on exit
cleanup() {
    log "\nReceived interrupt signal. Stopping container gracefully..."
    if docker stop "$CONTAINER_NAME" >/dev/null 2>&1; then
        log "Container stopped successfully"
    else
        warn "Failed to stop container gracefully, force killing..."
        docker kill "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    exit 0
}

# Set up signal traps for graceful shutdown (only when not running in background)
if [ "$BACKGROUND" = false ]; then
    trap cleanup SIGINT SIGTERM
fi

# Start the container
log "Starting container..."
if "${DOCKER_CMD[@]}"; then
    if [ "$BACKGROUND" = true ]; then
        log "Server started successfully in background!"
        log "Check logs with: docker logs -f $CONTAINER_NAME"
        log "Stop server with: docker stop $CONTAINER_NAME"
        log "Or use the stop script: ./scripts/stop-server.sh"
    else
        log "Server stopped."
    fi
else
    error "Failed to start server"
    exit 1
fi

