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
- [ ] Installer migration pass executed (Category 5 boot defaults, mirrors, and package-facing names still have deferred work)
- [ ] Brand assets pass executed (Category 4)
- [ ] Verified end-to-end install still works post-rename

## Current Reality

- Canonical runtime surfaces are `ryoku-*`, `~/.config/ryoku`, `~/.local/state/ryoku`, and `~/.local/share/ryoku`.
- Legacy `omarchy-*` wrappers still exist where migration safety or package compatibility still depends on them.
- Package-facing names remain deferred until Ryoku-native replacements exist:
  - `omarchy-keyring`
  - `omarchy-nvim`
  - `omarchy-walker`
- Live boot-theme migration is still incomplete until the Ryoku Plymouth asset path is installed and activated everywhere.
