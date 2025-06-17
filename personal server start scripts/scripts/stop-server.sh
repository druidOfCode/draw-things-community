#!/bin/bash

# Draw Things Community Server Stop Script
# This script properly stops the Draw Things gRPC server Docker container

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="draw-things-server"

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
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}" | grep -q "$CONTAINER_NAME" 2>/dev/null
}

# Function to check if container exists (running or stopped)
container_exists() {
    docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}" | grep -q "$CONTAINER_NAME" 2>/dev/null
}

# Parse command line arguments
FORCE_KILL=false
REMOVE_CONTAINER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_KILL=true
            shift
            ;;
        --remove|-r)
            REMOVE_CONTAINER=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --force, -f     Force kill the container if it doesn't stop gracefully"
            echo "  --remove, -r    Remove the container after stopping it"
            echo "  --help, -h      Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

log "Stopping Draw Things Community Server..."

# Check if container is running
if ! container_exists; then
    warn "No container named '$CONTAINER_NAME' found"
    exit 0
fi

if ! container_running; then
    log "Container '$CONTAINER_NAME' is already stopped"
else
    log "Stopping container '$CONTAINER_NAME'..."
    
    if [ "$FORCE_KILL" = true ]; then
        log "Force killing container..."
        if docker kill "$CONTAINER_NAME" >/dev/null 2>&1; then
            log "Container force killed successfully"
        else
            error "Failed to force kill container"
            exit 1
        fi
    else
        log "Gracefully stopping container..."
        if docker stop "$CONTAINER_NAME" >/dev/null 2>&1; then
            log "Container stopped successfully"
        else
            error "Failed to stop container gracefully"
            warn "Try using --force flag for force kill"
            exit 1
        fi
    fi
fi

# Remove container if requested
if [ "$REMOVE_CONTAINER" = true ]; then
    log "Removing container '$CONTAINER_NAME'..."
    if docker rm "$CONTAINER_NAME" >/dev/null 2>&1; then
        log "Container removed successfully"
    else
        error "Failed to remove container"
        exit 1
    fi
fi

log "Draw Things server stopped successfully!"
log "To start the server again, run: ./scripts/start-server.sh"

