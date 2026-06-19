package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestConfigRoundTrip(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)

	// Missing file yields the default.
	if c := loadConfig(); c.UI.Section != "keybinds" {
		t.Fatalf("default section = %q, want keybinds", c.UI.Section)
	}

	if err := configSet("section", "extras"); err != nil {
		t.Fatal(err)
	}
	if v, ok := configGet("section"); !ok || v != "extras" {
		t.Fatalf("after set: got %q ok=%v, want extras", v, ok)
	}

	// It persisted as real TOML on disk.
	b, err := os.ReadFile(filepath.Join(dir, "ryoku", "hub.toml"))
	if err != nil {
		t.Fatalf("config not written: %v", err)
	}
	if !contains(string(b), "section = \"extras\"") {
		t.Errorf("toml missing section line:\n%s", b)
	}
}

func TestConfigUnknownKey(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	if err := configSet("nope", "x"); err == nil {
		t.Error("setting an unknown key should error")
	}
	if _, ok := configGet("nope"); ok {
		t.Error("getting an unknown key should report not-ok")
	}
}

func contains(haystack, needle string) bool {
	return len(haystack) >= len(needle) && (indexOf(haystack, needle) >= 0)
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}
