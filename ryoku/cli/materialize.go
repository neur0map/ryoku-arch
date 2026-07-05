package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// generatedSeed: base files seeded once on a fresh install, then never
// clobbered or pruned by an update. The machine owns them after first boot.
// Two kinds qualify: per-machine files the runtime regenerates (monitors.lua
// from ryoku-monitor, gpu.lua from ryoku-gpu), and user-owned config the
// package only seeds a default for (keyboard.lua, the keyboard layout).
//
// fastfetch/config.jsonc is the second kind. kitty and Hyprland let a shipped
// config stay managed because the user's edits live in a separate include
// (kitty user.conf, hypr user.lua) an update never touches; fastfetch reads a
// single config file with no include, so editing config.jsonc directly is the
// only way to customize the readout, and clobbering it on every update wiped
// that out. seed it once instead. the emblem it draws (fastfetch-emblem.png)
// stays managed so the logo keeps updating, and ryoku doctor restores it
// wherever the config points, so this does not bring back the Arch-logo bug.
// Slash-separated paths, relative to the config base.
var generatedSeed = map[string]bool{
	"hypr/monitors.lua":      true,
	"hypr/gpu.lua":           true,
	"hypr/keyboard.lua":      true,
	"fastfetch/config.jsonc": true,
}

// Materialize lays the Ryoku-owned base configs into the user's ~/.config,
// declaratively: every file the package ships under baseConfigDir() is
// copied over (clobbering the previous Ryoku copy), files we shipped before
// but no longer ship are removed, anything the package never shipped (user
// files: hypr/user.lua, kitty/user.conf, ...) is left alone. Per-machine
// generated seeds (generatedSeed, e.g. hypr/monitors.lua) are the exception:
// seeded only when absent, never clobbered, so an update keeps the user's
// runtime-written display and GPU config.
//
// Production replacement for deploy.sh's per-user config copy. Base lives at
// /usr/share/ryoku/config on an installed system; on a dev checkout
// RYOKU_CONFIG_BASE points at ryoku/<...> via `ryoku deploy`.
//
// The set of Ryoku-owned paths is the manifest. Recorded in the state file so
// the next run can prune files dropped from a release without guessing.
func materialize() error {
	base := baseConfigDir()
	dest := configHome()
	state := materializeStatePath()

	info, err := os.Stat(base)
	if err != nil || !info.IsDir() {
		if os.Getenv("RYOKU_CONFIG_BASE") != "" {
			return fmt.Errorf("base config dir not found: %s (RYOKU_CONFIG_BASE points at a missing dir)", base)
		}
		return fmt.Errorf("base config dir not found: %s\n"+
			"  `ryoku materialize` applies a packaged install's config; on a dev checkout run `ryoku deploy` instead", base)
	}

	current, err := walkRel(base)
	if err != nil {
		return fmt.Errorf("scan %s: %w", base, err)
	}

	// Lay down every shipped file, except seeds: those copy only when absent
	// (fresh install) and never get overwritten, so an update leaves the
	// user's display, GPU pin, and keyboard layout alone. Only clobbered
	// files enter the manifest, so a later prune can never remove a seed either.
	managed := make([]string, 0, len(current))
	for _, rel := range current {
		dst := filepath.Join(dest, rel)
		if generatedSeed[rel] {
			if !exists(dst) {
				if err := copyFile(filepath.Join(base, rel), dst); err != nil {
					return fmt.Errorf("seed %s: %w", rel, err)
				}
			}
			continue
		}
		if err := copyFile(filepath.Join(base, rel), dst); err != nil {
			return fmt.Errorf("copy %s: %w", rel, err)
		}
		managed = append(managed, rel)
	}

	// Prune files this release no longer ships (in the previous manifest,
	// absent now). Never touches paths outside the manifest, i.e. user files.
	previous := readManifest(state)
	curSet := make(map[string]bool, len(current))
	for _, p := range current {
		curSet[p] = true
	}
	for _, rel := range previous {
		if curSet[rel] {
			continue
		}
		_ = os.Remove(filepath.Join(dest, rel))
		pruneEmptyParents(dest, filepath.Dir(rel))
	}

	if err := writeManifest(state, managed); err != nil {
		return fmt.Errorf("record manifest: %w", err)
	}
	fmt.Printf("materialized %d files -> %s\n", len(managed), dest)
	return nil
}

// walkRel: every regular file under root, as slash-separated paths relative
// to root, sorted.
func walkRel(root string) ([]string, error) {
	var rels []string
	err := filepath.WalkDir(root, func(p string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(root, p)
		if err != nil {
			return err
		}
		rels = append(rels, filepath.ToSlash(rel))
		return nil
	})
	sort.Strings(rels)
	return rels, err
}

func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	si, err := in.Stat()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	tmp := dst + ".ryoku-tmp"
	out, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, si.Mode().Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		os.Remove(tmp)
		return err
	}
	if err := out.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, dst)
}

func pruneEmptyParents(root, rel string) {
	for rel != "." && rel != "/" && rel != "" {
		dir := filepath.Join(root, rel)
		entries, err := os.ReadDir(dir)
		if err != nil || len(entries) > 0 {
			return
		}
		if err := os.Remove(dir); err != nil {
			return
		}
		rel = filepath.Dir(rel)
	}
}

func readManifest(path string) []string {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var out []string
	for _, line := range strings.Split(string(b), "\n") {
		if line = strings.TrimSpace(line); line != "" {
			out = append(out, line)
		}
	}
	return out
}

func writeManifest(path string, rels []string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(strings.Join(rels, "\n")+"\n"), 0o644)
}
