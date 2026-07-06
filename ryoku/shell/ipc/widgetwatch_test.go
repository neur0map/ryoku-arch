package main

import "testing"

func TestParsePerfFlag(t *testing.T) {
	cases := []struct {
		name string
		body string
		key  string
		want bool
	}{
		{"true", `{"unloadWidgetsWhenCovered":true}`, "unloadWidgetsWhenCovered", true},
		{"false", `{"unloadWidgetsWhenCovered":false}`, "unloadWidgetsWhenCovered", false},
		{"other key", `{"freezeVisualizerWhenIdle":true}`, "unloadWidgetsWhenCovered", false},
		{"absent", `{}`, "unloadVisualizerWhenSilent", false},
		{"malformed", `not json`, "x", false},
		{"empty", ``, "x", false},
		{"wrong type", `{"x":"yes"}`, "x", false},
		{"visualiser key", `{"unloadVisualizerWhenSilent":true}`, "unloadVisualizerWhenSilent", true},
	}
	for _, c := range cases {
		if got := parsePerfFlag([]byte(c.body), c.key); got != c.want {
			t.Errorf("%s: parsePerfFlag(%q,%q) = %v, want %v", c.name, c.body, c.key, got, c.want)
		}
	}
}

func TestParseDesktopVisible(t *testing.T) {
	cases := []struct {
		name string
		mons string
		wss  string
		want bool
	}{
		{
			"single empty workspace is visible",
			`[{"name":"eDP-1","activeWorkspace":{"id":1,"name":"1"}}]`,
			`[{"id":1,"name":"1","windows":0}]`,
			true,
		},
		{
			"single covered workspace is hidden",
			`[{"name":"eDP-1","activeWorkspace":{"id":1,"name":"1"}}]`,
			`[{"id":1,"name":"1","windows":2}]`,
			false,
		},
		{
			"one of two monitors empty is visible",
			`[{"activeWorkspace":{"id":1}},{"activeWorkspace":{"id":2}}]`,
			`[{"id":1,"windows":3},{"id":2,"windows":0}]`,
			true,
		},
		{
			"all monitors covered is hidden",
			`[{"activeWorkspace":{"id":1}},{"activeWorkspace":{"id":2}}]`,
			`[{"id":1,"windows":3},{"id":2,"windows":1}]`,
			false,
		},
		{"malformed monitors stays visible", `nope`, `[{"id":1,"windows":2}]`, true},
		{"malformed workspaces stays visible", `[{"activeWorkspace":{"id":1}}]`, `nope`, true},
		{"no monitors stays visible", `[]`, `[{"id":1,"windows":2}]`, true},
		{"unknown active workspace stays visible", `[{"activeWorkspace":{"id":9}}]`, `[{"id":1,"windows":2}]`, true},
	}
	for _, c := range cases {
		if got := parseDesktopVisible([]byte(c.mons), []byte(c.wss)); got != c.want {
			t.Errorf("%s: parseDesktopVisible = %v, want %v", c.name, got, c.want)
		}
	}
}

func TestAffectsCoverage(t *testing.T) {
	relevant := []string{
		"openwindow>>0x1,1,kitty,kitty",
		"closewindow>>0x1",
		"movewindowv2>>0x1,2,2",
		"workspacev2>>2,2",
		"workspace>>2",
		"focusedmonv2>>eDP-1,2",
		"monitoradded>>HDMI-A-1",
		"monitorremoved>>HDMI-A-1",
	}
	irrelevant := []string{
		"activewindow>>kitty,kitty",
		"activelayout>>keyboard,layout",
		"submap>>resize",
		"",
	}
	for _, l := range relevant {
		if !affectsCoverage(l) {
			t.Errorf("affectsCoverage(%q) = false, want true", l)
		}
	}
	for _, l := range irrelevant {
		if affectsCoverage(l) {
			t.Errorf("affectsCoverage(%q) = true, want false", l)
		}
	}
}
