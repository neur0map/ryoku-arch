# Omarchy Infrastructure Independence (Path A) Design

**Date:** 2026-04-23
**Status:** Draft, pending user review
**Owner:** Carlos Mejia (neur0map)

## Purpose

Sever every operational dependency on DHH-operated infrastructure. After this pass, no Ryoku component needs `omarchy.org` DNS, `pkgs.omarchy.org` package hosting, or any package shipped by the `omarchy-*` AUR-style suite to update, install, or run. The replacement set uses upstream Arch mirrors and upstream packages only. Standing up a Ryoku-operated package repository (Path B) is deferred to a later spec.

This is the design input for the follow-on implementation plan. It does not implement the cutover. It defines the target state, the sequencing rules, the migration contract for existing installs, the verification bar, and what is explicitly out of scope.

## Context

The Category 1 rename closed out in commits `977020ca` and `4a6511da`. The runtime surface, command namespace, user-visible strings, and active code references are Ryoku-canonical. What remains is the supply chain.

Today, a Ryoku system running `ryoku-update` still touches omarchy infrastructure in these ways:

- Pacman pulls Arch core/extra/multilib from `stable-mirror.omarchy.org` (or `rc-mirror`, `mirror`). Those hosts are operated by DHH.
- `/etc/pacman.conf` declares `[omarchy]` pointing at `https://pkgs.omarchy.org/<channel>/$arch`, serving `omarchy-keyring`, `omarchy-nvim`, `omarchy-walker`, `omarchy-chromium(-bin)`, `omarchy-lazyvim`, and possibly other artifacts.
- `bin/ryoku-update-keyring` hardcodes the signing-key fingerprint `40DFB630FF42BCFFB047046CF0134EE680CAC571` and installs `omarchy-keyring`.
- `install/ryoku-base.packages` requires `omarchy-nvim` and `omarchy-walker`.
- Several migrations manipulate `omarchy-*` packages (`1760434895.sh`, `1762150269.sh`, `1758107879.sh`, `1761585764.sh`) or paths inside them (`/usr/share/omarchy-nvim/`).
- `bin/ryoku-version-channel` identifies the active channel by grepping mirror and repo URLs in `/etc/pacman.d/mirrorlist` and `/etc/pacman.conf`.

Concrete failure modes this spec mitigates:

- Key rotation by DHH invalidates the hardcoded fingerprint; `ryoku-update-keyring` loops.
- Outage of `pkgs.omarchy.org` blocks updates entirely.
- Breaking change in `omarchy-walker` (provider rename, config-path move) breaks the Ryoku menu and launcher without warning.
- Removal of `/usr/share/omarchy-nvim/config/lua/plugins/disable-news-alert.lua` silently breaks migration `1761585764.sh`.
- Sunset of the omarchy repo leaves existing Ryoku installs unable to install or refresh the three packages.

## Goals

- Remove every runtime and update-path reference to `omarchy.org` hosts, the `[omarchy]` repo, and the three omarchy-published packages from active code.
- Replace each with a named upstream alternative or a Ryoku-owned asset committed to this repository.
- Converge existing installed systems onto the independent baseline via idempotent migrations without losing the update path, breaking the graphical session, or discarding user-owned configuration.
- Land fresh installs on the independent baseline directly, with no transitional state on first boot.
- Make every step individually revertible via a fresh commit and leave any destructive migration step behind a snapshot-create gate.
- Preserve the Category 1 rename discipline: many small commits, no `--no-verify`, no AI trailers.

## Non-goals

- Standing up a Ryoku-operated package repository. Path B is a separate spec when and if custom packages become necessary.
- Introducing signing infrastructure. All replacement repos use upstream Arch signing already.
- Renaming `omarchy_linux.efi`, `omarchy_resume.conf`, `/usr/share/sddm/themes/omarchy`, `omarchy.ttf`, or any other local-filename relic. Those are carried forward in a boot-and-assets spec of their own.
- Replacing SDDM or any other subsystem the user has flagged for later removal. This spec changes only the package supply chain.
- Rewriting the Ryoku Elephant provider set beyond parity with what ships today. Any feature improvement rides in a later spec.
- Chasing `omarchy-chromium`, `omarchy-chromium-bin`, `omarchy-lazyvim`. Migrations that name these are historical, have already run on every current install, and do not appear in `install/ryoku-base.packages`. Chunk 9 confirms this with `pacman -Qq | grep '^omarchy-'` on the live clone and records the actual installed set; any unexpected package becomes a documented follow-up, not a scope expansion mid-pass.

## Target State

After this pass:

**Mirrors.** `default/pacman/mirrorlist-stable`, `mirrorlist-rc`, and `mirrorlist-edge` contain only standard Arch mirrors. The repo commits a reflector-produced snapshot and documents the regeneration command. All three mirrorlists are identical snapshots pointing at upstream Arch: the three filenames survive as scaffolding so the channel machinery stays wired, but the contents do not differ until a future Ryoku channel model earns real separation. Updating mirrors is a manual reflector refresh committed like any other repo change; it is not a runtime concern.

**Pacman config.** `default/pacman/pacman-stable.conf`, `pacman-rc.conf`, and `pacman-edge.conf` contain only `[core]`, `[extra]`, and `[multilib]`. No `[omarchy]` section. `install/preflight/pacman.sh` still copies the active channel's config at install time, but the channel selection no longer determines a remote repo - it only selects the commit pin of the mirrorlist snapshot.

**Keyring.** `bin/ryoku-update-keyring` runs `pacman -Sy --needed archlinux-keyring` only. No custom key import, no hardcoded fingerprint, no `omarchy-keyring` package reference. `install/ryoku-base.packages` and `install/preflight/pacman.sh` drop the keyring entry entirely.

**Walker.** `walker-bin` and its Elephant framework come from AUR (via `ryoku-pkg-aur-install`). Ryoku-owned provider Lua lives under `$RYOKU_PATH/default/elephant/` and is installed to the runtime Elephant providers directory by a Ryoku script. `install/ryoku-base.packages` replaces `omarchy-walker` with `walker-bin` or whatever the current upstream AUR name is at implementation time. `bin/ryoku-launch-walker`, `bin/ryoku-refresh-walker`, and `bin/ryoku-menu` continue to work against the upstream binary.

**Neovim.** Upstream `neovim` from `extra` replaces `omarchy-nvim`. `$RYOKU_PATH/default/nvim/` holds a committed starter configuration (LazyVim-derived or fresh, operator's choice at plan time). `bin/ryoku-nvim-setup` becomes the real implementation: it copies `default/nvim/` into `~/.config/nvim/` with backup of any existing user config. No reference to the AUR command `omarchy-nvim-setup` remains.

**Channel detection.** `bin/ryoku-version-channel` reads `$RYOKU_STATE_PATH/channel` (one-line plaintext: `stable`, `rc`, or `edge`; default `stable` on absence). `bin/ryoku-channel-set` writes that state file and triggers `ryoku-refresh-pacman` to lay down the matching mirrorlist snapshot. Pacman URL grepping is removed. Channels do not point at distinct upstream infrastructure today; the state file records intent so the channel concept survives for a future Ryoku model.

**Migrations.** Every migration that still installs, drops, or refreshes `omarchy-keyring`, `omarchy-nvim`, `omarchy-walker`, `omarchy-lazyvim`, or `omarchy-chromium(-bin)` either runs to completion on pre-cutover systems or is gated by a feature flag that makes it a no-op on post-cutover systems. New migrations handle the cutover itself.

**Documentation.** `docs/rebrand-inventory.md` records Category 1 infrastructure independence as complete. The package-facing name policy from Category 1 retires: the three preserved tokens become historical.

## Installed-System Migration Contract

This cutover is the single highest-risk change in the Ryoku rebrand program because it touches package management, the update path, and the graphical session. The migration contract is stricter than Category 1's.

**Ordering is load-bearing.** The cutover must land in a sequence where every intermediate state is bootable, updatable, and returns a usable graphical session. Concretely:

1. The mirror swap lands before any pacman-conf edit. Standard Arch mirrors must already be serving `[core]`/`[extra]`/`[multilib]` from the user's perspective before the `[omarchy]` section is removed, so a `pacman -Syu` inside the migration window never depends on an omarchy-served proxy for Arch base packages.
2. Replacement packages install before omarchy packages are removed. Walker and nvim replacements must succeed on the live system before `pacman -Rdd omarchy-walker omarchy-nvim omarchy-keyring` runs. If the replacement install fails, the migration aborts with omarchy packages intact and the repo still wired up.
3. The `[omarchy]` repo section is removed only after the three packages are gone. Pacman should never be asked to sync a repo that still declares as authoritative packages the user no longer has.
4. `omarchy-keyring` is removed only after the `[omarchy]` section is gone. The keyring exists specifically to verify that repo; removing it first is harmless on a `TrustAll` repo but creates noise.

**Every migration step is idempotent.** A partial failure that leaves the system on an intermediate state must converge on the next `ryoku-update` or `ryoku-migrate` without manual intervention. That means every step checks its own precondition (is the omarchy section still present? is walker-bin installed? does the user's `~/.config/nvim` already match the new layout?) before acting.

**Snapshot gate.** The migration that performs the atomic walker swap and the one that performs the nvim swap must each call `ryoku-snapshot create` as their first action. If snapper is unavailable (exit 127), the migration logs the condition and proceeds, but the implementation plan must declare this risk explicitly.

**No split-brain.** At no point may one subsystem read omarchy paths while another writes Ryoku paths. If the plan introduces a transitional bridge (for example, keeping `/etc/pacman.d/mirrorlist-backup` until verification), the bridge must be removed in the same commit that removes the source of the split brain.

**User data preservation.** Any config that a user might have customized (`~/.config/nvim`, `~/.config/walker`) must be backed up before overwrite. The plan must specify a single backup convention (`.bak.<epoch>` suffix or equivalent) and document it once.

**Repo-live parity.** After each committed chunk, the repository state and the live system state must match. If a chunk edits a shipped config file, the same chunk applies the change to any live equivalent that exists outside the repo (for example, running `ryoku-refresh-pacman` on the live clone, or merging updated `~/.config/walker/config.toml` from the new defaults). The commit message and session log both record which live files were touched and how they were verified.

**AUR precondition check.** Chunks 3-6 depend on AUR access through `yay`. Every cutover migration that installs from AUR begins by running `ryoku-pkg-aur-accessible`. On failure (no network, rate-limited, yay missing) the migration exits with a clear message and a non-zero code, leaving omarchy packages installed and the `[omarchy]` section intact. The plan also adds an install-flow guard so fresh installs cannot land on the post-cutover config without a working yay.

**Walker kill-before-replace.** Chunk 4 must stop the running Walker process before `pacman -R omarchy-walker` and restart against the upstream binary after install. Concretely: `pkill -x walker || true` before replace, `ryoku-refresh-walker` after. If Waybar re-spawns Walker mid-replace the replace still succeeds, but the new binary is what becomes authoritative.

**Atomic file writes.** Migrations that rewrite `/etc/pacman.conf`, `/etc/pacman.d/mirrorlist`, or any other privileged file use the temp-file-plus-rename pattern: write to `<path>.ryoku.tmp`, validate with a format-appropriate check (for pacman.conf, run `pacman-conf --config <tmp>` to parse it), then `sudo mv -f <tmp> <path>`. No chunk is allowed to leave a partially-written privileged file on disk if the migration aborts.

**User section preservation in `/etc/pacman.conf`.** The user may have added third-party repo sections (chaotic-aur, endeavouros, a local repo). The pacman-config migration reads the live file, removes only the `[omarchy]` section and the `[core]`/`[extra]`/`[multilib]` blocks under its own `Include` management, preserves everything else verbatim, and writes the result atomically. The plan spells out the exact awk/sed-safe detection pattern.

**Orphan cleanup after removals.** `pacman -Rdd` skips dependency checks. After chunk 4, chunk 6, or chunk 8 removes omarchy packages, the migration ends with `sudo pacman -Rns $(pacman -Qdtq) --noconfirm` or an explicit confirmation if orphans are found, so the system does not accumulate dead packages. The plan names the expected orphan set at commit time so the user can confirm the list before confirming removal.

**Partial-upgrade safety gate.** A user who pulls HEAD after skipping several cycles will queue every cutover migration in one `ryoku-migrate` pass. That is the exact failure mode this spec guards against. The first cutover migration (chunk 2's mirror swap) drops a marker file `$RYOKU_STATE_PATH/independence-cutover.started`. Each subsequent cutover migration (chunks 4, 6, 7, 8) checks the marker and, if present, runs `ryoku-snapshot create` before its own work regardless of whether the previous migration already snapshotted. The final cutover migration (chunk 8) removes the marker. If any cutover migration fails, the marker stays; the next run resumes where the previous one left off and takes a fresh snapshot before the retry.

## Execution Model

The cutover uses dependency-first chunking, same as Category 1. Each chunk owns one failure boundary. No chunk is allowed to cross two boundaries even if the edits look trivial.

Rules for every chunk:

- One chunk owns one dependency boundary.
- One chunk ends in at least one commit. Most chunks end in exactly one commit; the walker and nvim cutovers may need two (prepare, then cutover).
- One chunk has one explicit verification contract naming the exact commands to run.
- One chunk must be revertable via `git revert <sha>` without collateral damage to unrelated rename work already landed.
- Every chunk updates `docs/rebrand-inventory.md` (if it moves any item off the deferred list) and the current session log before commit.

High-risk chunks use maximal verification. In this spec, maximal verification is mandatory for every chunk because every chunk touches the update path, pacman state, or the display stack.

## Chunk Queue

| # | Chunk | Owned Surfaces | Exit Criteria |
|---|---|---|---|
| 1 | State-file channel plumbing | `bin/ryoku-version-channel`, `bin/ryoku-channel-set`, `$RYOKU_STATE_PATH/channel` writer, migration that backfills the state file from the current mirror URL | Channel detection no longer reads `omarchy.org` URLs; pre-cutover systems report the same channel after migration as before |
| 2 | Mirror swap | `default/pacman/mirrorlist-stable`, `mirrorlist-rc`, `mirrorlist-edge`, `bin/ryoku-refresh-pacman`, migration that rewrites `/etc/pacman.d/mirrorlist` on live systems | No `omarchy.org` hostname in any mirrorlist; `pacman -Sy` succeeds; `pacman -Syu` is a no-op on systems already current |
| 3 | Walker replacement preparation | `default/elephant/*.lua` providers (full parity with today's Ryoku set), `install/packaging/walker.sh` (new) that resolves walker + elephant from AUR, `bin/ryoku-launch-walker` retargeting if needed | `walker-bin` and its elephant dependency install cleanly; new provider Lua passes `luac -p`; no live change yet |
| 4 | Walker cutover | Migration that atomically removes `omarchy-walker`, installs `walker-bin`, and reloads the live Walker service; `install/ryoku-base.packages` and `install/omarchy-base.packages` updated; migrations `1762150269.sh` and `1758107879.sh` gated to no-op post-cutover | Live `walker --help` resolves the new binary; Ryoku menu opens; theme picker and background selector still work; `ryoku-refresh-walker` reloads cleanly |
| 5 | Nvim replacement preparation | `default/nvim/` starter config committed, `bin/ryoku-nvim-setup` rewritten to use Ryoku-owned path, `install/packaging/nvim.sh` (new or adjusted) that installs stock `neovim` | `nvim -c 'q!'` runs against the Ryoku config without errors on a scratch home; no live change yet |
| 6 | Nvim cutover | Migration that backs up existing `~/.config/nvim`, removes `omarchy-nvim`, installs `neovim`, runs the new `ryoku-nvim-setup`; base package list updated; migrations `1760434895.sh`, `1760724934.sh`, `1761585764.sh` gated | Live `nvim --version` reports upstream neovim; existing user plugins either preserved via backup or explicitly replaced from the Ryoku defaults; documented in session log |
| 7 | Pacman config drop | `default/pacman/pacman-stable.conf`, `pacman-rc.conf`, `pacman-edge.conf` lose the `[omarchy]` section; migration rewrites live `/etc/pacman.conf` | `pacman -Sy` sees only `core`, `extra`, `multilib`; no omarchy entries in `/etc/pacman.conf` on repo or live |
| 8 | Keyring simplification | `bin/ryoku-update-keyring` drops the custom keyring import; `install/preflight/pacman.sh` and base package lists drop `omarchy-keyring`; migration runs `pacman -Rdd omarchy-keyring` on live systems once the repo is gone | `ryoku-update-keyring` installs only `archlinux-keyring`; `pacman -Qi omarchy-keyring` returns not-found on live |
| 9 | Final sweep and close-out | `docs/rebrand-inventory.md`, session log, remaining `omarchy-*` or `omarchy.org` references audited and justified | Final grep suite excluding docs/legal passes; Category 1 package-facing policy retired; rebrand inventory updated |

Order is strict. Chunks 3–4 and 5–6 are paired; do not split one from its cutover across an unrelated commit. Chunks 7 and 8 must follow 4 and 6 because they remove surfaces those chunks still depend on.

## Rollback Protocol

Because migrations mutate pacman state that `git revert` cannot reverse, the rollback plan is snapshot-based and chunk-scoped.

**Primary rollback: snapper restore.** Every cutover migration runs `ryoku-snapshot create` as its first action and records the resulting snapshot ID in the session log. Restore is `sudo snapper -c root undochange <pre-snapshot>..<post-snapshot>` or a full `snapper rollback <pre-snapshot>` and reboot, whichever is appropriate for the damage. The plan names the exact snapper invocation for each chunk because chunk 4 (walker) is user-session-recoverable without reboot and chunk 7 (pacman.conf) is better served by `undochange` alone.

**Fallback rollback: manual steps.** When snapper is unavailable (exit 127 from `ryoku-snapshot create`), the migration still proceeds, but the session log records the absence and the plan lists per-chunk manual-rollback recipes:

- Chunk 2 (mirror swap): `sudo cp /etc/pacman.d/mirrorlist.ryoku.bak /etc/pacman.d/mirrorlist`. The migration writes `.ryoku.bak` before it writes.
- Chunk 4 (walker): `sudo pacman -S --asdeps omarchy-walker` (still in the omarchy repo while it exists), then `ryoku-refresh-walker`.
- Chunk 6 (nvim): restore `~/.config/nvim` from the timestamped backup the migration created; reinstall `omarchy-nvim`.
- Chunk 7 (pacman.conf): `sudo cp /etc/pacman.conf.ryoku.bak /etc/pacman.conf`. The migration writes `.ryoku.bak` before the atomic write.
- Chunk 8 (keyring): `sudo pacman -S omarchy-keyring` while the repo is still reachable (requires rolling back chunk 7 first).

**Git revert is cosmetic.** Reverting a cutover commit reverses the repo side only. The live system rollback is always the snapshot or the per-chunk manual recipe above. The plan makes this explicit in every chunk's rollback note so we do not rely on `git revert` for safety.

**Rollback test gate.** Before each cutover chunk (4, 6, 7, 8) lands on the live clone, the user confirms they have an accessible non-GUI shell (local TTY or SSH from another machine). The plan refuses to proceed without confirmation.

## Fresh-Install Validation

Every chunk that touches `install/preflight/`, `install/packaging/`, or `default/pacman/` can silently break fresh installs while leaving live-clone verification green. The spec requires per-chunk fresh-install validation, scoped to what is realistically testable.

**Primary method: chroot + arch-install-scripts.** Each time a chunk edits a file under `install/preflight/` or `install/packaging/`, the plan prescribes a `pacstrap` against a tmpfs or btrfs subvolume with the new config, followed by a sourced run of the touched install step inside `arch-chroot`. This does not exercise Hyprland or Walker, but it catches every pacman, keyring, and package-list regression before push.

**Secondary method: VM boot drill.** Before declaring Path A complete, the user runs `boot.sh` once against a fresh Arch VM (libvirt or otherwise). The session log records the VM image used, the full install transcript, and the first `ryoku-update` inside the VM. This catches integration failures the chroot method cannot reproduce.

**Accepted limitation.** Between chunks, the chroot method is the only gate. A chunk can pass chroot verification and still break VM install if the bug is in UWSM, Hyprland autostart, or SDDM. Those subsystems are live-clone-tested only. The plan documents this gap and schedules the VM drill as the final chunk gate.

## Verification Contract

Every chunk uses maximal verification. Concretely, a chunk is not complete until each of the following has been run on the repo and, where applicable, the live clone.

- `bash -n` on every touched shell script.
- `luac -p` on every touched Lua file.
- `rg` with the Category 1 grep rules (docs-excluded) returns only sanctioned tokens and what the chunk itself intentionally preserves.
- For mirror or pacman-config chunks: `sudo pacman -Sy` succeeds against the new configuration and prints no omarchy hostnames.
- For walker or nvim chunks: the subsystem is actually launched and exercised on the live clone, and the session log records what was exercised.
- The snapshot/rollback path for that chunk is exercised in dry-run (snapper list, git revert dry-run) before the real cutover.

## Validation Matrix

Per file type:

- Shell scripts and migrations: `bash -n` passes; any changed migration also executes successfully under `ryoku-migrate` in the live clone or is gated by a precondition that makes it a no-op on already-migrated systems.
- Pacman configs: `sudo pacman --config <path> -Sy` succeeds in a sandbox or on the live clone after the swap.
- Mirrorlist: every line parses as a `Server = …` directive; `curl -I` against each listed host returns HTTP 200 for at least the first five entries.
- Elephant Lua providers: `luac -p` passes; Walker loads the provider without errors in the journal.
- Systemd user units touched (if any): `systemd-analyze --user verify` passes.
- The final Category 1 grep suite from the earlier plan continues to pass after every chunk.

If a file type lacks a good static validator, the plan must state so explicitly and strengthen the runtime verification.

## Display-Safe Rules

Chunks 4 (walker cutover) and 6 (nvim cutover) are the display-critical chunks. Apply the Category 1 display-safe rules:

- A non-GUI recovery path is tested before either chunk begins.
- `ryoku-snapshot create` runs immediately before the live cutover.
- Walker and Hyprland must continue to resolve launcher commands at every step; if the launcher breaks, revert the last commit before debugging forward.
- If a Walker theme provider throws at runtime, `ryoku-refresh-walker` must still start Walker cleanly. The plan's walker chunk verifies this with a deliberate provider check.

## Commit and Push Rules

Inherit from the Category 1 plan:

- No push before the owned chunk is verified and tested locally.
- No `--no-verify` unless the user explicitly instructs it for a specific exceptional case.
- No `Co-Authored-By` trailers.
- Plain `git commit -m` only, matching repo convention.
- Stage only the paths owned by the active chunk.
- Many small commits, never one big cutover commit.

The `.githooks/` pre-commit and commit-msg hooks enforce em-dash absence and AI-attribution absence; pre-push blocks dangerous pushes to `main`.

The live-clone-fast-forward discipline from Category 1 carries forward unchanged: commit locally, fast-forward the live clone from the local repo as a temporary remote, verify the live behavior, then push to `origin`. The temporary `local` remote on the live clone is removed after fast-forward and before the push.

## Source-of-Truth Updates

After each verified chunk:

- `docs/rebrand-inventory.md` updated if the chunk moved an item off the deferred list.
- Current session log under `logs/` appended with the chunk's `Changed`, `Verified`, `Next`, and `Open issues` sections.
- The implementation plan updated inline if execution detail changed.

Only after these updates does the chunk count as part of the source of truth.

## Grep Scope Rules

Same exclusion set as the Category 1 plan:

- `docs/specs/*`
- `docs/plans/*`
- `docs/superpowers/specs/*`
- `docs/superpowers/plans/*`
- `docs/rebrand-inventory.md`
- `logs/*`

If a new design-only document path is introduced, the exclusion set must be updated before raw grep counts are used as evidence of progress.

## Definition of Done

### Chunk done

A chunk is done only when:

- The targeted omarchy infrastructure reference for that chunk is removed from repo, from the live clone, and from any documentation describing the operational surface.
- The owned subsystem works through its real runtime path on the live clone.
- The chunk has been committed and pushed.
- The live clone is fast-forwarded to the new commit and verified.
- The chunk can be reverted without undoing unrelated rename work.
- The session log for the chunk records the verification evidence.

### Path A done

Path A is complete only when:

- No `omarchy.org` hostname is referenced by any active configuration that the update path or a fresh install consumes.
- `/etc/pacman.conf` on the live system contains no `[omarchy]` section; no packages in `pacman -Qm` start with `omarchy-`.
- `bin/ryoku-update-keyring`, `install/preflight/pacman.sh`, and `install/ryoku-base.packages` do not name `omarchy-keyring`, `omarchy-nvim`, or `omarchy-walker`.
- The walker and nvim subsystems work against upstream packages on the live clone.
- `ryoku-version-channel` identifies the channel via state file, not by grepping mirror URLs.
- The final grep suite from Category 1, extended with `omarchy\.org`, `pkgs\.omarchy\.org`, `omarchy-keyring`, `omarchy-nvim`, `omarchy-walker`, `omarchy-chromium`, `omarchy-lazyvim`, returns only documentation, legal, and historical migration content. Each remaining hit is justified in `docs/rebrand-inventory.md` with one line naming the category (legal, historical migration, external URL, brand asset, boot-rename-pending).
- `docs/rebrand-inventory.md` records Path A complete; the package-facing name policy block is marked retired.

## Risks

The highest-risk failure modes and their mitigations:

- **Replacement package unavailable.** The AUR name for walker or elephant may have moved since last audit. Mitigation: the plan names the exact AUR package at execution time, verifies it via `pacman -Si` or `yay -Si` before staging the cutover migration, and falls back to a deferred chunk if the dependency is not ready.
- **Walker regression.** Upstream Walker may have changed Elephant provider loading. Mitigation: run the live `walker --help`, then launch the Ryoku menu end to end, before declaring the chunk done. Revert on any user-visible regression.
- **Nvim plugin regression.** Users may have added plugins on top of `omarchy-nvim`. Mitigation: the nvim cutover migration backs up `~/.config/nvim` with a dated suffix, points the user at the backup in the session log, and does not delete it.
- **Split brain during pacman-config rewrite.** A `pacman -Sy` run between mirror swap and repo-section drop could succeed against a stale cache. Mitigation: the migration always runs `pacman -Syy` (force database refresh) immediately after rewriting either `/etc/pacman.d/mirrorlist` or `/etc/pacman.conf`.
- **Key rotation mid-cutover.** If DHH rotates the keyring during the cutover window, the live clone's `pacman -Sy` may fail with signature errors before we drop the `[omarchy]` section. Mitigation: the plan's first step after mirror swap is to refresh the omarchy keyring one last time; if that fails, drop the section immediately and bail out of the legacy key path.
- **Snapper unavailable.** The snapshot gate is best-effort. The plan must tolerate `ryoku-snapshot` exit 127 without blocking and must record the absence in the session log so a post-incident rollback has the right evidence.
- **Bootstrap on fresh install regresses.** `install/preflight/pacman.sh` runs before the new state file exists; if it reads `$RYOKU_STATE_PATH/channel` blindly, fresh installs break. Mitigation: chunk 1 adds default-if-missing semantics everywhere the channel is read.
- **Mirrorlist rot.** A static committed mirrorlist goes stale. Mitigation: the plan commits a reflector command and a regeneration cadence in `docs/maintenance.md`; it does not try to solve mirror refresh dynamically.

## Out-of-Scope Reminders

- Standing up a Ryoku package repo. Path B.
- Boot-name rename (`omarchy_linux.efi`, `omarchy_resume.conf`). Tracked separately; note added to `docs/rebrand-inventory.md` under "Deferred cross-spec work" as a follow-up plan.
- SDDM removal or theme-name rename. Flagged for a future desktop-session spec.
- Font family name in `omarchy.ttf`. Deferred; will change when the logo is redrawn.
- Upstream branch adoption (`upstream/dev` merges). Unchanged by this spec; the Ryoku maintenance doc already covers that discipline.

Chunk 9 adds a `## Deferred cross-spec work` section to `docs/rebrand-inventory.md` that lists each deferred item with a one-line status: what it is, why it is deferred, and what spec or plan will track it when one exists. That section is the single source of truth for follow-up work escaping Path A.

## Recommended Next Step

Write the implementation plan that expands the chunk queue into concrete execution steps, owned files, migration scripts, validation commands, rollback commands, and live-verification transcripts for every chunk. The plan should preserve the strict chunk ordering from this design unless a newly discovered dependency forces a documented change, and it should produce one commit per chunk (with the walker and nvim cutovers allowed to split into preparation + cutover commits if size warrants).

The plan must:

- Name every AUR package by the version confirmed via `pacman -Si` at plan time.
- Include the exact reflector invocation used to produce the committed mirrorlist, and a dated note in `docs/maintenance.md` recording the snapshot date.
- Include the exact migration filenames (via `ryoku-dev-add-migration --no-edit`) for every cutover step, not placeholders.
- Spell out the backup filename convention for `~/.config/nvim` and `~/.config/walker`.
- Spell out the manual verification steps each chunk's live-clone verification depends on.
