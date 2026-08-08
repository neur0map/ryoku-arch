package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func riceFixtureServer(t *testing.T, missingWallpaper bool) *httptest.Server {
	t.Helper()
	files := map[string]string{
		"/rices/registry.json":            `{"version":1,"rices":[{"id":"demo","name":"Demo Rice","author":"Ryoku","blurb":"A deliberate desktop look","tags":["warm"],"createdWith":"0.19.4","color":"fixed","manifest":"rices/demo/rice.json","preview":"assets/preview.webp","screenshots":["assets/shot.png"],"palette":"rices/demo/palette.json","wallpaper":"rices/demo/wall.png","hero":"rices/demo/hero.png","accent":"#d75f5f","surface":"#101010","rounding":14}]}`,
		"/rices/demo/rice.json":           `{"schema":1,"slug":"demo","name":"Demo Rice","createdWith":"0.19.4","color":{"mode":"fixed","palette":"palette.json"},"assets":{"wallpaper":"wall.png","hero":"hero.png"},"look":{}}`,
		"/rices/demo/palette.json":        `{"background":"#101010"}`,
		"/rices/demo/assets/preview.webp": "preview",
		"/rices/demo/assets/shot.png":     "shot",
		"/rices/demo/wall.png":            "wallpaper",
		"/rices/demo/hero.png":            "hero",
	}
	if missingWallpaper {
		delete(files, "/rices/demo/wall.png")
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if body, ok := files[r.URL.Path]; ok {
			_, _ = w.Write([]byte(body))
			return
		}
		http.NotFound(w, r)
	}))
	t.Cleanup(srv.Close)
	return srv
}

func testRiceProvider(t *testing.T, srv *httptest.Server) riceProvider {
	t.Helper()
	root := t.TempDir()
	return riceProvider{
		cache: &Cache{
			client: srv.Client(),
			base:   srv.URL,
			dir:    filepath.Join(root, "cache"),
			memo:   map[string]memoEntry{},
		},
		downloadClient: srv.Client(),
		base:           srv.URL,
		ricesDir:       filepath.Join(root, "rices"),
		activePath:     filepath.Join(root, "rices", ".active"),
		runningVersion: func() string { return "0.19.1" },
	}
}

func TestRiceProviderNormalizesInstalledActiveAndAssets(t *testing.T) {
	srv := riceFixtureServer(t, false)
	p := testRiceProvider(t, srv)
	installed := filepath.Join(p.ricesDir, "demo")
	if err := os.MkdirAll(installed, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(installed, "rice.json"), []byte(`{}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p.activePath, []byte("demo\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	items, state, err := p.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if state.Offline || len(items) != 1 {
		t.Fatalf("state=%+v items=%+v", state, items)
	}
	item := items[0]
	if item.ID != "demo" || !item.Installed || !item.Active || item.Compatibility != "ok" {
		t.Fatalf("state normalization = %+v", item)
	}
	if item.Art != srv.URL+"/rices/demo/assets/preview.webp" || len(item.Screenshots) != 1 {
		t.Fatalf("asset normalization = %+v", item)
	}
	if item.Metadata["color"] != "fixed" || item.Metadata["rounding"] != 14 || item.Metadata["accent"] != "#d75f5f" {
		t.Fatalf("metadata = %+v", item.Metadata)
	}
}

func TestRiceInstallIsAtomicAndDoesNotActivate(t *testing.T) {
	srv := riceFixtureServer(t, false)
	p := testRiceProvider(t, srv)
	if err := os.MkdirAll(filepath.Dir(p.activePath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p.activePath, []byte("old-rice\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := p.Install(context.Background(), "demo"); err != nil {
		t.Fatal(err)
	}
	for path, want := range map[string]string{
		"rice.json":    `"slug":"demo"`,
		"palette.json": `"background":"#101010"`,
		"wall.png":     "wallpaper",
		"hero.png":     "hero",
	} {
		b, err := os.ReadFile(filepath.Join(p.ricesDir, "demo", path))
		if err != nil || !strings.Contains(string(b), want) {
			t.Fatalf("%s = %q, err=%v", path, b, err)
		}
	}
	active, err := os.ReadFile(p.activePath)
	if err != nil || string(active) != "old-rice\n" {
		t.Fatalf("install changed active rice: %q err=%v", active, err)
	}
}

func TestRiceInstallMissingWallpaperLeavesNoManifest(t *testing.T) {
	srv := riceFixtureServer(t, true)
	p := testRiceProvider(t, srv)
	if err := p.Install(context.Background(), "demo"); err == nil {
		t.Fatal("install succeeded without its required wallpaper")
	}
	if _, err := os.Stat(filepath.Join(p.ricesDir, "demo", "rice.json")); !os.IsNotExist(err) {
		t.Fatalf("failed install left rice.json: %v", err)
	}
}

func TestRiceInstallRejectsMismatchedManifest(t *testing.T) {
	files := map[string]string{
		"/rices/registry.json":  `{"version":1,"rices":[{"id":"demo","name":"Demo","manifest":"rices/demo/rice.json"}]}`,
		"/rices/demo/rice.json": `{"schema":1,"slug":"another","name":"Wrong","assets":{}}`,
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if body, ok := files[r.URL.Path]; ok {
			_, _ = w.Write([]byte(body))
			return
		}
		http.NotFound(w, r)
	}))
	defer srv.Close()
	p := testRiceProvider(t, srv)
	if err := p.Install(context.Background(), "demo"); err == nil {
		t.Fatal("install accepted a manifest for another rice")
	}
	if _, err := os.Stat(filepath.Join(p.ricesDir, "demo", "rice.json")); !os.IsNotExist(err) {
		t.Fatalf("failed install left rice.json: %v", err)
	}
}

func TestRiceInstallRejectsTraversingAssetPath(t *testing.T) {
	files := map[string]string{
		"/rices/registry.json":  `{"version":1,"rices":[{"id":"demo","name":"Demo","manifest":"rices/demo/rice.json","wallpaper":"rices/demo/wall.png"}]}`,
		"/rices/demo/rice.json": `{"schema":1,"slug":"demo","name":"Demo","assets":{"wallpaper":"../outside.png"}}`,
		"/rices/demo/wall.png":  "wallpaper",
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if body, ok := files[r.URL.Path]; ok {
			_, _ = w.Write([]byte(body))
			return
		}
		http.NotFound(w, r)
	}))
	defer srv.Close()
	p := testRiceProvider(t, srv)
	if err := p.Install(context.Background(), "demo"); err == nil {
		t.Fatal("install accepted a traversing wallpaper path")
	}
	if _, err := os.Stat(filepath.Join(p.ricesDir, "outside.png")); !os.IsNotExist(err) {
		t.Fatalf("install wrote outside its rice directory: %v", err)
	}
}

func TestRiceInstallFetchesBundledDecorAndBrandAssets(t *testing.T) {
	files := map[string]string{
		"/rices/registry.json":     `{"version":1,"rices":[{"id":"demo","name":"Demo","manifest":"rices/demo/rice.json","palette":"rices/demo/palette.json","wallpaper":"rices/demo/wall.png"}]}`,
		"/rices/demo/rice.json":    `{"schema":1,"slug":"demo","name":"Demo","color":{"palette":"palette.json"},"assets":{"wallpaper":"wall.png"},"look":{"decor":[{"src":"rice://decor-x.png"}]},"layers":{"brand":{"markImage":"rice://mark.png"}}}`,
		"/rices/demo/palette.json": `{"background":"#101010"}`,
		"/rices/demo/wall.png":     "wallpaper",
		"/rices/demo/decor-x.png":  "decor-art",
		"/rices/demo/mark.png":     "brand-mark",
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if body, ok := files[r.URL.Path]; ok {
			_, _ = w.Write([]byte(body))
			return
		}
		http.NotFound(w, r)
	}))
	defer srv.Close()
	p := testRiceProvider(t, srv)
	if err := p.Install(context.Background(), "demo"); err != nil {
		t.Fatal(err)
	}
	for path, want := range map[string]string{
		"decor-x.png": "decor-art",
		"mark.png":    "brand-mark",
	} {
		b, err := os.ReadFile(filepath.Join(p.ricesDir, "demo", path))
		if err != nil || string(b) != want {
			t.Fatalf("bundled asset %s = %q, err=%v", path, b, err)
		}
	}
}

func TestRiceInstallSkipsMissingBundledAsset(t *testing.T) {
	files := map[string]string{
		"/rices/registry.json":     `{"version":1,"rices":[{"id":"demo","name":"Demo","manifest":"rices/demo/rice.json","palette":"rices/demo/palette.json","wallpaper":"rices/demo/wall.png"}]}`,
		"/rices/demo/rice.json":    `{"schema":1,"slug":"demo","name":"Demo","color":{"palette":"palette.json"},"assets":{"wallpaper":"wall.png"},"look":{"decor":[{"src":"rice://gone.png"}]}}`,
		"/rices/demo/palette.json": `{"background":"#101010"}`,
		"/rices/demo/wall.png":     "wallpaper",
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if body, ok := files[r.URL.Path]; ok {
			_, _ = w.Write([]byte(body))
			return
		}
		http.NotFound(w, r)
	}))
	defer srv.Close()
	p := testRiceProvider(t, srv)
	if err := p.Install(context.Background(), "demo"); err != nil {
		t.Fatalf("missing optional decor asset failed the install: %v", err)
	}
	if _, err := os.Stat(filepath.Join(p.ricesDir, "demo", "rice.json")); err != nil {
		t.Fatalf("install did not complete: %v", err)
	}
	if _, err := os.Stat(filepath.Join(p.ricesDir, "demo", "gone.png")); !os.IsNotExist(err) {
		t.Fatalf("missing asset unexpectedly present: %v", err)
	}
}
