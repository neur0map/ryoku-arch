# Rebrand Inventory

## Purpose

Working inventory of the remaining Omarchy-era surfaces in this repository. It now serves as a close-out ledger rather than a greenfield rename spec: most runtime and docs surfaces have moved to Ryoku, and the remaining references are either compatibility bridges, package-name deferments, upstream attribution, or brand-asset backlog.

## Generation

Raw reference list produced by:

```
rg -n 'omarchy' --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*'
```

Re-run the command above to regenerate the raw list. `docs/specs/` and `docs/plans/` are excluded because they discuss omarchy by name on purpose; those references do not need to change.

## Categories

Every reference falls into one of five categories.

### Category 1: MUST change (functional)

Command names, package names, install paths, user-visible strings. Most of this category is complete for active runtime and installed-system behavior. The main unresolved pieces are package-facing names and a shrinking set of compatibility bridges.

- `bin/omarchy-*` command names (all ~200 scripts)
- `$OMARCHY_PATH` runtime path references
- `~/.local/share/omarchy/` hardcoded paths in install scripts
- `~/.local/state/omarchy/` state directory references
- User-visible strings in scripts ("Update Omarchy", log messages)

### Category 2: MUST NOT change (legal and attribution)

Attribution that has to remain verbatim for legal or historical reasons.

- `LICENSE`: `Copyright (c) David Heinemeier Hansson` line (preserved; Ryoku copyright is prepended, not replaced).
- `NOTICE`: references to the omarchy project and DHH.
- Upstream commit messages and authorship (immutable git history).

### Category 3: SHOULD change (cosmetic and internal)

Internal identifiers and comments that are not user-visible but should be renamed for brand coherence.

- Environment variables: `$OMARCHY_PATH`, `$OMARCHY_REPO`, `$OMARCHY_REF`, `$OMARCHY_MIRROR`, `$OMARCHY_ONLINE_INSTALL`, `$OMARCHY_USER_NAME`, `$OMARCHY_USER_EMAIL`, `$OMARCHY_CHROOT_INSTALL`, `$OMARCHY_UPDATE_LOGGED`.
- Comments and log strings inside scripts.
- `AGENTS.md`: rewrite complete; keep revisiting if new Omarchy-language drift appears.

### Category 4: Brand assets (deferred)

Image and text assets that represent the brand. Handled in a dedicated brand-assets spec.

- `logo.svg`, `logo.txt`: upstream omarchy logo in SVG and ASCII form.
- `icon.png`, `icon.txt`: upstream omarchy icon.
- ANSI art banners inside scripts (for example, the banner in `boot.sh`).

### Category 5: Installer defaults and infrastructure (deferred)

Install-time defaults and references to omarchy-operated infrastructure. Handled in a dedicated installer-migration spec. The user's machine is already installed, so these do not block the current dev loop.

- `boot.sh`: `OMARCHY_REPO="${OMARCHY_REPO:-basecamp/omarchy}"` default.
- `boot.sh`: `OMARCHY_REF="${OMARCHY_REF:-master}"` default.
- `boot.sh`: pacman mirror URLs `stable-mirror.omarchy.org`, `mirror.omarchy.org`, `rc-mirror.omarchy.org`.
- `.github/` workflow files (not yet audited; may reference the repo URL or omarchy-specific conventions).

## Raw inventory

Run the `rg` command in the Generation section to produce the raw list. At the time of scaffolding the output contained several thousand lines across bin/, config/, install/, default/, migrations/, themes/, AGENTS.md, and a handful of other locations. The raw list is not embedded here because it changes every time upstream is pulled; regenerate on demand.

For per-directory summaries, the following commands are useful:

```
rg -l 'omarchy' --hidden --glob '!.git/*' --glob '!docs/specs/*' --glob '!docs/plans/*' | sort | uniq -c | sort -rn
rg -c 'omarchy' bin/ | sort -t: -k2 -n -r | head -20
```

## Status checklist

- [x] Raw grep done (initial, at scaffolding)
- [x] Categorized (categories above are final; line-level categorization happens in the rename pass)
- [x] Command rename pass executed (Category 1 and 3 commands in `bin/`)
- [x] Install-path rename pass executed (Category 1 path references)
- [x] Migration backlog sweep executed (Category 1 migrations rewritten to Ryoku command/path names; preserved tokens limited to AUR package names, legacy systemd units under cleanup, `OMARCHY_PATH` compat export, and `~/.local/share/omarchy` until Category 5 share-path move)
- [x] Final Category 1 grep gate passed (remaining matches are Category 2 legal, Category 4 brand assets, Category 5 installer defaults, sanctioned compatibility bridges, or external URL/package names)
- [x] Installer migration pass executed (Path A complete: upstream Arch mirrors, `[omarchy]` repo dropped, keyring simplified, boot.sh repo/repo-pin defaults repointed to `neur0map/ryoku-arch`, package-facing names resolved via AUR rebuilds or tool replacement)
- [x] Category 3 cosmetic rename executed (every active `OMARCHY_*` env var swept to `RYOKU_*`; redundant compat exports dropped from `lib/runtime-env.sh`)
- [x] Brand assets pass (Category 4) executed:
    - [x] `logo.txt` (RYOKU word-art), `icon.txt` (力 via Noto CJK), `boot.sh` inline ANSI art
    - [x] Terminal accent color swapped from terminal-green to Japanese old red `#8F1D21` in `bin/ryoku-show-logo` and the fastfetch logo
    - [x] SDDM theme set: hand-rolled `default/sddm/ryoku/` retired in favor of the [qylock](https://github.com/Darkkal44/qylock) theme bundle; `ryoku-install-qylock` handles the install/switch flow; autologin disabled by default so the greeter is actually visible
    - [x] Hibernation drop-in renamed `omarchy_resume.conf` -> `ryoku_resume.conf`; existing installs converge via migration `1777001391`
    - [x] Runtime battery notification flag renamed `omarchy_battery_notified` -> `ryoku_battery_notified`
    - [x] `logo.svg`, `icon.png` redrawn as the 力 kanji in the Greek Noir palette (commit `5d0860ab`)
    - [x] Plymouth boot theme renamed to `ryoku`; assets regenerated with the new 力 logo and activated via migration `1777006137` (commit `5d0860ab`)
    - [x] `config/ryoku.ttf` rebuilt from Noto Sans Mono CJK JP with the 力 glyph mapped to both `U+529B` and `U+E900`; waybar reference updated from `font='omarchy'` to `font='ryoku'`; existing installs converge via migrations `1777007260` (font refresh) and `1777007437` (waybar span patch) (commits `d0a0c923`, `3d9e46b7`)
    - [x] UKI filename flipped to `ryoku_linux.efi` with `CUSTOM_UKI_NAME="ryoku"`, `TARGET_OS_NAME="Ryoku"`, and `interface_branding: Ryoku Bootloader`; existing installs converge via the snapshot-gated migration `1777006624` (commit `9a9aaff0`)
- [ ] Verified end-to-end install still works post-rename (VM boot drill pending)

## Current Reality

- Canonical runtime surfaces are `ryoku-*`, `~/.config/ryoku`, `~/.local/state/ryoku`, and `~/.local/share/ryoku`.
- No Ryoku component contacts `omarchy.org` or `pkgs.omarchy.org` during install, update, or runtime.
- `omarchy-nvim` (LazyVim bundle) replaced by the Helix editor from Arch extra.
- `omarchy-walker` (meta) and the Elephant provider framework replaced by tofi from AUR plus Ryoku-owned shell pickers.
- `omarchy-keyring` and the hardcoded third-party signing key are gone; `archlinux-keyring` is the only keyring in play.
- Mirrors point at standard Arch upstream via a reflector-produced snapshot.
- Legacy `omarchy-*` wrappers remain in `bin/` only where legacy migrations, legacy user webapp `.desktop` files, or legacy shell snippets still need them; they forward to Ryoku-native implementations.
- Live boot-theme migration is still incomplete until the Ryoku Plymouth asset path is installed and activated everywhere.

## Category 1 Close-out (2026-04-23)

Category 1 rename is complete for active code. The owned Category 1 chunk queue from the rename program has been fully executed:

- Runtime contract, state/share/config namespace bridges, and shell/session env are on Ryoku canonical names.
- All core lifecycle, package, theme, menu, launcher, hardware, Hyprland, Waybar, and privileged-file surfaces have canonical Ryoku entry points; legacy `omarchy-*` names remain only as compatibility wrappers.
- Migration backlog has been rewritten: every `omarchy-*` command call in `migrations/*.sh` is now `ryoku-*`, and every `~/.config/omarchy`/`~/.local/state/omarchy` path is now on the Ryoku namespace, with preserved tokens limited to AUR package names (`omarchy-nvim`, `omarchy-walker`, `omarchy-keyring`, `omarchy-chromium(-bin)`, `omarchy-lazyvim`), legacy systemd units being disabled/removed (`omarchy-battery-monitor.*`, `omarchy-seamless-login.service`), `omarchy-nvim-setup` (provided by the `omarchy-nvim` AUR package), and the `OMARCHY_PATH` compat env var exported by `lib/runtime-env.sh`.
- Active callers in `bin/ryoku-*` all resolve through `ryoku-*` names; 18 previously-unwrapped `omarchy-*` utilities gained thin `ryoku-*` wrappers so the menu, install helpers, and lifecycle helpers no longer reference `omarchy-*` at the source-of-truth level.

What is intentionally still left:

- Compatibility `omarchy-*` wrappers in `bin/` - kept because legacy migrations, legacy user-created webapps, and legacy shell snippets can still resolve them. Removal is gated on downstream cleanup, not Category 1 completion.
- `~/.local/share/omarchy/` - still the canonical live repo path because `boot.sh` defaults and the share-path migration belong to Category 5.
- `OMARCHY_PATH`, `OMARCHY_INSTALL`, `OMARCHY_INSTALL_LOG_FILE` env exports - sanctioned bridges in `lib/runtime-env.sh` until downstream consumers stop reading them.
- Category 4 brand assets closed out: `config/ryoku.ttf` rebuilt with the 力 glyph at `U+E900`, logo/icon redrawn, Plymouth activated as `ryoku`, and the UKI flipped to `ryoku_linux.efi`. Remaining artifacts are legacy state being cleaned up by one-shot migrations.
- `boot.sh` repo/branch/mirror defaults and pacman mirror URLs - Category 5 installer migration.

## Path A Close-out (2026-04-23)

Path A (Omarchy Infrastructure Independence) is complete for active code. Nine tasks shipped, each live-verified and pushed:

1. Channel state-file plumbing (`$RYOKU_STATE_PATH/channel`, `bin/ryoku-channel-current`).
2. Mirror swap: mirrorlists now source upstream Arch directly (reflector snapshot).
3. Tofi preparation: shims, config, picker scripts, AUR install step.
4. Launcher cutover: omarchy-walker/elephant family removed, tofi + cliphist active, keybindings rewired.
5-6. Editor swap: omarchy-nvim (LazyVim bundle) replaced by Helix (Arch extra), EDITOR=helix, Learn menu points at https://docs.helix-editor.com/.
7. `[omarchy]` pacman repo section dropped; 15 of the packages it hosted moved to an AUR install step, 2 retired, 1 kept as-is.
8. `ryoku-update-keyring` reduced to archlinux-keyring only; hardcoded fingerprint and omarchy-keyring install removed.
9. Final sweep; legacy compat battery-monitor units, empty sddm/omarchy/ dir, legacy packages files, and the category1-rename worktree retired.

Remaining intentional omarchy references now fall into four buckets:

- **Compatibility env var aliases** in `lib/runtime-env.sh`, `boot.sh`, `install/preflight/pacman.sh`, `install/post-install/pacman.sh`, `install/login/limine-snapper.sh`, `install/helpers/chroot.sh`, `install/config/mise-work.sh`, `install/config/git.sh`: `OMARCHY_PATH`, `OMARCHY_INSTALL`, `OMARCHY_MIRROR`, `OMARCHY_REPO`, `OMARCHY_REF`, `OMARCHY_ONLINE_INSTALL`, `OMARCHY_CHROOT_INSTALL`, `OMARCHY_USER_NAME`, `OMARCHY_USER_EMAIL`. Each is now the fallback form for its `RYOKU_*` counterpart.
- **Legacy filesystem cleanup paths** in `install/first-run/cleanup-reboot-sudoers.sh`, `install/post-install/finished.sh`, and `boot.sh`'s `rm -rf "$HOME/.local/share/omarchy"` - these only *remove* legacy state.
- **Legacy brand cleanup in transit**: the `/run/user/$UID/omarchy_battery_notified` flag filename is the last omarchy-named runtime touchpoint and is retired by the battery-notification rename. Cleanup of `/etc/mkinitcpio.conf.d/omarchy_resume.conf` and `/usr/share/sddm/themes/omarchy` happens through their respective migrations (`1777001391` for hibernation, qylock install for SDDM).
- **External identifiers** (must not change): `themes/{ethereal,hackerman,vantablack}/vscode.json` extension IDs like `Bjarne.vantablack-omarchy`, upstream Omarchy manual URL in the Learn menu, `basecamp/omarchy` references in attribution docs and the `.githooks/pre-push` upstream-mirror guard.

## Deferred cross-spec work

Tracked here as the single source of truth for Path A follow-ups:

- **Category 4 brand assets**: complete. Font rebuilt (`config/ryoku.ttf`, migrations `1777006265`/`1777007260`/`1777007437`), Plymouth activated (migration `1777006137`), UKI flipped (migration `1777006624`), logo/icon redrawn, SDDM migrated to qylock. Hibernation drop-in covered by `1777001391`. What is left is a VM boot drill to confirm the installer story end-to-end.
- **Path B package repo**: stand up a Ryoku-hosted pacman repo on the VPS once there are meaningfully Ryoku-native packages to publish. No urgency now that every Path A dependency routes through Arch extras or AUR.
- **omarchy-* wrapper cleanup**: once no installed system has the legacy webapp `.desktop` files or legacy shell calls, the `bin/omarchy-*` wrappers can be removed. Requires either a population survey or a generous deprecation window.
