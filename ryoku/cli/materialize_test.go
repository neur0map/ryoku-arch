package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// materialize must never overwrite a per-machine generated seed (monitors.lua,
// gpu.lua) or a user file, so `ryoku update` can't change a user's settings
// while it refreshes the managed config the package ships.
func TestMaterializePreservesGeneratedAndUserFiles(t *testing.T) {
	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	// Package ships a managed module and seeds for the generated drop-ins
	// plus the user-owned keyboard layout and fastfetch readout.
	writeFile(t, filepath.Join(base, "hypr/hyprland.lua"), "require(\"monitors\")\n")
	writeFile(t, filepath.Join(base, "hypr/monitors.lua"), "-- seed\n")
	writeFile(t, filepath.Join(base, "hypr/gpu.lua"), "-- seed\n")
	writeFile(t, filepath.Join(base, "hypr/keyboard.lua"), "kb_layout = \"us\"\n")
	writeFile(t, filepath.Join(base, "fastfetch/config.jsonc"), "\"source\": \"ryoku\"\n")
	writeFile(t, filepath.Join(base, "kitty/current-theme.conf"), "background #16110b\n")

	// fresh install: every file lands, seeds included so first boot works.
	if err := materialize(); err != nil {
		t.Fatalf("fresh materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "hypr/monitors.lua"), "-- seed")
	wantFile(t, filepath.Join(dest, "hypr/gpu.lua"), "-- seed")
	wantFile(t, filepath.Join(dest, "hypr/keyboard.lua"), "kb_layout = \"us\"")
	wantFile(t, filepath.Join(dest, "fastfetch/config.jsonc"), "ryoku")
	wantFile(t, filepath.Join(dest, "kitty/current-theme.conf"), "16110b")

	// Runtime regenerates the drop-in seeds; user adds extra keyboard layouts,
	// a user file, and customizes the fastfetch readout.
	writeFile(t, filepath.Join(dest, "hypr/monitors.lua"), "DISPLAY\n")
	writeFile(t, filepath.Join(dest, "hypr/gpu.lua"), "GPUPIN\n")
	writeFile(t, filepath.Join(dest, "hypr/keyboard.lua"), "kb_layout = \"us,ru,de,fr\"\n")
	writeFile(t, filepath.Join(dest, "hypr/user.lua"), "USER\n")
	writeFile(t, filepath.Join(dest, "fastfetch/config.jsonc"), "\"source\": \"my-custom-logo\"\n")
	writeFile(t, filepath.Join(dest, "kitty/current-theme.conf"), "background #3a5f8a\n") // wallust from the wallpaper
	// later release changes the managed module and reworks the shipped readout.
	writeFile(t, filepath.Join(base, "hypr/hyprland.lua"), "require(\"monitors_user\")\n")
	writeFile(t, filepath.Join(base, "fastfetch/config.jsonc"), "\"source\": \"ryoku-redesigned\"\n")

	// update: managed file is refreshed; the generated seeds, the user file,
	// and the customized fastfetch readout stay exactly as the machine had them.
	if err := materialize(); err != nil {
		t.Fatalf("update materialize: %v", err)
	}
	wantFile(t, filepath.Join(dest, "hypr/hyprland.lua"), "monitors_user")
	wantFile(t, filepath.Join(dest, "hypr/monitors.lua"), "DISPLAY")
	wantFile(t, filepath.Join(dest, "hypr/gpu.lua"), "GPUPIN")
	wantFile(t, filepath.Join(dest, "hypr/user.lua"), "USER")
	wantFile(t, filepath.Join(dest, "hypr/keyboard.lua"), "us,ru,de,fr")
	wantFile(t, filepath.Join(dest, "fastfetch/config.jsonc"), "my-custom-logo")
	wantFile(t, filepath.Join(dest, "kitty/current-theme.conf"), "3a5f8a")
}

// A managed file dropped from a release is pruned; a generated seed is never
// pruned, even after the base stops shipping it.
func TestMaterializePrunesManagedNotSeeds(t *testing.T) {
	base, dest := t.TempDir(), t.TempDir()
	t.Setenv("RYOKU_CONFIG_BASE", base)
	t.Setenv("XDG_CONFIG_HOME", dest)
	t.Setenv("XDG_STATE_HOME", t.TempDir())

	writeFile(t, filepath.Join(base, "hypr/old.lua"), "x\n")
	writeFile(t, filepath.Join(base, "hypr/monitors.lua"), "-- seed\n")
	if err := materialize(); err != nil {
		t.Fatalf("first materialize: %v", err)
	}
	writeFile(t, filepath.Join(dest, "hypr/monitors.lua"), "DISPLAY\n") // runtime-regenerated

	// next release drops both the managed file and the monitors seed.
	os.Remove(filepath.Join(base, "hypr/old.lua"))
	os.Remove(filepath.Join(base, "hypr/monitors.lua"))
	if err := materialize(); err != nil {
		t.Fatalf("second materialize: %v", err)
	}
	if exists(filepath.Join(dest, "hypr/old.lua")) {
		t.Error("a managed file dropped from the release should be pruned")
	}
	wantFile(t, filepath.Join(dest, "hypr/monitors.lua"), "DISPLAY") // seed survives
}

func wantFile(t *testing.T, path, want string) {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	if !strings.Contains(string(b), want) {
		t.Errorf("%s = %q, want substring %q", path, string(b), want)
	}
}
