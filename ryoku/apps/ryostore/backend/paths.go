package main

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// The extras catalogue lives in the ryoku-extras repo, fetched from raw GitHub.
// RYOKU_EXTRAS_BASE overrides the base for a fork or a local tree under test.
const defaultExtrasBase = "https://raw.githubusercontent.com/neur0map/ryoku-extras/main"

func extrasBase() string {
	if b := os.Getenv("RYOKU_EXTRAS_BASE"); b != "" {
		return strings.TrimRight(b, "/")
	}
	if b := configuredExtrasBase(); b != "" {
		return strings.TrimRight(b, "/")
	}
	return defaultExtrasBase
}

// configuredExtrasBase reads a persistent source override from
// ${XDG_CONFIG_HOME:-~/.config}/ryoku/ryostore-base (one line: a base URL or a
// file:// path). It lets a dev checkout, fork, or mirror be selected without a
// session env var, which a long-running compositor may never have inherited.
func configuredExtrasBase() string {
	b, err := os.ReadFile(filepath.Join(configHome(), "ryoku", "ryostore-base"))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// localBase reports whether the extras base is a local tree (file:// URL) and
// returns its root path. A local base lets a fork or a checkout under test serve
// the catalogue straight off disk, with no network and no CDN, so browsing is
// instant and art loads from the same tree.
func localBase(base string) (string, bool) {
	if strings.HasPrefix(base, "file://") {
		return strings.TrimPrefix(base, "file://"), true
	}
	return "", false
}

func xdgCacheHome() string {
	if b := os.Getenv("XDG_CACHE_HOME"); b != "" {
		return b
	}
	return filepath.Join(os.Getenv("HOME"), ".cache")
}

// extrasCacheDir is where fetched registries and assets are cached so the
// catalogue still renders offline. The default source keeps the legacy
// ${XDG_CACHE_HOME:-~/.cache}/ryoku/extras location for upgrade and offline
// continuity; an explicit RYOKU_EXTRAS_BASE override caches under a stable
// per-source subdirectory so a fork or local tree never serves its bytes as the
// default source's archive.
func extrasCacheDir() string {
	root := filepath.Join(xdgCacheHome(), "ryoku", "extras")
	if extrasBase() == defaultExtrasBase {
		return root
	}
	sum := sha256.Sum256([]byte(extrasBase()))
	return filepath.Join(root, "sources", hex.EncodeToString(sum[:8]))
}

func currentRyokuVersion() string {
	out, err := exec.Command("ryoku", "version").Output()
	if err != nil {
		return ""
	}
	return strings.TrimPrefix(strings.TrimSpace(string(out)), "v")
}
