package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// extrasServer: tiny catalogue (registry + one bundle + one installer); flip
// `down` to fake the network dropping.
func extrasServer(t *testing.T) (*httptest.Server, *bool) {
	t.Helper()
	down := false
	files := map[string]string{
		"/bundles/registry.json": `{"version":1,"bundles":[
			{"id":"demo","name":"Demo","description":"A demo bundle.","sources":"pacman / script","path":"bundles/demo"}]}`,
		"/bundles/demo/bundle.json": `{"id":"demo","name":"Demo","description":"A demo bundle.",
			"preview":"assets/hero.png","screenshots":["assets/a.png","https://cdn.example/b.png"],"items":[
			{"type":"package","name":"cmatrix","detect":"cmatrix","summary":"rain","source":"official","tier":"core"},
			{"type":"script","name":"demo-cli","detect":"demo","summary":"a cli","source":"curl","tier":"optional","interactive":true}]}`,
		"/installers/demo-cli.sh": "#!/bin/bash\necho demo\n",
	}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if down {
			http.Error(w, "down", http.StatusServiceUnavailable)
			return
		}
		body, ok := files[r.URL.Path]
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Write([]byte(body))
	}))
	t.Cleanup(srv.Close)
	return srv, &down
}

func TestBuildCatalog(t *testing.T) {
	cache := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cache)
	srv, down := extrasServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	cat, err := buildCatalog()
	if err != nil {
		t.Fatalf("buildCatalog: %v", err)
	}
	bundles := cat["bundles"]
	if len(bundles) != 1 {
		t.Fatalf("want 1 bundle, got %d", len(bundles))
	}
	b := bundles[0]
	if b.ID != "demo" || b.Sources != "pacman / script" {
		t.Fatalf("registry metadata not carried through: %+v", b)
	}
	if len(b.Items) != 2 || b.Items[0].Name != "cmatrix" || b.Items[1].Type != "script" {
		t.Fatalf("items not resolved: %+v", b.Items)
	}
	if b.Preview != srv.URL+"/bundles/demo/assets/hero.png" {
		t.Fatalf("preview not resolved to a URL: %q", b.Preview)
	}
	if len(b.Screenshots) != 2 || b.Screenshots[0] != srv.URL+"/bundles/demo/assets/a.png" {
		t.Fatalf("relative screenshot not resolved: %+v", b.Screenshots)
	}
	if b.Screenshots[1] != "https://cdn.example/b.png" {
		t.Fatalf("absolute screenshot must pass through: %q", b.Screenshots[1])
	}
	if b.Items[0].Tier != "core" || b.Items[1].Tier != "optional" || !b.Items[1].Interactive {
		t.Fatalf("tier/interactive lost: %+v", b.Items)
	}

	// script installer should have been warmed into the cache.
	if _, err := os.Stat(filepath.Join(cache, "ryoku", "extras", "installers", "demo-cli.sh")); err != nil {
		t.Fatalf("installer not cached: %v", err)
	}

	// network down -> catalogue still resolves from the cache.
	*down = true
	cat2, err := buildCatalog()
	if err != nil {
		t.Fatalf("offline buildCatalog: %v", err)
	}
	if len(cat2["bundles"]) != 1 || len(cat2["bundles"][0].Items) != 2 {
		t.Fatalf("offline catalogue did not come from cache: %+v", cat2["bundles"])
	}
}

func TestEnsureInstaller(t *testing.T) {
	cache := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cache)
	srv, down := extrasServer(t)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	p, err := ensureInstaller("demo-cli")
	if err != nil {
		t.Fatalf("ensureInstaller: %v", err)
	}
	if want := filepath.Join(cache, "ryoku", "extras", "installers", "demo-cli.sh"); p != want {
		t.Fatalf("path = %q, want %q", p, want)
	}

	// offline but cached: still resolves.
	*down = true
	if _, err := ensureInstaller("demo-cli"); err != nil {
		t.Fatalf("offline ensureInstaller: %v", err)
	}
	// offline + never cached: clear error.
	if _, err := ensureInstaller("missing"); err == nil {
		t.Fatal("expected an error for an uncached, unreachable installer")
	}
}

// fetch must beat the GitHub raw CDN cache so a catalogue refresh always sees
// the latest push; else a freshly added addon stays invisible for minutes.
func TestFetchBustsCDNCache(t *testing.T) {
	got := make(chan string, 2)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if cc := r.Header.Get("Cache-Control"); cc != "no-cache" {
			t.Errorf("missing no-cache header, got %q", cc)
		}
		got <- r.URL.RawQuery
		w.Write([]byte("ok"))
	}))
	t.Cleanup(srv.Close)

	if _, err := fetch(srv.URL + "/plugins/registry.json"); err != nil {
		t.Fatalf("fetch: %v", err)
	}
	time.Sleep(time.Millisecond)
	if _, err := fetch(srv.URL + "/plugins/registry.json?keep=1"); err != nil {
		t.Fatalf("fetch: %v", err)
	}

	q1, q2 := <-got, <-got
	if q1 == "" {
		t.Fatalf("first fetch sent no cache-busting query")
	}
	if q1 == q2 {
		t.Fatalf("two fetches reused query %q; a CDN could serve a stale hit", q1)
	}
	if !strings.Contains(q2, "keep=1") {
		t.Fatalf("an existing query was dropped: %q", q2)
	}
}

func TestEnsureNautilusPack(t *testing.T) {
	dataHome := t.TempDir()
	t.Setenv("XDG_DATA_HOME", dataHome)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/nautilus/registry.json":
			w.Write([]byte(`{"version":1,"packs":[{"id":"video-reformat","name":"Video Reformat","path":"nautilus/video-reformat","subdir":"Ryoku Creator"}]}`))
		case "/nautilus/video-reformat/manifest.json":
			w.Write([]byte(`{"subdir":"Ryoku Creator","scripts":["Reformat 9x16"]}`))
		case "/nautilus/video-reformat/scripts/Reformat 9x16":
			w.Write([]byte("#!/usr/bin/env bash\necho hi\n"))
		default:
			http.NotFound(w, r)
		}
	}))
	defer srv.Close()
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	if _, err := ensureNautilusPack("video-reformat"); err != nil {
		t.Fatalf("ensure: %v", err)
	}
	script := filepath.Join(dataHome, "nautilus", "scripts", "Ryoku Creator", "Reformat 9x16")
	fi, err := os.Stat(script)
	if err != nil {
		t.Fatalf("script not installed: %v", err)
	}
	if fi.Mode().Perm()&0o111 == 0 {
		t.Errorf("script not executable: %v", fi.Mode())
	}
	if _, err := os.Stat(filepath.Join(dataHome, "ryoku", "nautilus", "video-reformat", "manifest.json")); err != nil {
		t.Errorf("tracking manifest missing: %v", err)
	}
	if err := removeNautilusPack("video-reformat"); err != nil {
		t.Fatalf("remove: %v", err)
	}
	if _, err := os.Stat(script); !os.IsNotExist(err) {
		t.Errorf("script survived removal: %v", err)
	}
}
