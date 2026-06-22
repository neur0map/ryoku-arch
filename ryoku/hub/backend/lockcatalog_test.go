package main

import (
	"strings"
	"testing"
)

func TestParseQylockTree(t *testing.T) {
	js := `{"truncated":false,"tree":[
		{"path":"Assets/clockwork.gif","type":"blob","size":1000},
		{"path":"Assets/forest.gif","type":"blob","size":2000},
		{"path":"Assets/title.png","type":"blob","size":10},
		{"path":"themes","type":"tree","size":0},
		{"path":"themes/clockwork/orbital/Main.qml","type":"blob","size":100},
		{"path":"themes/clockwork/orbital/theme.conf","type":"blob","size":50},
		{"path":"themes/clockwork/tape/Main.qml","type":"blob","size":120},
		{"path":"themes/forest/Main.qml","type":"blob","size":80},
		{"path":"themes/forest/bg.mp4","type":"blob","size":5242880},
		{"path":"README.md","type":"blob","size":10}
	]}`
	tree, err := parseQylockTree([]byte(js))
	if err != nil {
		t.Fatal(err)
	}
	wantThemes := []string{"clockwork/orbital", "clockwork/tape", "forest"}
	if strings.Join(tree.Themes, ",") != strings.Join(wantThemes, ",") {
		t.Fatalf("themes = %v, want %v", tree.Themes, wantThemes)
	}
	if !tree.Gifs["clockwork"] || !tree.Gifs["forest"] || len(tree.Gifs) != 2 {
		t.Fatalf("gifs = %v", tree.Gifs)
	}
	if len(tree.Files["clockwork/orbital"]) != 2 {
		t.Errorf("orbital files = %v, want 2", tree.Files["clockwork/orbital"])
	}
	// forest's video background dominates its install weight.
	if tree.SizeKB["forest"] < 5000 {
		t.Errorf("forest sizeKB = %d, want >= 5000", tree.SizeKB["forest"])
	}
	if tree.SizeKB["clockwork/orbital"] != 0 {
		t.Errorf("orbital sizeKB = %d, want 0 (150 bytes rounds down)", tree.SizeKB["clockwork/orbital"])
	}
}

func TestMapThemeGif(t *testing.T) {
	gifs := map[string]bool{
		"clockwork": true, "nier_automata": true, "pixel_coffee": true,
		"the_last_of_us": true, "win7": true, "material-you": true,
	}
	cases := map[string]string{
		"clockwork/orbital": "clockwork",     // nested variant -> top-level gif
		"clockwork/tape":    "clockwork",     // both variants share it
		"nier-automata":     "nier_automata", // hyphen vs underscore
		"pixel-coffee":      "pixel_coffee",
		"material-you":      "material-you",
		"last-of-us":        "the_last_of_us", // alias
		"windows_7":         "win7",           // alias
	}
	for slug, want := range cases {
		got, ok := mapThemeGif(slug, gifs)
		if !ok || got != want {
			t.Errorf("mapThemeGif(%q) = %q,%v; want %q,true", slug, got, ok, want)
		}
	}
	if _, ok := mapThemeGif("ghost-theme", gifs); ok {
		t.Errorf("mapThemeGif(ghost-theme) should not match")
	}
}

func TestLockSkinNameAndTags(t *testing.T) {
	names := map[string]string{
		"pixel-coffee":      "Pixel Coffee",
		"nier-automata":     "Nier Automata",
		"windows_7":         "Windows 7",
		"clockwork/orbital": "Orbital",
		"forest":            "Forest",
	}
	for slug, want := range names {
		if got := lockSkinName(slug); got != want {
			t.Errorf("lockSkinName(%q) = %q, want %q", slug, got, want)
		}
	}
	tags := map[string]string{
		"clockwork/orbital": "Clockwork",
		"pixel-coffee":      "Pixel",
		"R1999_1":           "Reverse 1999",
		"forest":            "",
	}
	for slug, want := range tags {
		got := lockSkinTags(slug)
		first := ""
		if len(got) > 0 {
			first = got[0]
		}
		if first != want {
			t.Errorf("lockSkinTags(%q) = %v, want first %q", slug, got, want)
		}
	}
}

func TestBuildLockCatalog(t *testing.T) {
	t.Setenv("RYOKU_QYLOCK_RAW", "https://example.test")
	dir := t.TempDir()
	mkSkin(t, dir, "clockwork/orbital", true) // installed, ships a local preview.gif
	mkSkin(t, dir, "clockwork/tape", false)   // installed, no local preview.gif

	tree := qylockTree{
		Themes: []string{"clockwork/orbital", "clockwork/tape", "forest"},
		Gifs:   map[string]bool{"clockwork": true, "forest": true},
		SizeKB: map[string]int{"forest": 5120},
	}
	resp := buildLockCatalog(tree, dir, "clockwork/orbital")

	if !resp.Online {
		t.Errorf("catalog from a tree should be online")
	}
	if len(resp.Skins) != 3 {
		t.Fatalf("got %d skins, want 3", len(resp.Skins))
	}
	// Sort order: active, then installed, then the rest.
	order := []string{resp.Skins[0].Slug, resp.Skins[1].Slug, resp.Skins[2].Slug}
	want := []string{"clockwork/orbital", "clockwork/tape", "forest"}
	if strings.Join(order, ",") != strings.Join(want, ",") {
		t.Fatalf("order = %v, want %v", order, want)
	}

	orb, tape, forest := resp.Skins[0], resp.Skins[1], resp.Skins[2]
	if !orb.Active || !orb.Installed || !strings.HasPrefix(orb.Preview, "file://") {
		t.Errorf("orbital: active/installed/local-preview wrong: %+v", orb)
	}
	if tape.Active || !tape.Installed {
		t.Errorf("tape: should be installed and inactive: %+v", tape)
	}
	// Tape has no local preview.gif, so it falls back to the upstream clockwork gif.
	if tape.Preview != "https://example.test/Darkkal44/qylock/main/Assets/clockwork.gif" {
		t.Errorf("tape preview = %q, want upstream clockwork gif", tape.Preview)
	}
	if forest.Installed || forest.Active {
		t.Errorf("forest should be neither installed nor active: %+v", forest)
	}
	if forest.Preview != "https://example.test/Darkkal44/qylock/main/Assets/forest.gif" {
		t.Errorf("forest preview = %q, want upstream forest gif", forest.Preview)
	}
	if forest.SizeKB != 5120 {
		t.Errorf("forest sizeKB = %d, want 5120", forest.SizeKB)
	}
}
