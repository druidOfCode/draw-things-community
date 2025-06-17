#!/bin/bash

# Draw Things Community Server Control Script
# This script provides easy management of the Draw Things server

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONTAINER_NAME="draw-things-server"
SERVER_DIR="$HOME/Development/draw-things-server"
SCRIPTS_DIR="$SERVER_DIR/scripts"

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

# Function to show container status
show_status() {
    echo -e "\n${BLUE}=== Draw Things Server Status ===${NC}"
    
    if container_running; then
        log "Server is RUNNING"
        
        # Get container details
        echo -e "\n${BLUE}Container Details:${NC}"
        docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        # Get resource usage
        echo -e "\n${BLUE}Resource Usage:${NC}"
        docker stats --no-stream "$CONTAINER_NAME" 2>/dev/null || echo "Unable to get stats"
        
        # Get server port
        PORT=$(docker port "$CONTAINER_NAME" 7859 2>/dev/null | cut -d: -f2)
        if [ -n "$PORT" ]; then
            echo -e "\n${BLUE}Access URLs:${NC}"
            echo "  Local:    http://localhost:$PORT"
            LOCAL_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1 || echo "localhost")
            echo "  Network:  http://$LOCAL_IP:$PORT"
        fi
    else
        warn "Server is NOT RUNNING"
        
        # Check if container exists but stopped
        if docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}" | grep -q "$CONTAINER_NAME"; then
            log "Container exists but is stopped"
            docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}"
        else
            log "No container found"
        fi
    fi
    echo
}

# Function to start server
start_server() {
    if container_running; then
        warn "Server is already running"
        show_status
        return 0
    fi
    
    log "Starting Draw Things server..."
    "$SCRIPTS_DIR/start-server.sh" "$@"
}

# Function to stop server
stop_server() {
    if ! container_running; then
        warn "Server is not running"
        return 0
    fi
    
    log "Stopping Draw Things server..."
    docker stop "$CONTAINER_NAME"
    log "Server stopped"
}

# Function to restart server
restart_server() {
    log "Restarting Draw Things server..."
    stop_server
    sleep 2
    start_server "$@"
}

# Function to show logs
show_logs() {
    if ! container_running; then
        error "Server is not running"
        return 1
    fi
    
    log "Showing server logs (Press Ctrl+C to exit)..."
    docker logs -f "$CONTAINER_NAME"
}

# Function to remove container
remove_container() {
    if container_running; then
        log "Stopping running container..."
        docker stop "$CONTAINER_NAME"
    fi
    
    if docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}" | grep -q "$CONTAINER_NAME"; then
        log "Removing container..."
        docker rm "$CONTAINER_NAME"
        log "Container removed"
    else
        log "No container to remove"
    fi
}

# Function to update image
update_image() {
    log "Updating Draw Things Docker image..."
    
    # Stop server if running
    if container_running; then
        log "Stopping server for update..."
        stop_server
    fi
    
    # Pull latest image
    docker pull drawthingsai/draw-things-grpc-server-cli:latest
    
    # Remove old container
    remove_container
    
    log "Image updated successfully"
    log "Start the server with: $0 start"
}

# Function to show help
show_help() {
    echo "Draw Things Community Server Control Script"
    echo ""
    echo "Usage: $0 COMMAND [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  start [OPTIONS]     Start the server"
    echo "  stop                Stop the server"
    echo "  restart [OPTIONS]   Restart the server"
    echo "  status              Show server status"
    echo "  logs                Show server logs"
    echo "  remove              Remove server container"
    echo "  update              Update Docker image"
    echo "  help                Show this help message"
    echo ""
    echo "Start Options:"
    echo "  --background, -b        Run in background"
    echo "  --no-flash-attention    Disable FlashAttention (for RTX 20xx)"
    echo "  --cpu-only              Force CPU-only mode"
    echo "  --port PORT             Custom port (default: 7859)"
    echo ""
    echo "Examples:"
    echo "  $0 start                           # Start server normally"
    echo "  $0 start --background              # Start in background"
    echo "  $0 start --no-flash-attention      # Start without FlashAttention"
    echo "  $0 start --port 8080               # Start on port 8080"
    echo "  $0 status                          # Check server status"
    echo "  $0 logs                            # View live logs"
}

# Main script logic
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    start)
        start_server "$@"
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server "$@"
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    remove)
        remove_container
        ;;
    update)
        update_image
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

