package main

import (
	"os"
	"path/filepath"
	"testing"
)

// currentScheme must report "follow" whenever the wallpaper is being followed,
// even when theme.json omits the scheme key (the exact state the Appearance
// control persists when you pick Follow). Regression guard for the bug where the
// "mono" default filled the omitted key and the scheme check ran before the
// follow check, so Follow silently reverted to Mono on the next read.
func TestCurrentSchemeReportsFollow(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	tp := filepath.Join(dir, "ryoku", "theme.json")
	if err := os.MkdirAll(filepath.Dir(tp), 0o755); err != nil {
		t.Fatal(err)
	}
	cases := []struct{ name, file, want string }{
		{"follow, scheme key omitted", `{"followWallpaper":true}`, "follow"},
		{"follow, empty scheme", `{"followWallpaper":true,"scheme":""}`, "follow"},
		{"locked mono", `{"followWallpaper":false,"scheme":"mono"}`, "mono"},
		{"locked light", `{"followWallpaper":false,"scheme":"light"}`, "light"},
		{"locked dark", `{"followWallpaper":false,"scheme":"dark"}`, "dark"},
	}
	for _, c := range cases {
		if err := os.WriteFile(tp, []byte(c.file), 0o644); err != nil {
			t.Fatal(err)
		}
		if got := currentScheme(); got != c.want {
			t.Errorf("%s: currentScheme() = %q, want %q", c.name, got, c.want)
		}
	}

	// a missing file is a fresh box: the shipped grainy-mono default.
	os.Remove(tp)
	if got := currentScheme(); got != "mono" {
		t.Errorf("missing file: currentScheme() = %q, want mono", got)
	}
}

// The follow state must survive a save/load round-trip: writing FollowWallpaper
// with an empty scheme and reading it back must still resolve to "follow", not
// the default mono.
func TestSchemeFollowRoundTrips(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	saveThemeState(themeState{FollowWallpaper: true, Scheme: ""})
	if got := currentScheme(); got != "follow" {
		t.Errorf("follow round-trip: currentScheme() = %q, want follow", got)
	}
}
