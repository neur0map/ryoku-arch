package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

type fastfetchProviderFixture struct {
	cache     *Cache
	entries   []ProductEntry
	configs   map[string][]byte
	responses map[string][]byte
}

func newFastfetchProviderFixture(t *testing.T) fastfetchProviderFixture {
	t.Helper()
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(t.TempDir(), "config"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(t.TempDir(), "data"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(t.TempDir(), "state"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(t.TempDir(), "cache"))

	configs := map[string][]byte{
		"ryoku-dossier": []byte("{\n  \"logo\": {\"type\": \"none\"},\n  \"modules\": [\"os\", \"kernel\"]\n}\n"),
		"minimal-grid":  []byte("{\n  \"logo\": {\"type\": \"none\"},\n  \"modules\": [\"os\", \"memory\"]\n}\n"),
	}
	responses := make(map[string][]byte)
	entries := make([]ProductEntry, 0, len(configs))
	for _, id := range []string{"ryoku-dossier", "minimal-grid"} {
		body := configs[id]
		bodyHash := sha256.Sum256(body)
		manifest := ProductManifest{
			Schema: 1, ID: id, Category: "fastfetch", Version: "1.0.0",
			Destination: filepath.ToSlash(filepath.Join("ryoku", "fastfetch", id)),
			Files: []ProductFile{{
				Source: "config.jsonc", Destination: "config.jsonc", Mode: "0644",
				Size: int64(len(body)), SHA256: fmt.Sprintf("%x", bodyHash), Install: true,
			}},
		}
		manifestRaw, err := json.Marshal(manifest)
		if err != nil {
			t.Fatal(err)
		}
		manifestHash := sha256.Sum256(manifestRaw)
		entry := ProductEntry{
			ID: id, Name: id, Version: "1.0.0", Path: "fastfetch/" + id,
			Author: "Ryoku Team", Summary: "Terminal style", Description: "A complete Fastfetch config.",
			Tags: []string{"terminal"}, Accent: "#68c7c1", Surface: "#0b1115",
			Preview: "preview.webp", Screenshots: []string{}, Manifest: "manifest.json",
			ManifestSHA256: fmt.Sprintf("%x", manifestHash),
		}
		entries = append(entries, entry)
		responses["/fastfetch/"+id+"/manifest.json"] = manifestRaw
		responses["/fastfetch/"+id+"/config.jsonc"] = body
	}
	registryRaw, err := json.Marshal(map[string]any{"schema": 1, "fastfetch": entries})
	if err != nil {
		t.Fatal(err)
	}
	responses["/fastfetch/registry.json"] = registryRaw

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, ok := responses[r.URL.Path]
		if !ok {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write(body)
	}))
	t.Cleanup(server.Close)
	return fastfetchProviderFixture{
		cache:     &Cache{client: server.Client(), base: server.URL, dir: t.TempDir(), memo: map[string]memoEntry{}},
		entries:   entries,
		configs:   configs,
		responses: responses,
	}
}

func (fixture *fastfetchProviderFixture) publish(t *testing.T, id, version string, body []byte) {
	t.Helper()
	var index int
	for i := range fixture.entries {
		if fixture.entries[i].ID == id {
			index = i
			break
		}
	}
	bodyHash := sha256.Sum256(body)
	manifest := ProductManifest{
		Schema: 1, ID: id, Category: "fastfetch", Version: version,
		Destination: filepath.ToSlash(filepath.Join("ryoku", "fastfetch", id)),
		Files: []ProductFile{{
			Source: "config.jsonc", Destination: "config.jsonc", Mode: "0644",
			Size: int64(len(body)), SHA256: fmt.Sprintf("%x", bodyHash), Install: true,
		}},
	}
	manifestRaw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	manifestHash := sha256.Sum256(manifestRaw)
	fixture.entries[index].Version = version
	fixture.entries[index].ManifestSHA256 = fmt.Sprintf("%x", manifestHash)
	registryRaw, err := json.Marshal(map[string]any{"schema": 1, "fastfetch": fixture.entries})
	if err != nil {
		t.Fatal(err)
	}
	fixture.responses["/fastfetch/registry.json"] = registryRaw
	fixture.responses["/fastfetch/"+id+"/manifest.json"] = manifestRaw
	fixture.responses["/fastfetch/"+id+"/config.jsonc"] = body
	fixture.cache.dir = t.TempDir()
	fixture.cache.memo = map[string]memoEntry{}
}

func TestFastfetchProviderUsesRegistryReceiptsAndExplicitApply(t *testing.T) {
	fixture := newFastfetchProviderFixture(t)
	configPath := filepath.Join(configHome(), "fastfetch", "config.jsonc")
	if err := os.MkdirAll(filepath.Dir(configPath), 0o755); err != nil {
		t.Fatal(err)
	}
	original := []byte("{\"modules\":[\"title\"]}\n")
	if err := os.WriteFile(configPath, original, 0o644); err != nil {
		t.Fatal(err)
	}
	provider := fastfetchProvider{cache: fixture.cache, configPath: configPath}

	items, _, err := provider.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 2 || items[0].Installed || items[1].Installed {
		t.Fatalf("initial items = %+v", items)
	}
	if items[0].Art == "" || items[0].Manifest == "" {
		t.Fatalf("missing external metadata: %+v", items[0])
	}

	if err := provider.Install(context.Background(), "ryoku-dossier"); err != nil {
		t.Fatal(err)
	}
	if raw, err := os.ReadFile(configPath); err != nil || string(raw) != string(original) {
		t.Fatalf("install changed editable config: %q, err=%v", raw, err)
	}
	if err := applyFastfetchStyle("ryoku-dossier"); err != nil {
		t.Fatal(err)
	}
	if raw, err := os.ReadFile(configPath); err != nil || string(raw) != string(fixture.configs["ryoku-dossier"]) {
		t.Fatalf("applied config = %q, err=%v", raw, err)
	}
	items, _, err = provider.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if !items[0].Installed || !items[0].Active || items[1].Active {
		t.Fatalf("applied items = %+v", items)
	}
	updated := []byte("{\n  \"logo\": {\"type\": \"none\"},\n  \"modules\": [\"os\", \"kernel\", \"uptime\"]\n}\n")
	fixture.publish(t, "ryoku-dossier", "2.0.0", updated)
	if err := provider.Install(context.Background(), "ryoku-dossier"); err != nil {
		t.Fatal(err)
	}
	if raw, err := os.ReadFile(configPath); err != nil || string(raw) != string(fixture.configs["ryoku-dossier"]) {
		t.Fatalf("update changed editable config: %q, err=%v", raw, err)
	}
	items, _, err = provider.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if !items[0].Installed || items[0].InstalledVersion != "2.0.0" || items[0].Active {
		t.Fatalf("updated item = %+v", items[0])
	}

	if err := provider.Remove(context.Background(), "ryoku-dossier"); err != nil {
		t.Fatal(err)
	}
	if raw, err := os.ReadFile(configPath); err != nil || string(raw) != string(fixture.configs["ryoku-dossier"]) {
		t.Fatalf("remove changed editable config: %q, err=%v", raw, err)
	}
}

func TestApplyFastfetchStyleRequiresValidReceiptOwnedConfig(t *testing.T) {
	fixture := newFastfetchProviderFixture(t)
	if err := applyFastfetchStyle("minimal-grid"); err == nil {
		t.Fatal("uninstalled style was applied")
	}
	provider := fastfetchProvider{cache: fixture.cache, configPath: filepath.Join(configHome(), "fastfetch", "config.jsonc")}
	if err := provider.Install(context.Background(), "minimal-grid"); err != nil {
		t.Fatal(err)
	}
	dst, _, err := productDestination("fastfetch", "minimal-grid")
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dst, "config.jsonc"), []byte("corrupt"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := applyFastfetchStyle("minimal-grid"); err == nil {
		t.Fatal("corrupt installed style was applied")
	}
}

func TestFastfetchProviderTreatsMissingRegistryAsSourceError(t *testing.T) {
	server := httptest.NewServer(http.NotFoundHandler())
	defer server.Close()
	cache := &Cache{client: server.Client(), base: server.URL, dir: t.TempDir(), memo: map[string]memoEntry{}}
	if _, _, err := (fastfetchProvider{cache: cache}).Load(context.Background(), false); err == nil {
		t.Fatal("missing registry was accepted as an empty catalogue")
	}
}
