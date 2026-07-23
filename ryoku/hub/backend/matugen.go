package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

type matugenConfig struct {
	Engine           string          `json:"engine"`           // "wallust" or "matugen"
	SchemeType       string          `json:"schemeType"`       // e.g. "scheme-tonal-spot"
	Mode             string          `json:"mode"`             // "dark", "light", "smart"
	Contrast         float64         `json:"contrast"`         // -1.0 to 1.0
	LightnessDark    float64         `json:"lightnessDark"`    // -1.0 to 1.0
	LightnessLight   float64         `json:"lightnessLight"`   // -1.0 to 1.0
	Prefer           string          `json:"prefer"`           // "dominant" or "vibrant"
	SourceColorIndex int             `json:"sourceColorIndex"` // 0..4
	ThemeRyokuApps   bool            `json:"themeRyokuApps"`   // theme Ryoku's native shell & apps
	Templates        map[string]bool `json:"templates"`        // app -> bool
}

func hexToRGB(hex string) (int, int, int) {
	hex = strings.TrimPrefix(hex, "#")
	if len(hex) == 6 {
		r, _ := strconv.ParseInt(hex[0:2], 16, 64)
		g, _ := strconv.ParseInt(hex[2:4], 16, 64)
		b, _ := strconv.ParseInt(hex[4:6], 16, 64)
		return int(r), int(g), int(b)
	}
	return 0, 0, 0
}

func paletteCarrier(pal map[string]string) map[string]any {
	c := map[string]any{}
	put := func(name, hex string) {
		if hex == "" {
			return
		}
		stripped := strings.TrimPrefix(hex, "#")
		r, g, b := hexToRGB(hex)
		colorObj := map[string]any{
			"hex":          hex,
			"hex_stripped": stripped,
			"red":          strconv.Itoa(r),
			"green":        strconv.Itoa(g),
			"blue":         strconv.Itoa(b),
			"rgb":          fmt.Sprintf("%d, %d, %d", r, g, b),
		}
		entry := map[string]any{
			"default":      colorObj,
			"dark":         colorObj,
			"light":        colorObj,
			"hex":          hex,
			"hex_stripped": stripped,
			"red":          strconv.Itoa(r),
			"green":        strconv.Itoa(g),
			"blue":         strconv.Itoa(b),
			"rgb":          fmt.Sprintf("%d, %d, %d", r, g, b),
		}
		c[name] = entry
	}
	for k, v := range pal {
		put(k, v)
		put(k+"_argb", "#ff"+strings.TrimPrefix(v, "#"))
	}
	if fg, ok := pal["foreground"]; ok {
		put("cursor", fg)
	} else if onSurf, ok := pal["on_surface"]; ok {
		put("cursor", onSurf)
	}
	return c
}

func defaultMatugenConfig() matugenConfig {
	return matugenConfig{
		Engine:           "wallust",
		SchemeType:       "scheme-tonal-spot",
		Mode:             "dark",
		Contrast:         0.0,
		LightnessDark:    0.0,
		LightnessLight:   0.0,
		Prefer:           "saturation",
		SourceColorIndex: 0,
		ThemeRyokuApps:   false,
		Templates: map[string]bool{
			"btop":     true,
			"qt":       true,
			"qt5":      true,
			"gtk":      true,
			"discord":  true,
			"obs":      true,
			"zed":      true,
			"heroic":   true,
			"hyprland": true,
			"telegram": true,
			"steam":    true,
			"kitty":    true,
			"cava":     true,
			"ghostty":  true,
			"micro":    true,
			"papirus":  true,
		},
	}
}

func matugenConfigPath() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(base, "ryoku", "matugen.json")
}

func loadMatugenConfig() matugenConfig {
	cfg := defaultMatugenConfig()
	b, err := os.ReadFile(matugenConfigPath())
	if err == nil {
		_ = json.Unmarshal(b, &cfg)
	}
	if cfg.Templates == nil {
		cfg.Templates = defaultMatugenConfig().Templates
	}
	return cfg
}

func saveMatugenConfig(cfg matugenConfig) error {
	return atomicWrite(matugenConfigPath(), mustJSON(cfg), 0o644)
}

func runMatugenCmd(args []string) error {
	if len(args) == 0 {
		return printJSON(loadMatugenConfig())
	}
	switch args[0] {
	case "get":
		return printJSON(loadMatugenConfig())
	case "set":
		if len(args) < 2 {
			return fmt.Errorf("matugen set requires JSON argument")
		}
		var cfg matugenConfig
		if err := json.Unmarshal([]byte(args[1]), &cfg); err != nil {
			return err
		}
		if err := saveMatugenConfig(cfg); err != nil {
			return err
		}
		// Apply live so a settings change (scheme, per-app toggle) takes hold at
		// once. Matugen re-derives the whole palette from the wallpaper; wallust
		// keeps its current colors.json and just re-fans it through the (possibly
		// newly toggled) templates.
		if cfg.Engine == "matugen" {
			_ = generateMatugenTheme("")
		} else if pal := readPalette(filepath.Join(wallustCacheDir(), "colors.json")); pal != nil {
			renderActiveTemplates(cfg, pal)
		}
		return nil
	case "apply":
		imgPath := ""
		if len(args) > 1 {
			imgPath = args[1]
		}
		return generateMatugenTheme(imgPath)
	case "render-apps":
		pal := readPalette(filepath.Join(wallustCacheDir(), "colors.json"))
		if pal != nil {
			cfg := loadMatugenConfig()
			renderActiveTemplates(cfg, pal)
		}
		return nil
	default:
		return fmt.Errorf("unknown matugen subcommand %q", args[0])
	}
}

// generateMatugenTheme executes matugen on wallpaper image, parses palette,
// updates ~/.cache/wallust/colors.json and renders configured app templates.
func generateMatugenTheme(imgPath string) error {
	cfg := loadMatugenConfig()
	if imgPath == "" {
		stateFile := filepath.Join(cacheHome(), "..", ".local", "state", "ryoku-wallpaper")
		b, err := os.ReadFile(stateFile)
		if err == nil {
			imgPath = strings.TrimSpace(string(b))
		}
	}
	if imgPath == "" || !isFile(imgPath) {
		wallDir := filepath.Join(os.Getenv("HOME"), "Pictures", "Wallpapers")
		entries, err := os.ReadDir(wallDir)
		if err == nil {
			for _, e := range entries {
				if !e.IsDir() && (strings.HasSuffix(e.Name(), ".png") || strings.HasSuffix(e.Name(), ".jpg") || strings.HasSuffix(e.Name(), ".jpeg") || strings.HasSuffix(e.Name(), ".webp")) {
					imgPath = filepath.Join(wallDir, e.Name())
					break
				}
			}
		}
	}
	if imgPath == "" || !isFile(imgPath) {
		return fmt.Errorf("no valid wallpaper image found at %q", imgPath)
	}
	// matugen decodes still images only. A live/video wallpaper (.webm/.mp4)
	// must be sampled to one frame first, exactly as the shell's paint path does;
	// otherwise matugen panics ("not recognized as an image format") and the
	// whole apply -- colors.json, every app template, and the folder-recolor
	// post_hook -- silently no-ops.
	if isVideoWallpaper(imgPath) {
		frame := videoStill(imgPath)
		if frame == "" {
			return fmt.Errorf("could not sample a still frame from live wallpaper %q", imgPath)
		}
		imgPath = frame
	}
	cliArgs := []string{
		"image", imgPath,
		"-t", cfg.SchemeType,
		"-m", cfg.Mode,
		"--lightness-dark", strconv.FormatFloat(cfg.LightnessDark, 'f', 2, 64),
		"--lightness-light", strconv.FormatFloat(cfg.LightnessLight, 'f', 2, 64),
		"--source-color-index", strconv.Itoa(cfg.SourceColorIndex),
		"--prefer", cfg.Prefer,
		"--json", "hex",
		"--dry-run",
	}

	out, err := exec.Command("matugen", cliArgs...).CombinedOutput()
	if err != nil {
		fmt.Fprintf(os.Stderr, "matugen CLI error: %v: %s\n", err, out)
		return err
	}

	var m3Data map[string]any
	if err := json.Unmarshal(out, &m3Data); err != nil {
		fmt.Fprintf(os.Stderr, "matugen parse error: %v\n", err)
		return err
	}

	// Extract colors map from Matugen output JSON
	colorsObj, ok := m3Data["colors"].(map[string]any)
	if !ok {
		return fmt.Errorf("invalid matugen json format: missing colors key")
	}

	palette := map[string]string{}
	modeKey := cfg.Mode
	if modeKey == "smart" || modeKey == "" {
		modeKey = "dark"
	}

	for k, v := range colorsObj {
		colorPropMap, ok := v.(map[string]any)
		if !ok {
			continue
		}
		var hexVal string
		for _, m := range []string{modeKey, "default", "dark", "light"} {
			if modeMap, ok := colorPropMap[m].(map[string]any); ok {
				if h, ok := modeMap["color"].(string); ok && h != "" {
					hexVal = h
					break
				} else if h, ok := modeMap["hex"].(string); ok && h != "" {
					hexVal = h
					break
				}
			}
		}
		if hexVal != "" {
			palette[k] = hexVal
		}
	}

	if len(palette) == 0 {
		return fmt.Errorf("no colors extracted from matugen output")
	}

	// Map Material 3 colors to Ryoku base16 / wallust expected keys (color0..color15, background, foreground, etc.)
	getHex := func(key, fallback string) string {
		if val, ok := palette[key]; ok && val != "" {
			return val
		}
		return fallback
	}

	bg := getHex("surface", getHex("background", "#121212"))
	fg := getHex("on_surface", getHex("on_background", "#e6e6e6"))
	primary := getHex("primary", "#a8c7fa")
	secondary := getHex("secondary", "#7cacf8")
	tertiary := getHex("tertiary", "#ffb4a9")
	errorCol := getHex("error", "#ffb4ab")
	surfaceVar := getHex("surface_variant", "#444746")
	outline := getHex("outline", "#8e918f")

	wallustMap := map[string]string{
		"background": bg,
		"foreground": fg,
		"cursor":     fg,
		"color0":     bg,
		"color1":     errorCol,
		"color2":     primary,
		"color3":     tertiary,
		"color4":     secondary,
		"color5":     getHex("primary_container", primary),
		"color6":     getHex("secondary_container", secondary),
		"color7":     fg,
		"color8":     surfaceVar,
		"color9":     getHex("error_container", errorCol),
		"color10":    primary,
		"color11":    tertiary,
		"color12":    secondary,
		"color13":    getHex("inverse_primary", primary),
		"color14":    outline,
		"color15":    getHex("on_primary_container", fg),
	}

	// Also add all M3 colors to wallustMap so templates can use both Material 3 roles and base16
	for k, v := range palette {
		wallustMap[k] = v
	}

	// Write wallust cache colors.json for Quickshell & desktop based on user choice
	_ = os.MkdirAll(wallustCacheDir(), 0o755)
	st := loadThemeState()
	if cfg.ThemeRyokuApps {
		_ = atomicWrite(filepath.Join(wallustCacheDir(), "colors.json"), mustJSON(wallustMap), 0o644)
		st.FollowWallpaper = true
		st.Scheme = ""
		saveThemeState(st)
	} else {
		if monoPal, err := loadScheme("mono"); err == nil {
			_ = atomicWrite(filepath.Join(wallustCacheDir(), "colors.json"), mustJSON(monoPal), 0o644)
		}
		st.FollowWallpaper = false
		st.Scheme = "mono"
		saveThemeState(st)
	}
	// Build active apps.toml filtered by user toggles in cfg.Templates
	renderActiveTemplates(cfg, wallustMap)

	// Trigger live updates
	_ = exec.Command("hyprctl", "reload", "config-only").Run()
	_ = exec.Command("pkill", "-USR1", "-x", "kitty").Run()
	nudgeGtk()

	return nil
}

// isVideoWallpaper reports whether p is a live/video wallpaper matugen cannot read.
func isVideoWallpaper(p string) bool {
	switch strings.ToLower(filepath.Ext(p)) {
	case ".mp4", ".webm", ".mkv", ".mov":
		return true
	}
	return false
}

// videoStill samples one frame from a live wallpaper so matugen has an image to
// extract a palette from. Returns "" when ffmpeg is absent or fails, so the
// caller reports a clean error instead of crashing matugen.
func videoStill(video string) string {
	out := filepath.Join(cacheHome(), "ryoku", "matugen-frame.png")
	if err := os.MkdirAll(filepath.Dir(out), 0o755); err != nil {
		return ""
	}
	if err := exec.Command("ffmpeg", "-y", "-ss", "1", "-i", video, "-frames:v", "1", out).Run(); err != nil || !isFile(out) {
		return ""
	}
	return out
}

// renderActiveTemplates generates matugen configs for enabled templates
func renderActiveTemplates(cfg matugenConfig, pal map[string]string) {
	matugenDir := filepath.Join(configHome(), "matugen")
	cacheDir := filepath.Join(cacheHome(), "ryoku")
	_ = os.MkdirAll(cacheDir, 0o755)

	// Ensure all target output directories exist
	home := os.Getenv("HOME")
	dataHome := os.Getenv("XDG_DATA_HOME")
	if dataHome == "" {
		dataHome = filepath.Join(home, ".local", "share")
	}

	targetDirs := []string{
		filepath.Join(configHome(), "kitty"),
		filepath.Join(cacheHome(), "wallust"),
		filepath.Join(configHome(), "qt6ct", "colors"),
		filepath.Join(configHome(), "qt5ct", "colors"),
		filepath.Join(configHome(), "gtk-3.0"),
		filepath.Join(configHome(), "vesktop", "themes"),
		filepath.Join(configHome(), "equibop", "themes"),
		filepath.Join(configHome(), "obs-studio", "themes"),
		filepath.Join(configHome(), "zed", "themes"),
		filepath.Join(configHome(), "heroic", "store", "styles"),
		filepath.Join(dataHome, "TelegramDesktop", "tdata"),
		filepath.Join(home, ".steam", "steam", "steamui", "skins", "Material-Theme", "css", "main", "colors"),
		filepath.Join(configHome(), "cava"),
		filepath.Join(configHome(), "ghostty"),
		filepath.Join(configHome(), "micro", "colorschemes"),
		filepath.Join(cacheHome(), "matugen"),
	}
	for _, d := range targetDirs {
		_ = os.MkdirAll(d, 0o755)
	}

	carrierPath := filepath.Join(cacheDir, "matugen-carrier.json")
	carrier := map[string]any{"colors": paletteCarrier(pal)}
	if err := atomicWrite(carrierPath, mustJSON(carrier), 0o644); err != nil {
		return
	}
	// Always render core surface
	runMatugen(filepath.Join(matugenDir, "config.toml"), carrierPath)

	// Filter apps.toml entries based on cfg.Templates
	appsTomlPath := filepath.Join(matugenDir, "apps.toml")
	b, err := os.ReadFile(appsTomlPath)
	if err != nil {
		return
	}

	// Write filtered apps.toml to cache and execute
	content := string(b)
	sections := strings.Split(content, "\n[")
	var activeSections []string

	for i, sec := range sections {
		secStr := sec
		if i > 0 {
			secStr = "[" + sec
		}
		trimmed := strings.TrimSpace(secStr)
		if strings.HasPrefix(trimmed, "[config]") || strings.HasPrefix(trimmed, "[config\n") {
			activeSections = append(activeSections, secStr)
			continue
		}
		if strings.HasPrefix(trimmed, "[templates.") {
			headerEnd := strings.Index(trimmed, "]")
			if headerEnd > 11 {
				appName := trimmed[11:headerEnd]
				groupKey := appName
				switch appName {
				case "gtk3", "gtk4":
					groupKey = "gtk"
				case "qt5ct":
					groupKey = "qt5"
				case "vesktop", "equibop":
					groupKey = "discord"
				}
				if enabled, ok := cfg.Templates[groupKey]; !ok || enabled {
					activeSections = append(activeSections, secStr)
				}
			}
		}
	}

	activeAppsToml := filepath.Join(cacheDir, "active-apps.toml")
	_ = os.WriteFile(activeAppsToml, []byte(strings.Join(activeSections, "\n")), 0o644)

	runMatugen(activeAppsToml, carrierPath)
}
