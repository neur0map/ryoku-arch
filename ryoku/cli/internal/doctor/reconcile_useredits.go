package doctor

import (
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"sort"
	"strings"
)

// The user overlay (~/.config/ryoku/user_edits) is the one place a user's config
// edits live, laid over the Ryoku-owned base on every update. These reconcilers
// converge the pieces materialize's file copy cannot: they adopt a machine's
// legacy scattered user files into the overlay, surface the Hub's structured
// stores in the same tree, and report when an upstream fix has landed on a file
// the user forked whole. All idempotent and safe to repeat.

// userEditsAdopt: the hand- and Hub-authored files that used to sit loose in
// ~/.config, now carried in the overlay so they survive an update as user edits.
// The live copy stays put (the overlay re-lays it), so adoption never disturbs a
// running session; it only teaches the overlay to own the file.
var userEditsAdopt = []string{
	"hypr/user.lua",
	"hypr/monitors_user.lua",
	"hypr/settings.lua",
	"hypr/rebinds.lua",
	"kitty/user.conf",
}

func reconcileUserEditsAdopt(checkOnly bool) recResult {
	edits := sys.UserEditsDir()
	cfg := sys.ConfigHome()
	var pending []string
	for _, rel := range userEditsAdopt {
		if sys.Exists(filepath.Join(cfg, rel)) && !sys.Exists(filepath.Join(edits, rel)) {
			pending = append(pending, rel)
		}
	}
	if len(pending) == 0 {
		return okRes("no legacy user files outside the overlay")
	}
	if checkOnly {
		return wouldRes("user file(s) live outside the overlay: %s", strings.Join(pending, ", ")).
			withFix("ryoku doctor copies them into %s", edits)
	}
	for _, rel := range pending {
		if err := sys.CopyFile(filepath.Join(cfg, rel), filepath.Join(edits, rel)); err != nil {
			return failRes("could not adopt %s into the overlay: %v", rel, err).
				withFix("copy it into %s by hand", edits)
		}
	}
	return fixedRes("adopted %d user file(s) into the overlay: %s", len(pending), strings.Join(pending, ", "))
}

// userEditsStores: the Hub's structured stores. They stay where the running
// shell reads them (~/.config/ryoku); the overlay surfaces them as symlinks so a
// user browses every edit in one tree without the shell's many read sites moving.
var userEditsStores = []string{
	"shell.json", "theme.json", "launcher.json", "widgets.json",
	"visualizer.json", "decor.json", "brand.json", "hypr.json", "plugins.json",
}

func reconcileUserEditsMirror(checkOnly bool) recResult {
	ryoku := filepath.Join(sys.ConfigHome(), "ryoku")
	mirror := filepath.Join(sys.UserEditsDir(), "ryoku")
	var link, heal []string
	for _, name := range userEditsStores {
		real := filepath.Join(ryoku, name)
		if !sys.Exists(real) {
			continue // no store yet; nothing to surface
		}
		l := filepath.Join(mirror, name)
		fi, err := os.Lstat(l)
		switch {
		case err != nil:
			link = append(link, name)
		case fi.Mode()&os.ModeSymlink != 0:
			if dst, _ := os.Readlink(l); dst != real {
				link = append(link, name)
			}
		default:
			heal = append(heal, name) // a real file broke the link
		}
	}
	if len(link) == 0 && len(heal) == 0 {
		return okRes("stores surfaced in the overlay")
	}
	if checkOnly {
		return wouldRes("store(s) not surfaced in the overlay: %s", strings.Join(append(append([]string{}, link...), heal...), ", ")).
			withFix("ryoku doctor links them into %s", mirror)
	}
	if err := os.MkdirAll(mirror, 0o755); err != nil {
		return failRes("could not create the overlay store mirror: %v", err)
	}
	// a hand atomic-save can replace a symlink with a real file: fold its content
	// back into the real store (the user's edit wins) before relinking.
	for _, name := range heal {
		l := filepath.Join(mirror, name)
		_ = sys.CopyFile(l, filepath.Join(ryoku, name))
		_ = os.Remove(l)
		link = append(link, name)
	}
	for _, name := range link {
		l := filepath.Join(mirror, name)
		_ = os.Remove(l)
		if err := os.Symlink(filepath.Join(ryoku, name), l); err != nil {
			return failRes("could not link %s into the overlay: %v", name, err).withFix("ryoku doctor")
		}
	}
	return fixedRes("surfaced %d store(s) in the overlay: %s", len(link), strings.Join(link, ", "))
}

// reconcileForkDrift reports files the user forked (took over whole) whose base
// version has since changed: an upstream fix cannot reach a forked file without a
// merge, so the user is told once, the ancestor advances so it does not nag, and
// their copy always stands. `ryoku reset <path>` takes the new base instead.
func reconcileForkDrift(checkOnly bool) recResult {
	ledger := sys.ReadForkLedger()
	if len(ledger) == 0 {
		return okRes("no forked files to watch")
	}
	base := sys.BaseConfigDir()
	if fi, err := os.Stat(base); err != nil || !fi.IsDir() {
		return okRes("no base tree to compare forks against")
	}
	drifted := map[string]string{}
	for rel, ancestor := range ledger {
		if cur := sys.FileHash(filepath.Join(base, rel)); cur != "" && cur != ancestor {
			drifted[rel] = cur
		}
	}
	if len(drifted) == 0 {
		return okRes("forked files are current with the base")
	}
	names := make([]string, 0, len(drifted))
	for rel := range drifted {
		names = append(names, rel)
	}
	sort.Strings(names)
	if checkOnly {
		return wouldRes("%d forked file(s) changed upstream since you took them over: %s", len(names), strings.Join(names, ", ")).
			withFix("review your copy, or `ryoku reset <path>` to take the new base")
	}
	for rel, cur := range drifted {
		ledger[rel] = cur // notice once per base change, then rest
	}
	_ = sys.WriteForkLedger(ledger)
	return noteRes("%d forked file(s) changed upstream; kept your version: %s", len(names), strings.Join(names, ", ")).
		withFix("review, or `ryoku reset <path>` to take the new base")
}
