package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// themeRoles is the colour-role set every generated palette must carry: the 30
// Material roles Theme.qml resolves plus background/onBackground and shadow/scrim
// (the full map contract 08 tabulates).
var themeRoles = []string{
	"surface", "onSurface", "surfaceVariant", "onSurfaceVariant",
	"surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer",
	"surfaceContainerHigh", "surfaceContainerHighest",
	"inverseSurface", "inverseOnSurface", "surfaceTint",
	"primary", "onPrimary", "primaryContainer", "onPrimaryContainer",
	"secondary", "onSecondary", "secondaryContainer", "onSecondaryContainer",
	"tertiary", "onTertiary", "tertiaryContainer", "onTertiaryContainer",
	"error", "onError", "errorContainer", "onErrorContainer",
	"outline", "outlineVariant", "background", "onBackground",
	"shadow", "scrim",
}

var hexColor = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

// frameHas reports whether a top-level key is present in a marshalled frame,
// without failing when it is absent (frameGet fails on a missing path).
func frameHas(t *testing.T, frame []byte, key string) bool {
	t.Helper()
	var m map[string]any
	if err := json.Unmarshal(frame, &m); err != nil {
		t.Fatalf("frame is not a JSON object: %v", err)
	}
	_, ok := m[key]
	return ok
}

// TestThemeCatalog guards the generated palette catalog: 57 named palettes, each
// carrying the whole role set with valid hex, cross-checked against contract 08
// sec 8.1 for a dark theme (Solitude) and a second theme (Tokyo Night). The
// ordered name slice and the palette map must agree.
func TestThemeCatalog(t *testing.T) {
	if len(themePalettes) != 57 {
		t.Fatalf("themePalettes has %d named palettes, want 57", len(themePalettes))
	}
	if len(themeCatalogNames) != 57 {
		t.Fatalf("themeCatalogNames has %d entries, want 57", len(themeCatalogNames))
	}
	for _, name := range themeCatalogNames {
		if _, ok := themePalettes[name]; !ok {
			t.Fatalf("themeCatalogNames lists %q but themePalettes has no such palette", name)
		}
	}

	// Every palette carries exactly the role set, each a real hex colour.
	for name, pal := range themePalettes {
		if len(pal) != len(themeRoles) {
			t.Fatalf("%s: palette has %d roles, want %d", name, len(pal), len(themeRoles))
		}
		for _, role := range themeRoles {
			hex, ok := pal[role]
			if !ok {
				t.Fatalf("%s: palette missing role %q", name, role)
			}
			if !hexColor.MatchString(hex) {
				t.Fatalf("%s.%s = %q, not a #rrggbb hex", name, role, hex)
			}
		}
	}

	// Contract 08 sec 8.1 spot-checks (surface, onSurface, outline).
	checks := []struct{ theme, surface, onSurface, outline string }{
		{"Solitude", "#101315", "#cacccc", "#565d60"},
		{"Tokyo Night", "#1a1b26", "#a9b1d6", "#9aa5ce"},
	}
	for _, c := range checks {
		pal := themePalettes[c.theme]
		if pal["surface"] != c.surface || pal["onSurface"] != c.onSurface || pal["outline"] != c.outline {
			t.Fatalf("%s: surface=%s onSurface=%s outline=%s, want %s/%s/%s",
				c.theme, pal["surface"], pal["onSurface"], pal["outline"],
				c.surface, c.onSurface, c.outline)
		}
	}
}

// TestThemePalettePatch checks a theme.theme patch to a named theme lands the
// theme's resolved palette in the store under the passthrough themePalette key.
func TestThemePalettePatch(t *testing.T) {
	s := newTestStore(t)
	if err := s.patch("theme.theme", rm(`"Solitude"`)); err != nil {
		t.Fatalf("patch theme.theme=Solitude: %v", err)
	}
	pal, ok := frameGet(t, s.frameLocked(), "themePalette").(map[string]any)
	if !ok {
		t.Fatalf("themePalette missing or not an object after a named-theme patch")
	}
	if pal["surface"] != "#101315" || pal["onSurface"] != "#cacccc" || pal["outline"] != "#565d60" {
		t.Fatalf("Solitude palette in store = surface %v onSurface %v outline %v, want #101315/#cacccc/#565d60",
			pal["surface"], pal["onSurface"], pal["outline"])
	}
}

// TestThemePaletteDynamicRemoves checks the two dynamic variants carry no static
// palette: switching to Default or Wallpaper removes themePalette from the store.
func TestThemePaletteDynamicRemoves(t *testing.T) {
	for _, dyn := range []string{"Default", "Wallpaper"} {
		t.Run(dyn, func(t *testing.T) {
			s := newTestStore(t)
			if err := s.patch("theme.theme", rm(`"Tokyo Night"`)); err != nil {
				t.Fatalf("seed named theme: %v", err)
			}
			if !frameHas(t, s.frameLocked(), "themePalette") {
				t.Fatalf("themePalette not present after seeding a named theme")
			}
			if err := s.patch("theme.theme", rm(`"`+dyn+`"`)); err != nil {
				t.Fatalf("patch theme.theme=%s: %v", dyn, err)
			}
			if frameHas(t, s.frameLocked(), "themePalette") {
				t.Fatalf("themePalette still present after switching to dynamic %s", dyn)
			}
		})
	}
}

// TestThemePaletteUnknownRejected checks an unknown theme name is rejected
// (the call returns an error, so ok:false) and leaves the store untouched: the
// on-disk file, the active theme, and the palette all stay as they were.
func TestThemePaletteUnknownRejected(t *testing.T) {
	s := newTestStore(t)
	if err := s.patch("theme.theme", rm(`"Solitude"`)); err != nil {
		t.Fatalf("seed Solitude: %v", err)
	}
	before, _ := os.ReadFile(s.path)

	err := s.patch("theme.theme", rm(`"Nonexistent Theme"`))
	if err == nil {
		t.Fatalf("unknown theme.theme: want error, got nil")
	}
	if !strings.Contains(err.Error(), "is not one of") {
		t.Fatalf("unknown theme.theme error = %q, want enum rejection", err)
	}

	after, _ := os.ReadFile(s.path)
	if string(before) != string(after) {
		t.Fatalf("rejected theme patch modified the file on disk")
	}
	if got := frameGet(t, s.frameLocked(), "theme.theme"); got != "Solitude" {
		t.Fatalf("theme.theme = %v after rejected patch, want Solitude untouched", got)
	}
	pal, ok := frameGet(t, s.frameLocked(), "themePalette").(map[string]any)
	if !ok || pal["surface"] != "#101315" {
		t.Fatalf("themePalette changed after rejected patch: %v", pal)
	}
}

// TestThemePaletteResetRefreshes checks reset re-derives themePalette: after a
// named theme, resetting theme.theme restores the shipped default (Default, a
// dynamic variant) and clears the palette in the same frame.
func TestThemePaletteResetRefreshes(t *testing.T) {
	s := newTestStore(t)
	if err := s.patch("theme.theme", rm(`"Tokyo Night"`)); err != nil {
		t.Fatalf("patch Tokyo Night: %v", err)
	}
	if !frameHas(t, s.frameLocked(), "themePalette") {
		t.Fatalf("themePalette missing after named-theme patch")
	}
	if err := s.reset("theme.theme"); err != nil {
		t.Fatalf("reset theme.theme: %v", err)
	}
	if got := frameGet(t, s.frameLocked(), "theme.theme"); got != "Default" {
		t.Fatalf("reset theme.theme = %v, want default Default", got)
	}
	if frameHas(t, s.frameLocked(), "themePalette") {
		t.Fatalf("themePalette still present after reset to the dynamic default")
	}
}

// TestThemePaletteLoad checks the load path derives themePalette from the file's
// stored theme on startup, in both directions: a stored named theme yields its
// palette, and a stale palette left beside a dynamic theme is dropped.
func TestThemePaletteLoad(t *testing.T) {
	path := filepath.Join(t.TempDir(), "shell.json")

	if err := os.WriteFile(path, []byte(`{"theme":{"theme":"Solitude"}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	s := newSettingsStore(path)
	pal, ok := frameGet(t, s.frameLocked(), "themePalette").(map[string]any)
	if !ok || pal["surface"] != "#101315" {
		t.Fatalf("load of a named theme: themePalette = %v, want Solitude palette", pal)
	}

	if err := os.WriteFile(path, []byte(`{"theme":{"theme":"Default"},"themePalette":{"surface":"#ffffff"}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	s = newSettingsStore(path)
	if frameHas(t, s.frameLocked(), "themePalette") {
		t.Fatalf("load of a dynamic theme: stale themePalette not dropped")
	}
}

// TestThemePaletteReload checks an external hand-edit of theme.theme retunes the
// palette on reload (the watch path), not only on patch/load: switching the file
// to a dynamic variant drops a stale palette, and switching to another named
// theme re-derives it even when the editor wrote no themePalette.
func TestThemePaletteReload(t *testing.T) {
	s := newTestStore(t)
	if err := s.patch("theme.theme", rm(`"Solitude"`)); err != nil {
		t.Fatalf("seed Solitude: %v", err)
	}

	// Hand-edit -> a dynamic variant, but with a stale palette left in the file.
	if err := os.WriteFile(s.path, []byte(`{"theme":{"theme":"Default"},"themePalette":{"surface":"#123456"}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	s.reload()
	if frameHas(t, s.frameLocked(), "themePalette") {
		t.Fatalf("reload to a dynamic theme kept a stale themePalette")
	}

	// Hand-edit -> another named theme, editor wrote no palette.
	if err := os.WriteFile(s.path, []byte(`{"theme":{"theme":"Tokyo Night"}}`), 0o644); err != nil {
		t.Fatal(err)
	}
	s.reload()
	pal, ok := frameGet(t, s.frameLocked(), "themePalette").(map[string]any)
	if !ok || pal["surface"] != "#1a1b26" {
		t.Fatalf("reload to a named theme did not re-derive the palette: %v", pal)
	}
}
