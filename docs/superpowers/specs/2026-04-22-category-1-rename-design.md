# Ryoku Arch: Category 1 Rename Design

**Date:** 2026-04-22
**Status:** Draft, pending user review
**Owner:** Carlos Mejia (neur0map)

## Purpose

Break Category 1 of `docs/rebrand-inventory.md` into a systematic, reversible rename program that removes functional `omarchy` references from code, scripts, configs, and dotfiles while keeping the live system usable at every step. Documentation is intentionally excluded from this pass.

This spec defines the execution model, chunk boundaries, verification bar, rollback rules, commit discipline, and the definition of Category 1 completion. It does not implement the rename. It is the design input for the follow-on implementation plan.

## Context

Ryoku Arch currently tracks a forked omarchy codebase with Ryoku branding layered on top. The source-of-truth docs already identify command and path rename as the next major priority after scaffolding.

The user wants the system to transition into a standalone opinionated Arch distribution. The rename must therefore move the runtime contract from `omarchy` to `ryoku` in small verified chunks, not in one risky sweep.

The repo findings that matter most for this spec are:

- `bin/` currently contains 227 `omarchy-*` command files.
- `OMARCHY_PATH` appears 165 times in non-doc files.
- The old runtime paths still appear broadly across install scripts, migrations, Hyprland, Waybar, UWSM, state handling, theming, systemd, and udev wiring.
- `byverse` is not present in this repository or sibling project roots, so repo docs remain the canonical source of truth for this work.

## Goals

- Remove Category 1 `omarchy` references from active code and dotfiles before any Category 3 or deferred rename work begins.
- Establish Ryoku as the canonical runtime surface for commands, paths, environment variables, and user-visible operational strings.
- Execute the rename in many small commits so each step is easy to revert.
- Verify every chunk through the real subsystem it touches, not only through grep or syntax checks.
- Treat Hyprland, Waybar, and Wayland session wiring as high-risk surfaces with stricter safety rules.
- Update the source-of-truth docs only after each chunk is locally verified.

## Non-goals

- Rewriting documentation references to `omarchy`. Docs may retain historical mentions during this pass.
- Changing legal attribution in `LICENSE` or `NOTICE`.
- Doing Category 3 cleanup just because a file is open. Cosmetic leftovers do not block Category 1 progress unless they are functional.
- Pushing unverified work. This spec assumes local commit and test first.
- Shipping a full rebrand of deferred brand-asset or installer-infrastructure work unless a change is required to complete Category 1 safely.

## Canonical Runtime Contract

The target runtime contract for active code is:

- `ryoku-*` command names
- `RYOKU_*` environment variables
- `~/.local/share/ryoku`
- `~/.local/state/ryoku`
- `~/.config/ryoku`

Temporary compatibility bridges are allowed only when they make the next verified chunk possible. They are migration scaffolding, not part of the end state.

## Execution Model

The rename program uses dependency-first chunking.

- Shared foundations move first: canonical paths, env vars, path helpers, and command resolution rules.
- Dependent subsystems move after their dependencies are stable: config namespace, command consumers, dotfiles, services, install scripts, and migration backlog.
- High-risk desktop consumers are flipped only after their Ryoku targets already exist and are verified.
- No Category 3, Category 4, or Category 5 work starts until Category 1 is complete.

Rules for every chunk:

- One chunk owns one dependency boundary.
- One chunk ends in at least one commit.
- One chunk has one explicit verification contract.
- One chunk must be revertable without collateral damage to unrelated rename work.

## Chunk Queue

| # | Chunk | Owned surfaces | Verification bar | Exit criteria |
|---|---|---|---|---|
| 1 | Runtime contract foundation | shared path helpers, canonical env names, bootstrap helpers | maximal | Ryoku path and env contract exists and can be consumed without removing old bridges yet |
| 2 | Share path migration | `~/.local/share/omarchy` consumers in active runtime code | maximal | owned consumers read from `~/.local/share/ryoku` or a verified bridge to it |
| 3 | State path migration | toggles, first-run markers, restart markers, migration markers, runtime state helpers | maximal | owned state readers and writers use `~/.local/state/ryoku` |
| 4 | Config namespace migration | themes, branding, hooks, backgrounds, current-theme links, template overrides | maximal | owned consumers use `~/.config/ryoku` |
| 5 | Shell and session env | `install.sh`, shell env files, `config/uwsm/env`, PATH exports | maximal | new shells and sessions resolve Ryoku paths and vars first |
| 6 | Core lifecycle commands | version, state, migrate, hook, update, branch, channel, shared helpers | maximal | core control plane commands exist as `ryoku-*` and their internal calls resolve correctly |
| 7 | Package and install helper commands | package add/drop/present helpers, keyring helpers, install wrappers | subsystem | install and package helper surfaces stop depending on `omarchy-*` names |
| 8 | Theme and config commands | theme set/list/install/remove, refresh-config, branding, background, template helpers | subsystem | theme and config workflows resolve through Ryoku names and Ryoku config paths |
| 9 | Menu, launcher, and interaction commands | menu, launchers, browser, audio, bluetooth, wifi, screenshot, screenrecord, share, lock helpers | subsystem | the desktop interaction layer resolves through Ryoku commands |
| 10 | Hardware, power, and toggle commands | brightness, battery, powerprofiles, hibernation, monitors, touchpad, idle, nightlight, toggles | subsystem | hardware and toggle workflows use Ryoku commands and state paths |
| 11 | Hyprland sources and bindings | `config/hypr`, `default/hypr`, sourced state includes | maximal | Hyprland sources only Ryoku runtime paths and commands for owned surfaces |
| 12 | Waybar wiring | `config/waybar`, waybar restart and refresh helpers, bar command hooks | maximal | top bar resolves Ryoku commands and path variables without losing bar functionality |
| 13 | Remaining desktop dotfiles | Walker, Mako, terminal imports, browser flags, Fastfetch, related desktop configs | maximal | remaining dotfiles consume Ryoku config and command surfaces |
| 14 | systemd, udev, and privileged filenames | unit names, udev-triggered unit names, sudoers fragments, mkinitcpio fragments, sysctl drop-ins, functional theme names | maximal | privileged runtime files stop exposing functional `omarchy` names |
| 15 | Installer and packaging scripts | `install/preflight`, `install/post-install`, `install/config`, `install/login`, `install/packaging` | maximal | install-time behavior calls Ryoku names and writes Ryoku paths for Category 1 surfaces |
| 16 | Migration backlog sweep | `migrations/*.sh` that would reintroduce old names or paths | subsystem | upgrades stop reintroducing Category 1 `omarchy` references |
| 17 | Functional package and repo names | package-list entries and functional package-facing names such as keyring or repo-specific surfaces | maximal | package and repo-facing operational names required by Category 1 are Ryoku-aligned |
| 18 | Compatibility bridge removal and final gate | wrappers, dual exports, old path bridges, final grep suite | maximal | all temporary bridges are removed unless one final migration hatch is explicitly justified |

## Why This Ordering

This order is intentional:

- Paths and namespaces move before command consumers so later chunks have a stable target.
- Core commands move before desktop consumers so Hyprland and Waybar do not become the place where command naming is invented.
- Display-critical chunks are late, narrow, and isolated because a broken screen or top bar blocks further debugging.
- Migration backlog cleanup is late because old migrations should not be rewritten until the new runtime contract is already stable.
- Bridge removal is last because removing safety rails early increases regression risk without providing architectural value.

## Verification Contract

Default rule: every chunk uses subsystem verification.

That means:

- `rg` proves the targeted Category 1 references for that chunk are removed from owned files.
- touched shell scripts pass shell syntax checks.
- every renamed command, path, state file, or include referenced by the chunk exists before runtime reload or restart.
- the actual subsystem workflow is exercised end to end.

High-risk chunks use maximal verification instead of the default. In this spec, maximal verification is mandatory for:

- runtime contract foundation
- share path migration
- state path migration
- config namespace migration
- shell and session env
- core lifecycle commands
- Hyprland sources and bindings
- Waybar wiring
- remaining desktop dotfiles
- systemd, udev, and privileged filenames
- installer and packaging scripts
- functional package and repo names
- compatibility bridge removal and final gate

## Display-safe Rules

Hyprland and Wayland-facing surfaces require stricter isolation because a broken display blocks the ability to continue work.

Rules:

- Do not mix Hyprland, Waybar, and UWSM edits into one commit unless the change is trivial and proven safe.
- Do not flip a display consumer to `ryoku-*` until the target command already exists and has been verified outside the compositor.
- Back up any touched user-facing config before live replacement or refresh.
- Validate file structure before live reload whenever possible.
- Apply one live display change at a time.
- If a display chunk regresses the session, revert the last chunk commit immediately instead of debugging forward inside a broken desktop.

Display verification sequence:

1. Confirm every referenced `ryoku-*` command and include path exists.
2. Check file validity before reload.
3. Apply the smallest live change possible.
4. Verify launcher or menu access still works.
5. Verify terminal launch still works.
6. Verify the bar still loads if Waybar was touched.
7. Verify Hyprland still loads its config if Hyprland was touched.

## Commit and Push Rules

This rename program assumes strict local discipline:

- No push before the owned chunk is verified and tested locally.
- No `--no-verify` unless the user explicitly instructs it for a specific exceptional case.
- No `Co-Authored-By` trailers.
- Plain `git commit -m` usage only, matching repo convention.
- Stage only the paths owned by the active chunk.
- Prefer many small commits over fewer mixed commits.

The repo already enforces part of this discipline through `.githooks`:

- `pre-commit` checks staged shell syntax and rejects em-dashes in staged text.
- `commit-msg` rejects `Co-Authored-By`, AI attribution terms, and em-dashes.
- `pre-push` blocks dangerous pushes to `main` and blocks publishing the upstream-tracking branches.

## Source-of-truth Updates

Because `byverse` is not currently present, the repo docs remain canonical.

After each verified chunk:

- update `docs/rebrand-inventory.md` to record chunk status for Category 1
- update the implementation plan if execution details changed
- record the work, verification, and next step in the current session log
- only then treat the chunk as part of the source of truth

If `byverse` is introduced later, it should mirror verified repo state instead of replacing the repo verification gate.

## Definition of Done

### Chunk done

A chunk is done only when:

- targeted Category 1 `omarchy` references for that chunk are removed or isolated behind a temporary verified bridge
- the owned subsystem works through its real runtime path
- the chunk has been committed
- the chunk can be reverted without undoing unrelated rename work

### Category 1 done

Category 1 is complete only when:

- no functional `omarchy` references remain in code, scripts, configs, dotfiles, runtime paths, command names, state paths, package-facing operational names, or user-visible runtime strings
- any remaining `omarchy` mentions are confined to documentation, legal attribution, or explicitly deferred non-Category-1 surfaces
- temporary compatibility bridges introduced during the rename are removed unless one final migration bridge is explicitly retained and documented
- the final functional grep suite excluding documentation passes
- the subsystem verification sweep passes, including display-critical surfaces

## Risks

The highest-risk failure modes are:

- breaking Hyprland sources or session startup through path or command flips
- breaking Waybar by renaming commands before the bar can resolve the new names
- leaving mixed path namespaces where one subsystem writes `ryoku` state and another still reads `omarchy` state
- rewriting old migrations too early and silently reintroducing `omarchy` on upgraded systems
- bundling too many unrelated rename surfaces into one commit and losing safe rollback

This spec mitigates those risks through dependency-first chunking, maximal verification on foundational and display-critical surfaces, late bridge removal, and explicit rollback-first handling of regressions.

## Recommended Next Step

Write an implementation plan that expands this chunk queue into concrete execution steps, owned files, verification commands, and rollback commands for each chunk. The plan should preserve the exact execution order from this design unless a newly discovered dependency forces a documented change.
