package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// usertheme.go projects RyoStore-installed colour schemes into the daemon's
// static-theme world. RyoStore installs a scheme (install-only) under
// userThemeDir()/<id>/ as a Noctalia-format scheme.json ({dark?, light?} of
// mPrimary/.../mSurface roles) plus a meta.json ({label, provider}). Here the
// chosen Noctalia block is converted into the 34-role catalog palette every
// static-theme seam consumes (matugenApplyStatic, resolveThemePalette, the theme
// catalog projection, and theme.theme validation), so a downloaded scheme
// behaves exactly like a built-in one: it appears in the switcher belt and the
// Hub picker, applies through `ryoku-shell theme <id>`, and matugen fans it into
// every app. themePalettes (themes_gen.go) stays the built-in source of truth;
// the library only adds names and never shadows a built-in id.

// userThemeDir is the install root RyoStore writes to and this reads.
func userThemeDir() string {
	return filepath.Join(matugenDataHome(), "ryoku", "themes")
}

// noctaliaColors is the reduced Material set each Noctalia block carries. The
// block's terminal sub-object is ignored: the catalog derives ANSI colours from
// the roles, exactly as it does for every built-in theme.
type noctaliaColors struct {
	Primary          string `json:"mPrimary"`
	OnPrimary        string `json:"mOnPrimary"`
	Secondary        string `json:"mSecondary"`
	OnSecondary      string `json:"mOnSecondary"`
	Tertiary         string `json:"mTertiary"`
	OnTertiary       string `json:"mOnTertiary"`
	Error            string `json:"mError"`
	OnError          string `json:"mOnError"`
	Surface          string `json:"mSurface"`
	OnSurface        string `json:"mOnSurface"`
	SurfaceVariant   string `json:"mSurfaceVariant"`
	OnSurfaceVariant string `json:"mOnSurfaceVariant"`
	Outline          string `json:"mOutline"`
	Shadow           string `json:"mShadow"`
}

// noctaliaScheme is the on-disk scheme.json: a dark and/or light block.
type noctaliaScheme struct {
	Dark  *noctaliaColors `json:"dark"`
	Light *noctaliaColors `json:"light"`
}

// userThemeMeta is the on-disk meta.json: the display label and the provider the
// scheme came from (the RyoStore subtab that offered it).
type userThemeMeta struct {
	Label    string `json:"label"`
	Provider string `json:"provider"`
}

// userTheme is one installed scheme resolved to the catalog's role palette.
type userTheme struct {
	ID       string
	Label    string
	Provider string
	Palette  map[string]string // the 34 catalog roles
}

// userThemes loads and converts every installed scheme, id-sorted for a stable
// catalog order. A malformed or unreadable entry is skipped, never fatal: a bad
// download can never blank the belt or the built-in catalog.
func userThemes() []userTheme {
	entries, err := os.ReadDir(userThemeDir())
	if err != nil {
		return nil
	}
	out := make([]userTheme, 0, len(entries))
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		id := e.Name()
		if _, baked := themePalettes[id]; baked {
			continue // a built-in id always wins; the library never shadows it
		}
		dir := filepath.Join(userThemeDir(), id)
		schemeRaw, err := os.ReadFile(filepath.Join(dir, "scheme.json"))
		if err != nil {
			continue
		}
		var scheme noctaliaScheme
		if json.Unmarshal(schemeRaw, &scheme) != nil {
			continue
		}
		block := scheme.Dark
		if block == nil {
			block = scheme.Light
		}
		if block == nil {
			continue
		}
		pal := noctaliaTo34(*block)
		if pal == nil {
			continue
		}
		meta := userThemeMeta{}
		if metaRaw, err := os.ReadFile(filepath.Join(dir, "meta.json")); err == nil {
			_ = json.Unmarshal(metaRaw, &meta)
		}
		label := meta.Label
		if label == "" {
			label = id
		}
		out = append(out, userTheme{ID: id, Label: label, Provider: meta.Provider, Palette: pal})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out
}

// noctaliaTo34 converts one Noctalia block into the 34-role catalog palette. The
// elevation ramp runs surface -> surfaceVariant -> outline; each accent maps to
// its Material role with the surface variant as its container. A block missing
// the core roles (surface, onSurface, primary) is unusable and returns nil.
func noctaliaTo34(c noctaliaColors) map[string]string {
	if c.Surface == "" || c.OnSurface == "" || c.Primary == "" {
		return nil
	}
	role := func(v, fallback string) string {
		if v != "" {
			return v
		}
		return fallback
	}
	sv := role(c.SurfaceVariant, mixHex(c.Surface, c.OnSurface, 0.12))
	outline := role(c.Outline, mixHex(c.Surface, c.OnSurface, 0.4))
	shadow := role(c.Shadow, "#000000")
	return map[string]string{
		"surface":                 c.Surface,
		"background":              c.Surface,
		"scrim":                   shadow,
		"shadow":                  shadow,
		"surfaceContainerLowest":  c.Surface,
		"inverseOnSurface":        c.Surface,
		"onSurface":               c.OnSurface,
		"onBackground":            c.OnSurface,
		"inverseSurface":          c.OnSurface,
		"surfaceVariant":          sv,
		"onSurfaceVariant":        role(c.OnSurfaceVariant, c.OnSurface),
		"surfaceContainerLow":     mixHex(c.Surface, sv, 0.5),
		"surfaceContainer":        sv,
		"surfaceContainerHigh":    mixHex(sv, outline, 0.35),
		"surfaceContainerHighest": mixHex(sv, outline, 0.6),
		"surfaceTint":             c.Primary,
		"primary":                 c.Primary,
		"onPrimary":               role(c.OnPrimary, c.Surface),
		"primaryContainer":        sv,
		"onPrimaryContainer":      c.Primary,
		"secondary":               role(c.Secondary, c.Primary),
		"onSecondary":             role(c.OnSecondary, c.Surface),
		"secondaryContainer":      sv,
		"onSecondaryContainer":    role(c.Secondary, c.Primary),
		"tertiary":                role(c.Tertiary, c.Primary),
		"onTertiary":              role(c.OnTertiary, c.Surface),
		"tertiaryContainer":       sv,
		"onTertiaryContainer":     role(c.Tertiary, c.Primary),
		"error":                   role(c.Error, c.Primary),
		"onError":                 role(c.OnError, c.Surface),
		"errorContainer":          sv,
		"onErrorContainer":        role(c.Error, c.Primary),
		"outline":                 outline,
		"outlineVariant":          mixHex(outline, c.Surface, 0.5),
	}
}

// lookupThemePalette resolves a theme.theme value to its 34-role palette: a
// built-in first (themes_gen.go), then the installed library. It is the single
// seam matugenApplyStatic and resolveThemePalette share so both honour a
// downloaded scheme.
func lookupThemePalette(name string) (map[string]string, bool) {
	if pal, ok := themePalettes[name]; ok {
		return pal, true
	}
	for _, t := range userThemes() {
		if t.ID == name {
			return t.Palette, true
		}
	}
	return nil, false
}

// userThemeIDs lists the installed scheme ids, for theme.theme validation.
func userThemeIDs() []string {
	ts := userThemes()
	ids := make([]string, 0, len(ts))
	for _, t := range ts {
		ids = append(ids, t.ID)
	}
	return ids
}

// effectiveThemeThemeValues is the set theme.theme accepts: the built-in names
// plus every installed library id, so applying a downloaded scheme validates.
func effectiveThemeThemeValues() []string {
	ids := userThemeIDs()
	if len(ids) == 0 {
		return themeThemeValues
	}
	return append(append([]string{}, themeThemeValues...), ids...)
}

// userThemeCards projects the installed library into the switcher/Hub catalog
// projection, after the built-ins, each tagged with its provider.
func userThemeCards() []themeCard {
	ts := userThemes()
	cards := make([]themeCard, 0, len(ts))
	for _, t := range ts {
		sw := make([]string, len(themeSwatchRoles))
		for i, r := range themeSwatchRoles {
			sw[i] = t.Palette[r]
		}
		luma, ok := hexLuma(t.Palette["surface"])
		cards = append(cards, themeCard{
			ID:       t.ID,
			Label:    t.Label,
			Provider: t.Provider,
			Dark:     !ok || luma < 0.5,
			Sw:       sw,
		})
	}
	return cards
}

// mixHex linearly blends two hex colours by t in [0,1]; a non-hex input returns
// the first colour unchanged.
func mixHex(a, b string, t float64) string {
	ar, ag, ab, ok1 := parseHexRGB(a)
	br, bg, bb, ok2 := parseHexRGB(b)
	if !ok1 || !ok2 {
		return a
	}
	m := func(x, y int) int {
		v := float64(x) + (float64(y)-float64(x))*t
		switch {
		case v < 0:
			v = 0
		case v > 255:
			v = 255
		}
		return int(v + 0.5)
	}
	return fmt.Sprintf("#%02x%02x%02x", m(ar, br), m(ag, bg), m(ab, bb))
}

// parseHexRGB splits a #rrggbb string into channels, ok=false when malformed.
func parseHexRGB(hex string) (int, int, int, bool) {
	h := strings.TrimPrefix(hex, "#")
	if len(h) != 6 {
		return 0, 0, 0, false
	}
	r, e1 := strconv.ParseInt(h[0:2], 16, 0)
	g, e2 := strconv.ParseInt(h[2:4], 16, 0)
	b, e3 := strconv.ParseInt(h[4:6], 16, 0)
	if e1 != nil || e2 != nil || e3 != nil {
		return 0, 0, 0, false
	}
	return int(r), int(g), int(b), true
}
