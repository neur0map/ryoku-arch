package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// TestThemeCatalogProjection guards the preview projection the switcher draws
// from: the two dynamic variants first, then every static theme with a
// seven-swatch preview taken from the authoritative palette and a dark flag
// (surface luma < 0.5). It must not drift from themePalettes.
func TestThemeCatalogProjection(t *testing.T) {
	// Isolate from any installed theme library so the built-in projection is
	// deterministic: user cards append after the built-ins (usertheme.go).
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	cat := themeCatalog()
	if len(cat) != len(themeCatalogNames)+2 {
		t.Fatalf("catalog has %d cards, want %d", len(cat), len(themeCatalogNames)+2)
	}

	// The two dynamic variants lead, carry a glyph, and no swatches.
	if cat[0].ID != "Default" || !cat[0].Dynamic || cat[0].Icon != "palette" || cat[0].Sw != nil {
		t.Fatalf("card 0 = %+v, want dynamic Default/palette with no swatches", cat[0])
	}
	if cat[1].ID != "Wallpaper" || !cat[1].Dynamic || cat[1].Icon != "wallpaper" || cat[1].Sw != nil {
		t.Fatalf("card 1 = %+v, want dynamic Wallpaper/wallpaper with no swatches", cat[1])
	}

	// Static cards follow in catalog order, each a valid seven-swatch preview
	// whose colours are its palette's roles, with a computed dark flag.
	for i, name := range themeCatalogNames {
		card := cat[i+2]
		if card.ID != name {
			t.Fatalf("card %d id = %q, want %q (order must match themeCatalogNames)", i+2, card.ID, name)
		}
		if card.Dynamic {
			t.Fatalf("%s: static theme marked dynamic", name)
		}
		if card.Label == "" {
			t.Fatalf("%s: empty label", name)
		}
		pal := themePalettes[name]
		if len(card.Sw) != len(themeSwatchRoles) {
			t.Fatalf("%s: %d swatches, want %d", name, len(card.Sw), len(themeSwatchRoles))
		}
		for j, role := range themeSwatchRoles {
			if !hexColor.MatchString(card.Sw[j]) {
				t.Fatalf("%s: swatch %d = %q is not a hex colour", name, j, card.Sw[j])
			}
			if card.Sw[j] != pal[role] {
				t.Fatalf("%s: swatch %d (%s) = %q, want palette role %q", name, j, role, card.Sw[j], pal[role])
			}
		}
		luma, ok := hexLuma(pal["surface"])
		if wantDark := !ok || luma < 0.5; card.Dark != wantDark {
			t.Fatalf("%s: dark = %v, want %v (surface %s luma %.3f)", name, card.Dark, wantDark, pal["surface"], luma)
		}
	}

	// Spot checks: an accented label and a known light theme.
	byID := map[string]themeCard{}
	for _, c := range cat {
		byID[c.ID] = c
	}
	if got := byID["Rose Pine"].Label; got != "Ros\u00e9 Pine" {
		t.Fatalf("Rose Pine label = %q, want %q", got, "Ros\u00e9 Pine")
	}
	if byID["Catppuccin Latte"].Dark {
		t.Fatalf("Catppuccin Latte marked dark; its surface is light")
	}
	if byID["Bauhaus"].Sw[2] != "#E37B66" {
		t.Fatalf("Bauhaus primary swatch = %q, want #E37B66", byID["Bauhaus"].Sw[2])
	}
}

// TestThemeCatalogJSONValid confirms the CLI output is well-formed JSON the
// switcher can parse.
func TestThemeCatalogJSONValid(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	var cards []themeCard
	if err := json.Unmarshal([]byte(themeCatalogJSON()), &cards); err != nil {
		t.Fatalf("theme catalog JSON does not round-trip: %v", err)
	}
	if len(cards) != len(themeCatalogNames)+2 {
		t.Fatalf("round-tripped %d cards, want %d", len(cards), len(themeCatalogNames)+2)
	}
}

// TestThemeApplyByCatalogID proves the apply path the daemon's `theme` command
// drives: every catalog id is a valid theme.theme the settings store accepts,
// and an id outside the catalog is rejected.
func TestThemeApplyByCatalogID(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	path := filepath.Join(t.TempDir(), "shell.json")
	if err := os.WriteFile(path, []byte(`{}`), 0o644); err != nil {
		t.Fatal(err)
	}
	s := newSettingsStore(path)

	for _, card := range themeCatalog() {
		name, _ := json.Marshal(card.ID)
		if err := s.patch("theme.theme", name); err != nil {
			t.Fatalf("apply %q: %v", card.ID, err)
		}
	}

	bad, _ := json.Marshal("Not A Real Theme")
	if err := s.patch("theme.theme", bad); err == nil {
		t.Fatalf("apply of an unknown theme was accepted; want rejection")
	}
}
