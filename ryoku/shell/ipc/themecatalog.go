package main

import "encoding/json"

// themecatalog.go serves the lightweight colour-scheme preview projection the
// wallpaper switcher's Color-scheme belt draws from. It is derived from the
// authoritative 30-role palettes (themes_gen.go), so those stay the single
// source of the colours; only the two dynamic variants and the handful of
// accented display labels are named here. `ryoku-shell theme catalog` prints it
// (client-side, in main.go: the JSON is larger than the daemon socket's reply
// buffer and needs no running daemon), and `ryoku-shell theme <name>` applies a
// scheme through the settings seam (daemon.go).

// themeCard is one entry in the projection: the id written to theme.theme, a
// display label, and either the seven-swatch preview (static themes) or a glyph
// (the two dynamic variants). Order matches the reference projection
// [surface, onSurface, primary, secondary, tertiary, error, outline].
type themeCard struct {
	ID      string   `json:"id"`
	Label   string   `json:"label"`
	Provider string   `json:"provider,omitempty"`
	Dynamic bool     `json:"dynamic,omitempty"`
	Icon    string   `json:"icon,omitempty"`
	Dark    bool     `json:"dark,omitempty"`
	Sw      []string `json:"sw,omitempty"`
}

// themeLabels overrides the display label for the themes whose presentation name
// carries an accent the id (the stored theme.theme value) cannot. Every other
// theme's label is its id verbatim.
var themeLabels = map[string]string{
	"Catppuccin Frappe": "Catppuccin Frapp\u00e9",
	"Rose Pine":         "Ros\u00e9 Pine",
	"Rose Pine Dawn":    "Ros\u00e9 Pine Dawn",
	"Rose Pine Moon":    "Ros\u00e9 Pine Moon",
}

// themeSwatchRoles are the seven palette roles the preview shows, in reference
// order.
var themeSwatchRoles = []string{"surface", "onSurface", "primary", "secondary", "tertiary", "error", "outline"}

// themeCatalog builds the preview projection: the two dynamic variants (Default,
// Wallpaper), then every static theme in catalog order, each with its
// seven-swatch preview and a dark flag (surface luma < 0.5).
func themeCatalog() []themeCard {
	out := make([]themeCard, 0, len(themeCatalogNames)+2)
	out = append(out,
		themeCard{ID: "Default", Label: "Default", Dynamic: true, Icon: "palette"},
		themeCard{ID: "Wallpaper", Label: "Wallpaper", Dynamic: true, Icon: "wallpaper"},
	)
	for _, name := range themeCatalogNames {
		pal := themePalettes[name]
		sw := make([]string, len(themeSwatchRoles))
		for i, role := range themeSwatchRoles {
			sw[i] = pal[role]
		}
		label := name
		if l, ok := themeLabels[name]; ok {
			label = l
		}
		luma, ok := hexLuma(pal["surface"])
		out = append(out, themeCard{
			ID:    name,
			Label: label,
			Dark:  !ok || luma < 0.5,
			Sw:    sw,
		})
	}
	// Installed library schemes follow the built-ins, each provider-tagged.
	out = append(out, userThemeCards()...)
	return out
}

// themeCatalogJSON marshals the projection for the CLI.
func themeCatalogJSON() string {
	b, _ := json.Marshal(themeCatalog())
	return string(b)
}
