# Omarchy Infrastructure Independence (Path A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut every operational dependency on DHH-operated infrastructure. After this plan lands, no Ryoku component needs `omarchy.org` DNS, `pkgs.omarchy.org` package hosting, or any `omarchy-*` AUR-shipped package to update, install, or run.

**Architecture:** Dependency-first cutover in nine chunks. Channel plumbing first so the rest of the plan can pivot off state. Mirror swap next so pacman is already pointing at upstream Arch when we start touching the repo section. Walker and nvim cutovers each split into preparation (committed, no live impact) and cutover (runs the migration) phases to keep blast radius bounded. Repo drop and keyring simplification come last because they remove surfaces earlier chunks still depend on. Final chunk runs the VM drill and updates docs.

**Tech Stack:** bash, pacman, yay (AUR helper), reflector, snapper, mkinitcpio, git, `pacman-conf`, `bash -n`, `luac -p`, `systemd-analyze`.

**Source spec:** `docs/superpowers/specs/2026-04-23-omarchy-infrastructure-independence-design.md`.

**Non-negotiable constraints:**
- No `Co-Authored-By` trailer on any commit. Plain `git commit -m` only.
- No mention of AI, Claude, Anthropic, or LLMs in any committed artifact.
- Destructive pacman operations (`-Rdd`, `-Syy` after config rewrite) require explicit user confirmation at execution time. These are gates, not auto-runs.
- AUR precondition check must pass before any chunk that installs from AUR.
- Every cutover migration calls `ryoku-snapshot create` first and records the snapshot ID in the session log.
- Repo and live clone must be at the same commit after each task completes.

---

## Preflight (one-time, not numbered)

Before Task 1, the implementation session records:

- Current repo HEAD and live-clone HEAD (must match).
- `pacman -Qq | grep '^omarchy-'` output from the live clone, saved to the session log. This is the authoritative list of installed `omarchy-*` packages at the start of the cutover. Any package in this list that is not in `{omarchy-keyring, omarchy-nvim, omarchy-walker}` becomes a documented follow-up, not in-scope work.
- `ryoku-pkg-aur-accessible` exit status. If non-zero, stop and resolve network access before proceeding.
- `snapper -c root list | head` confirming snapper is available; if not, record the fact and note that rollback switches to the manual recipes.
- Local TTY or SSH recovery path confirmed. Write the hostname and access method in the session log.

---

## Task 1: Channel state-file plumbing

**Files:**
- Create: `bin/ryoku-channel-current` (reads state file, defaults to `stable`)
- Modify: `bin/ryoku-version-channel` (replace mirror-URL grep with state-file read)
- Modify: `bin/ryoku-channel-set` (write state file, then call `ryoku-refresh-pacman`)
- Modify: `bin/ryoku-refresh-pacman` (read channel from state file if no arg)
- Create: new migration via `ryoku-dev-add-migration --no-edit` that backfills `$RYOKU_STATE_PATH/channel` from existing `/etc/pacman.d/mirrorlist` content

- [ ] **Step 1.1: Create `bin/ryoku-channel-current`**

The helper reads `$RYOKU_STATE_PATH/channel`, defaults to `stable` on absence, validates the value is one of `stable|rc|edge`, and prints it. Thin shell script, sourced by the callers. Chmod +x. `bash -n` must pass.

- [ ] **Step 1.2: Rewrite `bin/ryoku-version-channel`**

Drop the mirror-URL grep block. The command becomes a single line: `exec ryoku-channel-current`. Keep the shebang and runtime-env source so future code can add more detection if needed without another rewrite.

- [ ] **Step 1.3: Rewrite `bin/ryoku-channel-set`**

The command now writes `$1` to `$RYOKU_STATE_PATH/channel` (after validation), then calls `ryoku-refresh-pacman "$1"`. No pacman-config parsing.

- [ ] **Step 1.4: Update `bin/ryoku-refresh-pacman`**

If no argument, call `ryoku-channel-current` to get the channel. Otherwise use `$1` as today.

- [ ] **Step 1.5: Backfill migration**

Generate via `ryoku-dev-add-migration --no-edit`. Contents: if `$RYOKU_STATE_PATH/channel` does not exist, derive the current channel from the live `/etc/pacman.d/mirrorlist` (grep for `rc-mirror`, else `stable-mirror`, else `mirror`, else default `stable`), write it, and echo the result. Idempotent: if the file already exists, no-op.

- [ ] **Step 1.6: Syntax + smoke test**

Run:
```bash
bash -n bin/ryoku-channel-current bin/ryoku-version-channel bin/ryoku-channel-set bin/ryoku-refresh-pacman migrations/<new>.sh
bin/ryoku-channel-current
bin/ryoku-version-channel
```
Expected: both commands print the same channel identifier without error.

- [ ] **Step 1.7: Apply live**

Fast-forward the live clone from the repo, run the new migration explicitly (`bash migrations/<new>.sh`), confirm `cat ~/.local/state/ryoku/channel` returns `stable` (or whatever is correct for this machine), and `ryoku-version-channel` on the live clone returns the same value.

- [ ] **Step 1.8: Commit**

Stage only the files listed above. Commit message: `refactor: read ryoku channel from state file`.

- [ ] **Step 1.9: Push after live verification**

Push to origin. Fast-forward live clone from origin (already at the right commit, so it's a no-op in practice).

**Rollback note for Task 1:** `git revert <sha>`; pacman-config grepping returns. State file can be left behind; its presence does not break the reverted code.

---

## Task 2: Mirror swap to upstream Arch

**Files:**
- Modify: `default/pacman/mirrorlist-stable`, `mirrorlist-rc`, `mirrorlist-edge` (identical reflector-produced Arch mirror snapshots)
- Modify: `docs/maintenance.md` (add the reflector regeneration command and the snapshot date)
- Create: migration via `ryoku-dev-add-migration --no-edit` that rewrites `/etc/pacman.d/mirrorlist` via atomic write, after backing up to `/etc/pacman.d/mirrorlist.ryoku.bak`

- [ ] **Step 2.1: Install reflector if missing**

Confirm `pacman -Qq reflector` returns a version. If not, `sudo pacman -S reflector --noconfirm`. Record whether reflector was installed before this plan started in the session log.

- [ ] **Step 2.2: Generate the mirrorlist snapshot**

Run on a machine with a fresh pacman DB:
```bash
sudo reflector --country 'United States' --age 12 --protocol https --sort rate --save /tmp/ryoku-mirrorlist
head /tmp/ryoku-mirrorlist
```
Review the first ten entries. Copy the full file into `default/pacman/mirrorlist-stable`, `mirrorlist-rc`, and `mirrorlist-edge` identically. All three files must byte-for-byte match until a future channel model earns real separation.

The plan records the exact reflector command used (including country, age, protocol, sort) and the date in the session log and in `docs/maintenance.md`.

- [ ] **Step 2.3: Update `docs/maintenance.md`**

Add a short section: "Mirrorlist refresh. Run `<exact reflector command>`, copy the output to all three `default/pacman/mirrorlist-*` files, commit as a single change. Cadence: quarterly or on any visible mirror regression."

- [ ] **Step 2.4: Migration: atomic mirrorlist swap + cutover marker**

The migration:
1. `sudo cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.ryoku.bak` (idempotent: only if `.ryoku.bak` does not already exist).
2. Read `ryoku-channel-current` to pick which snapshot to copy.
3. Write `/etc/pacman.d/mirrorlist.ryoku.tmp` from `$RYOKU_PATH/default/pacman/mirrorlist-<channel>`.
4. `sudo mv -f /etc/pacman.d/mirrorlist.ryoku.tmp /etc/pacman.d/mirrorlist`.
5. `sudo pacman -Syy` to force DB refresh.
6. `mkdir -p $RYOKU_STATE_PATH && touch $RYOKU_STATE_PATH/independence-cutover.started`.

Migration aborts (non-zero exit) if step 5 fails; in that case, step 4 is already committed, but the backup at `.ryoku.bak` is still intact. Session log records the failure.

- [ ] **Step 2.5: Verify on a chroot**

Chroot validation for this chunk: on a tmpfs-backed pacstrap sandbox, copy the new mirrorlist into place, run `pacman -Sy --sysroot <chroot>`; must succeed and refresh all three Arch repos. Record the exact commands in the session log.

- [ ] **Step 2.6: Commit and apply live**

Commit message: `refactor: use upstream arch mirrors`. Stage the three mirrorlist files, the maintenance doc change, and the migration.

Apply live via local-remote fast-forward. Run the migration explicitly: `bash ~/.local/share/ryoku/migrations/<new>.sh`. Verify `grep -c omarchy.org /etc/pacman.d/mirrorlist` returns `0` and `sudo pacman -Sy` completes without errors.

- [ ] **Step 2.7: Push after live verification**

**Rollback note for Task 2:** `sudo cp -f /etc/pacman.d/mirrorlist.ryoku.bak /etc/pacman.d/mirrorlist && sudo pacman -Syy`. On repo side, `git revert <sha>`. The cutover marker `$RYOKU_STATE_PATH/independence-cutover.started` does not need to be removed for rollback; subsequent cutover migrations will re-trigger the snapshot gate, which is safe.

---

## Task 3: Tofi replacement preparation

**Files:**
- Create: `default/tofi/config` (tofi INI with Ryoku-themed colors, size, prompt; no behavior binding yet)
- Create: `default/tofi/pickers/` directory with shell scripts that replace the retired elephant Lua providers (theme picker, background picker). Each picker prints a list to stdin of a `tofi --dmenu`-style invocation and passes the selection back to its caller.
- Create: `install/packaging/tofi.sh` (new) that installs `tofi` via `ryoku-pkg-aur-install`
- Modify: `install/packaging/all.sh` (source the new tofi installer after the base package list step)
- Modify: `bin/ryoku-launch-walker`, `bin/ryoku-refresh-walker`, `bin/ryoku-restart-walker` (rewrite as thin tofi shims; filenames preserved)

The preparation chunk is allowed to land the shim rewrites because they do not take effect until tofi is installed on the live clone at Task 4. Any Hyprland binding that calls `ryoku-launch-walker` continues to hit walker through the old omarchy-walker package until the cutover runs.

- [ ] **Step 3.1: Verify tofi in AUR**

Run `yay -Si tofi | grep -E '^(Name|Version|Depends On)'`. If tofi is unavailable or the name has drifted, stop and amend the plan. Record the exact version observed in the session log.

- [ ] **Step 3.2: Write `default/tofi/config`**

Minimal INI that works immediately and does not require theming. Example shape (operator adjusts colors at plan execution time to match the current Ryoku theme):
```
font = "JetBrainsMono Nerd Font"
font-size = 12
prompt-text = "> "
width = 50%
height = 50%
anchor = center
background-color = #181818
text-color = #ffffff
selection-color = #00afff
border-width = 2
outline-width = 1
corner-radius = 6
```
Commit only after a local `tofi --config default/tofi/config < /etc/hostname` invocation returns without error (tofi parses the INI).

- [ ] **Step 3.3: Port the picker scripts**

Under `default/tofi/pickers/` create one shell script per retired elephant provider that Ryoku actually uses. At minimum: `themes.sh` and `backgrounds.sh`. Each script:
1. Enumerates the relevant list (themes from `~/.config/ryoku/themes/`, backgrounds from the active theme's `backgrounds/` directory).
2. Pipes it into `tofi --dmenu` (not `tofi` in app-launcher mode).
3. Captures the selection and passes it to the downstream ryoku command (for example, `ryoku-theme-set "$selection"`).

`bash -n` passes on every script.

- [ ] **Step 3.4: Rewrite launcher shim scripts**

`bin/ryoku-launch-walker` becomes:
```bash
#!/bin/bash
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"
if [[ $1 == --dmenu ]]; then
  shift
  exec tofi --dmenu "$@" --config "$RYOKU_PATH/default/tofi/config"
fi
exec tofi-drun --config "$RYOKU_PATH/default/tofi/config" "$@"
```
(`tofi-drun` is the app-launcher binary the tofi package provides.)

`bin/ryoku-refresh-walker` and `bin/ryoku-restart-walker` become no-ops (tofi is not a daemon). Keep the files as thin shebangs with a comment explaining the historical name.

- [ ] **Step 3.5: Create `install/packaging/tofi.sh`**

Contents:
```bash
ryoku-pkg-aur-accessible || return 1
ryoku-pkg-aur-install tofi
```
Source from `install/packaging/all.sh` after the base package step.

- [ ] **Step 3.6: Chroot dry-run**

Pacstrap a sandbox, run preflight + packaging/base + packaging/tofi. Tofi installs without errors. Record the transcript.

- [ ] **Step 3.7: Syntax checks**

`bash -n install/packaging/tofi.sh install/packaging/all.sh bin/ryoku-launch-walker bin/ryoku-refresh-walker bin/ryoku-restart-walker default/tofi/pickers/*.sh`. All pass.

- [ ] **Step 3.8: Commit**

Commit message: `prep: swap walker shims for tofi`. This commit does not alter live behavior; Super+Space still opens walker because tofi is not yet installed on the live clone.

- [ ] **Step 3.9: Push after live fast-forward**

Fast-forward the live clone. Do not yet run any migration. Confirm `ls ~/.local/share/ryoku/default/tofi/` shows the new config and pickers.

**Rollback note for Task 3:** `git revert <sha>`. Nothing runs on the live system beyond the fast-forward. The launcher-shim rewrites would only affect live behavior if tofi were already installed; at the end of Task 3 it is not.

---

## Task 4: Launcher cutover

**Display-critical.** Confirm a non-GUI shell (local TTY or SSH from another machine) is available before running the live migration. The plan refuses to proceed without confirmation.

**Files:**
- Modify: `install/ryoku-base.packages`, `install/omarchy-base.packages` (drop `omarchy-walker`, add `tofi`)
- Modify: `bin/ryoku-menu` (every `ryoku-launch-walker --dmenu ...` call is rewritten to match tofi's flag surface; use the `--config` and `--prompt-text` forms)
- Create: migration via `ryoku-dev-add-migration --no-edit` that performs the atomic launcher swap
- Modify: migrations `1762150269.sh` and `1758107879.sh` (add `independence-cutover.launcher.done` guard)
- Delete: `default/elephant/ryoku_*.lua` (retired; picker scripts in `default/tofi/pickers/` replace them)
- Delete: `default/walker/themes/ryoku-default/` (no longer consumed)

- [ ] **Step 4.1: Pre-cutover snapshot**

On the live clone, run `ryoku-snapshot create` manually before applying the migration. Record the snapshot number.

- [ ] **Step 4.2: Update base package lists**

Remove `omarchy-walker` from `install/ryoku-base.packages` and `install/omarchy-base.packages`. Add `tofi` to `install/ryoku-base.packages`.

- [ ] **Step 4.3: Rewrite `bin/ryoku-menu` call sites**

For every `ryoku-launch-walker --dmenu ...` call in `bin/ryoku-menu`, rewrite the flags to match tofi. Most existing flags (`--width`, `--prompt`, `--maxheight`, `--minheight`) do not exist on tofi; either replace with the tofi equivalent (`--width`, `--height`, `--prompt-text`) or delete the flag. Preserve the piped-stdin + captured-selection pattern. Every rewritten call is verified by hand against the tofi manpage at plan execution time.

- [ ] **Step 4.4: Delete retired walker/elephant assets**

`git rm -r default/elephant/` and `git rm -r default/walker/themes/ryoku-default/`. Any remaining `default/walker/` contents used only by omarchy-walker go with them. Verify with `rg -l walker default/` that no references point into the deleted paths.

- [ ] **Step 4.5: Gate legacy walker migrations**

Prepend to `migrations/1762150269.sh` and `migrations/1758107879.sh`:
```bash
[[ -f $HOME/.local/state/ryoku/independence-cutover.launcher.done ]] && exit 0
```
So fresh installs after the cutover skip the "install omarchy-walker" migrations.

- [ ] **Step 4.6: Write the cutover migration**

Generate via `ryoku-dev-add-migration --no-edit`. Contents (idempotent throughout):
1. `ryoku-pkg-aur-accessible || { echo "AUR unavailable, aborting"; exit 1; }`
2. `[[ -f $HOME/.local/state/ryoku/independence-cutover.launcher.done ]] && exit 0`
3. `ryoku-snapshot create || true`
4. `pkill -x walker || true`
5. `ryoku-pkg-aur-install tofi`
6. `sudo pacman -Rdd --noconfirm omarchy-walker 2>/dev/null || true`
7. Orphan sweep: `orphans=$(pacman -Qdtq || true); if [[ -n $orphans ]]; then echo "Orphans: $orphans"; sudo pacman -Rns --noconfirm $orphans; fi` (expect the elephant provider packages to appear as orphans and be removed here)
8. `touch $HOME/.local/state/ryoku/independence-cutover.launcher.done`

- [ ] **Step 4.7: Chroot validation**

Run steps 1, 5, and 7 in a pacstrap sandbox. `tofi --help` must return without error after step 5.

- [ ] **Step 4.8: Syntax check**

`bash -n migrations/<new>.sh migrations/1762150269.sh migrations/1758107879.sh bin/ryoku-menu`. All pass.

- [ ] **Step 4.9: Commit**

Commit message: `refactor: swap omarchy-walker for tofi`. Stage the modified migrations, the new cutover migration, the two base-packages files, the rewritten `bin/ryoku-menu`, and the deleted elephant/walker directories.

- [ ] **Step 4.10: Apply live under recovery-ready conditions**

1. Confirm the local TTY or SSH path. Session log records it.
2. Fast-forward the live clone.
3. Run `bash ~/.local/share/ryoku/migrations/<new>.sh` in a shell that is not itself the Hyprland session.
4. Verify:
   - `which tofi` resolves to `/usr/bin/tofi`.
   - `pacman -Qi tofi` reports installed.
   - `pacman -Qi omarchy-walker` reports not found.
   - Super+Space opens tofi with an application list; selecting an app launches it.
   - Super+Alt+Space opens the Ryoku menu; navigating a submenu returns a valid selection.
   - Theme picker and background picker both invoke tofi and apply the selection.
5. Session log records the verification transcript.
6. On failure, rollback: `snapper rollback <snapshot>` and reboot.

- [ ] **Step 4.11: Push**

Push only after Step 4.10 records a successful Super+Space, Super+Alt+Space, theme picker, and background picker round trip.

**Rollback note for Task 4:** Snapshot restore is the clean rollback (both launcher UI and package state roll back in one operation). Manual rollback is possible only while chunk 7 has not yet landed: `sudo pacman -R tofi && sudo pacman -S --asdeps omarchy-walker`, then copy `bin/ryoku-launch-walker` and `bin/ryoku-menu` from `git show HEAD~1:<path>` on the live clone. Repo-side `git revert` alone is insufficient.

---

## Task 5: Nvim replacement preparation

**Files:**
- Create: `default/nvim/` with a starter configuration (LazyVim-derived or fresh - decided at plan time; see Open Questions at the bottom of this plan)
- Modify: `bin/ryoku-nvim-setup` (rewrite from wrapper to real implementation)
- Create or modify: `install/packaging/nvim.sh` (install stock `neovim`, drop `omarchy-nvim` reference)

- [ ] **Step 5.1: Decide the nvim starter config**

Before writing any code, the plan's execution session confirms with the user which starter config goes into `default/nvim/`: LazyVim, NvChad, kickstart, or a Ryoku-authored minimal config. Record the decision in the session log. The resulting config must pass `nvim --headless -c 'Lazy!' -c 'qa'` (or the equivalent for the chosen framework) without plugin-install failures on a scratch home.

- [ ] **Step 5.2: Populate `default/nvim/`**

Commit the chosen starter configuration. Use `git add default/nvim/` with explicit paths; do not use `git add .`.

- [ ] **Step 5.3: Rewrite `bin/ryoku-nvim-setup`**

The new implementation:
1. If `~/.config/nvim` exists and is not a symlink to `default/nvim`, back it up: `mv ~/.config/nvim ~/.config/nvim.ryoku.bak.$(date +%s)`.
2. `cp -r $RYOKU_PATH/default/nvim ~/.config/nvim` (or `ln -s`, decided in Step 5.1).
3. Echo the backup path if one was made.

- [ ] **Step 5.4: Install-time packaging**

`install/packaging/nvim.sh` (new): `ryoku-pkg-add neovim`. No reference to `omarchy-nvim` or `omarchy-nvim-setup`. Source from `install/packaging/all.sh` if not already.

- [ ] **Step 5.5: Chroot validation**

In a pacstrap sandbox, run the base install + nvim install + the new `ryoku-nvim-setup`. Launch `nvim --headless +qa`; exit code 0.

- [ ] **Step 5.6: Syntax check**

`bash -n bin/ryoku-nvim-setup install/packaging/nvim.sh`. Pass.

- [ ] **Step 5.7: Commit**

Commit message: `prep: port nvim setup off omarchy-nvim`. No live impact yet.

- [ ] **Step 5.8: Push after live fast-forward**

**Rollback note for Task 5:** `git revert <sha>`. No live-system change beyond file presence.

---

## Task 6: Nvim cutover

**Display-critical (nvim is often in the user's terminal; a broken nvim is a daily friction, not a desktop crash).**

**Files:**
- Modify: `install/ryoku-base.packages`, `install/omarchy-base.packages` (replace `omarchy-nvim` with `neovim`)
- Create: migration via `ryoku-dev-add-migration --no-edit`
- Modify: migrations `1760434895.sh`, `1760724934.sh`, `1761585764.sh` (gate with `independence-cutover.nvim.done` marker)

- [ ] **Step 6.1: Pre-cutover snapshot**

Manual `ryoku-snapshot create` before applying the migration. Record the snapshot number.

- [ ] **Step 6.2: Update base package lists**

`omarchy-nvim` → `neovim` in `install/ryoku-base.packages`. Preserve `omarchy-base.packages` as historical.

- [ ] **Step 6.3: Gate legacy nvim migrations**

Prepend to each of `1760434895.sh`, `1760724934.sh`, `1761585764.sh`:
```bash
[[ -f $HOME/.local/state/ryoku/independence-cutover.nvim.done ]] && exit 0
```

- [ ] **Step 6.4: Write the cutover migration**

Contents (idempotent throughout):
1. `[[ -f $HOME/.local/state/ryoku/independence-cutover.nvim.done ]] && exit 0`
2. `ryoku-snapshot create || true`
3. If `~/.config/nvim` exists and has content not from Ryoku defaults, back up: `mv ~/.config/nvim ~/.config/nvim.ryoku.bak.$(date +%s)`.
4. `sudo pacman -R --noconfirm omarchy-nvim 2>/dev/null || true`
5. `sudo pacman -S --needed --noconfirm neovim`
6. `ryoku-nvim-setup`
7. `touch $HOME/.local/state/ryoku/independence-cutover.nvim.done`

- [ ] **Step 6.5: Chroot validation**

Same chroot run as Task 4. Confirm `nvim --version | head -1` reports upstream neovim and `nvim --headless +qa` returns 0.

- [ ] **Step 6.6: Commit**

Commit message: `refactor: swap omarchy-nvim for upstream neovim`. Stage migrations, base packages, and the cutover migration.

- [ ] **Step 6.7: Apply live**

Fast-forward live clone. Run the migration manually. Verify:
- `which nvim` points at `/usr/bin/nvim`.
- `pacman -Qi neovim` returns a version.
- `pacman -Qi omarchy-nvim` returns "not found".
- `nvim --headless +qa` returns 0.
- Backup directory recorded in the session log if one was made.

- [ ] **Step 6.8: Push**

Push only after live verification passes.

**Rollback note for Task 6:** `snapper rollback <pre-cutover>` and reboot; or manually `sudo pacman -R neovim && sudo pacman -S omarchy-nvim && mv ~/.config/nvim.ryoku.bak.<timestamp> ~/.config/nvim` (requires the `[omarchy]` section to still be in place - that is, chunk 7 has not yet landed).

---

## Task 7: Drop the `[omarchy]` pacman repo section

**Files:**
- Modify: `default/pacman/pacman-stable.conf`, `pacman-rc.conf`, `pacman-edge.conf` (remove the `[omarchy]` stanza)
- Create: migration via `ryoku-dev-add-migration --no-edit` that atomically rewrites live `/etc/pacman.conf` and preserves user-added sections

- [ ] **Step 7.1: Repo-side edits**

Remove the three `[omarchy]` blocks (header plus `SigLevel` + `Server` lines) from each pacman-<channel>.conf file. Commit staging is deferred to Step 7.4.

- [ ] **Step 7.2: Write the atomic rewrite migration**

Contents:
1. `[[ -f /etc/pacman.conf.ryoku.bak ]] || sudo cp -f /etc/pacman.conf /etc/pacman.conf.ryoku.bak`
2. Read the live file into memory. Using awk, remove the `[omarchy]` section (from `^\[omarchy\]$` to the next `^\[` or EOF). Preserve all other sections verbatim, including any user-added repos.
3. Write the result to `/etc/pacman.conf.ryoku.tmp`.
4. Validate: `sudo pacman-conf --config /etc/pacman.conf.ryoku.tmp` must parse without error.
5. `sudo mv -f /etc/pacman.conf.ryoku.tmp /etc/pacman.conf`.
6. `sudo pacman -Syy` to force DB refresh; `[omarchy]` sync should be absent.
7. Idempotent: on re-run, step 2 produces the same file, and the `mv` is a no-op.

- [ ] **Step 7.3: Chroot validation**

In a sandbox with a user-like `/etc/pacman.conf` containing `[omarchy]` plus a mock `[chaotic-aur]`, run the migration. Verify `[omarchy]` is gone and `[chaotic-aur]` survives verbatim.

- [ ] **Step 7.4: Commit**

Commit message: `refactor: drop omarchy pacman repo section`.

- [ ] **Step 7.5: Apply live**

Fast-forward live clone. Run the migration manually. Verify:
- `grep -c '^\[omarchy\]' /etc/pacman.conf` returns `0`.
- `sudo pacman -Sy` completes without syncing an `omarchy` database.
- Any user-added sections are still present.

- [ ] **Step 7.6: Push**

**Rollback note for Task 7:** `sudo cp -f /etc/pacman.conf.ryoku.bak /etc/pacman.conf && sudo pacman -Syy`. Repo-side: `git revert <sha>`.

---

## Task 8: Keyring simplification

**Files:**
- Modify: `bin/ryoku-update-keyring` (drop custom key import)
- Modify: `install/preflight/pacman.sh` (drop `ryoku-pkg-add omarchy-keyring`)
- Modify: `install/ryoku-base.packages` (drop `omarchy-keyring`)
- Create: migration via `ryoku-dev-add-migration --no-edit` that removes `omarchy-keyring` and clears the cutover marker

- [ ] **Step 8.1: Repo-side edits**

Rewrite `bin/ryoku-update-keyring` to install only `archlinux-keyring`:
```bash
echo -e "\e[32m\nUpdate Arch signing keys\e[0m"
sudo pacman -Sy --noconfirm --needed archlinux-keyring >/dev/null
```
Drop the `omarchy-keyring` line from `install/preflight/pacman.sh`. Drop it from `install/ryoku-base.packages`.

- [ ] **Step 8.2: Write the removal migration**

Contents:
1. `pacman -Qi omarchy-keyring &>/dev/null || { rm -f $HOME/.local/state/ryoku/independence-cutover.started; exit 0; }`
2. `ryoku-snapshot create || true`
3. `sudo pacman -Rdd --noconfirm omarchy-keyring`
4. Orphan sweep: `orphans=$(pacman -Qdtq || true); if [[ -n $orphans ]]; then echo "Orphans: $orphans"; sudo pacman -Rns --noconfirm $orphans; fi`
5. `rm -f $HOME/.local/state/ryoku/independence-cutover.started`

- [ ] **Step 8.3: Chroot validation**

In a sandbox, run the full Path A sequence (Tasks 2, 4, 6, 7, 8 migrations in order). Verify `pacman -Qq | grep '^omarchy-'` returns empty at the end.

- [ ] **Step 8.4: Syntax check**

`bash -n bin/ryoku-update-keyring install/preflight/pacman.sh migrations/<new>.sh`.

- [ ] **Step 8.5: Commit**

Commit message: `refactor: simplify ryoku-update-keyring to archlinux-keyring only`.

- [ ] **Step 8.6: Apply live**

Fast-forward live clone. Run the migration manually. Verify:
- `pacman -Qi omarchy-keyring` returns "not found".
- `ls ~/.local/state/ryoku/independence-cutover.started` reports absent.
- `ryoku-update-keyring` runs and only touches `archlinux-keyring`.

- [ ] **Step 8.7: Push**

**Rollback note for Task 8:** snapshot restore is the clean rollback. Manually: `sudo pacman -S omarchy-keyring` requires the `[omarchy]` section, which means Task 7 must also be rolled back first.

---

## Task 9: Final sweep, VM drill, and close-out

**Files:**
- Modify: `docs/rebrand-inventory.md` (mark Path A complete; add "Deferred cross-spec work" section)
- Modify: `docs/maintenance.md` (add the reflector regeneration note if not yet added in Task 2)
- Update: current session log

- [ ] **Step 9.1: Final grep gate**

Run:
```bash
rg -n --hidden \
  --glob '!.git/*' \
  --glob '!docs/specs/*' \
  --glob '!docs/plans/*' \
  --glob '!docs/superpowers/specs/*' \
  --glob '!docs/superpowers/plans/*' \
  --glob '!docs/rebrand-inventory.md' \
  --glob '!logs/*' \
  'omarchy-|omarchy\.org|pkgs\.omarchy\.org|OMARCHY_PATH|OMARCHY_INSTALL|\.local/share/omarchy|\.local/state/omarchy|\.config/omarchy' \
  .
```
Every remaining hit is annotated in `docs/rebrand-inventory.md` with its category: legal/attribution, historical migration marker, external URL, brand asset, or boot-rename-pending.

- [ ] **Step 9.2: VM boot drill**

On a fresh Arch Linux VM (libvirt or qemu), run `boot.sh` from the current origin `main`. Walk through the install. On first reboot, run `ryoku-update`. Record the transcript in the session log.

Expected: install completes without network errors; `ryoku-update` completes without touching any `omarchy.org` host; `walker` and `nvim` are the upstream packages.

- [ ] **Step 9.3: Update `docs/rebrand-inventory.md`**

Add:
- Mark "Installer migration pass executed" as complete.
- Add a "Deferred cross-spec work" section listing: boot-name rename, hibernation conf rename, SDDM removal, font rebrand, Path B package repo. One line each with status.
- Retire the package-facing name policy block; the three preserved tokens are now historical.

- [ ] **Step 9.4: Session log close-out**

The current session log under `logs/` records:
- Each chunk's commit SHA, pre-cutover snapshot ID (if any), and verification transcript.
- VM drill transcript.
- Any follow-up items discovered in Step 9.1.

- [ ] **Step 9.5: Commit**

Commit message: `docs: close out omarchy infrastructure independence`. Stage only the docs files; the session log is gitignored and does not get committed.

- [ ] **Step 9.6: Push**

- [ ] **Step 9.7: Announcement**

Optionally, tag this commit (for example, `path-a-complete`) so the history has an anchor for future reference.

**Rollback note for Task 9:** docs-only; `git revert` is safe and non-destructive.

---

## Done criteria

Path A is complete when all of the following are simultaneously true:

- `grep -c omarchy.org /etc/pacman.d/mirrorlist` returns `0`.
- `grep -c '^\[omarchy\]' /etc/pacman.conf` returns `0`.
- `pacman -Qq | grep '^omarchy-'` returns empty on the live clone.
- `bin/ryoku-update-keyring` contains no reference to `omarchy-keyring` or the hardcoded fingerprint.
- `install/ryoku-base.packages` does not name `omarchy-keyring`, `omarchy-nvim`, or `omarchy-walker`.
- `ryoku-version-channel` reads from `$RYOKU_STATE_PATH/channel` and not from pacman config.
- Super+Space and Super+Alt+Space open tofi on the live clone; theme picker and background picker both return valid selections via tofi.
- Nvim launches and reports upstream neovim version.
- `ryoku-update` completes end-to-end without contacting any `omarchy.org` host.
- VM boot drill from a fresh Arch VM via `boot.sh` completes install and first update without network error.
- The final grep gate in Step 9.1 passes or each residual hit is annotated.
- `docs/rebrand-inventory.md` records Path A complete and lists deferred work.

## Out-of-scope reminders

- No Ryoku package repo was stood up. Path B.
- `omarchy_linux.efi`, `omarchy_resume.conf`, SDDM theme path, `omarchy.ttf` all survive this pass. They are deferred to the boot-and-assets spec.
- SDDM removal is a future desktop-session spec.
- Signing for a future Ryoku repo is not addressed here.

## Open questions to resolve at plan execution time

1. **Nvim starter:** LazyVim, NvChad, kickstart, or Ryoku-authored minimal? Decided at Task 5 Step 1 before any code is written.
2. **Tofi availability and version:** verified at Task 3 Step 1 via `yay -Si tofi`. If the package is gone or has drifted, the plan is amended with an alternative (fuzzel, wofi) before proceeding.
3. **Reflector country and age filters:** recorded in the session log at Task 2 Step 2; quarterly regeneration cadence documented in `docs/maintenance.md`.
