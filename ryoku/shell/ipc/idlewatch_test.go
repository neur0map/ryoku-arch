package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestParkable(t *testing.T) {
	for _, n := range []string{"launcher", "overview"} {
		if !parkable(n) {
			t.Errorf("%s should be parkable", n)
		}
	}
	for _, n := range []string{"pill", "visualizer", "widgets", "hub", ""} {
		if parkable(n) {
			t.Errorf("%s should not be parkable", n)
		}
	}
}

func TestParkDue(t *testing.T) {
	now := time.Now()
	grace := 60 * time.Second
	cases := []struct {
		name   string
		since  time.Time
		hidden bool
		want   bool
	}{
		{"not hidden", now, false, false},
		{"hidden under grace", now.Add(-30 * time.Second), true, false},
		{"hidden at grace", now.Add(-grace), true, true},
		{"hidden past grace", now.Add(-90 * time.Second), true, true},
	}
	for _, c := range cases {
		if got := parkDue(c.since, c.hidden, grace, now); got != c.want {
			t.Errorf("%s: parkDue = %v, want %v", c.name, got, c.want)
		}
	}
}

func TestSetPaletteVisible(t *testing.T) {
	d := &daemon{hiddenSince: map[string]time.Time{}}

	d.setPaletteVisible("launcher", false) // hidden -> grace starts
	d.parkMu.Lock()
	_, hidden := d.hiddenSince["launcher"]
	d.parkMu.Unlock()
	if !hidden {
		t.Fatal("a hidden report must record hiddenSince")
	}

	d.setPaletteVisible("launcher", true) // shown -> grace cancelled
	d.parkMu.Lock()
	_, stillHidden := d.hiddenSince["launcher"]
	d.parkMu.Unlock()
	if stillHidden {
		t.Fatal("a shown report must clear hiddenSince")
	}
}

func TestUnloadPaletteWhenIdle(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "ryoku", "performance.json"),
		[]byte(`{"unloadLauncherWhenIdle":true}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if !unloadPaletteWhenIdle("launcher") {
		t.Error("launcher flag is on")
	}
	if unloadPaletteWhenIdle("overview") {
		t.Error("overview flag is unset -> off")
	}
	if unloadPaletteWhenIdle("pill") {
		t.Error("pill is not a parkable palette")
	}
}
