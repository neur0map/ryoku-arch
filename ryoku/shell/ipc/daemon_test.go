package main

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

func TestQsEnvAddsMallocConf(t *testing.T) {
	old, had := os.LookupEnv("MALLOC_CONF")
	os.Unsetenv("MALLOC_CONF")
	t.Cleanup(func() {
		if had {
			os.Setenv("MALLOC_CONF", old)
		} else {
			os.Unsetenv("MALLOC_CONF")
		}
	})
	want := "MALLOC_CONF=" + jemallocConf
	n := 0
	for _, e := range qsEnv() {
		if e == want {
			n++
		}
	}
	if n != 1 {
		t.Errorf("qsEnv() has %d copies of %q, want exactly 1", n, want)
	}
}

func TestQsEnvRespectsExistingMallocConf(t *testing.T) {
	t.Setenv("MALLOC_CONF", "narenas:8")
	for _, e := range qsEnv() {
		if e == "MALLOC_CONF="+jemallocConf {
			t.Errorf("qsEnv() overrode a user-pinned MALLOC_CONF")
		}
	}
}

func TestParseDisabledComponents(t *testing.T) {
	cases := []struct {
		name string
		body string
		want map[string]bool
	}{
		{"one", `{"disabledComponents":["overview"]}`, map[string]bool{"overview": true}},
		{"several", `{"disabledComponents":["launcher","visualizer"]}`, map[string]bool{"launcher": true, "visualizer": true}},
		{"pill excluded", `{"disabledComponents":["pill","widgets"]}`, map[string]bool{"widgets": true}},
		{"absent key", `{"unloadWidgetsWhenCovered":true}`, map[string]bool{}},
		{"empty list", `{"disabledComponents":[]}`, map[string]bool{}},
		{"malformed", `not json`, map[string]bool{}},
		{"empty body", ``, map[string]bool{}},
	}
	for _, c := range cases {
		if got := parseDisabledComponents([]byte(c.body)); !reflect.DeepEqual(got, c.want) {
			t.Errorf("%s: parseDisabledComponents(%q) = %v, want %v", c.name, c.body, got, c.want)
		}
	}
}

func TestComponentDisabled(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "ryoku", "performance.json"),
		[]byte(`{"disabledComponents":["overview","pill"]}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if !componentDisabled("overview") {
		t.Error("overview listed -> should be disabled")
	}
	if componentDisabled("launcher") {
		t.Error("launcher not listed -> should be enabled")
	}
	if componentDisabled("pill") {
		t.Error("pill must never be disabled, even when listed")
	}
}

func TestComponentDisabledMissingFile(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir()) // no performance.json in it
	if componentDisabled("overview") {
		t.Error("a missing performance.json must disable nothing")
	}
}
