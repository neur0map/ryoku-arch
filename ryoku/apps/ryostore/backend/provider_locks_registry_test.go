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
	"strings"
	"sync"
	"testing"
)

type lockRegistryFixture struct {
	cache    *Cache
	server   *httptest.Server
	requests []string
	mu       sync.Mutex
	entry    ProductEntry
	mainQML  []byte
}

func newLockRegistryFixture(t *testing.T) *lockRegistryFixture {
	t.Helper()
	t.Setenv("HOME", t.TempDir())
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(t.TempDir(), "config"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(t.TempDir(), "data"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(t.TempDir(), "state"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(t.TempDir(), "cache"))

	fixture := &lockRegistryFixture{mainQML: []byte("import QtQuick\nItem {}\n")}
	preview := []byte("animated-preview")
	detail := []byte("detail-image")
	file := func(source, destination string, body []byte, install bool) ProductFile {
		digest := sha256.Sum256(body)
		return ProductFile{
			Source: source, Destination: destination, Mode: "0644",
			Size: int64(len(body)), SHA256: fmt.Sprintf("%x", digest), Install: install,
		}
	}
	manifest := ProductManifest{
		Schema: 1, ID: "clockwork-tape", Category: "lockscreens", Version: "1.0.0",
		Destination: "qylock/themes/clockwork-tape",
		Files: []ProductFile{
			file("content/Main.qml", "Main.qml", fixture.mainQML, true),
			file("assets/preview.gif", "assets/preview.gif", preview, false),
			file("assets/detail.png", "assets/detail.png", detail, false),
		},
	}
	manifestRaw, err := json.Marshal(manifest)
	if err != nil {
		t.Fatal(err)
	}
	manifestRaw = append(manifestRaw, '\n')
	manifestDigest := sha256.Sum256(manifestRaw)
	fixture.entry = ProductEntry{
		ID: "clockwork-tape", Name: "Tape", Version: "1.0.0",
		Path: "lockscreens/clockwork-tape", Author: "Darkkal44",
		Summary: "Clockwork on magnetic tape.", Description: "A complete qylock scene.",
		Tags: []string{"clockwork", "retro"}, Accent: "#d7a45f", Surface: "#101010",
		Preview: "assets/preview.gif", Screenshots: []string{"assets/detail.png"}, Manifest: "manifest.json",
		ManifestSHA256: fmt.Sprintf("%x", manifestDigest),
	}
	registryRaw, err := json.Marshal(map[string]any{
		"schema": 1, "lockscreens": []ProductEntry{fixture.entry},
	})
	if err != nil {
		t.Fatal(err)
	}

	fixture.server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fixture.mu.Lock()
		fixture.requests = append(fixture.requests, r.URL.Path)
		fixture.mu.Unlock()
		switch r.URL.Path {
		case "/lockscreens/registry.json":
			_, _ = w.Write(registryRaw)
		case "/lockscreens/clockwork-tape/manifest.json":
			_, _ = w.Write(manifestRaw)
		case "/lockscreens/clockwork-tape/content/Main.qml":
			_, _ = w.Write(fixture.mainQML)
		case "/lockscreens/clockwork-tape/assets/preview.gif":
			_, _ = w.Write(preview)
		case "/lockscreens/clockwork-tape/assets/detail.png":
			_, _ = w.Write(detail)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(fixture.server.Close)
	t.Setenv("RYOKU_EXTRAS_BASE", fixture.server.URL)
	fixture.cache = &Cache{
		client: fixture.server.Client(), base: fixture.server.URL,
		dir: t.TempDir(), memo: map[string]memoEntry{},
	}
	return fixture
}

func (fixture *lockRegistryFixture) requestPaths() []string {
	fixture.mu.Lock()
	defer fixture.mu.Unlock()
	return append([]string(nil), fixture.requests...)
}

func TestLockProviderBrowsesRegistryOnlyAndJoinsOwnedState(t *testing.T) {
	fixture := newLockRegistryFixture(t)
	prefPath := filepath.Join(configHome(), "qylock", "theme")
	if err := os.MkdirAll(filepath.Dir(prefPath), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(prefPath, []byte("clockwork-tape\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := writeReceipt(Receipt{
		Category: "lockscreens", ID: "clockwork-tape", Version: "0.9.0",
		Destination: "qylock/themes/clockwork-tape",
	}); err != nil {
		t.Fatal(err)
	}
	unmanaged := filepath.Join(dataHome(), "qylock", "themes", "unmanaged", "Main.qml")
	if err := os.MkdirAll(filepath.Dir(unmanaged), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(unmanaged, []byte("unmanaged"), 0o644); err != nil {
		t.Fatal(err)
	}

	provider := lockProvider{cache: fixture.cache, prefPath: prefPath}
	items, state, err := provider.Load(context.Background(), false)
	if err != nil {
		t.Fatal(err)
	}
	if state.Offline || len(items) != 1 {
		t.Fatalf("state=%+v items=%+v", state, items)
	}
	item := items[0]
	if item.ID != "clockwork-tape" || !item.Installed || !item.Active || !item.UpdateAvailable {
		t.Fatalf("owned state = %+v", item)
	}
	if item.InstalledVersion != "0.9.0" || item.Version != "1.0.0" {
		t.Fatalf("versions = installed %q available %q", item.InstalledVersion, item.Version)
	}
	if item.Art != fixture.server.URL+"/lockscreens/clockwork-tape/assets/preview.gif" {
		t.Fatalf("art = %q", item.Art)
	}
	if len(item.Screenshots) != 1 ||
		item.Screenshots[0] != fixture.server.URL+"/lockscreens/clockwork-tape/assets/detail.png" {
		t.Fatalf("screenshots = %#v", item.Screenshots)
	}
	if got := strings.Join(fixture.requestPaths(), ","); got != "/lockscreens/registry.json" {
		t.Fatalf("browse requests = %q", got)
	}
}

func TestLockProviderInstallsAndRemovesWithoutTouchingCoreFallback(t *testing.T) {
	fixture := newLockRegistryFixture(t)
	provider := lockProvider{cache: fixture.cache, prefPath: filepath.Join(configHome(), "qylock", "theme")}
	core := filepath.Join(dataHome(), "qylock", "themes", "clockwork", "orbital", "Main.qml")
	if err := os.MkdirAll(filepath.Dir(core), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(core, []byte("core"), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := provider.Install(context.Background(), "clockwork-tape"); err != nil {
		t.Fatal(err)
	}
	installed := filepath.Join(dataHome(), "qylock", "themes", "clockwork-tape", "Main.qml")
	if body, err := os.ReadFile(installed); err != nil || string(body) != string(fixture.mainQML) {
		t.Fatalf("installed Main.qml = %q, err=%v", body, err)
	}
	if _, err := readReceipt("lockscreens", "clockwork-tape"); err != nil {
		t.Fatal(err)
	}
	if err := provider.Remove(context.Background(), "clockwork-tape"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(installed); !os.IsNotExist(err) {
		t.Fatalf("optional theme remains: %v", err)
	}
	if body, err := os.ReadFile(core); err != nil || string(body) != "core" {
		t.Fatalf("core fallback changed: %q, err=%v", body, err)
	}
}

func TestLockProviderRejectsMalformedRegistry(t *testing.T) {
	for name, payload := range map[string]string{
		"null catalogue":     `{"schema":1,"lockscreens":null}`,
		"unsupported schema": `{"schema":2,"lockscreens":[]}`,
	} {
		t.Run(name, func(t *testing.T) {
			t.Setenv("XDG_CACHE_HOME", t.TempDir())
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				_, _ = w.Write([]byte(payload))
			}))
			defer srv.Close()
			cache := &Cache{
				client: srv.Client(), base: srv.URL,
				dir: t.TempDir(), memo: map[string]memoEntry{},
			}
			if _, _, err := (lockProvider{cache: cache}).Load(context.Background(), false); err == nil {
				t.Fatalf("Load accepted %s", name)
			}
		})
	}
}

func TestLockscreenCategoryLeadsWearProviders(t *testing.T) {
	providers := providers()
	if len(providers) < 3 || providers[0].Category().ID != "lockscreens" {
		t.Fatalf("first provider = %q, want lockscreens", providers[0].Category().ID)
	}
	if providers[0].Category().Group != "wear" {
		t.Fatalf("lockscreen group = %q, want wear", providers[0].Category().Group)
	}
}

func TestLockProviderRefusesCoreFallbackRemoval(t *testing.T) {
	if err := (lockProvider{}).Remove(context.Background(), "clockwork-orbital"); err == nil {
		t.Fatal("core fallback was removable")
	}
}
