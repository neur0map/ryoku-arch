package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// sampleBlock is a Noctalia block with known values so the conversion is checked
// against exact expected roles, including the interpolated elevation ramp.
var sampleBlock = noctaliaColors{
	Primary:          "#ff0000",
	OnPrimary:        "#000000",
	Secondary:        "#00ff00",
	OnSecondary:      "#000000",
	Tertiary:         "#0000ff",
	OnTertiary:       "#000000",
	Error:            "#ff00ff",
	OnError:          "#000000",
	Surface:          "#000000",
	OnSurface:        "#ffffff",
	SurfaceVariant:   "#101010",
	OnSurfaceVariant: "#cccccc",
	Outline:          "#808080",
	Shadow:           "#000000",
}

func TestNoctaliaTo34Golden(t *testing.T) {
	pal := noctaliaTo34(sampleBlock)
	if pal == nil {
		t.Fatal("conversion returned nil for a complete block")
	}
	if len(pal) != len(themeRoles) {
		t.Fatalf("palette has %d roles, want %d", len(pal), len(themeRoles))
	}
	for _, role := range themeRoles {
		if !hexColor.MatchString(pal[role]) {
			t.Fatalf("role %q = %q, not a hex colour", role, pal[role])
		}
	}
	want := map[string]string{
		"surface":                 "#000000",
		"background":              "#000000",
		"onSurface":               "#ffffff",
		"primary":                 "#ff0000",
		"surfaceTint":             "#ff0000",
		"onPrimary":               "#000000",
		"secondary":               "#00ff00",
		"tertiary":                "#0000ff",
		"error":                   "#ff00ff",
		"surfaceVariant":          "#101010",
		"onSurfaceVariant":        "#cccccc",
		"outline":                 "#808080",
		"surfaceContainerLow":     "#080808", // mix(#000000,#101010,0.5)
		"surfaceContainer":        "#101010",
		"surfaceContainerHigh":    "#373737", // mix(#101010,#808080,0.35)
		"surfaceContainerHighest": "#535353", // mix(#101010,#808080,0.6)
		"outlineVariant":          "#404040", // mix(#808080,#000000,0.5)
		"primaryContainer":        "#101010",
		"scrim":                   "#000000",
	}
	for role, exp := range want {
		if pal[role] != exp {
			t.Errorf("role %q = %q, want %q", role, pal[role], exp)
		}
	}
}

func TestNoctaliaTo34RejectsIncomplete(t *testing.T) {
	if noctaliaTo34(noctaliaColors{Surface: "#000000"}) != nil {
		t.Fatal("a block missing onSurface/primary must not convert")
	}
}

// installFixtureTheme writes a library entry under a temp XDG_DATA_HOME.
func installFixtureTheme(t *testing.T, id, label, provider string, scheme noctaliaScheme) {
	t.Helper()
	dir := filepath.Join(userThemeDir(), id)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	sb, _ := json.Marshal(scheme)
	if err := os.WriteFile(filepath.Join(dir, "scheme.json"), sb, 0o644); err != nil {
		t.Fatal(err)
	}
	mb, _ := json.Marshal(userThemeMeta{Label: label, Provider: provider})
	if err := os.WriteFile(filepath.Join(dir, "meta.json"), mb, 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestUserThemeLibraryFlow(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	blk := sampleBlock
	installFixtureTheme(t, "hancore-sample", "Sample", "HANCORE-linux", noctaliaScheme{Dark: &blk})

	// lookupThemePalette resolves the installed id.
	pal, ok := lookupThemePalette("hancore-sample")
	if !ok || pal["primary"] != "#ff0000" {
		t.Fatalf("lookupThemePalette(installed) = %v, %v", pal["primary"], ok)
	}
	// A built-in still resolves and is not shadowed by the library.
	if _, ok := lookupThemePalette("Black Turq"); !ok {
		t.Fatal("built-in Black Turq no longer resolves")
	}
	// An unknown name resolves to nothing.
	if _, ok := lookupThemePalette("nope"); ok {
		t.Fatal("unknown theme resolved")
	}

	// theme.theme validation accepts the installed id.
	found := false
	for _, v := range effectiveThemeThemeValues() {
		if v == "hancore-sample" {
			found = true
		}
	}
	if !found {
		t.Fatal("effectiveThemeThemeValues omits the installed id")
	}

	// The catalog projection carries the user card after the built-ins, tagged.
	cat := themeCatalog()
	var card *themeCard
	for i := range cat {
		if cat[i].ID == "hancore-sample" {
			card = &cat[i]
		}
	}
	if card == nil {
		t.Fatal("themeCatalog omits the installed scheme")
	}
	if card.Provider != "HANCORE-linux" || card.Label != "Sample" || !card.Dark {
		t.Fatalf("user card = %+v, want provider HANCORE-linux, label Sample, dark true", *card)
	}
	if len(card.Sw) != len(themeSwatchRoles) || card.Sw[0] != "#000000" || card.Sw[2] != "#ff0000" {
		t.Fatalf("user card swatch = %v", card.Sw)
	}
}

func TestUserThemeBuiltinIDNotShadowed(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	blk := sampleBlock
	installFixtureTheme(t, "Black Turq", "Impostor", "x", noctaliaScheme{Dark: &blk})
	// The built-in palette must win over a library dir that reuses its id.
	pal, ok := lookupThemePalette("Black Turq")
	if !ok || pal["primary"] == "#ff0000" {
		t.Fatal("library entry shadowed the built-in Black Turq")
	}
	for _, tm := range userThemes() {
		if tm.ID == "Black Turq" {
			t.Fatal("userThemes surfaced a built-in id")
		}
	}
}
