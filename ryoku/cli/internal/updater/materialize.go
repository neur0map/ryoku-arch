package updater

import (
	"fmt"
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"sort"
	"strings"
)

// generatedSeed: base files seeded once on a fresh install, then never
// clobbered or pruned by an update. The machine owns them after first boot.
// Two kinds qualify: per-machine files the runtime regenerates (monitors.lua,
// gpu.lua; kitty/current-theme.conf, which wallust rewrites from the wallpaper)
// and user-owned config the package only seeds a starting point for
// (keyboard.lua; hypr/user.lua, seeded with a header so a hand-edit sticks;
// fastfetch/config.jsonc, which has no include mechanism, so direct edits
// are the only way to customize the readout).
// Slash-separated paths, relative to the config base.
var generatedSeed = map[string]bool{
	"hypr/monitors.lua":        true,
	"hypr/gpu.lua":             true,
	"hypr/keyboard.lua":        true,
	"hypr/user.lua":            true,
	"fastfetch/config.jsonc":   true,
	"kitty/current-theme.conf": true,
}

// Materialize lays the Ryoku-owned base configs into the user's ~/.config,
// declaratively: every file the package ships under baseConfigDir() is
// copied over (clobbering the previous Ryoku copy), files we shipped before
// but no longer ship are removed, anything the package never shipped (user
// files: hypr/monitors_user.lua, kitty/user.conf, ...) is left alone. Per-machine
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
func Materialize() error {
	base := sys.BaseConfigDir()
	dest := sys.ConfigHome()
	state := materializeStatePath()

	info, err := os.Stat(base)
	if err != nil || !info.IsDir() {
		if os.Getenv("RYOKU_CONFIG_BASE") != "" {
			return fmt.Errorf("base config dir not found: %s (RYOKU_CONFIG_BASE points at a missing dir)", base)
		}
		return fmt.Errorf("base config dir not found: %s\n"+
			"  `ryoku materialize` applies a packaged install's config; on a dev checkout run `ryoku deploy` instead", base)
	}

	// ~/.config/ryoku is where the shell's JSON stores live (shell.json,
	// launcher.json, hypr.json). The package ships no file under it, so the
	// walk below never creates it, and the shell's QML self-seed cannot make
	// parent directories: guarantee it here, at install and on every update.
	_ = os.MkdirAll(filepath.Join(dest, "ryoku"), 0o755)

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
			if !sys.Exists(dst) {
				if err := sys.CopyFile(filepath.Join(base, rel), dst); err != nil {
					return fmt.Errorf("seed %s: %w", rel, err)
				}
			}
			continue
		}
		if err := sys.CopyFile(filepath.Join(base, rel), dst); err != nil {
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

	// ~/.config/quickshell is wholly Ryoku-owned (user plugins live under
	// ~/.local/share/ryoku), so converge it against the shipped tree directly:
	// stale QML from releases this box's manifest never recorded (a lost state
	// file, an old deploy.sh run) would otherwise load beside the new tree
	// forever. Everything else is mixed with user files and stays manifest-pruned.
	if local, err := walkRel(filepath.Join(dest, "quickshell")); err == nil {
		for _, rel := range local {
			full := "quickshell/" + rel
			if curSet[full] || generatedSeed[full] {
				continue
			}
			_ = os.Remove(filepath.Join(dest, full))
			pruneEmptyParents(dest, filepath.Dir(full))
		}
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
	if err := overlayUserEdits(dest); err != nil {
		return err
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

// overlayUserEdits lays the user's override tree over the freshly materialized
// base: a regular file under ~/.config/ryoku/user_edits wins at the mirrored
// ~/.config path. Runs last, after the prune and the quickshell converge, so a
// fork is the final word and nothing sweeps it, while every base fix was still
// laid underneath first. An absent or empty overlay is a no-op.
func overlayUserEdits(dest string) error {
	rels, err := sys.UserEditFiles()
	if err != nil {
		return fmt.Errorf("scan overlay: %w", err)
	}
	root := sys.UserEditsDir()
	for _, rel := range rels {
		if err := sys.CopyFile(filepath.Join(root, rel), filepath.Join(dest, rel)); err != nil {
			return fmt.Errorf("overlay %s: %w", rel, err)
		}
	}
	return nil
}
