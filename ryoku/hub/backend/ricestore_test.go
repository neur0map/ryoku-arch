package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// the store registry parses into entries with their raw in-repo paths intact.
func TestParseRiceRegistry(t *testing.T) {
	raw := []byte(`{"version":1,"rices":[
		{"id":"lofi","name":"Lofi","createdWith":"0.6.8","color":"fixed","poster":"rices/lofi/poster.png","tags":["pixel"]}
	]}`)
	es, err := parseRiceRegistry(raw)
	if err != nil {
		t.Fatal(err)
	}
	if len(es) != 1 || es[0].ID != "lofi" {
		t.Fatalf("entries = %v, want one lofi", es)
	}
	if es[0].Poster != "rices/lofi/poster.png" {
		t.Fatalf("poster = %q", es[0].Poster)
	}
}

// publishRice lays a local rice into the store structure (manifest, poster,
// palette) and upserts its registry entry; a second publish replaces rather
// than duplicates it.
func TestPublishRice(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)

	if err := os.MkdirAll(filepath.Join(ricesDir(), "cool"), 0o755); err != nil {
		t.Fatal(err)
	}
	os.WriteFile(filepath.Join(ricesDir(), "cool", "palette.json"), []byte(`{"background":"#101010"}`), 0o644)
	os.WriteFile(filepath.Join(ricesDir(), "cool", "preview.png"), []byte("PNG"), 0o644)
	r := Rice{Schema: 1, Slug: "cool", Name: "Cool", CreatedWith: "0.6.8", Color: RiceColor{Mode: "fixed", Palette: "palette.json"}}
	if err := saveRice(r); err != nil {
		t.Fatal(err)
	}

	store := t.TempDir()
	if err := publishRice("cool", store); err != nil {
		t.Fatal(err)
	}

	for _, f := range []string{"rice.json", "poster.png", "palette.json"} {
		if !isFile(filepath.Join(store, "rices", "cool", f)) {
			t.Fatalf("store is missing rices/cool/%s", f)
		}
	}

	b, err := os.ReadFile(filepath.Join(store, "rices", "registry.json"))
	if err != nil {
		t.Fatal(err)
	}
	var reg riceRegistry
	if err := json.Unmarshal(b, &reg); err != nil {
		t.Fatal(err)
	}
	if len(reg.Rices) != 1 || reg.Rices[0].ID != "cool" {
		t.Fatalf("registry = %v, want one cool", reg.Rices)
	}
	if reg.Rices[0].Color != "fixed" || reg.Rices[0].Poster != "rices/cool/poster.png" {
		t.Fatalf("entry = %+v", reg.Rices[0])
	}

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
