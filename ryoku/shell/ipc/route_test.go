package main

import "testing"

// route = the single source of truth for which panel a keybind toggles; a wrong
// entry silently opens the wrong surface, so pin every command.
func TestRoute(t *testing.T) {
	cases := []struct {
		cmd, config, target, fn string
	}{
		{"launcher", "pill", "pill", "launcher"},
		{"clipboard", "pill", "pill", "clipboard"},
		{"link", "pill", "pill", "link"},
		{"inbox", "pill", "pill", "inbox"},
		{"wallpaper-picker", "pill", "pill", "wallpaper"},
		{"mixer", "pill", "pill", "mixer"},
		{"media", "pill", "pill", "media"},
		{"hide", "pill", "pill", "hide"},
		{"sysinfo", "pill", "pill", "sysinfo"},
		{"stash", "pill", "pill", "stash"},
		{"toolkit", "pill", "pill", "toolkit"},
		{"utilities", "pill", "pill", "utilities"},
		{"sidebar", "sidebar", "sidebar", "toggle"},
	}
	for _, c := range cases {
		config, target, fn, ok := route(c.cmd)
		if !ok {
			t.Fatalf("route(%q) not ok", c.cmd)
		}
		if config != c.config || target != c.target || fn != c.fn {
			t.Fatalf("route(%q) = (%s,%s,%s), want (%s,%s,%s)", c.cmd, config, target, fn, c.config, c.target, c.fn)
		}
	}
	for _, cmd := range []string{"voice", "lock", "wallpaper", "reload", "status", "ping", "quit", "bogus", ""} {
		if _, _, _, ok := route(cmd); ok {
			t.Fatalf("route(%q) should not be a single IPC call", cmd)
		}
	}
}

// only monitor-scoped surfaces get the active monitor; hide doesn't.
func TestNeedsMonitor(t *testing.T) {
	for fn, want := range map[string]bool{
		"launcher": true, "toggle": true, "clipboard": true,
		"hide": false,
	} {
		if got := needsMonitor(fn); got != want {
			t.Fatalf("needsMonitor(%q) = %v, want %v", fn, got, want)
		}
	}
}
