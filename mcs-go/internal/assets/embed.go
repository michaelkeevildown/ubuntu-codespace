package assets

import (
	_ "embed"
	"fmt"
	"os"
	"path/filepath"
)

// Embedded installer scripts
var (
	//go:embed installers/claude.sh
	claudeInstaller string

	//go:embed installers/claude-flow.sh
	claudeFlowInstaller string

	//go:embed installers/github-cli.sh
	githubCLIInstaller string

	//go:embed helpers/mcs-get-token.sh
	mcsGetTokenHelper string
)

// installerMap maps component IDs to their installer content
var installerMap = map[string]string{
	"claude":      claudeInstaller,
	"claude-flow": claudeFlowInstaller,
	"github-cli":  githubCLIInstaller,
}

// GetInstaller returns the installer content for a component
func GetInstaller(componentID string) (string, error) {
	content, ok := installerMap[componentID]
	if !ok {
		return "", fmt.Errorf("installer not found for component: %s", componentID)
	}
	return content, nil
}

// ExtractInstallers extracts all installer scripts to a directory
func ExtractInstallers(targetDir string) error {
	// Create installers directory
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("failed to create installers directory: %w", err)
	}

	// Write each installer
	for id, content := range installerMap {
		filename := fmt.Sprintf("%s.sh", id)
		path := filepath.Join(targetDir, filename)
		
		if err := os.WriteFile(path, []byte(content), 0755); err != nil {
			return fmt.Errorf("failed to write installer %s: %w", filename, err)
		}
	}

	// Also extract the mcs-get-token helper
	helperPath := filepath.Join(targetDir, "mcs-get-token.sh")
	if err := os.WriteFile(helperPath, []byte(mcsGetTokenHelper), 0755); err != nil {
		return fmt.Errorf("failed to write mcs-get-token helper: %w", err)
	}

	return nil
}