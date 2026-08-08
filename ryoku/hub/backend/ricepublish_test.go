package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"testing"
)

// publishRice lays a local rice into the store as a v1 product (a rice.json
// manifest with a files[] payload table + display art) and upserts its registry
// entry; a second publish replaces rather than duplicates it.
func TestPublishRice(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)

	if err := os.MkdirAll(filepath.Join(ricesDir(), "cool"), 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(ricesDir(), "cool", "palette.json"), []byte(`{"primary":"#aabbcc","surface":"#112233"}`), 0o644)
	os.WriteFile(filepath.Join(ricesDir(), "cool", "preview.png"), []byte("PNG-preview-bytes"), 0o644)
	r := Rice{
		Schema: 1, Slug: "cool", Name: "Cool", Author: "Tester",
		Blurb: "A cool test rice.", CreatedWith: "0.6.8",
		Color: RiceColor{Mode: "fixed", Palette: "palette.json"},
		Look: map[string]map[string]any{
			"hypr":  {"appearance": map[string]any{"activeBorder": "#aabbcc", "rounding": float64(8)}},
			"shell": {"surfaceColor": "#112233"},
		},
	}
	if err := saveRice(r); err != nil {
		t.Fatal(err)
	}

	store := t.TempDir()
	if err := publishRice("cool", store); err != nil {
		t.Fatal(err)
	}
	product := filepath.Join(store, "rices", "cool")

	// the product is laid out: manifest + preview art + poster + palette.
	for _, f := range []string{"rice.json", "assets/preview.webp", "poster.png", "palette.json"} {
		if !isFile(filepath.Join(product, filepath.FromSlash(f))) {
			t.Fatalf("store is missing rices/cool/%s", f)
		}
	}

	// registry: schema-1 envelope, one entry, required fields populated.
	b, err := os.ReadFile(filepath.Join(store, "rices", "registry.json"))
	if err != nil {
		t.Fatal(err)
	}
	var reg riceRegistry
	if err := json.Unmarshal(b, &reg); err != nil {
		t.Fatal(err)
	}
	if reg.Schema != 1 {
		t.Fatalf("registry schema = %d, want 1", reg.Schema)
	}
	if len(reg.Rices) != 1 || reg.Rices[0].ID != "cool" {
		t.Fatalf("registry = %+v, want one cool", reg.Rices)
	}
	e := reg.Rices[0]
	for name, val := range map[string]string{
		"name": e.Name, "version": e.Version, "path": e.Path, "author": e.Author,
		"summary": e.Summary, "description": e.Description, "accent": e.Accent,
		"surface": e.Surface, "preview": e.Preview, "manifest": e.Manifest,
		"manifestSha256": e.ManifestSha256,
	} {
		if val == "" {
			t.Fatalf("registry entry required field %q is empty", name)
		}
	}
	if e.Path != "rices/cool" || e.Preview != "assets/preview.webp" || e.Manifest != "rice.json" {
		t.Fatalf("entry paths = %+v", e)
	}
	if e.Color != "fixed" || e.Palette != "rices/cool/palette.json" {
		t.Fatalf("entry color/palette = %q/%q", e.Color, e.Palette)
	}
	if e.Accent != "#aabbcc" || e.Surface != "#112233" || e.Rounding != 8 {
		t.Fatalf("entry look = %q/%q/%d", e.Accent, e.Surface, e.Rounding)
	}
	if e.Tags == nil || e.Screenshots == nil {
		t.Fatalf("tags/screenshots must be non-nil arrays: %+v", e)
	}

	// manifest: the store envelope matches the entry and files[] hashes are real.
	mb, err := os.ReadFile(filepath.Join(product, "rice.json"))
	if err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(mb)
	if got := hex.EncodeToString(sum[:]); got != e.ManifestSha256 {
		t.Fatalf("manifestSha256 = %s, want %s", e.ManifestSha256, got)
	}
	var man riceManifest
	if err := json.Unmarshal(mb, &man); err != nil {
		t.Fatal(err)
	}
	if man.Schema != 1 || man.ID != "cool" || man.Category != "rices" || man.Version != e.Version {
		t.Fatalf("manifest envelope mismatch = %+v", man)
	}
	if man.Destination != "ryoku/rices/cool" {
		t.Fatalf("manifest destination = %q", man.Destination)
	}
	if len(man.Files) == 0 {
		t.Fatal("manifest files[] is empty")
	}
	hex64 := regexp.MustCompile(`^[0-9a-f]{64}$`)
	install := map[string]bool{}
	for _, f := range man.Files {
		if f.Source != f.Destination {
			t.Fatalf("files[] source != destination: %+v", f)
		}
		if !hex64.MatchString(f.Sha256) {
			t.Fatalf("files[] sha256 not lowercase hex64: %+v", f)
		}
		if f.Mode != "0644" && f.Mode != "0755" {
			t.Fatalf("files[] bad mode: %+v", f)
		}
		fi, err := os.Stat(filepath.Join(product, filepath.FromSlash(f.Source)))
		if err != nil {
			t.Fatalf("declared source missing on disk: %s", f.Source)
		}
		if fi.Size() != f.Size {
			t.Fatalf("files[] size mismatch for %s: declared %d, on disk %d", f.Source, f.Size, fi.Size())
		}
		install[f.Destination] = f.Install
	}
	// display art installs false; the real config payload installs true.
	if install["assets/preview.webp"] || install["poster.png"] {
		t.Fatalf("preview/poster must be install:false: %v", install)
	}
	if !install["palette.json"] {
		t.Fatalf("palette.json must be install:true: %v", install)
	}

	// a second publish upserts rather than duplicating.
	if err := publishRice("cool", store); err != nil {
		t.Fatal(err)
	}
	b2, _ := os.ReadFile(filepath.Join(store, "rices", "registry.json"))
	var reg2 riceRegistry
	if err := json.Unmarshal(b2, &reg2); err != nil {
		t.Fatal(err)
	}
	if len(reg2.Rices) != 1 {
		t.Fatalf("second publish duplicated: %d entries", len(reg2.Rices))
	}
}
