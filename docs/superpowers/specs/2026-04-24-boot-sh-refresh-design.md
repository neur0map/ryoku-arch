# boot.sh Refresh Design

## Context

`boot.sh` is the Ryoku online bootstrap: the script a fresh Arch Linux user runs via `bash <(curl -fsSL ...)`. It seeds the pacman mirrorlist, installs git, clones the Ryoku repo to `~/.local/share/ryoku`, checks out the requested branch, and sources `install.sh` to begin the full install.

The current boot.sh works structurally but carries three categories of rot from its Omarchy lineage:

1. **Broken default branch.** `RYOKU_REF="${RYOKU_REF:-master}"` references `master` but the repo's default branch is `main`. Fresh curl-to-shell users hit `git checkout master` -> fail. This alone would soft-brick new installs.
2. **Stale Omarchy infrastructure references.** `RYOKU_MIRROR=edge|rc|stable` is exported based on channel selection, but Ryoku does not own those mirrors (they were Omarchy-specific). Nothing downstream reads the variable. Dead code.
3. **Destructive omarchy dir handling.** `rm -rf "$HOME/.local/share/omarchy"` runs unconditionally. On fresh installs this is a no-op. On systems migrating from pre-rename Omarchy (where `~/.local/share/omarchy` may contain a legitimate git checkout with local commits), this silently discards history.

The banner art also carries a legacy shape at the top that no longer reads as anything Ryoku-specific, and the color (Japanese old red `#8F1D21`) does not match the rest of the Ryoku desktop which standardized on accent orange `#F25623` during the Phase 1 frame work.

## Goals

1. Fresh-install path works end to end on any modern Arch Linux base, with no manual env var overrides.
2. Legacy-Omarchy users get their data migrated, not destroyed, when they run boot.sh.
3. Banner is visually consistent with the Ryoku desktop identity (same orange as frame, Waybar, lockscreen, and logo-mark).
4. Script stays single-phase, non-interactive: curl-to-shell behavior is preserved; no prompts added.
5. Zero new runtime dependencies. Everything the banner needs is already present in any bash 5 + 24-bit-color terminal.

## Non-goals

- No interactive setup wizard (no gum, no huh, no prompts). A separate spec can propose that later.
- No chafa or other image-rendering tool at runtime. Hand-crafted ASCII block art is deliberately chosen because (a) boot.sh may run on the Arch installer VT with no extra packages, (b) Alacritty rendering tests showed chafa-to-terminal gives mediocre visual quality on standard terminals, and (c) a simple geometric kanji renders cleaner by hand than by photo-dithering.
- No package list changes, no first-run script changes, no migration changes. boot.sh delegates all of that to `install.sh`; those surfaces evolve separately.
- No fix for ryoku-update divergence. Upgrade-path reliability is out of scope; boot.sh remains the fresh-install entrypoint only.

## Locked decisions

| Decision | Choice | Rationale |
|---|---|---|
| Interaction model | Static, non-interactive (option A from brainstorming) | Preserves current curl-to-shell shape; no new UX surface |
| Banner color | Ryoku orange `#F25623` | Matches frame, Waybar, lockscreen, logo-mark |
| Banner rendering method | Hand-crafted ASCII block art | Works in TTY and every terminal; no runtime deps; crisper than chafa at small sizes for geometric glyphs |
| Omarchy dir handling | Migrate if real dir, ignore if symlink or absent | Preserves pre-rename user history |

## Architecture

boot.sh phases (unchanged from today):

```
1. Print banner             <- refresh
2. Set env vars (REF, REPO) <- fix defaults, drop MIRROR
3. Seed mirrorlist
4. pacman -Syu git
5. Handle ~/.local/share/omarchy legacy path  <- migrate, do not nuke
6. rm -rf + git clone to ~/.local/share/ryoku (fresh-install guarantee)
7. git fetch + checkout RYOKU_REF
8. source install.sh
```

All four edits land inside the same file. There is no other file to touch: the banner text is embedded as a heredoc in boot.sh itself, not sourced from the repo (which is not cloned yet at banner time).

## File-by-file changes

### `boot.sh`

**Banner block (current lines 7..31):**

Replace the art heredoc and the single `printf` that colors it. New structure:

```bash
# Ryoku banner: hand-crafted ASCII block-art 力 kanji + RYOKU wordmark +
# tagline. Orange #F25623 matches the rest of the Ryoku visual identity.
kanji_art='
                    ███████████████
                    ███████████████
  █████████████████████████████████████████
  █████████████████████████████████████████
                    █████          ████████
                  ██████           ████████
                ████████           ███████
              ███████              ██████
            ██████                ██████
          ██████                ████████
        ██████                ████████
      ████████             ███████
   ████████              ██████
'

wordmark='
 ██████╗ ██╗   ██╗ ██████╗ ██╗  ██╗██╗   ██╗
 ██╔══██╗╚██╗ ██╔╝██╔═══██╗██║ ██╔╝██║   ██║
 ██████╔╝ ╚████╔╝ ██║   ██║█████╔╝ ██║   ██║
 ██╔══██╗  ╚██╔╝  ██║   ██║██╔═██╗ ██║   ██║
 ██║  ██║   ██║   ╚██████╔╝██║  ██╗╚██████╔╝
 ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝ ╚═════╝
'

tagline='            力と美のために  :  For the sake of power and beauty.'

clear
# Ryoku accent orange #F25623 for brand elements; subdued theme foreground
# #aeab94 for the tagline so the kanji and wordmark read as the focal point.
printf '\033[38;2;242;86;35m%s\n%s\033[0m\n' "$kanji_art" "$wordmark"
printf '\033[38;2;174;171;148m%s\033[0m\n\n' "$tagline"
```

The exact ASCII block art for the kanji is a working sketch; the implementation step will iterate on it until it renders cleanly in a 26-column-wide block above the wordmark. The spec locks the approach, not the exact glyph pixels.

**Env var block (current lines 37..44):**

Replace:
```bash
RYOKU_REF="${RYOKU_REF:-master}"

case "$RYOKU_REF" in
  dev) export RYOKU_MIRROR=edge ;;
  rc)  export RYOKU_MIRROR=rc ;;
  *)   export RYOKU_MIRROR=stable ;;
esac
```

With:
```bash
RYOKU_REF="${RYOKU_REF:-main}"
```

The `RYOKU_MIRROR` case block is removed entirely: nothing consumes it, and Ryoku does not operate mirrors under those names.

**Omarchy dir block (current line 59):**

Replace the unconditional `rm -rf "$HOME/.local/share/omarchy"` with:

```bash
# If the pre-rename ~/.local/share/omarchy is a real directory (legacy
# Omarchy install), archive it by renaming rather than deleting so the
# user keeps their git history and any local commits. If it is a symlink
# (created by the post-rename compat shim) or absent, leave it alone.
OMARCHY_DIR="$HOME/.local/share/omarchy"
if [[ -d $OMARCHY_DIR && ! -L $OMARCHY_DIR ]]; then
  MIGRATED_DIR="$HOME/.local/share/ryoku.migrated-$(date +%s)"
  mv "$OMARCHY_DIR" "$MIGRATED_DIR"
  echo "Archived legacy ~/.local/share/omarchy to $MIGRATED_DIR"
fi
```

**Fresh-install guard comment (above current line 60):**

Add a comment clarifying that `rm -rf "$HOME/.local/share/ryoku"` is intentional because boot.sh is a fresh-install entrypoint:

```bash
# boot.sh is a fresh-install entrypoint. For upgrades, use ryoku-update,
# which preserves the local clone and applies migrations. Re-running
# boot.sh on an installed system will destroy the local clone.
rm -rf "$HOME/.local/share/ryoku"
```

No logic change on that line; the comment just documents intent for anyone reading the script.

## Test plan

### Local smoke (before committing)

1. `bash -n boot.sh` returns 0 (syntax clean).
2. `shellcheck boot.sh` returns 0 or only informational warnings.
3. Run just the banner portion in a throwaway shell: copy the `printf` block into a scratch script and run it. Verify:
   - Kanji renders in Ryoku orange.
   - Wordmark reads RYOKU legibly.
   - Tagline reads in a dimmer tone.
   - No broken escape codes visible as raw text.

### Fresh-install VM test (blocking for marking ready-to-ship)

Spin up a clean Arch base in QEMU. The test passes when:

1. `bash <(curl -fsSL https://raw.githubusercontent.com/neur0map/ryoku-arch/main/boot.sh)` prints the banner without error.
2. `git clone` succeeds on `main` with no override.
3. `install.sh` runs through to completion.
4. Reboot drops into a Ryoku desktop (Hyprland, Waybar, greeter).

This test is the same one flagged in the Phase 1 spec as a prerequisite for ISO readiness. Not blocking for landing the boot.sh PR locally, but landing boot.sh unlocks this test.

### Legacy-omarchy migration test

On a fresh VM:

1. Pre-populate `~/.local/share/omarchy` as a real git repo (e.g. clone the old Omarchy upstream, commit a marker file).
2. Run boot.sh.
3. Verify:
   - `~/.local/share/omarchy` no longer exists.
   - `~/.local/share/ryoku.migrated-<timestamp>` exists and contains the marker file and the original commits.
   - `~/.local/share/ryoku` is a fresh clone of the Ryoku repo at `main`.

## Gaps explicitly left for Phase 2+

- Interactive channel / hostname / timezone / user wizard (gum-based). Would belong in `install/first-run/` or a new `bin/ryoku-setup-wizard`, not boot.sh.
- Separate `boot.sh` hosting behind a short URL like `ryoku.sh`. Requires DNS and a static host. Orthogonal to the script contents.
- ISO build pipeline. Tracked in the Phase 1 spec's follow-up list; boot.sh remains the curl-to-shell entrypoint even after ISOs exist (the ISO's first-boot hook will call install.sh directly, bypassing boot.sh).

## Rollback plan

Before starting implementation: snapshot tag `pre-boot-sh-refresh` at the current dev-clone HEAD and push it. Rollback is:

```bash
cd /home/omi/prowl/ryoku-arch
git reset --hard pre-boot-sh-refresh
git push --force-with-lease origin main   # only if the refresh had been pushed
```

Single-file edit, single commit, trivial revert.
