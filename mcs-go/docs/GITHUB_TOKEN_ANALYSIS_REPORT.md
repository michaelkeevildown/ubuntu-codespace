# 🔐 GitHub Token Analysis Report - MCS Container Access

## 🎯 Executive Summary

**Issue**: GitHub tokens configured during MCS installation are not accessible inside containers, preventing components like GitHub CLI from authenticating with private repositories.

**Root Cause**: The token is stored in `~/.mcs/config.json` on the host but not passed to containers. The Docker Compose configuration only includes basic environment variables (CODESPACE_NAME, REPO_URL) but excludes the GitHub token.

**Solution**: Implement secure volume mount of the MCS config file into containers, following Docker security best practices.

---

## 🔍 Detailed Analysis

### Current Token Flow

1. **Installation Phase** ✅
   - `install.sh` accepts `GITHUB_TOKEN` environment variable
   - Used temporarily for cloning private repositories
   - Token is removed from git remotes after cloning (security practice)

2. **Configuration Storage** ✅
   - Token stored in `~/.mcs/config.json` via `config.Manager`
   - File permissions set to 0600 (read/write owner only)
   - Methods: `GetGitHubToken()` and `SetGitHubToken()`

3. **Git Operations** ✅
   - `internal/git/clone.go` checks for tokens:
     - First: `GITHUB_TOKEN` environment variable
     - Second: MCS config via `cfg.GetGitHubToken()`
   - Converts SSH URLs to HTTPS with basic auth

4. **Container Access** ❌ **THE GAP**
   - Docker Compose generation (`internal/docker/compose.go`) does NOT include:
     - GitHub token in environment variables
     - Volume mount for config file
     - Any token passing mechanism
   - Containers only receive:
     - `CODESPACE_NAME`
     - `REPO_URL`
     - `PASSWORD` (for code-server)

### Component Expectations

**GitHub CLI Component** (`internal/assets/installers/github-cli.sh`):
- Looks for token at `/home/coder/.tokens/github.token`
- MCS never creates this file or directory
- Without token, GitHub CLI remains unauthenticated

---

## 🛡️ Security Analysis

### ❌ Why NOT Environment Variables

Docker officially recommends **against** using environment variables for secrets:

1. **Visibility**: Exposed via `docker inspect <container>`
2. **Persistence**: Stored in image layers
3. **Process Access**: Available to all container processes
4. **Logging Risk**: May appear in logs or error messages

### ✅ Recommended: Volume Mount Approach

**Best Practice**: Mount config file as read-only volume

```yaml
volumes:
  - ${HOME}/.mcs/config.json:/home/coder/.mcs/config.json:ro
```

**Benefits**:
- No environment variable exposure
- Leverages existing file security (0600 permissions)
- Read-only prevents container tampering
- Single source of truth for configuration
- Simple implementation with minimal code changes

---

## 🚀 Proposed Solution

### 1. Code Changes Required

**File: `internal/docker/compose.go`**
```go
// Add to docker-compose template volumes section:
- ${HOME}/.mcs/config.json:/home/coder/.mcs/config.json:ro
```

### 2. Helper Script for Components

Create `/home/coder/.components/mcs-get-token.sh`:
```bash
#!/bin/bash
# Reads GitHub token from mounted MCS config
CONFIG_FILE="/home/coder/.mcs/config.json"
if [ -f "$CONFIG_FILE" ]; then
    jq -r '.github_token // empty' "$CONFIG_FILE" 2>/dev/null
fi
```

### 3. Update Component Installers

Modify GitHub CLI installer to:
1. Check for token via helper script
2. Fall back to legacy token file
3. Provide clear setup instructions

### 4. User Workflow

```bash
# One-time setup on host
mcs config set github-token ghp_xxxxxxxxxxxx

# Create codespace - token automatically available
mcs create github.com/private/repo

# Components in container are authenticated
# No manual token management needed
```

---

## 📊 Impact Assessment

### Positive Impacts
- ✅ **Security**: No tokens in environment variables
- ✅ **Simplicity**: Single configuration point
- ✅ **Compatibility**: Works with existing MCS config system
- ✅ **User Experience**: Transparent to users
- ✅ **Maintainability**: Minimal code changes

### Considerations
- ⚠️ **Backward Compatibility**: Existing codespaces need rebuild
- ⚠️ **Documentation**: Update user guides
- ⚠️ **Testing**: Verify with various component installers

---

## 🎯 Implementation Priority

### Phase 1: Core Implementation (High Priority)
1. Add volume mount to Docker Compose template
2. Create and embed helper script
3. Update GitHub CLI installer
4. Test with private repositories

### Phase 2: Component Updates (Medium Priority)
1. Update Claude installer for token usage
2. Update other components requiring authentication
3. Add token validation to `mcs doctor`

### Phase 3: Enhanced Security (Future)
1. Consider Docker secrets for production environments
2. Add token rotation reminders
3. Implement token scope validation

---

## 🔄 Alternative Approaches Considered

### 1. Docker Secrets (Rejected for MVP)
- **Pros**: Most secure, industry standard
- **Cons**: Complex setup, requires Swarm/Compose v3.1+
- **Decision**: Too complex for initial implementation

### 2. Encrypted Token File (Rejected)
- **Pros**: Additional security layer
- **Cons**: Key management complexity
- **Decision**: Over-engineering for current use case

### 3. Environment Variable (Rejected)
- **Pros**: Simple implementation
- **Cons**: Major security risk, against Docker best practices
- **Decision**: Security risk unacceptable

---

## 📚 References

- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [GitHub Token Security](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

---

## 🎉 Conclusion

The volume mount solution provides the optimal balance of security, simplicity, and user experience. It addresses the immediate need while following Docker security best practices and maintaining the existing MCS architecture.

**Recommendation**: Implement the volume mount solution as described, starting with Phase 1 for immediate resolution of the GitHub token accessibility issue.

---

*Generated by Claude Flow Security Analysis Swarm*  
*Session ID: swarm_1753785143092_d2e4jy6es*