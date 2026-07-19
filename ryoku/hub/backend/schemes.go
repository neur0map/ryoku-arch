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

// writePalette authors the shell's own palette (the cache colors.json every
// Quickshell singleton reads) and hands that same palette to matugen, which
// renders every external app config from it.
func writePalette(pal map[string]string) {
	_ = os.MkdirAll(wallustCacheDir(), 0o755)
	_ = atomicWrite(filepath.Join(wallustCacheDir(), "colors.json"), mustJSON(pal), 0o644)
	renderApps(pal)
}

// renderApps runs matugen in json (templating-only) mode over the palette, the
// one engine that fans it into kitty, Hyprland borders, GTK, Qt, and btop from
// the templates deployed under ~/.config/matugen. Passthrough keeps every
// colour byte-exact; only .hex resolves in this mode, so Qt's ARGB roles read
// the pre-formatted *_argb keys the carrier carries beside the plain colours.
func renderApps(pal map[string]string) {
	carrier := map[string]any{"colors": paletteCarrier(pal)}
	cacheDir := filepath.Join(cacheHome(), "ryoku")
	_ = os.MkdirAll(cacheDir, 0o755)
	carrierPath := filepath.Join(cacheDir, "matugen-carrier.json")
	if err := atomicWrite(carrierPath, mustJSON(carrier), 0o644); err != nil {
		return
	}
	cfg := filepath.Join(configHome(), "matugen", "config.toml")
	if out, err := exec.Command("matugen", "-c", cfg, "json", carrierPath).CombinedOutput(); err != nil {
		fmt.Fprintf(os.Stderr, "matugen: %v: %s\n", err, out)
	}
}

// paletteCarrier shapes the palette into matugen's json input: each colour as
// colors.<name>.default.hex, plus a colors.<name>_argb.default.hex variant
// (#aarrggbb) for Qt's palette roles, plus cursor mirrored from the foreground.
func paletteCarrier(pal map[string]string) map[string]any {
	c := map[string]any{}
	put := func(name, hex string) {
		c[name] = map[string]any{"default": map[string]any{"hex": hex}}
	}
	for k, v := range pal {
		put(k, v)
		put(k+"_argb", "#ff"+strings.TrimPrefix(v, "#"))
	}
	put("cursor", pal["foreground"])
	return c
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
		// GTK apps re-read gtk.css when the colour-scheme preference flips; pin
		// light/dark so libadwaita picks the freshly rendered palette up.
		gtkScheme := "prefer-dark"
		if mode == "light" {
			gtkScheme = "prefer-light"
		}
		_ = exec.Command("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", gtkScheme).Run()
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

func cacheHome() string {
	if b := os.Getenv("XDG_CACHE_HOME"); b != "" {
		return b
	}
	return filepath.Join(os.Getenv("HOME"), ".cache")
}

func mustJSON(v any) []byte {
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return []byte("{}")
	}
	return b
}
