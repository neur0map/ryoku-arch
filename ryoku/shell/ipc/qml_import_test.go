package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSetupQmlImportPathHonorsXDGConfigHome(t *testing.T) {
	configHome := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", configHome)
	t.Setenv("QML_IMPORT_PATH", "")
	t.Setenv("QML2_IMPORT_PATH", "")
	previousShellDir := shellDir
	shellDir = ""
	t.Cleanup(func() { shellDir = previousShellDir })

	setupQmlImportPath()
	want := filepath.Join(configHome, "quickshell")
	for _, name := range []string{"QML_IMPORT_PATH", "QML2_IMPORT_PATH"} {
		parts := strings.Split(os.Getenv(name), string(os.PathListSeparator))
		if len(parts) == 0 || parts[0] != want {
			t.Fatalf("%s = %q, want first entry %q", name, os.Getenv(name), want)
		}
	}
}
