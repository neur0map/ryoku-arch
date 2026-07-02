package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const hyprSample = `
$mainMod = SUPER
monitor = DP-1, 2560x1440@165, 0x0, 1.25, transform, 1, vrr, 1
monitor = desc:Some Co CoolMonitor 1234, preferred, auto, auto
monitor = eDP-1, disable
monitor = , preferred, auto, 1 # fallback rule, matches everything
monitor = HDMI-A-1, addreserved, 0, 40, 0, 0
input {
    kb_layout = us,ru
    kb_variant =
    kb_options = grp:win_space_toggle
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}
monitorv2 {
    output = DP-2
    mode = 1920x1080@144
    position = 2560x0
    scale = 1
    transform = 3
}
`

func TestParseHyprMonitors(t *testing.T) {
	outs := parseHyprMonitors(hyprSample)
	if len(outs) != 4 {
		t.Fatalf("want DP-1, desc, eDP-1, DP-2, got %+v", outs)
	}
	dp := outs[0]
	if dp.name != "DP-1" || dp.mode != "2560x1440@165" || dp.position != "0x0" ||
		dp.scale != "1.25" || dp.transform != 1 || dp.vrr != 1 {
		t.Fatalf("DP-1 parsed wrong: %+v", dp)
	}
	if outs[1].name != "desc:Some Co CoolMonitor 1234" || outs[1].mode != "preferred" || outs[1].scale != "" {
		t.Fatalf("desc pin parsed wrong: %+v", outs[1])
	}
	if !outs[2].off || outs[2].name != "eDP-1" {
		t.Fatalf("disable missed: %+v", outs[2])
	}
	v2 := outs[3]
	if v2.name != "DP-2" || v2.mode != "1920x1080@144" || v2.position != "2560x0" ||
		v2.scale != "1" || v2.transform != 3 {
		t.Fatalf("monitorv2 parsed wrong: %+v", v2)
	}
	// later line for the same name wins
	dup := parseHyprMonitors("monitor = DP-1, 1920x1080, 0x0, 1\nmonitor = DP-1, 2560x1440, 0x0, 2\n")
	if len(dup) != 1 || dup[0].scale != "2" {
		t.Fatalf("last-wins failed: %+v", dup)
	}
}

func TestParseHyprInput(t *testing.T) {
	layout, variant, options, hasFile := parseHyprInput(hyprSample)
	if hasFile || layout != "us,ru" || variant != "" || options != "grp:win_space_toggle" {
		t.Fatalf("got %q %q %q file=%v", layout, variant, options, hasFile)
	}
	_, _, _, hasFile = parseHyprInput("input {\n    kb_file = ~/.config/keymap.xkb\n}\n")
	if !hasFile {
		t.Fatal("keymap file must disable field salvage")
	}
	layout, _, _, _ = parseHyprInput("input:kb_layout = de\n")
	if layout != "de" {
		t.Fatalf("flat form missed: %q", layout)
	}
}

func TestRenderPinsDescNames(t *testing.T) {
	outs := parseHyprMonitors(hyprSample)
	pins, skipped := renderPins(outs, true, "hyprland")
	if len(skipped) != 0 {
		t.Fatalf("hyprland desc pins must be kept: %v", skipped)
	}
	if !strings.Contains(pins, `hl.monitor({ output = "desc:Some Co CoolMonitor 1234", mode = "preferred"`) {
		t.Fatalf("desc pin missing:\n%s", pins)
	}
	// the niri path still refuses names it cannot match to a connector
	_, skipped = renderPins(outs, false, "niri")
	if len(skipped) != 1 {
		t.Fatalf("non-desc dialects must skip desc names: %v", skipped)
	}
}

func TestReadHyprTreeSourcesAndVars(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".config/hypr")
	if err := os.MkdirAll(filepath.Join(root, "configs"), 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(root, "hyprland.conf"),
		[]byte("$configs = $HOME/.config/hypr/configs\nsource = $configs/*.conf\n"), 0o644)
	os.WriteFile(filepath.Join(root, "configs/monitors.conf"),
		[]byte("monitor = DP-3, 3840x2160@60, 0x0, 2\n"), 0o644)
	outs := parseHyprMonitors(loadHyprConfig(home))
	if len(outs) != 1 || outs[0].name != "DP-3" || outs[0].scale != "2" {
		t.Fatalf("source glob with $var not followed: %+v", outs)
	}
	// a lua-era config owns the tree, the conf grammar is dead weight
	os.WriteFile(filepath.Join(root, "hyprland.lua"), []byte("-- lua config\n"), 0o644)
	if loadHyprConfig(home) != "" {
		t.Fatal("hyprland.lua present must disable conf salvage")
	}
}
