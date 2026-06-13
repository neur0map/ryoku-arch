# Ryoku Consolidation Plan (organization → one unified shell)

> Execution roadmap for collapsing ryoku's **three parallel stacks** into one, so the
> repo stops feeling like three shells stitched together. Sequenced, **staged, and
> gated**: I implement one (sub)stage, run the narrow checks, show the diff + evidence,
> and you sign off before the next. **Nothing is deleted, relocated, or retired without
> your explicit OK.** This complements `docs/ryoku-config-architecture.md` (rice-vs-user
> defaults + the `[global]` migration contract) and the canonical-layers section of
> `AGENTS.md`, it does not change those rules, it executes the unification they imply.

Status: **Stage 0 (inventory) complete**, maps in `docs/consolidation/`. No code cut. Awaiting approval to begin Stage 1.

---

## Guardrails (apply to every stage)

1. **Gate per (sub)stage.** No stage starts until the previous is approved.
2. **No deletion without sign-off.** Old code stays live until its dedicated *retirement*
   sub-stage, which is itself gated. Migrations are **additive** (copy old→new); the old
   store is untouched until the retirement step.
3. **`[global]` migration for any existing-user data move**, CI-enforced by
   `.github/workflows/config-migration.yml`. Fresh installs get it via the rice.
4. **All code is Ryoku's own.** De-vendor framing continues; `CREDITS.md` +
   `*/ATTRIBUTION.md` + `LICENSE` stay intact (dashboard AGPL-3.0, settingsgui MIT).
5. **User edits win.** Typed config round-trips unknown keys; migrations respect explicit
   opt-outs (per `AGENTS.md` "user's files are the source of truth").
6. **Every (sub)stage is independently shippable, reversible, and verified** against a
   real shell surface (not just build/lint).

---

## Current state: the 3×3×3 (evidence)

**Three config stores** (all live, all read by the shell):
- `~/.config/ryoku/shell.json`, typed `GlobalConfig` (C++ `Ryoku.Config`): appearance,
  bar, border, background, gameMode, services… (the canonical layer).
- `~/.config/ryoku/settings-gui/settings.json`, `Settings.data` (noctalia-derived
  `JsonAdapter`, `settingsVersion 59`). **Functional, not dead**: ~44 settingsgui files
  write it across real domains, `colorSchemes.darkMode`, `nightLight.*`, `network.*`
  (wifi/bluetooth), `dock.pinnedApps`, `appLauncher.*`, `templates.*`, `wallpaper.*`,
  `clipboard.*`, `desktopWidgets.*`, `audio.visualizerType`. Live shell readers incl.
  `modules/ClipboardMaintenance.qml:17`, `modules/WallpaperRotation.qml:34,51-52`.
- `~/.config/ryoku/dashboard/*` (+ legacy `~/.config/ryoku-shell/config.json`), the
  dashboard store; defaults in `shell/dashboard/config/`.

**Three design systems**:
- `Ryoku.Config` `Tokens` + `services/Colours.qml` (`palette`/`tPalette`) + `Ryoku.Blobs`
 , canonical; drives the bar, drawers/frame, new surfaces.
- `shell/modules/common/Appearance.qml`, legacy singleton (end-4 heritage). Backs the
  whole `modules/common/widgets/*` cluster **and the notification subsystem**
  (`NotificationGroup/Item/ListView/ActionButton`, `RippleButton`, `ContextMenu`,
  `GroupButton`, `MaterialSymbol`, `SecondaryTabBar`, `GlassBackground`…) via
  `Appearance.colors.colLayer*`, `Appearance.animation.elementMove*`,
  `Appearance.animationCurves.*`, `Appearance.m3colors.*`, `Appearance.rounding/font.*`.
  Carries the **disabled** `angelEverywhere/inirEverywhere/auroraEverywhere` variant
  branches (all hardwired `false`) and `backgroundTransparency: 0` (so these surfaces
  ignore the transparency slider).
- `shell/settingsgui/Commons/` (`Color.qml`, `Style`), the settings app's own theme
  mapping (already bound to `Colours.palette`/`tPalette`, so mostly a thin adapter).

**Three UI surfaces** (loaded together): `settingsgui` (canonical, `ryoku-shell settings`),
`dashboard` (flagged **retiring** in `AGENTS.md`), `modules/controlcenter`.

The three stacks line up: each store has a matching design system and surface. Unifying
one axis makes the next cheaper.

---

## Stage 0: Inventory & mapping ✅ DONE (non-destructive)

No code change. I generate three authoritative mapping tables checked into
`docs/consolidation/`:
- **`config-map.md`**, every `Settings.data.*` and `dashboard/*` key → domain → write
  sites → live readers → proposed `GlobalConfig.<section>.<key>` target → migration note.
- **`design-map.md`**, every `Appearance.*` member → consumer files → `Tokens`/`Colours`
  equivalent → "needs new token?" flag.
- **`surface-map.md`**, every dashboard feature → is it unique, or duplicated by
  controlcenter/settingsgui? → re-home target or drop-candidate.

Verification: the maps account for 100% of `Settings.data`/`Appearance`/dashboard refs
(grep counts match). **This stage de-risks everything after it** and is the only stage
safe to run before you approve the cuts. Output is your decision input for Stages 1–4.

**Results (maps written to `docs/consolidation/`, cited + exhaustive):**
- **Config, `config-map.md`** (1335 `Settings.data.*` refs / 308 keys / 24 domains): only
  `shell/modules/WallpaperRotation.qml` + `shell/modules/ClipboardMaintenance.qml` read the store
  *outside* `shell/settingsgui/`, the active bar/dock/launcher/network modules live *inside*
  settingsgui, so Stage 1 is mostly **re-homing schema**, not chasing scattered readers.
  `Settings.data.idle` is a dead **duplicate** of `GlobalConfig.general.idle` (delete, don't migrate);
  `controlCenter` is empty-by-design. **First flip → `clipboard`** (4 keys, 1 outside reader, zero overlap).
- **Design, `design-map.md`** (1057 `Appearance.*` refs / 49 files / 167 members): `Appearance.qml`
  is *already a thin façade* over `Colours`/`Tokens`, so migration = delete façade + rename consumers.
  **Do Stage 2a first** (collapse ~196 `*Everywhere` dead-variant ternaries across 22 files, angel/inir/
  aurora are hardwired off), **then `m3colors.*`** (20 refs, pure 1:1). NEEDS-NEW-TOKEN gaps:
  `font.pixelSize.*` (pt→px, 51 refs), `sizes.elevationMargin`; `animation.*` (271 refs) is the heavy bucket.
- **Surface, `surface-map.md`**: `shell/dashboard/` (AGPL) is **live** (island `Content.qml:67`, mirror
  `shell.qml:74-77`, image-clip `clipboard/Wrapper.qml:7`). 5/8 features duplicate the canonical
  `shell/modules/dashboard/` (**drop-as-dup first**: Media/Weather/Calendar/Metrics/tab-chrome). 3 UNIQUE
  need re-home: screen-tools (trivial, execs MIT `ryoku-cmd-*`), webcam mirror (**AGPL**), image-clipboard
  service+overlay (**AGPL**).

---

## Stage 1: One config store (`Settings.data` → typed `GlobalConfig`)

Goal: `settings-gui/settings.json` retired; everything in typed `shell.json`. Done
**domain-by-domain** (each sub-stage independently shippable + gated), smallest/safest first.

Per sub-stage (template):
1. Add typed keys under `shell/plugin/src/Ryoku/Config/<section>.hpp` (rebuild plugin).
2. Rewire the settingsgui controls for that domain to write `GlobalConfig.<…>` + `save()`.
3. Rewire the live shell consumer(s) to read `GlobalConfig.<…>`.
4. Ship a `[global]` `migrations/<ts>.sh` copying `Settings.data.<…>` → `shell.json`
   (jq, idempotent, preserves user values).
5. Verify: toggle the setting → confirm the non-settings shell surface changes.

Proposed order (each gated):
- **1a** `audio.visualizerType`, `appLauncher.{viewMode,pinnedApps}` (low blast radius).
- **1b** `colorSchemes.darkMode`, `nightLight.*` (dark mode / night light).
- **1c** `network.*` (wifi/bluetooth prefs + poll intervals).
- **1d** `dock.*` (pinnedApps + dock prefs), touches Dock/Taskbar/Workspace/StaticDock.
- **1e** `templates.*` (app theming) + `wallpaper.*` (`WallpaperRotation` reader).
- **1f** `clipboard.*` (`ClipboardMaintenance` reader), `desktopWidgets.*`.
- **1g** **Retirement** (gated): collapse the `Settings` facade to a thin read-through to
  `GlobalConfig` (or remove), drop `settings-default.json`'s migrated keys. Final sign-off.

Rollback: until 1g, the old store is still present and untouched by reads only after each
domain flips; a sub-stage can be reverted by reverting its commit (migration is additive).

---

## Stage 2: One design system (`Appearance.*` → `Tokens` + `Colours`)

Goal: `modules/common/Appearance.qml` + `GlassBackground.qml` retired; common widgets +
notifications consume `Tokens`/`Colours`/`Blobs`. Done **cluster-by-cluster**.

- **2a (mechanical, low-risk, gated)** Collapse the dead variant branches. Every
  `Appearance.angelEverywhere ? … : Appearance.inirEverywhere ? … : <material>` ternary
  resolves to `<material>` today (all three flags are hardwired `false`,
  `Appearance.qml:15-17`). Simplify to the Material branch only across
  `modules/common/widgets/*`. This is *not* removing a feature, the variants are off -
  and it strips a large amount of dead code, making 2b/2c readable. Verify: build + lint +
  visual parity (no behavior change).
- **2b** Map `Appearance.colors.colLayer*`/`m3colors`/`rounding`/`font` → `Colours`/`Tokens`
  and migrate the `common/widgets/*` cluster. Add any missing token rather than hardcoding.
- **2c** Migrate the **notification subsystem** (the largest consumer) onto `Tokens`/`Colours`.
- **2d (retirement, gated)** Re-home `GlassBackground`'s wallpaper-blur need onto the
  compositor-blur path (the bar/drawers already use Hyprland layerrule blur), then retire
  `Appearance.qml` + `GlassBackground.qml`. Unify the two animation-disable mechanisms
  (`Appearance.animationsEnabled`/`calcEffectiveDuration` → the Tokens `durations.scale`
  path so game-mode quiet is one mechanism).

Verify each cluster visually (you screenshot) + build/lint; `backgroundTransparency:0`
goes away so these surfaces start honoring the transparency slider (a real win).

---

## Stage 3: Fewer UI surfaces (retire dashboard; settingsgui canonical)

Depends on Stages 1+2 (dashboard reads `Settings.data` and `Appearance.*`).

- **3a** From `surface-map.md`, list dashboard features still in use vs duplicated by
  controlcenter/settingsgui.
- **3b** Re-home any **unique** dashboard feature into the canonical surface (controlcenter
  or settingsgui), wired to `GlobalConfig`.
- **3c (retirement, gated)** Stop instantiating the dashboard surface; archive its tree.
  **License gate:** `shell/dashboard/` is **AGPL-3.0**. If any of its code is merged into
  the MIT settingsgui/controlcenter, that code carries AGPL obligations, I will surface
  this explicitly and **not** merge AGPL→MIT without your decision. Attribution stays.

---

## Stage 4: Repo-root organization (shell vs distro/system tooling)

The root mixes the shell product with whole-distro tooling. Non-destructive regrouping
via `git mv` + referencer repointing (the proven pattern from
`docs/ryoku-config-architecture.md` Step 1: move, repoint, `grep` clean, tests pass).

Proposed groups (exact layout decided in Stage 0/4a, gated):
- **Shell product:** `shell/`.
- **System core (the migrated `ryoku-*` core, stays, just legible):** `bin/` (≈240),
  `lib/`, `migrations/` (≈402).
- **Build / provisioning:** `iso/`, `install/`, `shell-install/`, `distro/`.
- **Assets:** `themes/`, `wallpapers/`, `videowalls/`.
- **Docs / tests:** `docs/`, `tests/`, `research/`.

`bin/` and `migrations/` are the migrated core and **stay** (do not relocate the command
layer); the goal is clear boundaries, not churn. Each move: `git mv` → repoint refs →
`grep` clean → run touched tests.

---

## Sequencing & gates

```
Stage 0 (inventory)  ── gate ──▶ Stage 1 (config store, 1a…1g each gated)
                                   └─ interleaves with ─┐
                                 Stage 2 (design system, 2a…2d each gated)
                                                         └─ gate ─▶ Stage 3 (surfaces) ─ gate ─▶ Stage 4 (repo layout)
```

- Stages 1 and 2 can interleave by cluster (independent files); Stage 3 needs both done.
- I run narrow checks per (sub)stage (plugin build, `qmllint`, the matching `tests/`),
  present the diff + verification, and **wait for your sign-off**.

## Explicitly NOT done without your sign-off
- Deleting/retiring any file, widget, or surface (each retirement is its own gate).
- Relocating user config without a `[global]` migration.
- Merging **AGPL** dashboard code into **MIT** surfaces (license decision is yours).
- Mass-renaming `N*` widgets / `noctalia.svg` branding (optional separate identity pass).

## Effort / risk snapshot
| Stage | Size | Risk | Reversible |
|---|---|---|---|
| 0 Inventory | S | none | n/a (no code) |
| 1 Config store | L (multi-domain) | med (data migration) | yes (additive migrations) |
| 2 Design system | L (notifications) | med (visual regressions) | yes (per-cluster commits) |
| 3 Surfaces | M | med (AGPL/feature parity) | yes until 3c |
| 4 Repo layout | M | low (git mv + repoint) | yes (pure moves) |

---

Recommendation: approve **Stage 0** first (zero risk, produces the exact key/consumer maps
that make every later cut precise). I'll deliver the three mapping tables, then we decide
which Stage 1 domain to flip first.
