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

var _ variantInstaller = flatImageProvider{}

func decorFixture(t *testing.T) flatImageProvider {
	t.Helper()
	files := map[string]string{
		"/decors/registry.json":                 `{"schema":1,"decors":[{"id":"demo-decor","name":"Demo Decor","version":"1.0.0","author":"Ryoku","summary":"A demo specimen.","description":"A demo specimen for tests.","path":"decors/demo-decor","preview":"assets/preview.webp","previewRaw":"assets/preview-raw.webp","manifest":"manifest.json","manifestSha256":"` + strings.Repeat("a", 64) + `","tags":["test"],"screenshots":[],"accent":"#d7a45f","surface":"#101010"}]}`,
		"/decors/demo-decor/content/source.png": "rawbytes",
		"/decors/demo-decor/content/dither.png": "ditherbytes",
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if body, ok := files[r.URL.Path]; ok {
			_, _ = w.Write([]byte(body))
			return
		}
		http.NotFound(w, r)
	}))
	t.Cleanup(srv.Close)
	t.Setenv("HOME", t.TempDir())
	return flatImageProvider{
		category: Category{ID: "decors"},
		cache:    &Cache{client: srv.Client(), base: srv.URL, dir: filepath.Join(t.TempDir(), "cache"), memo: map[string]memoEntry{}},
		dirPath:  filepath.Join(os.Getenv("HOME"), "Pictures", "ryodecors"),
	}
}

func TestDecorInstallVariantLandsFlatFile(t *testing.T) {
	p := decorFixture(t)
	installed := p.installedPath("demo-decor")

	items, _, err := p.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].ID != "demo-decor" {
		t.Fatalf("load = %+v", items)
	}
	if !strings.HasSuffix(items[0].ArtRaw, "decors/demo-decor/assets/preview-raw.webp") {
		t.Fatalf("decor ArtRaw not resolved from previewRaw: %q", items[0].ArtRaw)
	}
	if items[0].Installed {
		t.Fatal("decor reported installed before any install")
	}

	// Raw install lands the source variant at <id>.png in the gallery folder.
	if err := p.Install(context.Background(), "demo-decor"); err != nil {
		t.Fatal(err)
	}
	if got := readFile(t, installed); got != "rawbytes" {
		t.Fatalf("raw install content = %q, want rawbytes", got)
	}
	items, _, err = p.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if !items[0].Installed || items[0].InstalledVersion != "1.0.0" {
		t.Fatalf("decor not reported installed after install: %+v", items[0])
	}

	// The dither toggle overwrites the same flat file with the baked variant.
	if err := p.InstallVariant(context.Background(), "demo-decor", true); err != nil {
		t.Fatal(err)
	}
	if got := readFile(t, installed); got != "ditherbytes" {
		t.Fatalf("dither install content = %q, want ditherbytes", got)
	}

	// Removal deletes the owned file and clears the installed state.
	if err := p.Remove(context.Background(), "demo-decor"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(installed); !os.IsNotExist(err) {
		t.Fatalf("installed file survived removal: %v", err)
	}
	items, _, err = p.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if items[0].Installed {
		t.Fatal("decor still reported installed after removal")
	}
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	return string(data)
}
