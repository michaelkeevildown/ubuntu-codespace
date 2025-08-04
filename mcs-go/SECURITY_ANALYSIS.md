# Security Analysis: GitHub Token Handling in MCS

## Executive Summary

This security analysis examines the handling of GitHub tokens in the MCS (Michael's Codespaces) Go implementation. The analysis identifies current security practices, potential vulnerabilities, and provides recommendations aligned with Docker and industry best practices.

## Current Implementation

### Token Storage
- GitHub tokens are stored in `~/.mcs/config.json` file
- Tokens are stored in plain text (following GitHub CLI conventions)
- The config file contains the token in the `GitHubToken` field
- File permissions should be set to 0600 (read/write for owner only)

### Token Usage
- Tokens are read from config or environment variable (`GITHUB_TOKEN`)
- Used for Git authentication when cloning repositories
- Converted from SSH URLs to HTTPS with token authentication
- Currently NOT passed to Docker containers via environment variables

## Security Risks

### 1. Environment Variable Exposure (Critical)
**Risk**: Passing secrets via Docker environment variables is strongly discouraged by Docker documentation.

**Why it's dangerous**:
- Environment variables are visible via `docker inspect`
- They persist in image layers
- Accessible to all processes in the container
- Can be logged accidentally
- Exposed in crash dumps

### 2. Plain Text Storage (Medium)
**Risk**: GitHub tokens stored in plain text in config file.

**Mitigations**:
- File permissions (0600) restrict access
- Follows GitHub CLI convention
- Local filesystem security applies

### 3. Token Scope (Medium)
**Risk**: Tokens with excessive permissions increase impact of compromise.

**Recommendation**: Use minimal scopes (repo, read:user)

## Best Practices Analysis

### Docker Official Recommendations

1. **Never use environment variables for secrets**
2. **Use Docker secrets or volume mounts**
3. **Implement secret files pattern**
4. **Use tmpfs for runtime secrets**

### Industry Standards

1. **Principle of Least Privilege**: Minimal token scopes
2. **Defense in Depth**: Multiple security layers
3. **Secure by Default**: Safe configurations out of the box
4. **Auditability**: Log access to secrets

## Recommended Solutions

### Solution 1: Volume Mount (Recommended)
**Implementation**: Mount the config file as a read-only volume

```yaml
volumes:
  - ${HOME}/.mcs/config.json:/home/coder/.mcs/config.json:ro
```

**Advantages**:
- No environment variable exposure
- Read-only access prevents tampering
- Leverages existing file permissions
- Simple to implement

**Code Changes Required**:
1. Add volume mount to Docker Compose template
2. Update Git clone to read from mounted config
3. No API changes needed

### Solution 2: Docker Secrets (For Production)
**Implementation**: Use Docker Compose secrets

```yaml
secrets:
  github_token:
    file: ~/.mcs/github_token

services:
  codespace:
    secrets:
      - github_token
```

**Advantages**:
- Industry best practice
- Secrets never in environment
- Encrypted at rest (in Swarm mode)
- Fine-grained access control

**Code Changes Required**:
1. Add secrets section to compose template
2. Update application to read from `/run/secrets/github_token`
3. Modify config manager to support secret files

### Solution 3: External Secret Manager (Enterprise)
**Implementation**: Integrate with HashiCorp Vault, AWS Secrets Manager, etc.

**Advantages**:
- Centralized secret management
- Audit trails
- Secret rotation
- Enterprise compliance

**Disadvantages**:
- Complex setup
- External dependencies
- Overkill for individual developers

## Implementation Plan

### Phase 1: Immediate Security (Volume Mount)
1. Add config volume mount to Docker Compose
2. Ensure no environment variable passing
3. Update documentation

### Phase 2: Enhanced Security (Docker Secrets)
1. Implement secret file support in config manager
2. Add Docker secrets to compose template
3. Support both patterns for backward compatibility

### Phase 3: Future Considerations
1. Evaluate external secret managers
2. Implement token rotation reminders
3. Add security scanning to CI/CD

## Security Checklist

- [ ] Never pass GitHub token via environment variables
- [ ] Implement volume mount for config file
- [ ] Set proper file permissions (0600) on config
- [ ] Document security best practices
- [ ] Add security warnings to setup flow
- [ ] Validate token scopes during setup
- [ ] Implement token expiration checks
- [ ] Add `docker inspect` protection test

## Testing Recommendations

1. **Security Tests**:
   - Verify token not visible in `docker inspect`
   - Confirm config file permissions
   - Test read-only volume mount
   - Validate no token in image layers

2. **Functional Tests**:
   - Git clone with token auth
   - Component installation
   - Multi-repository support

## Conclusion

The current MCS implementation has good security foundations (file permissions, no environment variables). The recommended immediate action is to implement volume mounting of the config file, which provides security without breaking changes. This aligns with Docker best practices while maintaining developer convenience.

For production or enterprise use, implementing Docker secrets would provide additional security benefits. The modular design of MCS makes these enhancements straightforward to implement.