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
	Templates        map[string]bool `json:"templates"`        // app -> bool
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
		Templates: map[string]bool{
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
		// Apply matugen color generation if engine is matugen
		if cfg.Engine == "matugen" {
			_ = generateMatugenTheme("")
		}
		return nil
	case "apply":
		return generateMatugenTheme("")
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
		return fmt.Errorf("no valid wallpaper image found at %q", imgPath)
	}

	// Prepare CLI args for matugen
	cliArgs := []string{
		"image", imgPath,
		"-t", cfg.SchemeType,
		"-m", cfg.Mode,
		"--contrast", strconv.FormatFloat(cfg.Contrast, 'f', 2, 64),
		"--lightness-dark", strconv.FormatFloat(cfg.LightnessDark, 'f', 2, 64),
		"--lightness-light", strconv.FormatFloat(cfg.LightnessLight, 'f', 2, 64),
		"--source-color-index", strconv.Itoa(cfg.SourceColorIndex),
		"--json", "hex",
		"--dry-run",
	}
	if cfg.Prefer != "" {
		cliArgs = append(cliArgs, "--prefer", cfg.Prefer)
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
		return fmt.Errorf("invalid matugen json format")
	}

	palette := map[string]string{}
	// Extract dark scheme or light scheme colors
	var schemeColors map[string]any
	if darkMap, ok := colorsObj["dark"].(map[string]any); ok && cfg.Mode != "light" {
		schemeColors = darkMap
	} else if lightMap, ok := colorsObj["light"].(map[string]any); ok {
		schemeColors = lightMap
	}

	if schemeColors == nil {
		return fmt.Errorf("no scheme colors found in matugen output")
	}

	// Extract hex string for each color key
	for k, v := range schemeColors {
		if cMap, ok := v.(map[string]any); ok {
			if hexVal, ok := cMap["hex"].(string); ok {
				palette[k] = hexVal
			}
		}
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

	// Write wallust cache colors.json for Quickshell & desktop
	_ = os.MkdirAll(wallustCacheDir(), 0o755)
	_ = atomicWrite(filepath.Join(wallustCacheDir(), "colors.json"), mustJSON(wallustMap), 0o644)

	// Render Matugen app templates
	renderApps(wallustMap)

	// Trigger live updates
	_ = exec.Command("hyprctl", "reload", "config-only").Run()
	_ = exec.Command("pkill", "-USR1", "-x", "kitty").Run()
	nudgeGtk()

	return nil
}
