package main

import (
	"context"
	"crypto/sha256"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func productManifestContract() (ProductEntry, ProductManifest) {
	entry := ProductEntry{
		ID:             "demo",
		Name:           "Demo",
		Version:        "1.2.3",
		Path:           "rices/demo",
		Author:         "Ryoku Team",
		Summary:        "A fixture product",
		Description:    "A complete fixture product.",
		Tags:           []string{"fixture"},
		Accent:         "#cdc4ba",
		Surface:        "#101010",
		Preview:        "assets/preview.png",
		Screenshots:    []string{"assets/detail.png"},
		Manifest:       "manifest.json",
		ManifestSHA256: "",
	}
	manifest := ProductManifest{
		Schema:      1,
		ID:          entry.ID,
		Category:    "rices",
		Version:     entry.Version,
		Destination: "ryoku/rices/demo",
		Files: []ProductFile{
			{
				Source:      "content/Theme.qml",
				Destination: "content/Theme.qml",
				Mode:        "0644",
				Size:        21,
				SHA256:      strings.Repeat("a", 64),
				Install:     true,
			},
			{
				Source:      "assets/preview.png",
				Destination: "assets/preview.png",
				Mode:        "0644",
				Size:        13,
				SHA256:      strings.Repeat("b", 64),
				Install:     false,
			},
		},
	}
	return entry, manifest
}

func manifestBytes(manifest ProductManifest) []byte {
	return []byte(fmt.Sprintf(`{"schema":%d,"id":%q,"category":%q,"version":%q,"destination":%q,"files":[{"source":%q,"destination":%q,"mode":%q,"size":%d,"sha256":%q,"install":%t},{"source":%q,"destination":%q,"mode":%q,"size":%d,"sha256":%q,"install":%t}]}`,
		manifest.Schema,
		manifest.ID,
		manifest.Category,
		manifest.Version,
		manifest.Destination,
		manifest.Files[0].Source,
		manifest.Files[0].Destination,
		manifest.Files[0].Mode,
		manifest.Files[0].Size,
		manifest.Files[0].SHA256,
		manifest.Files[0].Install,
		manifest.Files[1].Source,
		manifest.Files[1].Destination,
		manifest.Files[1].Mode,
		manifest.Files[1].Size,
		manifest.Files[1].SHA256,
		manifest.Files[1].Install,
	))
}

func manifestDigest(raw []byte) string {
	return fmt.Sprintf("%x", sha256.Sum256(raw))
}

func manifestCache(t *testing.T, raw []byte) (*Cache, *int) {
	t.Helper()
	requests := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		requests++
		if r.URL.Path != "/rices/demo/manifest.json" {
			http.NotFound(w, r)
			return
		}
		_, _ = w.Write(raw)
	}))
	t.Cleanup(server.Close)
	return &Cache{
		client: server.Client(),
		base:   server.URL,
		dir:    t.TempDir(),
		memo:   map[string]memoEntry{},
	}, &requests
}

func TestProductManifestValid(t *testing.T) {
	entry, want := productManifestContract()
	raw := manifestBytes(want)
	entry.ManifestSHA256 = manifestDigest(raw)
	cache, requests := manifestCache(t, raw)

	got, err := loadProductManifest(context.Background(), cache, "rices", entry)
	if err != nil {
		t.Fatalf("loadProductManifest() error = %v", err)
	}
	if got.ID != want.ID || got.Category != want.Category || got.Version != want.Version {
		t.Fatalf("manifest identity = %q/%q@%q, want %q/%q@%q", got.Category, got.ID, got.Version, want.Category, want.ID, want.Version)
	}
	if len(got.Files) != 2 || !got.Files[0].Install || got.Files[1].Install {
		t.Fatalf("manifest files = %#v", got.Files)
	}
	if *requests != 1 {
		t.Fatalf("requests = %d, want only the manifest request", *requests)
	}
}

func TestProductEntryRequiresCompleteVisualContract(t *testing.T) {
	tests := map[string]func(*ProductEntry){
		"tags":        func(entry *ProductEntry) { entry.Tags = nil },
		"screenshots": func(entry *ProductEntry) { entry.Screenshots = nil },
		"accent":      func(entry *ProductEntry) { entry.Accent = "red" },
		"surface":     func(entry *ProductEntry) { entry.Surface = "#12345" },
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			entry, _ := productManifestContract()
			entry.ManifestSHA256 = strings.Repeat("a", 64)
			mutate(&entry)
			if err := validateProductEntry("rices", entry); err == nil {
				t.Fatalf("validateProductEntry() accepted invalid %s", name)
			}
		})
	}
}

func TestProductManifestHashMismatch(t *testing.T) {
	entry, _ := productManifestContract()
	raw := []byte("{")
	entry.ManifestSHA256 = strings.Repeat("0", 64)
	cache, _ := manifestCache(t, raw)

	if _, err := loadProductManifest(context.Background(), cache, "rices", entry); err == nil || !strings.Contains(err.Error(), "hash") {
		t.Fatalf("loadProductManifest() error = %v, want hash mismatch", err)
	}
}
func TestProductManifestRejectsNullScalars(t *testing.T) {
	tests := map[string]func(string) string{
		"size":    func(raw string) string { return strings.Replace(raw, `"size":21`, `"size":null`, 1) },
		"install": func(raw string) string { return strings.Replace(raw, `"install":true`, `"install":null`, 1) },
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			entry, manifest := productManifestContract()
			raw := []byte(mutate(string(manifestBytes(manifest))))
			entry.ManifestSHA256 = manifestDigest(raw)
			cache, _ := manifestCache(t, raw)
			if _, err := loadProductManifest(context.Background(), cache, "rices", entry); err == nil {
				t.Fatalf("loadProductManifest() accepted null %s", name)
			}
		})
	}
}

func TestProductManifestIdentity(t *testing.T) {
	tests := map[string]func(*ProductManifest){
		"schema":   func(manifest *ProductManifest) { manifest.Schema = 2 },
		"id":       func(manifest *ProductManifest) { manifest.ID = "other" },
		"category": func(manifest *ProductManifest) { manifest.Category = "plugins" },
		"version":  func(manifest *ProductManifest) { manifest.Version = "9.9.9" },
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			entry, manifest := productManifestContract()
			mutate(&manifest)
			raw := manifestBytes(manifest)
			entry.ManifestSHA256 = manifestDigest(raw)
			cache, _ := manifestCache(t, raw)
			if _, err := loadProductManifest(context.Background(), cache, "rices", entry); err == nil {
				t.Fatal("loadProductManifest() accepted mismatched manifest identity")
			}
		})
	}
}

func TestProductManifestPathsAndDestinations(t *testing.T) {
	tests := map[string]func(*ProductManifest){
		"parent source":        func(manifest *ProductManifest) { manifest.Files[0].Source = "../Theme.qml" },
		"absolute destination": func(manifest *ProductManifest) { manifest.Files[0].Destination = "/tmp/Theme.qml" },
		"parent root":          func(manifest *ProductManifest) { manifest.Destination = "../demo" },
		"duplicate destination": func(manifest *ProductManifest) {
			manifest.Files[1].Destination = manifest.Files[0].Destination
		},
		"ancestor destination": func(manifest *ProductManifest) {
			manifest.Files[1].Destination = manifest.Files[0].Destination + "/preview.png"
		},
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			entry, manifest := productManifestContract()
			mutate(&manifest)
			if err := validateProductManifest("rices", entry, manifest); err == nil {
				t.Fatal("validateProductManifest() accepted unsafe or colliding path")
			}
		})
	}
}

func TestProductManifestMode(t *testing.T) {
	entry, manifest := productManifestContract()
	manifest.Files[0].Mode = "0777"
	if err := validateProductManifest("rices", entry, manifest); err == nil {
		t.Fatal("validateProductManifest() accepted invalid mode")
	}
}

func TestProductManifestSizeLimits(t *testing.T) {
	tests := map[string]func(*ProductManifest){
		"negative": func(manifest *ProductManifest) { manifest.Files[0].Size = -1 },
		"file":     func(manifest *ProductManifest) { manifest.Files[0].Size = (256 << 20) + 1 },
		"product": func(manifest *ProductManifest) {
			manifest.Files[0].Size = 256 << 20
			manifest.Files[1].Size = 256 << 20
			manifest.Files = append(manifest.Files, ProductFile{
				Source:      "assets/extra.png",
				Destination: "assets/extra.png",
				Mode:        "0644",
				Size:        1,
				SHA256:      strings.Repeat("c", 64),
			})
		},
	}
	for name, mutate := range tests {
		t.Run(name, func(t *testing.T) {
			entry, manifest := productManifestContract()
			mutate(&manifest)
			if err := validateProductManifest("rices", entry, manifest); err == nil {
				t.Fatal("validateProductManifest() accepted invalid size")
			}
		})
	}
}
func TestProductManifestLimitBoundaries(t *testing.T) {
	entry, manifest := productManifestContract()
	makeFiles := func(count int, size int64) []ProductFile {
		files := make([]ProductFile, count)
		for index := range files {
			name := fmt.Sprintf("content/file-%04d", index)
			files[index] = ProductFile{
				Source:      name,
				Destination: name,
				Mode:        "0644",
				Size:        size,
				SHA256:      strings.Repeat("a", 64),
			}
		}
		return files
	}

	manifest.Files = makeFiles(2048, 0)
	if err := validateProductManifest("rices", entry, manifest); err != nil {
		t.Fatalf("2,048 files rejected: %v", err)
	}
	manifest.Files = makeFiles(2049, 0)
	if err := validateProductManifest("rices", entry, manifest); err == nil {
		t.Fatal("2,049 files accepted")
	}
	manifest.Files = makeFiles(1, 256<<20)
	if err := validateProductManifest("rices", entry, manifest); err != nil {
		t.Fatalf("256 MiB file rejected: %v", err)
	}
	manifest.Files = makeFiles(2, 256<<20)
	if err := validateProductManifest("rices", entry, manifest); err != nil {
		t.Fatalf("512 MiB product rejected: %v", err)
	}
}

func TestProductManifestEntryPath(t *testing.T) {
	entry, manifest := productManifestContract()
	raw := manifestBytes(manifest)
	entry.Path = "../demo"
	entry.ManifestSHA256 = manifestDigest(raw)
	cache, _ := manifestCache(t, raw)
	if _, err := loadProductManifest(context.Background(), cache, "rices", entry); err == nil {
		t.Fatal("loadProductManifest() accepted unsafe registry path")
	}
}

func TestProductVersion(t *testing.T) {
	if productUpdateAvailable("1.2.3", "1.2.3") {
		t.Fatal("equal exact versions reported an update")
	}
	if !productUpdateAvailable("1.2.3", "1.2.4") {
		t.Fatal("different exact versions did not report an update")
	}
	if !productUpdateAvailable("2.0.0", "1.0.0") {
		t.Fatal("different older available version did not report an update")
	}
	if productUpdateAvailable("", "1.2.4") {
		t.Fatal("missing installed receipt version reported an update")
	}
}
