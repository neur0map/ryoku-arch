package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
)

// themes = full-system "rices", one folder each under
// ~/.config/hypr/themes/<slug>/:
//   theme.json    metadata + the look (appearance store values).
//   init.lua      real Hyprland Lua loaded as the active theme. motion design
//                 (bezier curves, per-leaf animation feel) + the decoration
//                 nuances the store can't express (rounding power, blur
//                 vibrancy, shadow). the "actual system change", not only
//                 colours.
//   colors.json   the 16-colour palette, used only when colours don't follow
//                 the wallpaper.
//
// applying a theme: the look folds into the appearance store (so the Look /
// Borders tabs reflect it), init.lua is copied to ~/.config/hypr/theme.lua
// (loaded by hyprland.lua after the base modules and before settings.lua, so a
// user knob still wins), palette goes per the colour-source toggle. that
// toggle is global, independent of the theme: colours either track the
// wallpaper (wallust) or use the theme's fixed palette. the shell frame +
// island keep the Ryoku look.

// ThemeFile = themes/<slug>/theme.json.
type ThemeFile struct {
	Name       string          `json:"name"`
	Blurb      string          `json:"blurb"`
	Summary    string          `json:"summary"`
	Tags       []string        `json:"tags"`
	Accent     string          `json:"accent"`
	Swatch     []string        `json:"swatch"`
	HasPalette bool            `json:"hasPalette"`
	Look       json.RawMessage `json:"look"`
}

// ThemeListItem: GUI-facing summary (no look payload).
type ThemeListItem struct {
	Slug    string   `json:"slug"`
	Name    string   `json:"name"`
	Blurb   string   `json:"blurb"`
	Summary string   `json:"summary"`
	Tags    []string `json:"tags"`
	Accent  string   `json:"accent"`
	Swatch  []string `json:"swatch"`
	Active  bool     `json:"active"`
}

// ThemesResponse = `ryoku-hub hypr themes`: colour-source toggle + the list.
type ThemesResponse struct {
	FollowWallpaper bool            `json:"followWallpaper"`
	Themes          []ThemeListItem `json:"themes"`
}

type themeState struct {
	Slug            string `json:"slug"`
	FollowWallpaper bool   `json:"followWallpaper"`
	Scheme          string `json:"scheme,omitempty"`
}

func themesDir() string          { return filepath.Join(hyprConfigDir(), "themes") }
func activeThemeLuaPath() string { return filepath.Join(hyprConfigDir(), "theme.lua") }

func wallustCacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	return filepath.Join(base, "wallust")
}

func kittyThemePath() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(base, "kitty", "current-theme.conf")
}

func themeStatePath() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(base, "ryoku", "theme.json")
}

func wallpaperStatePath() string {
	base := os.Getenv("XDG_STATE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".local", "state")
	}
	return filepath.Join(base, "ryoku-wallpaper")
}

// loadThemeState defaults FollowWallpaper=true on a missing/blank file (the
// shipped behaviour: colours track the wallpaper).
func loadThemeState() themeState {
	s := themeState{FollowWallpaper: true}
	if b, err := os.ReadFile(themeStatePath()); err == nil {
		_ = json.Unmarshal(b, &s)
	}
	return s
}

func saveThemeState(s themeState) {
	_ = atomicWrite(themeStatePath(), mustJSON(s), 0o644)
}

func loadThemeFile(slug string) (ThemeFile, error) {
	var t ThemeFile
	if slug == "" {
		return t, fmt.Errorf("no theme")
	}
	b, err := os.ReadFile(filepath.Join(themesDir(), slug, "theme.json"))
	if err != nil {
		return t, err
	}
	return t, json.Unmarshal(b, &t)
}

func listThemes() ThemesResponse {
	st := loadThemeState()
	entries, _ := os.ReadDir(themesDir())
	items := []ThemeListItem{}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		t, err := loadThemeFile(e.Name())
		if err != nil {
			continue
		}
		items = append(items, ThemeListItem{
			Slug: e.Name(), Name: t.Name, Blurb: t.Blurb, Summary: t.Summary,
			Tags: t.Tags, Accent: t.Accent, Swatch: t.Swatch, Active: e.Name() == st.Slug,
		})
	}
	sort.Slice(items, func(i, j int) bool { return items[i].Name < items[j].Name })
	return ThemesResponse{FollowWallpaper: st.FollowWallpaper, Themes: items}
}

// applyTheme: set the look store, install the theme's init.lua, apply the
// palette per the current colour-source toggle, reload.
func applyTheme(slug string) error {
	dir := filepath.Join(themesDir(), slug)
	tf, err := loadThemeFile(slug)
	if err != nil {
		return fmt.Errorf("theme %q: %w", slug, err)
	}

	o := loadOverrides()
	app := defaultOverrides().Appearance
	if len(tf.Look) > 0 {
		if err := json.Unmarshal(tf.Look, &app); err != nil {
			return fmt.Errorf("theme %q look: %w", slug, err)
		}
	}
	o.Appearance = app
	if err := saveOverrides(o); err != nil {
		return err
	}
	if err := writeGeneratedLua(o); err != nil {
		return err
	}

	// real-Lua layer: motion + decoration nuances.
	if init, err := os.ReadFile(filepath.Join(dir, "init.lua")); err == nil {
		_ = atomicWrite(activeThemeLuaPath(), init, 0o644)
	} else {
		_ = atomicWrite(activeThemeLuaPath(), []byte("-- "+slug+": no extra Lua\n"), 0o644)
	}

	st := loadThemeState()
	st.Slug = slug
	st.Scheme = ""
	saveThemeState(st)
	applyPalette(dir, st.FollowWallpaper, tf.HasPalette)

	hyprReload()
	_ = exec.Command("pkill", "-USR1", "-x", "kitty").Run()
	return nil
}

// setFollowWallpaper flips the colour source and reapplies the palette for the
// active theme.
func setFollowWallpaper(follow bool) error {
	st := loadThemeState()
	st.FollowWallpaper = follow
	st.Scheme = ""
	saveThemeState(st)
	hasPalette := false
	dir := ""
	if st.Slug != "" {
		dir = filepath.Join(themesDir(), st.Slug)
		if tf, err := loadThemeFile(st.Slug); err == nil {
			hasPalette = tf.HasPalette
		}
	}
	applyPalette(dir, follow, hasPalette)
	hyprReload()
	_ = exec.Command("pkill", "-USR1", "-x", "kitty").Run()
	return nil
}

// applyPalette writes the wallust dsts every consumer reads. follow-wallpaper
// (or a theme with no palette) re-derives them via wallust; otherwise the
// theme's fixed palette is written and the wallpaper lock keeps it.
func applyPalette(dir string, follow, hasPalette bool) {
	if follow || !hasPalette || dir == "" {
		if pic := currentWallpaper(); pic != "" {
			_ = exec.Command("wallust", "run", pic).Run()
		}
		return
	}
	pal, err := loadPalette(filepath.Join(dir, "colors.json"))
	if err != nil {
		return
	}
	writePalette(pal)
}

// paletteAccent = the active-border colour: color4 by wallust convention.
func paletteAccent(p map[string]string) string {
	if c := p["color4"]; c != "" {
		return c
	}
	return p["foreground"]
}

func loadPalette(path string) (map[string]string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var m map[string]string
	if err := json.Unmarshal(b, &m); err != nil {
		return nil, err
	}
	return m, nil
}

// renderKitty fills kitty's current-theme.conf from the palette (cursor =
// foreground), matches the wallust kitty template.
func renderKitty(p map[string]string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "background %s\n", p["background"])
	fmt.Fprintf(&b, "foreground %s\n", p["foreground"])
	fmt.Fprintf(&b, "cursor %s\n", p["foreground"])
	fmt.Fprintf(&b, "cursor_text_color %s\n", p["background"])
	fmt.Fprintf(&b, "selection_background %s\n", p["color8"])
	fmt.Fprintf(&b, "selection_foreground %s\n", p["foreground"])
	for i := 0; i < 16; i++ {
		key := fmt.Sprintf("color%d", i)
		fmt.Fprintf(&b, "%s %s\n", key, p[key])
	}
	return b.String()
}

func currentWallpaper() string {
	b, err := os.ReadFile(wallpaperStatePath())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func mustJSON(v any) []byte {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return []byte("{}")
	}
	return b
}
