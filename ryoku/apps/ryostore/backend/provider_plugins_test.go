package main

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
)

// fixtureServer is shared by the bundle provider tests while bundles still use
// their legacy lazy catalogue contract.
func fixtureServer(t *testing.T) (*httptest.Server, *bool) {
	t.Helper()
	down := false
	fs := http.FileServer(http.Dir("testdata/extras"))
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if down {
			http.Error(w, "down", http.StatusServiceUnavailable)
			return
		}
		fs.ServeHTTP(w, r)
	}))
	t.Cleanup(srv.Close)
	return srv, &down
}

func itemsByID(items []Item) map[string]Item {
	indexed := make(map[string]Item, len(items))
	for _, item := range items {
		indexed[item.ID] = item
	}
	return indexed
}

func stubPlaceTool(t *testing.T) string {
	t.Helper()
	bin := t.TempDir()
	log := filepath.Join(t.TempDir(), "place.log")
	t.Setenv("PLACE_LOG", log)
	script := `#!/usr/bin/env bash
set -euo pipefail
echo "$*" >> "$PLACE_LOG"
id="$1"
field="$2"
shift 2
file="$XDG_CONFIG_HOME/ryoku/plugins.json"
mkdir -p "$(dirname "$file")"
[ -s "$file" ] || printf '{}\n' >"$file"
tmp="$(mktemp "$file.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
case "$field" in
enabled)
	jq --arg id "$id" --argjson enabled "$1" '.[$id] = ((.[$id] // {}) + {enabled: $enabled})' "$file" >"$tmp"
	mv "$tmp" "$file"
	;;
restore)
	if [ "$1" = "null" ]; then
		jq --arg id "$id" 'del(.[$id])' "$file" >"$tmp"
	else
		jq --arg id "$id" --argjson entry "$1" '.[$id] = $entry' "$file" >"$tmp"
	fi
	mv "$tmp" "$file"
	if [ "$2" = "false" ] && jq -e 'length == 0' "$file" >/dev/null; then rm -f "$file"; fi
	;;
esac
`
	if err := os.WriteFile(filepath.Join(bin, "ryoku-plugins-place"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	return log
}

type pluginProductFixture struct {
	testing *testing.T
	server  *httptest.Server
	cache   *Cache
	mu      sync.Mutex
	version string
	marker  string
	corrupt bool
	paths   []string
}

func newPluginProductFixture(t *testing.T) *pluginProductFixture {
	t.Helper()
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(t.TempDir(), "config"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(t.TempDir(), "data"))
	t.Setenv("XDG_STATE_HOME", filepath.Join(t.TempDir(), "state"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(t.TempDir(), "cache"))
	fixture := &pluginProductFixture{testing: t, version: "1.0.0", marker: "content-v1"}
	fixture.server = httptest.NewServer(http.HandlerFunc(fixture.serve))
	t.Cleanup(fixture.server.Close)
	fixture.cache = &Cache{
		client: fixture.server.Client(), base: fixture.server.URL,
		dir: filepath.Join(t.TempDir(), "cache"), memo: map[string]memoEntry{},
	}
	return fixture
}

func (fixture *pluginProductFixture) set(version, marker string, corrupt bool) {
	fixture.mu.Lock()
	defer fixture.mu.Unlock()
	fixture.version = version
	fixture.marker = marker
	fixture.corrupt = corrupt
}

func (fixture *pluginProductFixture) requests() []string {
	fixture.mu.Lock()
	defer fixture.mu.Unlock()
	return append([]string(nil), fixture.paths...)
}

func (fixture *pluginProductFixture) serve(w http.ResponseWriter, request *http.Request) {
	fixture.mu.Lock()
	version, marker, corrupt := fixture.version, fixture.marker, fixture.corrupt
	fixture.paths = append(fixture.paths, request.URL.Path)
	fixture.mu.Unlock()
	content := []byte("import QtQuick\nItem { property string marker: \"" + marker + "\" }\n")
	contentHash := sha256.Sum256(content)
	pluginManifest := []byte(fmt.Sprintf(`{"id":"fixture","name":"Fixture","version":%q,"hosts":["desktopWidget"]}`, version))
	pluginManifestHash := sha256.Sum256(pluginManifest)
	manifest := ProductManifest{
		Schema: 1, ID: "fixture", Category: "plugins", Version: version,
		Destination: "ryoku/plugins/fixture",
		Files: []ProductFile{
			{
				Source: "manifest.json", Destination: "manifest.json",
				SHA256: fmt.Sprintf("%x", pluginManifestHash), Mode: "0644", Size: int64(len(pluginManifest)), Install: true,
			},
			{
				Source: "content/Widget.qml", Destination: "content/Widget.qml",
				SHA256: fmt.Sprintf("%x", contentHash), Mode: "0644", Size: int64(len(content)), Install: true,
			},
		},
	}
	manifestRaw, err := json.Marshal(manifest)
	if err != nil {
		fixture.testing.Errorf("marshal manifest: %v", err)
		return
	}
	manifestHash := sha256.Sum256(manifestRaw)
	entry := ProductEntry{
		ID: "fixture", Name: "Fixture", Version: version, Path: "plugins/fixture",
		Author: "Ryoku Team", Summary: "Live fixture", Description: "A plugin fixture.",
		Tags: []string{"test"}, Screenshots: []string{"assets/detail.webp"},
		Accent: "#112233", Surface: "#101010", Preview: "assets/preview.webp",
		Manifest: "product-manifest.json", ManifestSHA256: fmt.Sprintf("%x", manifestHash),
		Official: true, Tagline: "Live updates", Icon: "test", Hosts: []string{"desktopWidget"},
		LastUpdated: "2026-08-02T00:00:00Z",
	}
	registryRaw, err := json.Marshal(map[string]any{"schema": 1, "plugins": []ProductEntry{entry}})
	if err != nil {
		fixture.testing.Errorf("marshal registry: %v", err)
		return
	}

	switch request.URL.Path {
	case "/plugins/registry.json":
		_, _ = w.Write(registryRaw)
	case "/plugins/fixture/product-manifest.json":
		_, _ = w.Write(manifestRaw)
	case "/plugins/fixture/manifest.json":
		_, _ = w.Write(pluginManifest)
	case "/plugins/fixture/content/Widget.qml":
		if corrupt {
			_, _ = w.Write([]byte("corrupt"))
		} else {
			_, _ = w.Write(content)
		}
	default:
		http.NotFound(w, request)
	}
}

func TestPluginProviderUsesProductRegistryReceiptsAndPlacement(t *testing.T) {
	fixture := newPluginProductFixture(t)
	placeLog := stubPlaceTool(t)
	provider := pluginProvider{cache: fixture.cache}

	items, _, err := provider.Load(context.Background(), false)
	if err != nil {
		t.Fatalf("Load: %v", err)
	}
	item := itemsByID(items)["fixture"]
	if item.Installed || item.Enabled || item.UpdateAvailable {
		t.Fatalf("fresh item has installed state: %+v", item)
	}
	if item.Art != fixture.server.URL+"/plugins/fixture/assets/preview.webp" || item.Screenshots[0] != fixture.server.URL+"/plugins/fixture/assets/detail.webp" {
		t.Fatalf("registry media not resolved: art=%q shots=%v", item.Art, item.Screenshots)
	}
	if item.Metadata["official"] != true || item.Metadata["icon"] != "test" {
		t.Fatalf("registry metadata missing: %+v", item.Metadata)
	}
	if got := fixture.requests(); len(got) != 1 || got[0] != "/plugins/registry.json" {
		t.Fatalf("browse fetched product internals: %v", got)
	}

	if err := provider.Install(context.Background(), "fixture"); err != nil {
		t.Fatalf("Install: %v", err)
	}
	destination, _, _ := productDestination("plugins", "fixture")
	content, err := os.ReadFile(filepath.Join(destination, "content", "Widget.qml"))
	if err != nil || !strings.Contains(string(content), "content-v1") {
		t.Fatalf("installed content = %q err=%v", content, err)
	}
	runtimeManifest, err := os.ReadFile(filepath.Join(destination, "manifest.json"))
	if err != nil || !strings.Contains(string(runtimeManifest), `"version":"1.0.0"`) {
		t.Fatalf("runtime manifest = %q err=%v", runtimeManifest, err)
	}
	receipt, err := readReceipt("plugins", "fixture")
	if err != nil {
		t.Fatalf("receipt: %v", err)
	}
	if receipt.Version != "1.0.0" || len(receipt.Files) != 2 {
		t.Fatalf("receipt does not own content and runtime manifest: %+v", receipt)
	}
	placeCalls, err := os.ReadFile(placeLog)
	if err != nil || string(placeCalls) != "fixture enabled false\n" {
		t.Fatalf("new install placement calls = %q err=%v", placeCalls, err)
	}

	placementPath := filepath.Join(configHome(), "ryoku", "plugins.json")
	if err := os.MkdirAll(filepath.Dir(placementPath), 0o755); err != nil {
		t.Fatal(err)
	}
	placement := []byte(`{"fixture":{"enabled":true,"host":"desktopWidget","settings":{"label":"mine"}}}`)
	if err := os.WriteFile(placementPath, placement, 0o600); err != nil {
		t.Fatal(err)
	}
	items, _, err = provider.Load(context.Background(), false)
	if err != nil {
		t.Fatalf("Load installed: %v", err)
	}
	item = itemsByID(items)["fixture"]
	if !item.Installed || !item.Enabled || item.InstalledVersion != "1.0.0" {
		t.Fatalf("receipt and placement state not joined: %+v", item)
	}
}

func TestPluginUpdateIsAtomicAndRemovalPreservesPlacement(t *testing.T) {
	fixture := newPluginProductFixture(t)
	placeLog := stubPlaceTool(t)
	provider := pluginProvider{cache: fixture.cache}
	if err := provider.Install(context.Background(), "fixture"); err != nil {
		t.Fatalf("install v1: %v", err)
	}

	fixture.set("2.0.0", "content-v2", false)
	if _, _, err := provider.Load(context.Background(), true); err != nil {
		t.Fatalf("refresh v2: %v", err)
	}
	if err := provider.Install(context.Background(), "fixture"); err != nil {
		t.Fatalf("update v2: %v", err)
	}
	destination, _, _ := productDestination("plugins", "fixture")
	content, _ := os.ReadFile(filepath.Join(destination, "content", "Widget.qml"))
	receipt, _ := readReceipt("plugins", "fixture")
	revision, _ := readStoreRevision()
	if !strings.Contains(string(content), "content-v2") || receipt.Version != "2.0.0" || revision.Revision != 2 {
		t.Fatalf("update not published together: content=%q receipt=%+v revision=%+v", content, receipt, revision)
	}

	fixture.set("3.0.0", "content-v3", true)
	if _, _, err := provider.Load(context.Background(), true); err != nil {
		t.Fatalf("refresh v3: %v", err)
	}
	if err := provider.Install(context.Background(), "fixture"); err == nil {
		t.Fatal("corrupt update succeeded")
	}
	content, _ = os.ReadFile(filepath.Join(destination, "content", "Widget.qml"))
	receipt, _ = readReceipt("plugins", "fixture")
	revision, _ = readStoreRevision()
	if !strings.Contains(string(content), "content-v2") || receipt.Version != "2.0.0" || revision.Revision != 2 {
		t.Fatalf("failed update changed installed product: content=%q receipt=%+v revision=%+v", content, receipt, revision)
	}

	placementPath := filepath.Join(configHome(), "ryoku", "plugins.json")
	if err := os.MkdirAll(filepath.Dir(placementPath), 0o755); err != nil {
		t.Fatal(err)
	}
	placement := []byte(`{"fixture":{"enabled":true,"host":"desktopWidget","settings":{"label":"mine"}}}`)
	if err := os.WriteFile(placementPath, placement, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := provider.Remove(context.Background(), "fixture"); err != nil {
		t.Fatalf("Remove: %v", err)
	}
	preserved, err := os.ReadFile(placementPath)
	if err != nil || string(preserved) != string(placement) {
		t.Fatalf("remove changed placement/settings: %q err=%v", preserved, err)
	}
	if _, err := os.Stat(destination); !os.IsNotExist(err) {
		t.Fatalf("plugin destination remains: %v", err)
	}
	if _, err := readReceipt("plugins", "fixture"); !os.IsNotExist(err) {
		t.Fatalf("plugin receipt remains: %v", err)
	}
	revision, _ = readStoreRevision()
	if revision.Revision != 3 || revision.Category != "plugins" || revision.Operation != "remove" {
		t.Fatalf("remove revision = %+v", revision)
	}
	placeCalls, _ := os.ReadFile(placeLog)
	if string(placeCalls) != "fixture enabled false\n" {
		t.Fatalf("update/remove placement calls = %q", placeCalls)
	}
}

func TestFreshPluginFailureRestoresPlacement(t *testing.T) {
	fixture := newPluginProductFixture(t)
	placeLog := stubPlaceTool(t)
	placementPath := filepath.Join(configHome(), "ryoku", "plugins.json")
	if err := os.MkdirAll(filepath.Dir(placementPath), 0o755); err != nil {
		t.Fatal(err)
	}
	placement := []byte(`{"fixture":{"enabled":true,"host":"desktopWidget","settings":{"label":"mine"}}}`)
	if err := os.WriteFile(placementPath, placement, 0o600); err != nil {
		t.Fatal(err)
	}
	previousCheckpoint := productTransactionCheckpoint
	productTransactionCheckpoint = func(phase string) error {
		if phase == "install-placement" {
			return errors.New("stop after placement")
		}
		return nil
	}
	t.Cleanup(func() { productTransactionCheckpoint = previousCheckpoint })

	provider := pluginProvider{cache: fixture.cache}
	if err := provider.Install(context.Background(), "fixture"); err == nil {
		t.Fatal("fresh install succeeded after placement checkpoint failure")
	}
	after, err := os.ReadFile(placementPath)
	var beforeValue, afterValue map[string]any
	beforeErr := json.Unmarshal(placement, &beforeValue)
	afterErr := json.Unmarshal(after, &afterValue)
	if err != nil || beforeErr != nil || afterErr != nil || !reflect.DeepEqual(afterValue, beforeValue) {
		t.Fatalf("failed install changed placement: %q err=%v/%v/%v", after, err, beforeErr, afterErr)
	}
	destination, _, _ := productDestination("plugins", "fixture")
	if _, err := os.Stat(destination); !os.IsNotExist(err) {
		t.Fatalf("failed install left destination: %v", err)
	}
	if _, err := readReceipt("plugins", "fixture"); !os.IsNotExist(err) {
		t.Fatalf("failed install left receipt: %v", err)
	}
	calls, _ := os.ReadFile(placeLog)
	if !strings.Contains(string(calls), "fixture enabled false\n") ||
		!strings.Contains(string(calls), "fixture restore ") {
		t.Fatalf("placement transaction calls = %q", calls)
	}
}
