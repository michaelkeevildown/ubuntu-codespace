# GitHub Token Solution for MCS Containers

## Overview

This solution securely provides GitHub tokens to components running inside MCS containers using Docker volume mounts instead of environment variables, following Docker security best practices.

## Architecture

### Security-First Design

1. **Volume Mount Approach**: The `~/.mcs/config.json` file is mounted as read-only into containers
2. **No Environment Variables**: Tokens are never exposed through environment variables
3. **Single Source of Truth**: Token is managed centrally on the host via `mcs config set github-token`
4. **Read-Only Access**: Containers cannot modify the token configuration

### Components

1. **Host Configuration** (`~/.mcs/config.json`)
   - Stores GitHub token securely on host
   - Managed via `mcs config set github-token <token>`
   - Protected with 0600 permissions

2. **Docker Compose Mount** (`internal/docker/compose.go`)
   ```yaml
   volumes:
     - ${HOME}/.mcs/config.json:/home/coder/.mcs/config.json:ro
   ```

3. **Token Helper Script** (`mcs-get-token.sh`)
   - Extracted to `/home/coder/.components/` in containers
   - Reads token from mounted config file
   - Provides multiple extraction methods for compatibility

4. **Component Integration** 
   - GitHub CLI installer updated to use helper script
   - Fallback to legacy token file for backward compatibility

## Implementation Details

### 1. Docker Compose Changes

Modified `internal/docker/compose.go` to add volume mount:

```go
volumes:
  - ${HOME}/.mcs/config.json:/home/coder/.mcs/config.json:ro
```

This ensures the config file is available in all containers.

### 2. Token Helper Script

Created `mcs-get-token.sh` helper that:
- Reads from `/home/coder/.mcs/config.json` in container
- Supports multiple JSON parsers (jq, python3, python, grep)
- Provides error messages with instructions
- Supports `--check` and `--export` modes

Usage in scripts:
```bash
# Get token
token=$(/home/coder/.components/mcs-get-token.sh)

# Check if available
if /home/coder/.components/mcs-get-token.sh --check; then
    echo "Token available"
fi

# Export to environment
eval "$(/home/coder/.components/mcs-get-token.sh --export)"
```

### 3. Component Updates

Updated GitHub CLI installer to:
1. Try mcs-get-token.sh helper first
2. Fall back to legacy token file
3. Provide clear instructions if token not found

### 4. Asset Embedding

Modified `internal/assets/embed.go` to:
- Embed the helper script
- Extract it to components directory during setup

## User Workflow

### Setting Up Token (One Time)

On the host machine:
```bash
# Set GitHub token
mcs config set github-token ghp_xxxxxxxxxxxx

# Verify it's stored
mcs config get github-token
```

### Using in Containers

The token is automatically available to components:
1. Container starts with mounted config
2. Components use mcs-get-token.sh to read token
3. GitHub CLI and other tools authenticate automatically

### Troubleshooting

If authentication fails in a container:
1. Check token is set: `mcs config get github-token` (on host)
2. Verify mount exists: `ls -la /home/coder/.mcs/config.json` (in container)
3. Test helper: `/home/coder/.components/mcs-get-token.sh` (in container)

## Security Benefits

1. **No Environment Variable Exposure**: Tokens never appear in `docker inspect` or process lists
2. **Read-Only Access**: Containers cannot modify or delete tokens
3. **Centralized Management**: Single location for token updates
4. **File Permission Protection**: Config file has restricted permissions on host
5. **Container Isolation**: Each container only sees its mounted config

## Migration from Environment Variables

For existing setups using environment variables:
1. Remove any `GITHUB_TOKEN` from docker-compose.yml
2. Set token via `mcs config set github-token`
3. Recreate containers to pick up volume mount

## Future Enhancements

1. Support for multiple token types (GitLab, Bitbucket)
2. Token rotation reminders
3. Encrypted config storage
4. Per-project token overrides

## Testing

Test the implementation:
```bash
# On host
mcs config set github-token ghp_test123
mcs create git@github.com:user/repo.git
mcs exec user-repo -- /home/coder/.components/mcs-get-token.sh
```

Expected output: `ghp_test123`