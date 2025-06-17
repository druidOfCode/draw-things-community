#!/bin/bash
# Simple alias to stop the Draw Things server
exec "$(dirname "$0")/scripts/stop-server.sh" "$@"

