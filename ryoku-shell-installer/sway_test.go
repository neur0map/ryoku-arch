package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const swaySample = `
# comment line
output HDMI-A-1 mode 1920x1080@60Hz pos 2560 0 transform 270
output HDMI-A-1 scale 1.5
output eDP-1 scale 2 pos 0 0 adaptive_sync on
output eDP-1 bg ~/wall.png fill
output DP-4 disable
output * subpixel rgb
output "Some Co Monitor 123" scale 2
input type:keyboard {
    xkb_layout "us,ru"
    xkb_options grp:win_space_toggle
}
input 1234:5678:Some_Keyboard xkb_layout de
`

func TestParseSwayOutputs(t *testing.T) {
	outs := parseSwayOutputs(swaySample)
	if len(outs) != 4 {
		t.Fatalf("want HDMI-A-1, eDP-1, DP-4 and the desc name, got %+v", outs)
	}
	hdmi := outs[0]
	if hdmi.name != "HDMI-A-1" || hdmi.mode != "1920x1080@60" || hdmi.position != "2560x0" ||
		hdmi.transform != 3 || hdmi.scale != "1.5" {
		t.Fatalf("HDMI-A-1 folded wrong: %+v", hdmi)
	}
	edp := outs[1]
	if edp.name != "eDP-1" || edp.scale != "2" || edp.position != "0x0" || edp.vrr != 1 {
		t.Fatalf("eDP-1 parsed wrong: %+v", edp)
	}
	if !outs[2].off || outs[2].name != "DP-4" {
		t.Fatalf("disable missed: %+v", outs[2])
	}
	_, skipped := renderPins(outs, false, "sway")
	if len(skipped) != 1 || skipped[0] != "Some Co Monitor 123" {
		t.Fatalf("desc name must land in skipped: %v", skipped)
	}
	if got := parseSwayOutputs("output * scale 2\n"); got != nil {
		t.Fatalf("wildcard output must not be pinned: %+v", got)
	}
}

func TestParseSwayInput(t *testing.T) {
	layout, variant, options, hasFile := parseSwayInput(swaySample)
	if hasFile || layout != "us,ru" || variant != "" || options != "grp:win_space_toggle" {
		t.Fatalf("got %q %q %q file=%v", layout, variant, options, hasFile)
	}
	// specific device is the fallback when no type:keyboard or * rule exists
	layout, _, _, _ = parseSwayInput("input 1:2:kbd xkb_layout fr\n")
	if layout != "fr" {
		t.Fatalf("device fallback missed: %q", layout)
	}
	_, _, _, hasFile = parseSwayInput("input type:keyboard xkb_file ~/.config/keymap.xkb\n")
	if !hasFile {
		t.Fatal("xkb_file must disable field salvage")
	}
}

func TestReadSwayTreeIncludes(t *testing.T) {
	home := t.TempDir()
	root := filepath.Join(home, ".config/sway")
	if err := os.MkdirAll(filepath.Join(root, "config.d"), 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(root, "config"),
		[]byte("include config.d/*\ninclude $(hostname).conf\n"), 0o644)
	os.WriteFile(filepath.Join(root, "config.d/displays"),
		[]byte("output DP-9 scale 2\n"), 0o644)
	text := loadSwayConfig(home)
	if !strings.Contains(text, "DP-9") {
		t.Fatalf("include glob not followed:\n%s", text)
	}
	outs := parseSwayOutputs(text)
	if len(outs) != 1 || outs[0].name != "DP-9" {
		t.Fatalf("got %+v", outs)
	}
}
