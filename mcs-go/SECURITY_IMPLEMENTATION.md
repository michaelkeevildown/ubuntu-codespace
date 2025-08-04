# Security Implementation Examples

## Volume Mount Solution (Recommended)

### 1. Update Docker Compose Template

```go
// internal/docker/compose.go - Add to volumes section
const dockerComposeTemplate = `
    volumes:
      - ./src:/home/coder/{{ .CodespaceName }}
      - ./data:/home/coder/.local/share/code-server
      - ./config:/home/coder/.config
      - ./logs:/home/coder/logs
      - ${HOME}/.ssh:/home/coder/.ssh:ro
      - ${HOME}/.gitconfig:/home/coder/.gitconfig:ro
      {{- if .MountGitHubConfig }}
      - ${HOME}/.mcs/config.json:/home/coder/.mcs/config.json:ro
      {{- end }}
`
```

### 2. Update ComposeConfig Structure

```go
// internal/docker/compose.go
type ComposeConfig struct {
    // ... existing fields ...
    MountGitHubConfig bool // Add this field
}
```

### 3. Update Git Clone Inside Container

```go
// internal/git/clone.go - Add helper to read token from mounted config
func getGitHubTokenFromMountedConfig() (string, error) {
    // Check if we're running inside a container
    if _, err := os.Stat("/.dockerenv"); err != nil {
        return "", nil // Not in container
    }
    
    // Try to read from mounted config
    configPath := "/home/coder/.mcs/config.json"
    if _, err := os.Stat(configPath); err != nil {
        return "", nil // Config not mounted
    }
    
    data, err := os.ReadFile(configPath)
    if err != nil {
        return "", err
    }
    
    var config struct {
        GitHubToken string `json:"github_token"`
    }
    
    if err := json.Unmarshal(data, &config); err != nil {
        return "", err
    }
    
    return config.GitHubToken, nil
}
```

### 4. Update Codespace Creation

```go
// internal/codespace/create.go
func generateComposeConfig(opts CreateOptions) docker.ComposeConfig {
    return docker.ComposeConfig{
        // ... existing fields ...
        MountGitHubConfig: true, // Enable secure token mounting
    }
}
```

## Docker Secrets Solution (Advanced)

### 1. Create Secret File Helper

```go
// internal/config/secrets.go
package config

import (
    "os"
    "path/filepath"
)

// PrepareGitHubTokenSecret creates a secret file for Docker
func (m *Manager) PrepareGitHubTokenSecret() (string, error) {
    token := m.GetGitHubToken()
    if token == "" {
        return "", nil
    }
    
    secretDir := filepath.Join(m.GetConfigDir(), "secrets")
    if err := os.MkdirAll(secretDir, 0700); err != nil {
        return "", err
    }
    
    secretFile := filepath.Join(secretDir, "github_token")
    if err := os.WriteFile(secretFile, []byte(token), 0600); err != nil {
        return "", err
    }
    
    return secretFile, nil
}
```

### 2. Docker Compose with Secrets

```yaml
version: '3.8'

secrets:
  github_token:
    file: ${HOME}/.mcs/secrets/github_token

services:
  {{ .ContainerName }}:
    image: {{ .Image }}
    secrets:
      - github_token
    # ... rest of config ...
```

### 3. Read Secret in Container

```go
// Helper to read Docker secret
func getGitHubTokenFromSecret() (string, error) {
    secretPath := "/run/secrets/github_token"
    if _, err := os.Stat(secretPath); err != nil {
        return "", nil // Secret not available
    }
    
    token, err := os.ReadFile(secretPath)
    if err != nil {
        return "", err
    }
    
    return strings.TrimSpace(string(token)), nil
}
```

## Environment Variable Protection

### Add Security Check

```go
// internal/cli/security_check.go
package cli

import (
    "fmt"
    "os/exec"
    "strings"
)

// CheckContainerSecurity verifies no secrets in environment
func CheckContainerSecurity(containerName string) error {
    cmd := exec.Command("docker", "inspect", containerName)
    output, err := cmd.Output()
    if err != nil {
        return err
    }
    
    // Check for GitHub token in output
    if strings.Contains(string(output), "GITHUB_TOKEN") ||
       strings.Contains(string(output), "ghp_") {
        return fmt.Errorf("SECURITY WARNING: GitHub token found in container environment!")
    }
    
    return nil
}
```

## Setup Flow Updates

### Add Security Warnings

```go
// internal/cli/setup.go - Add to setup flow
func setupGitHubToken() error {
    fmt.Println(warningStyle.Render(`
⚠️  Security Notice:
• Your GitHub token will be stored locally in ~/.mcs/config.json
• The token will be mounted read-only into containers
• Never share your config file or token
• Use minimal token scopes (repo, read:user)
`))
    // ... rest of setup ...
}
```

## Testing

### Security Test Suite

```go
// internal/security/security_test.go
package security

import (
    "testing"
    "os/exec"
)

func TestNoTokenInEnvironment(t *testing.T) {
    // Create test container
    containerName := "test-security"
    
    // ... create container ...
    
    // Inspect container
    cmd := exec.Command("docker", "inspect", containerName)
    output, err := cmd.Output()
    if err != nil {
        t.Fatal(err)
    }
    
    // Verify no token in environment
    outputStr := string(output)
    if strings.Contains(outputStr, "GITHUB_TOKEN") {
        t.Error("GitHub token found in container environment variables")
    }
    
    if strings.Contains(outputStr, "ghp_") {
        t.Error("GitHub token pattern found in container inspection")
    }
}

func TestConfigFilePermissions(t *testing.T) {
    configPath := filepath.Join(os.Getenv("HOME"), ".mcs", "config.json")
    info, err := os.Stat(configPath)
    if err != nil {
        t.Skip("Config file not found")
    }
    
    mode := info.Mode().Perm()
    if mode != 0600 {
        t.Errorf("Config file has insecure permissions: %o, want 0600", mode)
    }
}
```

## Migration Guide

### For Existing Users

1. **No Action Required**: The volume mount solution is backward compatible
2. **Enhanced Security**: Your token is now more secure without any changes
3. **Verify Security**: Run `mcs doctor --security` to check implementation

### For New Users

1. **Secure by Default**: New installations use volume mounting
2. **Clear Documentation**: Security best practices in setup flow
3. **Minimal Permissions**: Guided to use only required token scopes

## Monitoring and Alerts

### Add Security Monitoring

```go
// internal/cli/monitor.go
func (m *Monitor) CheckSecurity() {
    // Check for tokens in environment
    for _, container := range m.activeContainers {
        if err := CheckContainerSecurity(container); err != nil {
            log.Errorf("Security issue in %s: %v", container, err)
            m.SendAlert("Security Warning", err.Error())
        }
    }
}
```

## Future Enhancements

1. **Token Rotation**: Remind users to rotate tokens periodically
2. **Scope Validation**: Verify token has minimal required scopes
3. **Audit Logging**: Log all token usage for security audits
4. **Encryption at Rest**: Consider encrypting config file