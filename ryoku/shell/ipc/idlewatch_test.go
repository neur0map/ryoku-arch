package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestParkable(t *testing.T) {
	for _, n := range []string{"launcher", "overview", "ryolayer"} {
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
	// launcher opts OUT explicitly; overview and ryolayer are unset.
	if err := os.WriteFile(filepath.Join(dir, "ryoku", "performance.json"),
		[]byte(`{"unloadLauncherWhenIdle":false}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if unloadPaletteWhenIdle("launcher") {
		t.Error("launcher explicitly false -> off")
	}
	if !unloadPaletteWhenIdle("overview") {
		t.Error("overview unset -> on by default (cheap default)")
	}
	if !unloadPaletteWhenIdle("ryolayer") {
		t.Error("ryolayer unset -> on by default (cheap default)")
	}
	if unloadPaletteWhenIdle("pill") {
		t.Error("pill is not a parkable palette")
	}
}

func TestRyolayerHasPins(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	p := filepath.Join(dir, "ryoku", "ryolayer.json")
	if ryolayerHasPins() {
		t.Error("absent ryolayer.json -> no pins")
	}
	_ = os.WriteFile(p, []byte(`{"widgets":[{"pinned":false},{"pinned":false}]}`), 0o644)
	if ryolayerHasPins() {
		t.Error("no widget pinned -> no pins")
	}
	_ = os.WriteFile(p, []byte(`{"widgets":[{"pinned":false},{"pinned":true}]}`), 0o644)
	if !ryolayerHasPins() {
		t.Error("a pinned widget -> has pins")
	}
}

func TestStartsAtBoot(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	if !startsAtBoot(component{"pill", true}) {
		t.Error("a persistent component starts at boot")
	}
	if startsAtBoot(component{"launcher", false}) {
		t.Error("an on-demand palette does not start at boot")
	}
	if startsAtBoot(component{"ryolayer", false}) {
		t.Error("ryolayer with no pins does not start at boot")
	}
	_ = os.WriteFile(filepath.Join(dir, "ryoku", "ryolayer.json"),
		[]byte(`{"widgets":[{"pinned":true}]}`), 0o644)
	if !startsAtBoot(component{"ryolayer", false}) {
		t.Error("ryolayer with a pin starts at boot")
	}
	_ = os.WriteFile(filepath.Join(dir, "ryoku", "performance.json"),
		[]byte(`{"disabledComponents":["launcher"]}`), 0o644)
	if startsAtBoot(component{"launcher", true}) {
		t.Error("a disabled component never starts at boot")
	}
}

func TestComponentDisabledRyolayerToggle(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	sp := filepath.Join(dir, "ryoku", "shell.json")
	if componentDisabled("ryolayer") {
		t.Error("ryolayer with no shell.json is enabled by default")
	}
	_ = os.WriteFile(sp, []byte(`{"ryolayerEnabled":true}`), 0o644)
	if componentDisabled("ryolayer") {
		t.Error("ryolayerEnabled:true -> not disabled")
	}
	_ = os.WriteFile(sp, []byte(`{"ryolayerEnabled":false}`), 0o644)
	if !componentDisabled("ryolayer") {
		t.Error("ryolayerEnabled:false -> disabled")
	}
	if componentDisabled("launcher") {
		t.Error("launcher is unaffected by the ryolayer shell toggle")
	}
}
