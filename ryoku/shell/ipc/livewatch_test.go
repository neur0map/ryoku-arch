package main

import "testing"

// Only a real fullscreen hides the wallpaper. Hyprland reports a mode here:
// 0 none, 1 maximised, 2 fullscreen, and a maximised window still leaves the
// bars and the desktop edges showing.
func TestParseAnyFullscreen(t *testing.T) {
	cases := []struct {
		name string
		json string
		want bool
	}{
		{"nothing fullscreen", `[{"fullscreen":0},{"fullscreen":0}]`, false},
		{"maximised is not fullscreen", `[{"fullscreen":1}]`, false},
		{"one fullscreen", `[{"fullscreen":0},{"fullscreen":2}]`, true},
		{"older bool form", `[{"fullscreen":true}]`, true},
		{"older bool form, false", `[{"fullscreen":false}]`, false},
		{"no clients", `[]`, false},
		{"garbage keeps the wallpaper running", `not json`, false},
	}
	for _, c := range cases {
		if got := parseAnyFullscreen([]byte(c.json)); got != c.want {
			t.Errorf("%s: got %v want %v", c.name, got, c.want)
		}
	}
}
