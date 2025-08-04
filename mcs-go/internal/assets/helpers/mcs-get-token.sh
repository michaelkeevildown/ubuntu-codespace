#!/bin/bash
# MCS GitHub Token Helper
# Safely reads GitHub token from mounted MCS config

set -euo pipefail

# Default config location in container
CONFIG_FILE="${MCS_CONFIG_FILE:-/home/coder/.mcs/config.json}"

# Function to extract token from JSON config
get_github_token() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Error: MCS config not found at $CONFIG_FILE" >&2
        echo "Make sure the container was started with MCS volume mounts" >&2
        return 1
    fi

    # Extract github_token from JSON
    # Using multiple methods for compatibility
    if command -v jq >/dev/null 2>&1; then
        # Use jq if available
        token=$(jq -r '.github_token // empty' "$CONFIG_FILE" 2>/dev/null)
    elif command -v python3 >/dev/null 2>&1; then
        # Fall back to Python
        token=$(python3 -c "
import json, sys
try:
    with open('$CONFIG_FILE') as f:
        config = json.load(f)
        print(config.get('github_token', ''))
except:
    sys.exit(1)
" 2>/dev/null)
    elif command -v python >/dev/null 2>&1; then
        # Fall back to Python 2
        token=$(python -c "
import json, sys
try:
    with open('$CONFIG_FILE') as f:
        config = json.load(f)
        print(config.get('github_token', ''))
except:
    sys.exit(1)
" 2>/dev/null)
    else
        # Last resort: grep (less reliable)
        token=$(grep -o '"github_token"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2>/dev/null | cut -d'"' -f4)
    fi

    if [ -z "$token" ]; then
        echo "Error: No GitHub token found in MCS config" >&2
        echo "Set token on host with: mcs config set github-token <token>" >&2
        return 1
    fi

    echo "$token"
}

# Main execution
case "${1:-}" in
    --help|-h)
        cat <<EOF
MCS GitHub Token Helper

Usage: $(basename "$0") [OPTIONS]

Reads GitHub token from mounted MCS configuration file.

OPTIONS:
    --help, -h     Show this help message
    --check        Check if token is available (exit 0 if yes, 1 if no)
    --export       Output as export statement for shell sourcing

EXAMPLES:
    # Get token
    $(basename "$0")

    # Check if token exists
    $(basename "$0") --check && echo "Token available"

    # Export to environment
    eval "\$($(basename "$0") --export)"

ENVIRONMENT:
    MCS_CONFIG_FILE    Path to config.json (default: /home/coder/.mcs/config.json)

EOF
        exit 0
        ;;
    --check)
        if token=$(get_github_token 2>/dev/null) && [ -n "$token" ]; then
            exit 0
        else
            exit 1
        fi
        ;;
    --export)
        if token=$(get_github_token); then
            echo "export GITHUB_TOKEN=\"$token\""
        else
            exit 1
        fi
        ;;
    *)
        get_github_token
        ;;
esac