package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestConfigRoundTrip(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)

	// no file -> default.
	if c := loadConfig(); c.UI.Section != "displays" {
		t.Fatalf("default section = %q, want displays", c.UI.Section)
	}

	if err := configSet("section", "appearance"); err != nil {
		t.Fatal(err)
	}
	if v, ok := configGet("section"); !ok || v != "appearance" {
		t.Fatalf("after set: got %q ok=%v, want appearance", v, ok)
	}

	// landed on disk as real TOML.
	b, err := os.ReadFile(filepath.Join(dir, "ryoku", "hub.toml"))
	if err != nil {
		t.Fatalf("config not written: %v", err)
	}
	if !contains(string(b), "section = \"appearance\"") {
		t.Errorf("toml missing section line:\n%s", b)
	}
}

func TestUpdateInterval(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())

	// no file -> default.
	if c := loadConfig(); c.UI.UpdateInterval != "daily" {
		t.Fatalf("default update_interval = %q, want daily", c.UI.UpdateInterval)
	}

	if err := configSet("update_interval", "off"); err != nil {
		t.Fatal(err)
	}
	if v, ok := configGet("update_interval"); !ok || v != "off" {
		t.Fatalf("after set: got %q ok=%v, want off", v, ok)
	}
}

func TestAdvanced(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())

	// the Advanced reveal is off until set, so an unset value reads empty.
	if v, ok := configGet("advanced"); !ok || v != "" {
		t.Fatalf("default advanced = %q ok=%v, want empty", v, ok)
	}

	if err := configSet("advanced", "1"); err != nil {
		t.Fatal(err)
	}
	if v, ok := configGet("advanced"); !ok || v != "1" {
		t.Fatalf("after set: got %q ok=%v, want 1", v, ok)
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
