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
// one engine that fans it into the app configs from the templates deployed
// under ~/.config/matugen. config.toml is the core surface (kitty, Hyprland
// borders, btop, Qt) and always renders; apps.toml is the GTK / GUI-app reach,
// rendered only when "Theme apps" is on (else the GTK stylesheets are blanked
// so those apps fall back to stock). Passthrough keeps every colour byte-exact;
// only .hex resolves in this mode, so Qt's ARGB roles read the pre-formatted
// *_argb keys the carrier carries beside the plain colours.
func renderApps(pal map[string]string) {
	carrier := map[string]any{"colors": paletteCarrier(pal)}
	cacheDir := filepath.Join(cacheHome(), "ryoku")
	_ = os.MkdirAll(cacheDir, 0o755)
	carrierPath := filepath.Join(cacheDir, "matugen-carrier.json")
	if err := atomicWrite(carrierPath, mustJSON(carrier), 0o644); err != nil {
		return
	}
	for _, dir := range []string{
		filepath.Join(configHome(), "kitty"),
		filepath.Join(cacheHome(), "wallust"),
		filepath.Join(configHome(), "btop", "themes"),
		filepath.Join(configHome(), "qt6ct", "colors"),
		filepath.Join(configHome(), "gtk-3.0"),
		filepath.Join(configHome(), "gtk-4.0"),
	} {
		_ = os.MkdirAll(dir, 0o755)
	}
	matugenDir := filepath.Join(configHome(), "matugen")
	runMatugen(filepath.Join(matugenDir, "config.toml"), carrierPath)
	if themeAppsOn(loadThemeState()) {
		runMatugen(filepath.Join(matugenDir, "apps.toml"), carrierPath)
	} else {
		blankGtk()
	}
}

func runMatugen(cfg, carrier string) {
	if out, err := exec.Command("matugen", "-c", cfg, "json", carrier).CombinedOutput(); err != nil {
		fmt.Fprintf(os.Stderr, "matugen: %v: %s\n", err, out)
	}
}

// themeAppsOn reports whether the palette should reach GTK / GUI apps. A theme
// state without the key (an older theme.json) reads as on, so existing installs
// keep the themed apps they already had.
func themeAppsOn(s themeState) bool { return s.ThemeApps == nil || *s.ThemeApps }

// gtkOff is written to the generated GTK stylesheets when app theming is off, so
// GTK / libadwaita apps drop the Ryoku palette and use their own stock colours.
const gtkOff = "/* Ryoku: app theming is off; apps use their own colours. */\n"

func blankGtk() {
	for _, rel := range []string{"gtk-3.0/gtk.css", "gtk-4.0/gtk.css"} {
		p := filepath.Join(configHome(), rel)
		_ = os.MkdirAll(filepath.Dir(p), 0o755)
		_ = atomicWrite(p, []byte(gtkOff), 0o644)
	}
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

// currentThemeApps reports the app-theming toggle for the UI.
func currentThemeApps() bool { return themeAppsOn(loadThemeState()) }

// applyThemeApps sets whether the palette reaches GTK / GUI apps and re-fans the
// live palette at once, so the toggle takes hold without a wallpaper change or a
// scheme flip. renderApps honours the new flag (renders the GTK templates, or
// blanks them); nudgeGtk then asks already-open GTK apps to re-read.
func applyThemeApps(on bool) error {
	st := loadThemeState()
	st.ThemeApps = &on
	saveThemeState(st)
	if pal := readPalette(filepath.Join(wallustCacheDir(), "colors.json")); pal != nil {
		renderApps(pal)
	} else if !on {
		blankGtk()
	}
	nudgeGtk()
	return nil
}

// nudgeGtk forces already-open GTK / libadwaita apps to re-read the stylesheet
// by flipping the GTK theme name off and back, the standard live-reload signal.
func nudgeGtk() {
	out, err := exec.Command("gsettings", "get", "org.gnome.desktop.interface", "gtk-theme").Output()
	if err != nil {
		return
	}
	name := strings.Trim(strings.TrimSpace(string(out)), "'")
	if name == "" {
		return
	}
	_ = exec.Command("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "").Run()
	_ = exec.Command("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", name).Run()
}

// themeState persists the palette master: whether colours track the wallpaper
// (wallust) and, when they don't, which curated scheme is locked. Lives at
// ~/.config/ryoku/theme.json.
type themeState struct {
	FollowWallpaper bool   `json:"followWallpaper"`
	Scheme          string `json:"scheme,omitempty"`
	ThemeApps       *bool  `json:"themeApps,omitempty"`
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

// applyRyokuTheme resets the desktop to the Ryoku signature in one move: the
// stele bar, square corners everywhere, Space Grotesk type across the shell and
// apps, and the grainy-mono palette. Wired to the "Ryoku theme" button on the
// Appearance and Rices pages so a drifted look returns in one click.
func applyRyokuTheme() error {
	// the signature look in shell.json, merged so the user's sizing, weather,
	// sidebar panes and other choices survive.
	mergeShellJSON(map[string]any{
		"barStyle":          "stele",
		"roundness":         0,
		"islandRadius":      0,
		"frameRadius":       0,
		"osdRadius":         0,
		"sidebarCornerSize": 0,
		"fontFamily":        "Space Grotesk",
	})
	// square window corners: pin the appearance override the daemon reads.
	o := loadOverrides()
	o.Appearance.Rounding = 0
	_ = saveOverrides(o)
	// GTK type now; the Hyprland autostart pins it on the next login.
	_ = exec.Command("gsettings", "set", "org.gnome.desktop.interface", "font-name", "Space Grotesk 11").Run()
	// clear any active-rice marker: the signature is a fresh look, not a rice,
	// so the Rices page must not keep showing the last rice as applied.
	setActiveRice("")
	// the Ryoku mark: the 力 glyph, no custom logo, tinted to the accent, so the
	// signature brand reads as Ryoku (the desktop name is left as the user set it).
	mergeBrandJSON(map[string]any{"markText": "力", "markImage": "", "markTint": true})
	// grainy-mono palette + regen the border lua, reload hypr and kitty.
	return applyScheme("mono")
}

// mergeShellJSON overlays keys onto shell.json, mergeBrandJSON onto brand.json;
// both preserve every key already present, and the shell hot-reloads on write.
func mergeShellJSON(keys map[string]any) { mergeStore("shell.json", keys) }
func mergeBrandJSON(keys map[string]any) { mergeStore("brand.json", keys) }
func mergeStore(name string, keys map[string]any) {
	p := filepath.Join(configHome(), "ryoku", name)
	m := map[string]any{}
	if b, err := os.ReadFile(p); err == nil {
		_ = json.Unmarshal(b, &m)
	}
	for k, v := range keys {
		m[k] = v
	}
	_ = atomicWrite(p, mustJSON(m), 0o644)
}
