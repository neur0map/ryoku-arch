package doctor

import (
	"os"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"strings"
)

// The user overlay (~/.config/ryoku/user_edits) is the one place a user's config
// edits live, laid over the Ryoku-owned base on every update. This reconciler
// converges what materialize's file copy cannot: it seeds the how-to guide and
// adopts a machine's legacy loose files into the overlay. Idempotent.

// userEditsAdopt: hand-edited files that used to sit loose in ~/.config, moved
// into the overlay so they survive an update as user edits. The live copy stays
// put (the overlay re-lays it), so adoption never disturbs a running session.
// The Hub-generated files (settings.lua, rebinds.lua) are not here: the Hub
// writes those into the overlay itself.
var userEditsAdopt = []string{
	"hypr/user.lua",
	"hypr/monitors_user.lua",
	"kitty/user.conf",
}

func reconcileUserEditsAdopt(checkOnly bool) recResult {
	edits := sys.UserEditsDir()
	cfg := sys.ConfigHome()
	guide := filepath.Join(edits, "README.md")
	var pending []string
	if !sys.Exists(guide) {
		pending = append(pending, "README.md (the how-to-edit guide)")
	}
	for _, rel := range userEditsAdopt {
		if sys.Exists(filepath.Join(cfg, rel)) && !sys.Exists(filepath.Join(edits, rel)) {
			pending = append(pending, rel)
		}
	}
	if len(pending) == 0 {
		return okRes("overlay is set up")
	}
	if checkOnly {
		return wouldRes("overlay needs setting up: %s", strings.Join(pending, ", ")).
			withFix("ryoku doctor writes the guide and adopts loose files into %s", edits)
	}
	if err := os.MkdirAll(edits, 0o755); err != nil {
		return failRes("could not create the overlay dir %s: %v", edits, err)
	}
	if !sys.Exists(guide) {
		if err := os.WriteFile(guide, []byte(userEditsGuide), 0o644); err != nil {
			return failRes("could not write the overlay guide: %v", err).withFix("ryoku doctor")
		}
	}
	var adopted []string
	for _, rel := range userEditsAdopt {
		src, dst := filepath.Join(cfg, rel), filepath.Join(edits, rel)
		if sys.Exists(src) && !sys.Exists(dst) {
			if err := sys.CopyFile(src, dst); err != nil {
				return failRes("could not adopt %s into the overlay: %v", rel, err).
					withFix("copy it into %s by hand", edits)
			}
			adopted = append(adopted, rel)
		}
	}
	if len(adopted) == 0 {
		return fixedRes("wrote the overlay guide to %s", guide)
	}
	return fixedRes("set up the overlay: wrote the guide and adopted %s", strings.Join(adopted, ", "))
}

// userEditsGuide is seeded at the overlay root as README.md (which the overlay
// never lays into the live config), so a hand-editor who opens
// ~/.config/ryoku/user_edits sees what the tree is and how to use it.
const userEditsGuide = `# Your edits live here

This folder mirrors ~/.config. Anything you put here is yours: it wins over
Ryoku's defaults and survives every update. Ryoku's own files (the "base") are
replaced on each update, so fixes and new features keep arriving underneath your
changes. Empty is fine, add a file only to change something.

--- how overriding works -------------------------------------------------

    base (Ryoku)        laid down first, every update     you get fixes
    user_edits (here)   laid on top, wins per file        your changes win

Two ways to change a file:

  - Overlay (recommended): add your lines to the tool's own user file, like
    hypr/user.lua or kitty/user.conf. Ryoku's file still loads underneath, so a
    new default keybind or a bug fix still reaches you.
  - Fork: copy a whole Ryoku file here at the same path and edit it. You own it
    now, and ryoku doctor warns when an update changes the original.

--- what edits what ------------------------------------------------------

    hypr/user.lua        your Hyprland tweaks: binds, window rules, config
    hypr/settings.lua    written by Ryoku Settings, edit it in the GUI
    hypr/rebinds.lua     written by Ryoku Settings (keybind remaps), GUI only
    hypr/modules/*.lua   fork one to fully own a piece of the Hyprland config
    kitty/kitty.conf     fork it, or add to kitty/user.conf
    ryoku/*.json         Ryoku Settings state; the app keeps it, change it in-GUI

Any other file under ~/.config can be forked the same way: mirror its path
here and edit it.

--- commands -------------------------------------------------------------

    ryoku reset <path>   drop one edit, back to Ryoku's default
                         e.g. ryoku reset hypr/modules/binds.lua
    ryoku reset          drop everything here, back to defaults (asks first)
    ryoku recovery       last resort: wipe all edits and settings, pure Ryoku

--- notes ----------------------------------------------------------------

.md files here (like this one) are never copied into the live config, so keep
your own notes alongside your edits.
`
