package main

import (
	"bytes"
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
)

// TestCacheServesStaleDiskWhenOffline proves the archive-when-offline contract:
// a live fetch caches to disk, and a later invocation whose network is gone
// serves the same bytes flagged Offline with a non-empty CachedAt.
func TestCacheServesStaleDiskWhenOffline(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	body := []byte(`{"registry":true}`)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(body)
	}))
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	live, state, err := newCache().Fetch(context.Background(), "plugins/registry.json", false)
	if err != nil {
		t.Fatalf("live fetch: %v", err)
	}
	if state.Offline {
		t.Fatalf("live fetch must not report Offline")
	}
	if !bytes.Equal(live, body) {
		t.Fatalf("live bytes = %q, want %q", live, body)
	}

	srv.Close() // a fresh invocation with the network gone must fall back to disk.

	stale, state, err := newCache().Fetch(context.Background(), "plugins/registry.json", false)
	if err != nil {
		t.Fatalf("offline fetch: %v", err)
	}
	if !bytes.Equal(stale, body) {
		t.Fatalf("stale bytes = %q, want %q", stale, body)
	}
	if !state.Offline {
		t.Fatalf("offline fetch must report Offline")
	}
	if state.CachedAt == "" {
		t.Fatalf("offline fetch must report a CachedAt")
	}
}

// TestCacheRefreshBypassesMemoAndReplacesDisk proves refresh semantics: a
// repeated fetch answers from the fresh in-process copy, while refresh bypasses
// it to pull the new upstream bytes and rewrite the disk cache.
func TestCacheRefreshBypassesMemoAndReplacesDisk(t *testing.T) {
	cacheHome := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cacheHome)
	var mu sync.Mutex
	body := []byte("v1")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		w.Write(body)
	}))
	t.Cleanup(srv.Close)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	c := newCache()
	ctx := context.Background()

	if b, _, err := c.Fetch(ctx, "bundles/registry.json", false); err != nil || string(b) != "v1" {
		t.Fatalf("prime fetch = %q, %v", b, err)
	}

	mu.Lock()
	body = []byte("v2")
	mu.Unlock()

	if b, _, err := c.Fetch(ctx, "bundles/registry.json", false); err != nil || string(b) != "v1" {
		t.Fatalf("repeat fetch = %q, %v; want cached v1 without a network hit", b, err)
	}

	got, state, err := c.Fetch(ctx, "bundles/registry.json", true)
	if err != nil {
		t.Fatalf("refresh fetch: %v", err)
	}
	if string(got) != "v2" {
		t.Fatalf("refresh bytes = %q, want v2", got)
	}
	if state.Offline {
		t.Fatalf("a live refresh must not report Offline")
	}
	disk, err := os.ReadFile(filepath.Join(extrasCacheDir(), "bundles", "registry.json"))
	if err != nil {
		t.Fatalf("read disk cache: %v", err)
	}
	if string(disk) != "v2" {
		t.Fatalf("disk cache = %q, want v2", disk)
	}
}

// TestCacheRejectsUnsafeKeys proves an empty, dot, absolute, or traversing key
// is refused before any network or filesystem use, so a registry-derived path
// can never read or overwrite a file outside the cache directory.
func TestCacheRejectsUnsafeKeys(t *testing.T) {
	cacheHome := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cacheHome)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("remote"))
	}))
	t.Cleanup(srv.Close)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	// A file two levels above the extras dir that a traversal key would target.
	secret := filepath.Join(cacheHome, "secret.txt")
	if err := os.WriteFile(secret, []byte("secret"), 0o600); err != nil {
		t.Fatal(err)
	}

	bad := []string{"", ".", "..", "/etc/passwd", "../secret.txt", "../../secret.txt", "extras/../../secret.txt", "a//b", "a/./b", "a/"}
	for _, key := range bad {
		if _, _, err := newCache().Fetch(context.Background(), key, false); err == nil {
			t.Fatalf("read key %q: want error, got nil", key)
		}
		if _, _, err := newCache().Fetch(context.Background(), key, true); err == nil {
			t.Fatalf("write key %q: want error, got nil", key)
		}
	}
	// The secret above the cache root was neither read out nor overwritten.
	if b, _ := os.ReadFile(secret); string(b) != "secret" {
		t.Fatalf("secret changed to %q", b)
	}
}

// TestCacheKeepsStaleWhenLiveOversized proves an oversized live response is
// rejected without replacing a valid stale entry: the good cache survives and
// is served offline instead of being overwritten with truncated bytes.
func TestCacheKeepsStaleWhenLiveOversized(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	var mu sync.Mutex
	body := []byte("good")
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		defer mu.Unlock()
		w.Write(body)
	}))
	t.Cleanup(srv.Close)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	ctx := context.Background()
	if b, _, err := newCache().Fetch(ctx, "plugins/registry.json", false); err != nil || string(b) != "good" {
		t.Fatalf("prime fetch = %q, %v", b, err)
	}

	mu.Lock()
	body = bytes.Repeat([]byte("x"), (4<<20)+1)
	mu.Unlock()

	got, state, err := newCache().Fetch(ctx, "plugins/registry.json", true)
	if err != nil {
		t.Fatalf("refresh over oversize: %v", err)
	}
	if string(got) != "good" {
		t.Fatalf("bytes len %d, want the 4-byte stale entry", len(got))
	}
	if !state.Offline {
		t.Fatalf("oversize fallback must report Offline")
	}
	disk, err := os.ReadFile(filepath.Join(extrasCacheDir(), "plugins", "registry.json"))
	if err != nil {
		t.Fatalf("read disk: %v", err)
	}
	if string(disk) != "good" {
		t.Fatalf("disk len %d, truncation must not replace a valid entry", len(disk))
	}
}

// TestCacheMemoStaysOfflineAfterFailedRefresh proves the memo carries source
// state: once a failed refresh serves the disk archive, a later non-refresh
// fetch stays Offline with the same CachedAt instead of reverting to online.
func TestCacheMemoStaysOfflineAfterFailedRefresh(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	up := true
	var mu sync.Mutex
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		mu.Lock()
		ok := up
		mu.Unlock()
		if !ok {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		w.Write([]byte("live"))
	}))
	t.Cleanup(srv.Close)
	t.Setenv("RYOKU_EXTRAS_BASE", srv.URL)

	c := newCache()
	ctx := context.Background()
	if b, s, err := c.Fetch(ctx, "plugins/registry.json", false); err != nil || string(b) != "live" || s.Offline {
		t.Fatalf("prime = %q %+v %v", b, s, err)
	}

	mu.Lock()
	up = false
	mu.Unlock()

	_, s1, err := c.Fetch(ctx, "plugins/registry.json", true)
	if err != nil || !s1.Offline || s1.CachedAt == "" {
		t.Fatalf("failed refresh = %+v %v", s1, err)
	}

	_, s2, err := c.Fetch(ctx, "plugins/registry.json", false)
	if err != nil {
		t.Fatalf("post-refresh fetch: %v", err)
	}
	if !s2.Offline {
		t.Fatalf("non-refresh after a failed refresh must stay Offline, got %+v", s2)
	}
	if s2.CachedAt != s1.CachedAt {
		t.Fatalf("CachedAt drifted: %q -> %q", s1.CachedAt, s2.CachedAt)
	}
}

// TestCacheIsolatesPerSourceBase proves two RYOKU_EXTRAS_BASE overrides sharing
// one XDG cache root use distinct disk namespaces, so one source never serves
// another's archive, while the default source keeps its legacy location.
func TestCacheIsolatesPerSourceBase(t *testing.T) {
	cacheHome := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cacheHome)
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	root := filepath.Join(cacheHome, "ryoku", "extras")
	ctx := context.Background()

	srvA := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("A"))
	}))
	t.Setenv("RYOKU_EXTRAS_BASE", srvA.URL)
	ca := newCache()
	if b, _, err := ca.Fetch(ctx, "registry.json", false); err != nil || string(b) != "A" {
		t.Fatalf("A fetch = %q %v", b, err)
	}
	srvA.Close()

	srvB := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	baseB := srvB.URL + "/fork"
	srvB.Close()
	t.Setenv("RYOKU_EXTRAS_BASE", baseB)
	cb := newCache()
	if cb.dir == ca.dir {
		t.Fatalf("distinct bases must not share a cache dir: %q", cb.dir)
	}
	if _, _, err := cb.Fetch(ctx, "registry.json", false); err == nil {
		t.Fatal("source B with no cache must not serve source A's archive")
	}
	if !strings.HasPrefix(ca.dir, root) || !strings.HasPrefix(cb.dir, root) {
		t.Fatalf("caches must stay under %q: A=%q B=%q", root, ca.dir, cb.dir)
	}

	t.Setenv("RYOKU_EXTRAS_BASE", "")
	if got := extrasCacheDir(); got != root {
		t.Fatalf("default cache dir = %q, want %q for upgrade/offline continuity", got, root)
	}

	// Explicitly setting the default URL (even with a trailing slash) is the
	// same effective source and must keep the legacy root for archive continuity.
	t.Setenv("RYOKU_EXTRAS_BASE", defaultExtrasBase+"/")
	if got := extrasCacheDir(); got != root {
		t.Fatalf("explicit default base cache dir = %q, want legacy %q", got, root)
	}
}

// TestCachePreservesLiveErrorWithoutDisk proves an uncached failure surfaces its
// original error, and that an HTTP status is a typed error distinguishable from
// a transport failure via errors.As, so a provider can treat a 404 as an empty
// category while still seeing network failures.
func TestCachePreservesLiveErrorWithoutDisk(t *testing.T) {
	t.Setenv("XDG_CACHE_HOME", t.TempDir())

	notFound := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	t.Cleanup(notFound.Close)
	t.Setenv("RYOKU_EXTRAS_BASE", notFound.URL)

	_, _, err := newCache().Fetch(context.Background(), "fastfetch/registry.json", false)
	if err == nil {
		t.Fatal("uncached 404 must return an error")
	}
	var he *HTTPStatusError
	if !errors.As(err, &he) {
		t.Fatalf("error %v is not an *HTTPStatusError", err)
	}
	if he.Status != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", he.Status)
	}

	down := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	addr := down.URL
	down.Close()
	t.Setenv("RYOKU_EXTRAS_BASE", addr)

	_, _, err = newCache().Fetch(context.Background(), "plugins/registry.json", false)
	if err == nil {
		t.Fatal("uncached network failure must return an error")
	}
	var he2 *HTTPStatusError
	if errors.As(err, &he2) {
		t.Fatalf("network failure must not look like an HTTP status error: %v", err)
	}
}
