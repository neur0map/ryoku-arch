package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestRecoveryRunsLocalScript(t *testing.T) {
	repo := t.TempDir()
	// resolveRepo wants a real git work tree.
	init := exec.Command("git", "-C", repo, "init")
	init.Env = append(os.Environ(), "GIT_CONFIG_GLOBAL=/dev/null", "GIT_CONFIG_SYSTEM=/dev/null")
	if out, err := init.CombinedOutput(); err != nil {
		t.Fatalf("git init: %v\n%s", err, out)
	}

	marker := filepath.Join(repo, "ran")
	script := filepath.Join(repo, "bin", "ryoku-recovery")
	if err := os.MkdirAll(filepath.Dir(script), 0o755); err != nil {
		t.Fatal(err)
	}
	body := "#!/bin/sh\nprintf '%s' \"$1\" > " + shellQuote(marker) + "\n"
	if err := os.WriteFile(script, []byte(body), 0o755); err != nil {
		t.Fatal(err)
	}

	t.Setenv("RYOKU_REPO", repo)
	if err := cmdRecovery([]string{"--ping"}); err != nil {
		t.Fatalf("cmdRecovery: %v", err)
	}

	got, err := os.ReadFile(marker)
	if err != nil {
		t.Fatalf("local recovery script did not run: %v", err)
	}
	if strings.TrimSpace(string(got)) != "--ping" {
		t.Errorf("script received %q, want --ping (args not passed through)", got)
	}
}

func shellQuote(s string) string { return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'" }
