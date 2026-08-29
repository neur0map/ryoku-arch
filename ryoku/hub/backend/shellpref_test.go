package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEnsureShellLoadersPreservesUserContent(t *testing.T) {
	home := t.TempDir()
	bashrc := filepath.Join(home, ".bashrc")
	profile := filepath.Join(home, ".bash_profile")
	if err := os.WriteFile(bashrc, []byte("alias mine='yes'\n"), 0o640); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(profile, []byte("export MINE=1\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	changed, err := ensureShellLoaders(home, "bash")
	if err != nil || !changed {
		t.Fatalf("ensureShellLoaders = %v, %v", changed, err)
	}
	for _, path := range []string{bashrc, profile} {
		b, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		text := string(b)
		if !strings.HasSuffix(text, bashLoader+"\n") {
			t.Errorf("loader not last in %s: %q", path, text)
		}
	}
	b, _ := os.ReadFile(bashrc)
	if !strings.Contains(string(b), "alias mine='yes'") {
		t.Fatal("existing bashrc content was lost")
	}
	changed, err = ensureShellLoaders(home, "bash")
	if err != nil || changed {
		t.Fatalf("second ensure = %v, %v, want unchanged", changed, err)
	}
}

func TestShellChoiceValidation(t *testing.T) {
	dir := t.TempDir()
	fish := filepath.Join(dir, "fish")
	if err := os.WriteFile(fish, nil, 0o755); err != nil {
		t.Fatal(err)
	}
	shells := filepath.Join(dir, "shells")
	if err := os.WriteFile(shells, []byte(fish+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	choices := map[string]string{"fish": fish, "bash": filepath.Join(dir, "bash")}
	if got, err := validateShellChoice("fish", choices, shells); err != nil || got != fish {
		t.Fatalf("fish = %q, %v", got, err)
	}
	if _, err := validateShellChoice("bash", choices, shells); err == nil {
		t.Fatal("missing bash accepted")
	}
	if _, err := validateShellChoice("sh", choices, shells); err == nil {
		t.Fatal("unknown shell accepted")
	}
}

func TestSyncSessionShellUpdatesLaunchEnvironments(t *testing.T) {
	old := runSessionCommand
	defer func() { runSessionCommand = old }()
	var calls []string
	runSessionCommand = func(name string, args ...string) error {
		calls = append(calls, name+" "+strings.Join(args, " "))
		return nil
	}
	syncSessionShell("/usr/bin/zsh")
	joined := strings.Join(calls, "\n")
	for _, want := range []string{
		"systemctl --user set-environment SHELL=/usr/bin/zsh",
		"dbus-update-activation-environment --systemd SHELL=/usr/bin/zsh",
		"hyprctl eval hl.env(\"SHELL\", \"/usr/bin/zsh\")",
		"ryoku reload",
	} {
		if !strings.Contains(joined, want) {
			t.Errorf("session calls missing %q:\n%s", want, joined)
		}
	}
}
