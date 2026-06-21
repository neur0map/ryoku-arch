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

// Themes are full-system "rices", each its own folder under ~/.config/hypr/themes/
// <slug>/:
//   - theme.json   metadata + the look (the appearance store values).
//   - init.lua     real Hyprland Lua loaded as the active theme: the motion design
//                  (bezier curves, per-leaf animation feel) and the decoration
//                  nuances the store cannot express (rounding power, blur vibrancy,
//                  shadow). This is the "actual system change", not just colours.
//   - colors.json  the 16-colour palette, used only when colours do not follow the
//                  wallpaper.
//
// Applying a theme: the look folds onto the appearance store (so the Look/Borders
// tabs reflect it), init.lua is copied to ~/.config/hypr/theme.lua (loaded by
// hyprland.lua after the base modules and before settings.lua, so a user knob still
// wins), and the palette is set per the colour-source toggle. The toggle is global
// and independent of the theme: colours either track the wallpaper (wallust) or use
// the theme's fixed palette. The shell frame and island keep the Ryoku identity.

// ThemeFile is themes/<slug>/theme.json.
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

// ThemeListItem is the GUI-facing summary (no look payload).
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

// ThemesResponse is `ryoku-hub hypr themes`: the colour-source toggle plus the list.
type ThemesResponse struct {
	FollowWallpaper bool            `json:"followWallpaper"`
	Themes          []ThemeListItem `json:"themes"`
}

type themeState struct {
	Slug            string `json:"slug"`
	FollowWallpaper bool   `json:"followWallpaper"`
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

// loadThemeState defaults FollowWallpaper to true on a missing/blank file (the
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

// applyTheme sets the look store, installs the theme's init.lua, applies the
// palette per the current colour-source toggle, and reloads.
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
	app.FollowWallpaper = true // borders come from the wallust palette, set below
	o.Appearance = app
	if err := saveOverrides(o); err != nil {
		return err
	}
	if err := writeGeneratedLua(o); err != nil {
		return err
	}

	// The real-Lua layer: motion + decoration nuances.
	if init, err := os.ReadFile(filepath.Join(dir, "init.lua")); err == nil {
		_ = atomicWrite(activeThemeLuaPath(), init, 0o644)
	} else {
		_ = atomicWrite(activeThemeLuaPath(), []byte("-- "+slug+": no extra Lua\n"), 0o644)
	}

	st := loadThemeState()
	st.Slug = slug
	saveThemeState(st)
	applyPalette(dir, st.FollowWallpaper, tf.HasPalette)

	hyprReload()
	_ = exec.Command("pkill", "-USR1", "-x", "kitty").Run()
	return nil
}

// setFollowWallpaper flips the colour source and re-applies the palette for the
// active theme.
func setFollowWallpaper(follow bool) error {
	st := loadThemeState()
	st.FollowWallpaper = follow
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

// applyPalette writes the wallust dsts every consumer reads. Following the
// wallpaper (or a theme with no palette) re-derives them with wallust; otherwise
// the theme's fixed palette is written and the wallpaper lock keeps it.
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
	_ = os.MkdirAll(wallustCacheDir(), 0o755)
	_ = atomicWrite(filepath.Join(wallustCacheDir(), "colors.json"), mustJSON(pal), 0o644)
	_ = atomicWrite(filepath.Join(wallustCacheDir(), "hypr-colors.lua"),
		[]byte(fmt.Sprintf("return {\n    active = %q,\n    inactive = %q,\n}\n", paletteAccent(pal), pal["background"])), 0o644)
	_ = atomicWrite(kittyThemePath(), []byte(renderKitty(pal)), 0o644)
}

// paletteAccent is the active-border colour: color4 by wallust convention.
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

// renderKitty fills kitty's current-theme.conf from the palette (cursor follows
// the foreground), matching the wallust kitty template.
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
