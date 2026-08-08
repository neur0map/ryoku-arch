package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

const csRegistry = `{"version":1,"themes":[
  {"id":"noctalia-adw","name":"ADW","provider":"Noctalia","path":"colorschemes/ADW","accent":"#3584e4","surface":"#242424",
   "dark":{"mPrimary":"#3584e4","mOnPrimary":"#ffffff","mSecondary":"#1b467c","mOnSecondary":"#ffffff","mTertiary":"#ffffff","mOnTertiary":"#2e3436","mError":"#c01c28","mOnError":"#ffffff","mSurface":"#242424","mOnSurface":"#ffffff","mSurfaceVariant":"#1e1e1e","mOnSurfaceVariant":"#ffffff","mOutline":"#3d3846","mShadow":"#000000"},
   "light":{"mPrimary":"#3584e4","mSurface":"#fafafa","mOnSurface":"#2e3436","mOnPrimary":"#ffffff","mOutline":"#d6d6d6"}},
  {"id":"hancore-kanso","name":"Kanso","provider":"HANCORE-linux","path":"colorschemes/hancore-kanso","accent":"#8ba4b0","surface":"#090e13",
   "source":"https://github.com/HANCORE-linux/omarchy-kanso-theme","preview":"https://raw.githubusercontent.com/HANCORE-linux/omarchy-kanso-theme/master/preview.png",
   "dark":{"mPrimary":"#8ba4b0","mOnPrimary":"#090e13","mSecondary":"#8a9a7b","mOnSecondary":"#090e13","mTertiary":"#c4b28a","mOnTertiary":"#090e13","mError":"#c4746e","mOnError":"#090e13","mSurface":"#090e13","mOnSurface":"#c5c9c7","mSurfaceVariant":"#161b22","mOnSurfaceVariant":"#c8c093","mOutline":"#a292a3","mShadow":"#000000"}}
]}`

func csFixtureServer(t *testing.T) *httptest.Server {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/colorschemes/registry.json" {
			_, _ = w.Write([]byte(csRegistry))
			return
		}
		http.NotFound(w, r)
	}))
	t.Cleanup(srv.Close)
	return srv
}

func testColorschemeProvider(t *testing.T, srv *httptest.Server, active string) colorschemeProvider {
	t.Helper()
	root := t.TempDir()
	return colorschemeProvider{
		cache: &Cache{
			client: srv.Client(),
			base:   srv.URL,
			dir:    filepath.Join(root, "cache"),
			memo:   map[string]memoEntry{},
		},
		base:       srv.URL,
		libraryDir: filepath.Join(root, "themes"),
		activeName: func() string { return active },
	}
}

func TestColorschemeLoadNormalizes(t *testing.T) {
	p := testColorschemeProvider(t, csFixtureServer(t), "")
	items, _, err := p.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 2 {
		t.Fatalf("got %d items, want 2", len(items))
	}
	byID := map[string]Item{}
	for _, it := range items {
		byID[it.ID] = it
	}
	adw := byID["noctalia-adw"]
	if adw.Metadata["provider"] != "Noctalia" || adw.Category != "colorschemes" {
		t.Fatalf("adw meta = %+v", adw)
	}
	if len(adw.Tags) != 2 { // dark + light
		t.Fatalf("adw tags = %v, want dark+light", adw.Tags)
	}
	kanso := byID["hancore-kanso"]
	if kanso.Metadata["provider"] != "HANCORE-linux" {
		t.Fatalf("kanso provider = %v", kanso.Metadata["provider"])
	}
	if kanso.Art != "https://raw.githubusercontent.com/HANCORE-linux/omarchy-kanso-theme/master/preview.png" {
		t.Fatalf("kanso art (absolute preview) = %q", kanso.Art)
	}
	if len(kanso.Tags) != 1 || kanso.Tags[0] != "dark" {
		t.Fatalf("kanso tags = %v, want [dark]", kanso.Tags)
	}
	if adw.Installed || kanso.Installed {
		t.Fatal("nothing should read installed before install")
	}
}

func TestColorschemeInstallRemoveAndActive(t *testing.T) {
	p := testColorschemeProvider(t, csFixtureServer(t), "hancore-kanso")
	ctx := context.Background()

	if err := p.Install(ctx, "hancore-kanso"); err != nil {
		t.Fatal(err)
	}
	dir := filepath.Join(p.libraryDir, "hancore-kanso")
	schemeRaw, err := os.ReadFile(filepath.Join(dir, "scheme.json"))
	if err != nil {
		t.Fatalf("scheme.json not written: %v", err)
	}
	var scheme map[string]map[string]any
	if err := json.Unmarshal(schemeRaw, &scheme); err != nil {
		t.Fatalf("scheme.json invalid: %v", err)
	}
	if _, ok := scheme["dark"]; !ok {
		t.Fatal("scheme.json missing dark block")
	}
	if _, ok := scheme["light"]; ok {
		t.Fatal("kanso has no light block; scheme.json must not invent one")
	}
	if scheme["dark"]["mPrimary"] != "#8ba4b0" {
		t.Fatalf("dark mPrimary = %v", scheme["dark"]["mPrimary"])
	}
	metaRaw, err := os.ReadFile(filepath.Join(dir, "meta.json"))
	if err != nil {
		t.Fatal(err)
	}
	var meta map[string]any
	_ = json.Unmarshal(metaRaw, &meta)
	if meta["label"] != "Kanso" || meta["provider"] != "HANCORE-linux" || meta["source"] == nil {
		t.Fatalf("meta.json = %v", meta)
	}

	// Re-load: installed, and active because the fixture reports it worn.
	items, _, err := p.Load(ctx, false)
	if err != nil {
		t.Fatal(err)
	}
	for _, it := range items {
		if it.ID == "hancore-kanso" && (!it.Installed || !it.Active) {
			t.Fatalf("worn scheme not installed/active: %+v", it)
		}
	}

	// Remove clears it; a second remove errors.
	if err := p.Remove(ctx, "hancore-kanso"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Fatal("library dir survived remove")
	}
	if err := p.Remove(ctx, "hancore-kanso"); err == nil {
		t.Fatal("remove of an uninstalled scheme should error")
	}
}

func TestColorschemeInstallRejectsUnknown(t *testing.T) {
	p := testColorschemeProvider(t, csFixtureServer(t), "")
	if err := p.Install(context.Background(), "not-a-scheme"); err == nil {
		t.Fatal("install of an unlisted id should error")
	}
	if err := p.Install(context.Background(), "../escape"); err == nil {
		t.Fatal("install of a traversing id should error")
	}
}
