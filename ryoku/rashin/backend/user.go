package main

import (
	"crypto/sha256"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// user.go builds user.md: the user-owned changes layer. It diffs the shipped
// base config tree (what `ryoku materialize` lays down) against the live
// ~/.config, so agents can tell Ryoku's defaults from this user's own edits,
// and it is reindexed separately from the system layer when the user changes
// something.

// baseConfigDir mirrors the ryoku CLI's resolution: the packaged base tree,
// overridable for dev checkouts.
func baseConfigDir() string {
	if v := os.Getenv("RYOKU_CONFIG_BASE"); v != "" {
		return v
	}
	return "/usr/share/ryoku/config"
}

// userOverrideFiles are the documented always-user files: present means the
// user customized; they are never shipped.
var userOverrideFiles = []string{
	"hypr/user.lua",
	"hypr/monitors_user.lua",
	"kitty/user.conf",
	"fish/user.fish",
	"bash/user.bash",
	"zsh/user.zsh",
}

type userDiff struct {
	Modified  []string // shipped file, user edited it in place
	Missing   []string // shipped file, user deleted it
	Overrides []string // dedicated user-override files present
}

// diffUserConfig walks the base tree and compares each file against the live
// config by content hash. relPrefix maps the base onto its subdir under cfg:
// "" for the packaged config tree (which already mirrors ~/.config), "hypr" for
// a dev checkout's hyprland tree.
func diffUserConfig(base, cfg, relPrefix string) (userDiff, error) {
	var d userDiff
	err := filepath.WalkDir(base, func(p string, e os.DirEntry, err error) error {
		if err != nil || e.IsDir() {
			return nil
		}
		rel, rerr := filepath.Rel(base, p)
		if rerr != nil {
			return nil
		}
		rel = filepath.ToSlash(filepath.Join(relPrefix, rel))
		live := filepath.Join(cfg, filepath.FromSlash(rel))
		lfi, lerr := os.Stat(live)
		if lerr != nil {
			d.Missing = append(d.Missing, rel)
			return nil
		}
		if lfi.IsDir() {
			return nil
		}
		if !sameContent(p, live) {
			d.Modified = append(d.Modified, rel)
		}
		return nil
	})
	if err != nil {
		return d, err
	}
	for _, rel := range userOverrideFiles {
		if _, err := os.Stat(filepath.Join(cfg, rel)); err == nil {
			d.Overrides = append(d.Overrides, rel)
		}
	}
	sort.Strings(d.Modified)
	sort.Strings(d.Missing)
	return d, nil
}

func sameContent(a, b string) bool {
	ha, err1 := fileHash(a)
	hb, err2 := fileHash(b)
	return err1 == nil && err2 == nil && ha == hb
}

func fileHash(p string) (string, error) {
	f, err := os.Open(p)
	if err != nil {
		return "", err
	}
	defer f.Close()
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", h.Sum(nil)), nil
}

// resolveUserBase finds the baseline to diff the live config against. The
// packaged base (/usr/share/ryoku/config, or RYOKU_CONFIG_BASE) mirrors the
// whole ~/.config, so its prefix is "". On a dev checkout that base is absent,
// so fall back to the checkout ryoku deploy recorded and diff its hyprland tree
// (prefix "hypr"), the surface where Ryoku-vs-user ownership actually lives.
func resolveUserBase() (base, prefix string, ok bool) {
	pkg := baseConfigDir()
	if fi, err := os.Stat(pkg); err == nil && fi.IsDir() {
		return pkg, "", true
	}
	if repo := recordedCheckout(); repo != "" {
		hypr := filepath.Join(repo, "ryoku", "hyprland")
		if fi, err := os.Stat(hypr); err == nil && fi.IsDir() {
			return hypr, "hypr", true
		}
	}
	return "", "", false
}

// recordedCheckout returns the repo root a dev deploy last recorded (or the
// RYOKU_RASHIN_REPO override), or "" when there is none. `ryoku/shell/deploy.sh`
// writes it to ~/.local/state/ryoku/repo on every `ryoku deploy`.
func recordedCheckout() string {
	if repo := os.Getenv("RYOKU_RASHIN_REPO"); repo != "" {
		return repo
	}
	state := os.Getenv("XDG_STATE_HOME")
	if state == "" {
		state = filepath.Join(home(), ".local", "state")
	}
	b, err := os.ReadFile(filepath.Join(state, "ryoku", "repo"))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// noBaselineBody covers the case with no baseline at all (no packaged config,
// no recorded dev checkout). It can still name the always-user override files,
// which are user-owned regardless of any baseline.
func noBaselineBody(cfg string) string {
	var present []string
	for _, rel := range userOverrideFiles {
		if _, err := os.Stat(filepath.Join(cfg, rel)); err == nil {
			present = append(present, rel)
		}
	}
	var b strings.Builder
	b.WriteString("No shipped baseline found: no `/usr/share/ryoku/config`, no\n" +
		"`RYOKU_CONFIG_BASE`, and no dev checkout recorded by `ryoku deploy`, so a\n" +
		"full shipped-vs-user diff is unavailable. Treat everything in `~/.config`\n" +
		"as potentially user-owned.\n")
	if len(present) > 0 {
		b.WriteString("\nThese override files are always user-owned and are present:\n\n")
		for _, f := range present {
			fmt.Fprintf(&b, "- `~/.config/%s`\n", f)
		}
	}
	return b.String()
}

// userDocBody renders the fenced body of user.md.
func userDocBody() string {
	cfg := configHomeDir()
	base, prefix, ok := resolveUserBase()
	if !ok {
		return noBaselineBody(cfg)
	}
	d, err := diffUserConfig(base, cfg, prefix)
	if err != nil {
		return "Diff failed: " + err.Error() + "\n"
	}

	var b strings.Builder
	if prefix != "" {
		b.WriteString("Baseline: this machine has no packaged `/usr/share/ryoku/config`, so the\n" +
			"comparison uses the hyprland tree of the dev checkout `ryoku deploy` recorded.\n" +
			"It covers `~/.config/hypr` (where Ryoku-vs-user ownership lives); other config\n" +
			"trees are not diffed here.\n\n")
	}
	if len(d.Modified) == 0 && len(d.Missing) == 0 && len(d.Overrides) == 0 {
		b.WriteString("The live config matches the shipped Ryoku baseline exactly; no user\nedits detected.\n")
		return b.String()
	}
	b.WriteString("Files where this user diverges from the shipped Ryoku baseline. Respect\n" +
		"these when editing: they are the user's own choices, not Ryoku defaults.\n\n")
	if len(d.Overrides) > 0 {
		b.WriteString("## User override files (always user-owned)\n\n")
		for _, f := range d.Overrides {
			fmt.Fprintf(&b, "- `~/.config/%s`\n", f)
		}
		b.WriteString("\n")
	}
	if len(d.Modified) > 0 {
		b.WriteString("## Shipped files that diverge (user or runtime edits)\n\n")
		for _, f := range d.Modified {
			fmt.Fprintf(&b, "- `~/.config/%s`\n", f)
		}
		b.WriteString("\n")
	}
	if len(d.Missing) > 0 {
		b.WriteString("## Shipped files the user removed\n\n")
		for _, f := range d.Missing {
			fmt.Fprintf(&b, "- `~/.config/%s`\n", f)
		}
	}
	return b.String()
}

func configHomeDir() string {
	if v := os.Getenv("XDG_CONFIG_HOME"); v != "" {
		return v
	}
	return filepath.Join(home(), ".config")
}

// writeUserVaultDoc lays user.md into the vault.
func writeUserVaultDoc() error {
	const header = "# User-owned changes\n" +
		"\n" +
		"Where this machine's config diverges from the shipped Ryoku baseline.\n" +
		"Generated: the content between the markers is overwritten whenever the\n" +
		"user's config changes."
	return writeVaultDoc("user.md", header, userDocBody())
}

// userConfigFingerprint summarizes the live config tree cheaply (paths,
// sizes, mtimes of Ryoku-relevant dirs) so the watcher can tell "something
// changed" without hashing every file.
func userConfigFingerprint() string {
	cfg := configHomeDir()
	h := sha256.New()
	for _, dir := range []string{"hypr", "quickshell", "ryoku", "kitty", "fish"} {
		root := filepath.Join(cfg, dir)
		_ = filepath.WalkDir(root, func(p string, e os.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			fi, ferr := e.Info()
			if ferr != nil {
				return nil
			}
			fmt.Fprintf(h, "%s|%d|%d\n", p, fi.Size(), fi.ModTime().UnixNano())
			return nil
		})
	}
	return fmt.Sprintf("%x", h.Sum(nil))
}
