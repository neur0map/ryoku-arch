package main

import (
	"embed"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

//go:embed schemes/light.json schemes/dark.json schemes/mono.json
var schemesFS embed.FS

// loadScheme returns a curated fixed palette (light or dark) baked into the
// binary: the desktop's "set it light / set it dark" presets.
func loadScheme(mode string) (map[string]string, error) {
	b, err := schemesFS.ReadFile("schemes/" + mode + ".json")
	if err != nil {
		return nil, err
	}
	var m map[string]string
	return m, json.Unmarshal(b, &m)
}

// writePalette writes the wallust outputs every consumer reads (the cache
// colors.json, the hypr border colours, the kitty theme) from a fixed palette.
func writePalette(pal map[string]string) {
	_ = os.MkdirAll(wallustCacheDir(), 0o755)
	_ = atomicWrite(filepath.Join(wallustCacheDir(), "colors.json"), mustJSON(pal), 0o644)
	_ = atomicWrite(filepath.Join(wallustCacheDir(), "hypr-colors.lua"),
		[]byte(fmt.Sprintf("return {\n    active = %q,\n    inactive = %q,\n}\n", paletteAccent(pal), pal["background"])), 0o644)
	_ = atomicWrite(kittyThemePath(), []byte(renderKitty(pal)), 0o644)
}

// currentScheme reports the active palette mode for the UI: light/dark when a
// curated preset is locked, follow when colours track the wallpaper, custom when
// a theme owns its own fixed palette.
func currentScheme() string {
	st := loadThemeState()
	if st.Scheme == "light" || st.Scheme == "dark" || st.Scheme == "mono" {
		return st.Scheme
	}
	if st.FollowWallpaper {
		return "follow"
	}
	return "custom"
}

// applyScheme sets the desktop palette mode. follow re-derives from the current
// wallpaper (the reset); light/dark lock a curated preset that survives wallpaper
// changes (themePaletteLocked keeps it). Reused by the Appearance control.
func applyScheme(mode string) error {
	st := loadThemeState()
	switch mode {
	case "follow":
		st.Scheme = ""
		st.FollowWallpaper = true
		saveThemeState(st)
		// borders read the master: regen so they follow the wallpaper again.
		if err := writeGeneratedLua(loadOverrides()); err != nil {
			return err
		}
		// the daemon derives (honouring the per-image tune); no re-animation.
		_ = exec.Command("ryoku-shell", "wallpaper", "repaint").Run()
	case "light", "dark", "mono":
		pal, err := loadScheme(mode)
		if err != nil {
			return err
		}
		st.Scheme = mode
		st.FollowWallpaper = false
		saveThemeState(st)
		// borders read the master: regen so the fixed border colours pin now,
		// not only on the next appearance save.
		if err := writeGeneratedLua(loadOverrides()); err != nil {
			return err
		}
		writePalette(pal)
	default:
		return fmt.Errorf("unknown scheme %q (want follow|light|dark|mono)", mode)
	}
	hyprReload()
	_ = exec.Command("pkill", "-USR1", "-x", "kitty").Run()
	return nil
}

// themeState persists the palette master: whether colours track the wallpaper
// (wallust) and, when they don't, which curated scheme is locked. Lives at
// ~/.config/ryoku/theme.json.
type themeState struct {
	FollowWallpaper bool   `json:"followWallpaper"`
	Scheme          string `json:"scheme,omitempty"`
}

func themeStatePath() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(base, "ryoku", "theme.json")
}

// loadThemeState defaults to the shipped grainy-mono preset on a missing or
// blank file; an existing file (a user who picked follow or a scheme) wins.
func loadThemeState() themeState {
	s := themeState{FollowWallpaper: false, Scheme: "mono"}
	if b, err := os.ReadFile(themeStatePath()); err == nil {
		_ = json.Unmarshal(b, &s)
	}
	return s
}

func saveThemeState(s themeState) {
	_ = atomicWrite(themeStatePath(), mustJSON(s), 0o644)
}

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

// paletteAccent = the active-border colour: color4 by wallust convention.
func paletteAccent(p map[string]string) string {
	if c := p["color4"]; c != "" {
		return c
	}
	return p["foreground"]
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
	for i := range 16 {
		key := fmt.Sprintf("color%d", i)
		fmt.Fprintf(&b, "%s %s\n", key, p[key])
	}
	return b.String()
}

func mustJSON(v any) []byte {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return []byte("{}")
	}
	return b
}
