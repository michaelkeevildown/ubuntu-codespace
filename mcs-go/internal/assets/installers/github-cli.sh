#!/bin/bash

# GitHub CLI Component Installer
# Installs and configures GitHub CLI in containers

set -e

# Component metadata
metadata() {
    echo "name=GitHub CLI"
    echo "version=latest"
    echo "description=GitHub command-line interface with authentication"
}

# Component dependencies
dependencies() {
    # No dependencies
    echo ""
}

# Installation function
install() {
    echo "Installing GitHub CLI..."
    
    # Detect OS and architecture
    local os="linux"
    local arch=$(uname -m)
    
    case "$arch" in
        x86_64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
        *)
            echo "Unsupported architecture: $arch" >&2
            return 1
            ;;
    esac
    
    # Always use binary installation for non-root environments
    install_binary
}

# Install on Debian/Ubuntu (kept for reference but not used)
install_debian() {
    echo "Package manager installation requires root privileges."
    echo "Falling back to binary installation..."
    install_binary
}

# Install on RHEL/CentOS/Fedora (kept for reference but not used)
install_rhel() {
    echo "Package manager installation requires root privileges."
    echo "Falling back to binary installation..."
    install_binary
}

# Install on Alpine
install_alpine() {
    echo "Installing GitHub CLI on Alpine..."
    
    # GitHub CLI is not in Alpine repos, use binary installation
    install_binary
}

# Binary installation (fallback)
install_binary() {
    echo "Installing GitHub CLI from binary..."
    
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            arch="amd64"
            ;;
        aarch64|arm64)
            arch="arm64"
            ;;
    esac
    
    # Get latest version
    local version=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep -Po '"tag_name": "v\K[^"]*')
    
    if [ -z "$version" ]; then
        echo "Failed to get latest GitHub CLI version" >&2
        return 1
    fi
    
    # Download and install
    local url="https://github.com/cli/cli/releases/download/v${version}/gh_${version}_linux_${arch}.tar.gz"
    
    # Create local bin directory
    mkdir -p "$HOME/.local/bin"
    
    # Download and extract to user directory
    curl -fsSL "$url" | tar -xz -C /tmp
    mv "/tmp/gh_${version}_linux_${arch}/bin/gh" "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/gh"
    
    # Update PATH if needed
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    # Cleanup
    rm -rf "/tmp/gh_${version}_linux_${arch}"
}

# Configuration function
configure() {
    echo "Configuring GitHub CLI..."
    
    # Try to get token from MCS config using helper script
    local token=""
    local mcs_helper="/home/coder/.components/mcs-get-token.sh"
    
    # First, try the helper script if available
    if [ -x "$mcs_helper" ]; then
        echo "Using MCS token helper..."
        token=$("$mcs_helper" 2>/dev/null || echo "")
    fi
    
    # Fallback to legacy token file location
    if [ -z "$token" ]; then
        local token_file="/home/coder/.tokens/github.token"
        if [ -f "$token_file" ] && [ -s "$token_file" ]; then
            echo "Using legacy token file..."
            token=$(cat "$token_file")
        fi
    fi
    
    # If we have a token, configure GitHub CLI
    if [ -n "$token" ]; then
        # Configure gh with token
        echo "$token" | gh auth login --with-token
        
        # Verify authentication
        if gh auth status >/dev/null 2>&1; then
            echo "GitHub CLI authenticated successfully"
            
            # Get username for git config
            local username=$(gh api user --jq .login 2>/dev/null || echo "")
            
            if [ -n "$username" ]; then
                # Configure git
                git config --global user.name "$username"
                git config --global user.email "${username}@users.noreply.github.com"
                git config --global init.defaultBranch main
                
                echo "Git configured for user: $username"
            fi
        else
            echo "GitHub CLI authentication failed" >&2
            return 1
        fi
    else
        echo "GitHub token not found"
        echo "GitHub CLI installed but not authenticated"
        echo "To set token on host: mcs config set github-token <token>"
        echo "To authenticate manually: gh auth login"
    fi
    
    # Set up git credential helper to use gh
    git config --global credential.helper "!gh auth git-credential"
    
    # Configure gh settings
    gh config set git_protocol https
    gh config set prompt enabled
}

# Verification function
verify() {
    echo "Verifying GitHub CLI installation..."
    
    # Check if gh is installed
    if ! command -v gh >/dev/null 2>&1; then
        echo "GitHub CLI not found in PATH" >&2
        return 1
    fi
    
    # Check version
    local version=$(gh --version | head -n1)
    echo "GitHub CLI installed: $version"
    
    # Check authentication status
    if gh auth status >/dev/null 2>&1; then
        echo "GitHub CLI is authenticated"
        gh auth status
    else
        echo "GitHub CLI is not authenticated"
    fi
    
    # Check git configuration
    local git_user=$(git config --global user.name 2>/dev/null || echo "")
    local git_email=$(git config --global user.email 2>/dev/null || echo "")
    
    if [ -n "$git_user" ] && [ -n "$git_email" ]; then
        echo "Git is configured: $git_user <$git_email>"
    else
        echo "Git user configuration is incomplete"
    fi
    
    return 0
}

# Uninstall function
uninstall() {
    echo "Uninstalling GitHub CLI..."
    
    # Remove based on installation method
    if command -v apt-get >/dev/null 2>&1 && dpkg -l gh >/dev/null 2>&1; then
        apt-get remove -y gh
    elif command -v yum >/dev/null 2>&1 && rpm -q gh >/dev/null 2>&1; then
        yum remove -y gh
    elif [ -f /usr/local/bin/gh ]; then
        rm -f "$HOME/.local/bin/gh"
    fi
    
    # Remove auth config
    rm -rf ~/.config/gh
    
    echo "GitHub CLI uninstalled"
}

# Main function
main() {
    local action="${1:-install}"
    
    case "$action" in
        metadata)
            metadata
            ;;
        dependencies)
            dependencies
            ;;
        install)
            install
            ;;
        configure)
            configure
            ;;
        verify)
            verify
            ;;
        uninstall)
            uninstall
            ;;
        *)
            echo "Usage: $0 {metadata|dependencies|install|configure|verify|uninstall}" >&2
            return 1
            ;;
    esac
}

# Run main if executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi