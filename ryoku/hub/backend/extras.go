package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// ryoku-hub owns all network and disk for the extras catalogue, so the shell
// actuator (ryoku-extras-install) never fetches anything itself: it reads the
// cache this writes and asks for an installer path on demand.
//
//	ryoku-hub extras catalog        fetch + merge the bundle catalogue as JSON
//	ryoku-hub extras cache          print the catalogue cache directory
//	ryoku-hub extras installer <n>  ensure installers/<n>.sh is cached, print its path
//
// The source is the ryoku-extras repo, served raw from GitHub; RYOKU_EXTRAS_BASE
// overrides it (a fork, or a local tree under test).
const defaultExtrasBase = "https://raw.githubusercontent.com/neur0map/ryoku-extras/main"

func extrasBase() string {
	if b := os.Getenv("RYOKU_EXTRAS_BASE"); b != "" {
		return strings.TrimRight(b, "/")
	}
	return defaultExtrasBase
}

func extrasCacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	return filepath.Join(base, "ryoku", "extras")
}

type registryEntry struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Tagline     string `json:"tagline,omitempty"`
	Sources     string `json:"sources,omitempty"`
	Path        string `json:"path"`
}

type registry struct {
	Version int             `json:"version"`
	Bundles []registryEntry `json:"bundles"`
}

type bundleItem struct {
	Type     string `json:"type"`
	Name     string `json:"name"`
	Detect   string `json:"detect,omitempty"`
	Summary  string `json:"summary,omitempty"`
	Source   string `json:"source,omitempty"`
	Upstream string `json:"upstream,omitempty"`
}

type bundleDef struct {
	ID          string       `json:"id"`
	Name        string       `json:"name"`
	Description string       `json:"description"`
	Items       []bundleItem `json:"items"`
}

// catalogBundle is one bundle as the Hub renders it: the registry metadata plus
// the resolved item list.
type catalogBundle struct {
	ID          string       `json:"id"`
	Name        string       `json:"name"`
	Description string       `json:"description"`
	Tagline     string       `json:"tagline,omitempty"`
	Sources     string       `json:"sources,omitempty"`
	Path        string       `json:"path"`
	Items       []bundleItem `json:"items"`
}

type pluginRegistryEntry struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Tagline     string   `json:"tagline,omitempty"`
	Description string   `json:"description,omitempty"`
	Author      string   `json:"author,omitempty"`
	Official    bool     `json:"official,omitempty"`
	Tags        []string `json:"tags,omitempty"`
	Icon        string   `json:"icon,omitempty"`
	Screenshots []string `json:"screenshots,omitempty"`
	Preview     string   `json:"preview,omitempty"`
	Hosts       []string `json:"hosts,omitempty"`
	Path        string   `json:"path,omitempty"`
}

type pluginRegistry struct {
	Version int                   `json:"version"`
	Plugins []pluginRegistryEntry `json:"plugins"`
}

// catalogPlugin is one plugin as the Hub renders it: the registry metadata
// enriched from the plugin's manifest.json, with screenshot/preview asset paths
// resolved to absolute URLs the Hub can fetch directly.
type catalogPlugin struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Tagline     string   `json:"tagline,omitempty"`
	Description string   `json:"description,omitempty"`
	Author      string   `json:"author,omitempty"`
	Official    bool     `json:"official,omitempty"`
	Tags        []string `json:"tags,omitempty"`
	Icon        string   `json:"icon,omitempty"`
	Screenshots []string `json:"screenshots,omitempty"`
	Preview     string   `json:"preview,omitempty"`
	Hosts       []string `json:"hosts,omitempty"`
	Path        string   `json:"path"`
}

func runExtras(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("extras needs catalog|cache|installer|plugin|plugincatalog")
	}
	switch args[0] {
	case "catalog":
		cat, err := buildCatalog()
		if err != nil {
			return err
		}
		b, err := json.Marshal(cat)
		if err != nil {
			return err
		}
		os.Stdout.Write(b)
		fmt.Println()
		return nil
	case "cache":
		fmt.Println(extrasCacheDir())
		return nil
	case "installer":
		if len(args) < 2 {
			return fmt.Errorf("extras installer needs a name")
		}
		p, err := ensureInstaller(args[1])
		if err != nil {
			return err
		}
		fmt.Println(p)
		return nil
	case "plugin":
		if len(args) < 2 {
			return fmt.Errorf("extras plugin needs a name")
		}
		p, err := ensurePlugin(args[1])
		if err != nil {
			return err
		}
		fmt.Println(p)
		return nil
	case "pluginremove":
		if len(args) < 2 {
			return fmt.Errorf("extras pluginremove needs a name")
		}
		return removePlugin(args[1])
	case "plugincatalog":
		cat, err := buildPluginCatalog()
		if err != nil {
			return err
		}
		b, err := json.Marshal(cat)
		if err != nil {
			return err
		}
		os.Stdout.Write(b)
		fmt.Println()
		return nil
	default:
		return fmt.Errorf("extras needs catalog|cache|installer|plugin|plugincatalog")
	}
}

var extrasClient = &http.Client{Timeout: 12 * time.Second}

func fetch(url string) ([]byte, error) {
	// Bust the GitHub raw (Fastly) CDN cache. The plain URL can keep serving a
	// pre-push copy of the catalogue for minutes, so a Hub refresh looks broken:
	// it re-fetches but keeps getting the stale registry.json. A unique query
	// param is the only reliable buster (raw ignores it for content but keys its
	// cache on it); the no-cache header is belt and braces.
	sep := "?"
	if strings.Contains(url, "?") {
		sep = "&"
	}
	req, err := http.NewRequest(http.MethodGet, fmt.Sprintf("%s%s_=%d", url, sep, time.Now().UnixNano()), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Cache-Control", "no-cache")
	resp, err := extrasClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("%s: %s", url, resp.Status)
	}
	return io.ReadAll(io.LimitReader(resp.Body, 4<<20))
}

func writeCache(rel string, data []byte) {
	p := filepath.Join(extrasCacheDir(), rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return
	}
	tmp, err := os.CreateTemp(filepath.Dir(p), ".tmp-*")
	if err != nil {
		return
	}
	name := tmp.Name()
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		os.Remove(name)
		return
	}
	if err := tmp.Close(); err != nil {
		os.Remove(name)
		return
	}
	os.Rename(name, p)
}

// fetchOrCache returns the live bytes (caching them) or, when the network is
// unreachable, the last cached copy, so the catalogue still renders offline.
func fetchOrCache(rel string) ([]byte, error) {
	if b, err := fetch(extrasBase() + "/" + rel); err == nil {
		writeCache(rel, b)
		return b, nil
	}
	if b, err := os.ReadFile(filepath.Join(extrasCacheDir(), rel)); err == nil {
		return b, nil
	}
	return nil, fmt.Errorf("cannot fetch or find cached %s", rel)
}

func buildCatalog() (map[string][]catalogBundle, error) {
	raw, err := fetchOrCache("bundles/registry.json")
	if err != nil {
		return nil, err
	}
	var reg registry
	if err := json.Unmarshal(raw, &reg); err != nil {
		return nil, fmt.Errorf("registry.json: %w", err)
	}

	out := make([]catalogBundle, 0, len(reg.Bundles))
	for _, e := range reg.Bundles {
		path := e.Path
		if path == "" {
			path = "bundles/" + e.ID
		}
		cb := catalogBundle{ID: e.ID, Name: e.Name, Description: e.Description, Tagline: e.Tagline, Sources: e.Sources, Path: path}
		if b, err := fetchOrCache(path + "/bundle.json"); err == nil {
			var def bundleDef
			if json.Unmarshal(b, &def) == nil {
				cb.Items = def.Items
				if cb.Description == "" {
					cb.Description = def.Description
				}
				if cb.Name == "" {
					cb.Name = def.Name
				}
			}
		}
		// Warm the installer cache for any script item, best-effort and lazy.
		for _, it := range cb.Items {
			if it.Type == "script" {
				rel := "installers/" + it.Name + ".sh"
				if _, err := os.Stat(filepath.Join(extrasCacheDir(), rel)); err != nil {
					if data, err := fetch(extrasBase() + "/" + rel); err == nil {
						writeCache(rel, data)
					}
				}
			}
		}
		out = append(out, cb)
	}
	return map[string][]catalogBundle{"bundles": out}, nil
}

func buildPluginCatalog() (map[string][]catalogPlugin, error) {
	raw, err := fetchOrCache("plugins/registry.json")
	if err != nil {
		return nil, err
	}
	var reg pluginRegistry
	if err := json.Unmarshal(raw, &reg); err != nil {
		return nil, fmt.Errorf("plugins/registry.json: %w", err)
	}

	out := make([]catalogPlugin, 0, len(reg.Plugins))
	for _, e := range reg.Plugins {
		path := e.Path
		if path == "" {
			path = "plugins/" + e.ID
		}
		cp := catalogPlugin{
			ID:          e.ID,
			Name:        e.Name,
			Tagline:     e.Tagline,
			Description: e.Description,
			Author:      e.Author,
			Official:    e.Official,
			Tags:        e.Tags,
			Icon:        e.Icon,
			Screenshots: e.Screenshots,
			Preview:     e.Preview,
			Hosts:       e.Hosts,
			Path:        path,
		}
		// Best-effort manifest enrichment, mirroring how buildCatalog folds
		// bundle.json into the registry entry: only fill what the registry
		// omitted, so a curated registry always wins.
		if b, err := fetchOrCache(path + "/manifest.json"); err == nil {
			var man struct {
				Name        string   `json:"name"`
				Description string   `json:"description"`
				Hosts       []string `json:"hosts"`
				Tags        []string `json:"tags"`
			}
			if json.Unmarshal(b, &man) == nil {
				if cp.Name == "" {
					cp.Name = man.Name
				}
				if cp.Description == "" {
					cp.Description = man.Description
				}
				if len(cp.Hosts) == 0 {
					cp.Hosts = man.Hosts
				}
				if len(cp.Tags) == 0 {
					cp.Tags = man.Tags
				}
			}
		}
		// Resolve relative asset paths under plugins/<id>/ to absolute URLs;
		// anything already http(s):// passes through untouched.
		resolve := func(p string) string {
			if p == "" {
				return ""
			}
			if strings.HasPrefix(p, "http://") || strings.HasPrefix(p, "https://") {
				return p
			}
			return extrasBase() + "/" + path + "/" + strings.TrimLeft(p, "/")
		}
		cp.Preview = resolve(cp.Preview)
		if len(cp.Screenshots) > 0 {
			shots := make([]string, len(cp.Screenshots))
			for i, s := range cp.Screenshots {
				shots[i] = resolve(s)
			}
			cp.Screenshots = shots
		}
		out = append(out, cp)
	}
	return map[string][]catalogPlugin{"plugins": out}, nil
}

// ensureInstaller fetches a fresh copy of installers/<name>.sh into the cache and
// returns its path, falling back to the cached copy when offline.
func ensureInstaller(name string) (string, error) {
	rel := "installers/" + name + ".sh"
	dst := filepath.Join(extrasCacheDir(), rel)
	if b, err := fetch(extrasBase() + "/" + rel); err == nil {
		writeCache(rel, b)
		return dst, nil
	}
	if _, err := os.Stat(dst); err == nil {
		return dst, nil
	}
	return "", fmt.Errorf("installer %q not found in the catalogue", name)
}

// pluginDataDir is where an installed plugin's source lives; the shell runtime
// and Settings read it. Mirrors plugin_dir() in ryoku-extras-install.
func pluginDataDir(id string) string {
	base := os.Getenv("XDG_DATA_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".local", "share")
	}
	return filepath.Join(base, "ryoku", "plugins", id)
}

// removePlugin deletes an installed plugin from the data dir. It is symlink-safe:
// a dev plugin is often a symlink into a checkout, so the symlink itself is
// removed (os.Remove) without ever recursing into - and deleting - the source
// tree it points at. A real installed copy is removed with RemoveAll.
func removePlugin(id string) error {
	if id == "" {
		return fmt.Errorf("plugin id required")
	}
	// Drop the plugin's plugins.json entry (placement + settings) so its config
	// disappears with it; the data-dir removal below is the real uninstall.
	_ = exec.Command("ryoku-plugins-place", id, "forget").Run()
	dir := pluginDataDir(id)
	fi, err := os.Lstat(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil // already gone
		}
		return err
	}
	if fi.Mode()&os.ModeSymlink != 0 {
		return os.Remove(dir) // unlink only; never touch the target
	}
	return os.RemoveAll(dir)
}

// ensurePlugin fetches a plugin's full source tree from the catalogue
// (plugins/<id>/) into the data dir and returns that dir. It reads the manifest
// to learn which files to pull (entryPoints + commands), so a plugin ships only
// the files it declares. Best-effort per file; a missing optional file is fine.
func ensurePlugin(id string) (string, error) {
	rel := "plugins/" + id
	manRaw, err := fetch(extrasBase() + "/" + rel + "/manifest.json")
	if err != nil {
		return "", fmt.Errorf("plugin %q not found in the catalogue: %w", id, err)
	}
	var man struct {
		EntryPoints map[string]string `json:"entryPoints"`
		Commands    []string          `json:"commands"`
		Files       []string          `json:"files"`
	}
	if err := json.Unmarshal(manRaw, &man); err != nil {
		return "", fmt.Errorf("plugin %q manifest: %w", id, err)
	}

	dst := pluginDataDir(id)
	if err := os.MkdirAll(dst, 0o755); err != nil {
		return "", err
	}
	write := func(name string, data []byte, mode os.FileMode) error {
		p := filepath.Join(dst, filepath.Clean(name))
		if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
			return err
		}
		return os.WriteFile(p, data, mode)
	}
	if err := write("manifest.json", manRaw, 0o644); err != nil {
		return "", err
	}

	files := []string{"README.md", "assets/preview.gif"}
	for _, f := range man.EntryPoints {
		files = append(files, f)
	}
	for _, c := range man.Commands {
		files = append(files, c)
	}
	files = append(files, man.Files...)
	for _, f := range files {
		b, err := fetch(extrasBase() + "/" + rel + "/" + f)
		if err != nil {
			continue // optional or absent; skip
		}
		mode := os.FileMode(0o644)
		if strings.HasPrefix(f, "bin/") {
			mode = 0o755
		}
		if err := write(f, b, mode); err != nil {
			return "", err
		}
	}
	// Seed the plugin's preset block into plugins.json so its settings exist in
	// the right place the moment it is installed (forgotten again on uninstall).
	_ = exec.Command("ryoku-plugins-place", id, "seed").Run()
	return dst, nil
}
