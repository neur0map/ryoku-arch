package main

import (
	"embed"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

//go:embed schemes/light.json schemes/dark.json
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
	if st.Scheme == "light" || st.Scheme == "dark" {
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
		// through ryoku-shell so the derive honours the ryowalls palette tune,
		// matching a normal wallpaper change instead of a bare wallust run.
		if pic := currentWallpaper(); pic != "" {
			_ = exec.Command("ryoku-shell", "wallpaper", "set", pic).Run()
		}
	case "light", "dark":
		pal, err := loadScheme(mode)
		if err != nil {
			return err
		}
		st.Scheme = mode
		st.FollowWallpaper = false
		saveThemeState(st)
		writePalette(pal)
	default:
		return fmt.Errorf("unknown scheme %q (want follow|light|dark)", mode)
	}
	hyprReload()
	_ = exec.Command("pkill", "-USR1", "-x", "kitty").Run()
	return nil
}
