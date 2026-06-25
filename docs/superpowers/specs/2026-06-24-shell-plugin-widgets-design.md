# Shell plugin widgets: design

Status: draft, awaiting user review
Date: 2026-06-24
Area: ryoku (shell + hub)

## Problem

Ryoku has no plugin runtime. The shell surfaces are static: each of `pill`,
`sidebar`, `visualizer` registers a fixed `IpcHandler` block, and every QML
component is imported at startup. The Hub lists Extras (package bundles) and
Themes, but has no Plugins page. `system/extras/ryoku-extras-install` already
routes `package` and `script` bundle items and explicitly defers `plugin` items
"to the shell's plugin path" with the reason "install from Settings, Plugins" --
a page that does not exist. So a plugin path was designed into the extras flow
and left as a stub.

A legacy design exists in the `neur0map/ryoku-extras` repo
(`plugins/AUTHORING.md`, `plugins/wallhaven/`). It is sound but no longer
compatible: its QML imports (`qs.components`, `qs.components.controls`,
`Ryoku.Config` with `Tokens`/`Colours`, `qs.settingsgui`) belong to a different
shell lineage and do not exist in the current codebase. The current shell ships
its own signature kit instead.

We want a plugin system that lets contributors extend the desktop without
breaking its cohesion, where the shell owns the look and the user owns the
placement.

## Goals

- One plugin can present itself in multiple places (frame popout, desktop
  widget, island, topbar glyph, keybind window); the **user** chooses which,
  and where.
- The **shell** owns the layer, shape, size envelope, motion, and input region
  for every placement. A plugin never draws a raw surface or positions itself.
- A plugin's UI matches the **control-deck** signature at runtime and the
  **Ryoku Settings (hub)** signature in its options page.
- A widget does not break or misform when the user moves it between placements.
- Contributions are allowed, via a curated registry, with an official/community
  distinction.

## Non-goals

- No arbitrary, free-positioned QML overlays (the GNOME-extension model). A
  plugin only supplies content bound to a shell-owned host.
- No new theming engine. Color schemes and package bundles keep their existing,
  separate paths; this spec covers shell-UI plugins only.
- No sandboxing of plugin code in v1. Plugins run with full session
  permissions, like every mature Quickshell shell; trust is handled by the
  registry review and the official/community flag (see Security).

## The three tiers (kept separate)

These already exist as distinct mechanisms and stay distinct. The Hub may
present them under one "extend" umbrella, but they are never merged into one
catalogue or trust model.

| Tier | What it is | Risk | Home | Mechanism (existing) |
|---|---|---|---|---|
| Color schemes | palette data (JSON) | none | Themes/Appearance | `ryoku-hub hypr theme` |
| Extras/bundles | package sets (pacman/AUR/script) | system, no shell UI | Extras page | `ryoku-extras-install` |
| Plugins | live QML in the session | full session perms | **Plugins page (new)** | this spec |

## Architecture

### Plugin layout

```
plugins/<id>/
  manifest.json        capabilities + proposed defaults
  service/Main.qml     persistent headless logic/state (the plugin's "main")
  content/Widget.qml   ONE adaptive view, renders at a requested density
  settings/Page.qml    options page, authored in the hub dialect
  bin/                 optional shipped executables
  assets/              preview image, etc.
  README.md
```

This keeps the legacy split that already works (a headless service + a view +
a settings page), and removes the legacy assumption that a plugin is bound to a
single fixed frame corner.

### The widget contract (capabilities + density tiers)

A plugin declares **capabilities**, not a fixed surface. `content/Widget.qml` is
a single adaptive view that renders at one of three densities chosen by the
host:

- `glyph`   icon (+ optional badge). Topbar glyph, collapsed island.
- `compact` a summary card. Island, narrow popout, small desktop tile.
- `full`    the rich panel. Frame popout, window, large desktop tile.

Two-level adaptivity guarantees "does not misform when moved":

1. The **density tier** decides *what information is shown* (host-selected).
2. **Layout** (`ColumnLayout`/`GridLayout`/`Flow`, intrinsic `implicitWidth`/
   `implicitHeight`) decides *how it reflows* within the tier, inside whatever
   width budget the host supplies.

There is no absolute geometry in plugin content, so there is nothing to break.
This is already how the legacy wallhaven panel behaves (it switches between a
`compactHeight` search view and an `expandedHeight` grid, sizes itself with
`implicitWidth`/`implicitHeight`, and reflows the grid by width); the contract
formalizes and generalizes it.

### Properties the host sets (read, never assign)

On `content/Widget.qml`:

| Property | Type | Meaning |
|---|---|---|
| `pluginApi` | var | handle to service, settings, plugin dir |
| `screen` | ShellScreen | the screen this instance is on |
| `density` | string | `"glyph"` \| `"compact"` \| `"full"` |
| `active` | bool | true while the placement is open/visible |
| `widthBudget` | real | available width the content must lay out within |

On `service/Main.qml` and `settings/Page.qml`: just `pluginApi`.

`pluginApi` mirrors the legacy contract: `pluginApi.mainInstance` (the live
service), `pluginApi.pluginSettings` (seeded from `manifest.metadata.
defaultSettings`), `pluginApi.saveSettings()`, `pluginApi.pluginDir`.

### Host vocabulary

Each host is a shell-owned shape. The shell supplies the layer, material,
size envelope, motion (`Motion.morph` curve), input region, and trigger; the
host requests a default density and the user may override placement.

| User intent | Host | Layer | Default density | Trigger | Position model |
|---|---|---|---|---|---|
| hover to open on frame | FramePopout | blob overlay | full | hover edge+align | edge + align |
| make it a widget | DesktopWidget | `WlrLayer.Bottom` | compact/full | always-on | drag, free |
| small island | Island | island blob group | compact | always-on / hover | drag along top edge |
| topbar icon | TopbarGlyph | pill bar | glyph (+ full popout) | click/hover glyph | bar slot order |
| keybind window | Window | centered surface | full | leader key / keybind | centered |

Universal keyboard access stays the `Super+X` leader menu: one leader key, then
a per-plugin sub-key, user-rebindable, so plugin shortcuts never crowd the
`Super+<key>` space.

### v1 scope

- v1 hosts: **FramePopout, DesktopWidget, Island.** These reuse infrastructure
  that already exists: `PillSurface` (morph/clip base), the shared `BlobGroup`
  and the `triggerX/Y/W/H` + `bodyX/Y/W/H` Region-union input mask, and the
  `WlrLayer.Bottom` desktop widget layer.
- Fast-follow hosts: **TopbarGlyph, Window.**
- The host abstraction is designed so adding a host is adding one host renderer,
  not reworking the plugin model.

### manifest.json

Replaces the legacy single `frame{}` block with capabilities + allowed hosts +
proposed defaults:

```json
{
  "id": "wallhaven",
  "name": "Wallhaven",
  "version": "2.0.0",
  "author": "Ryoku Team <hello@ryoku.sh>",
  "description": "Browse wallhaven.cc and set wallpapers.",
  "license": "MIT",
  "tags": ["wallpaper"],
  "official": true,
  "entryPoints": {
    "main": "service/Main.qml",
    "content": "content/Widget.qml",
    "settings": "settings/Page.qml"
  },
  "capabilities": {
    "densities": ["glyph", "compact", "full"]
  },
  "hosts": ["framePopout", "desktopWidget", "island", "topbarGlyph", "window"],
  "defaults": {
    "host": "framePopout",
    "framePopout": { "edge": "top", "align": "end" },
    "key": "w",
    "icon": "wallpaper",
    "label": "Wallhaven"
  },
  "commands": ["bin/ryoku-wallhaven-search"],
  "dependencies": { "commands": ["curl", "jq"] },
  "metadata": { "defaultSettings": { "apiKey": "" } }
}
```

`defaults.*` are *proposals*. The user's placement/keybind choices, persisted by
the Hub, always win.

## Two styling dialects

A plugin authors against two existing, separate kits. Research confirmed the
legacy namespaces do not exist; these are the real ones.

### Deck dialect (runtime content)

From `ryoku/shell/quickshell/pill/`: `Theme` (brand `#F25623`, `cream`,
`tileBg`, `frameBg`, `hair`, `border`, fonts Inter/Noto CJK/JetBrainsMono),
`Motion` (`fast` 140ms, `standard` 300ms, `morph` 420ms, curve
`cubic-bezier(0.16,1,0.3,1)`, `rSmall` 7, `rTile` 13), `GlyphIcon`,
`MicroLabel` (vermilion dot + mono eyebrow), `PillSurface`, `SearchField`,
`Card`, `CornerTicks`, `WaveMeter`.

Problem: these live *inside* `pill/` and are imported by relative path, and
each Quickshell config in this repo is self-contained (sidebar, widgets,
visualizer each ship their own `Singletons/`). There is NO `qs.*` module in the
codebase; that namespace was legacy-shell fiction. Forcing one would add a
second convention beside the established per-config relative-import pattern,
which the cardinal rules forbid.

Decision (revised after reading the code): the plugin runtime is its own
self-contained config, `ryoku/shell/quickshell/plugins/`, following the house
pattern exactly. It ships its own `Singletons/` (Theme/Motion/Config, the same
source as the pill's) and a local `components/` holding the reusable
presentational kit (`GlyphIcon`, `MicroLabel`, `Card`, `SearchField`,
`CornerTicks`, `WaveMeter`, and a host-side `PluginSurface` adapted from
`PillSurface`). Plugin QML imports these relatively, like every other config.
The deck kit is the source of truth; the `plugins/components/` copies are kept
faithful to it. Stateful pill internals (`DeckStash`, `DeckUtilities`, etc.)
are never copied. This is zero-churn to the existing `pill/` tree.

### Hub dialect (settings page)

From `ryoku/hub/quickshell/`: the hub `Theme` (warm palette) plus
`SettingSection`, `ToggleRow`, `SliderRow`, `ChoiceRow`, `Segmented`,
`Dropdown`, `ColorField`, `TextFieldRow`, `HubButton`, `ActionPill`,
`PageHeader`. A plugin's `settings/Page.qml` is loaded inside the Hub and uses
these directly.

## Who decides what

- **Shell (creator):** the host set; each host's shape, motion, material, input
  region; the density contract; the styling kits. A plugin cannot break
  cohesion because it never draws a surface.
- **Plugin author:** the service, the adaptive content, the settings page; and
  *proposes* defaults (suitable hosts, a default keybind, an icon).
- **User:** enable/disable; assign each capability to a host; position/order it;
  rebind; configure. User choice always wins.

## The Hub Plugins page

A new section registered in `Hub.qml` (`sectionDefs` + `pageMeta` + `pageFor`),
under the "Desktop" group, following the existing page patterns.

- **Browse/install:** reuse the Extras catalogue plumbing. `ryoku-hub` gains a
  `plugins catalog` command that reads `plugins/registry.json` from
  `RYOKU_EXTRAS_BASE` (env or GitHub raw) and caches under
  `~/.cache/ryoku/extras`, exactly as `extras catalog` does for bundles. The
  bento-grid + detail-overlay UI (`ExtraBundleCard`, `ExtraBundleDetail`) is the
  template.
- **Per-plugin management (detail view):** enable toggle (`ToggleRow`); a
  placement editor -- pick host(s) (`ChoiceRow`/`Dropdown`), set position
  (edge+align for FramePopout; drag for DesktopWidget/Island), set trigger and
  keybind; the plugin's own `settings/Page.qml` embedded; a **live preview** of
  the widget at each density so the user sees exactly how it will look before
  committing (uses the established live-preview pattern).
- **Persistence:** user placement/config is written to a watched JSON
  (`~/.config/ryoku/plugins.json`) via the `FileView` + `JsonAdapter` pattern
  (as `WidgetsPage` does), and the shell's plugin host watches it and
  applies/relays out live.
- **Install actuation:** `ryoku-extras-install` plugin items stop being deferred
  and install plugin sources into `~/.local/share/ryoku/plugins/<id>/`; the
  deferral reason string is updated to reflect the now-real Plugins page.

## Plugin runtime (shell side)

Refined after reading the blob architecture: the SDF blob field is **per
process** (frame.md: everything that must fuse lives in one scene and one
`BlobGroup`, in the pill process). So a single separate "PluginHost" process
cannot host a frame-fusing popout. The runtime is therefore split by whether a
host must fuse the frame:

- **Shared discovery.** `plugins/Singletons/Registry.qml` runs `discover.sh`
  (scan plugin dirs + merge `~/.config/ryoku/plugins.json` + keep enabled),
  exposes `plugins: [{ id, dir, manifest, placement }]`, and re-runs on a
  `plugins.json` change. Both processes below read this same singleton.
- **Frame-fusing hosts (FramePopout, Island)** are hosted **in the pill
  process**: the pill's overlay instantiates plugin content into a `Popout` (the
  existing edge-popout machinery) or the island, in the pill's `blobGroup`, so
  it melts into the frame exactly like Mixer/Power do today.
- **Independent-layer hosts (DesktopWidget, Window, TopbarGlyph)** live in the
  `plugins/` config (its own process): DesktopWidget mirrors `widgets/`
  (`WlrLayer.Bottom` + `WidgetSlot` drag), Window is a centered surface,
  TopbarGlyph is a bar slot.
- Each plugin's `service/Main.qml` loads once per process that renders it;
  content is instantiated via `Qt.createComponent(dir + "/content/Widget.qml")`
  behind an error guard, so a broken plugin disables itself and never crashes
  the host.
- Daemon verbs (plain-text socket, matching the protocol): `plugin <id>
  <action>` (`toggle`/`show`/`hide`) routed to the pill or plugins IpcHandler by
  the host the plugin uses, plus `plugins reload`. The leader menu and plugin
  keybinds route through these.

## Wallhaven rework (proof case)

The acceptance proof: one wallhaven plugin runs as a top-right frame popout, a
desktop tile, **and** a topbar glyph, and looks deliberately Ryoku in each.

- `service/Main.qml`: keep nearly verbatim (search/download/paging,
  `Walls.setWallpaper`, `Toaster`). Swap legacy `qs.services` for the real
  singletons. The headless service is already the right shape.
- `content/Widget.qml`: collapse the legacy Panel into one adaptive view.
  - `glyph`: `wallpaper` `GlyphIcon` + a running-download dot.
  - `compact`: `SearchField` + one thumbnail row + the Top-week/month chips
    (the legacy `compactHeight` state).
  - `full`: the search grid + pager + per-tile menu (the legacy `expandedHeight`
    state).
  - Rewritten against the deck kit: `StyledRect`/`Colours.*`/`Tokens.*` ->
    deck `Card`/`Theme.*`/`Motion.r*`; `MaterialIcon` -> `GlyphIcon`; `CAnim` ->
    `Behavior { ... Motion.fast }`; masthead picks up `MicroLabel` so it reads
    as a deck section.
- `settings/Page.qml`: rebuild in the hub dialect (API key becomes a
  `TextFieldRow` in a `SettingSection`). Drop `qs.settingsgui`.
- `manifest.json`: as above (capabilities + hosts + defaults).

## Security and governance

- Plugins run with full session permissions (no sandbox in v1). This matches
  DankMaterialShell and Noctalia, which both warn "review source before
  install."
- Trust is the registry: a PR-reviewed `plugins/registry.json` in the extras
  repo, with `official: true|false`. The Plugins page surfaces the
  official/community distinction and a clear "runs with full access" note on
  community plugins.
- The slot system contains the blast radius: a bad plugin can be ugly, but
  cannot break the frame's cohesion or seize the desktop, because the shell owns
  every host's chrome.

## Risks and mitigations

- **Kit extraction churn.** Moving components out of `pill/` touches existing
  imports. Mitigation: extract only the presentational subset, leave stateful
  deck internals in place, and update shell imports in the same change; verify
  the shell renders unchanged before wiring any plugin.
- **External QML load failure breaking the shell.** Mitigation: the PluginHost
  loads each plugin in isolation (a failed `content/Widget.qml` disables that
  plugin and toasts, never crashes the host); the service and content load
  behind error guards.
- **Density misforming at extremes.** Mitigation: each density declares a
  minimum size; the host clamps its envelope to >= minimum; content uses only
  intrinsic sizing + Layouts (enforced by the wallhaven proof and a second
  example plugin during review).
- **Live re-placement jank.** Mitigation: re-placement goes through the host's
  `Motion.morph`; the PluginHost reparents content between hosts on an explicit
  state change, never per-frame.

## Implementation status (live build)

Built and verified live on the running shell (grim screenshots at each step):

- Foundation: `Ryoku.PluginKit` QML module; `plugins/` Quickshell config;
  `discover.sh` (catalogue + `plugins.json` merge), tested for the empty,
  disabled, and enabled cases.
- FramePopout host: wallhaven fused into the frame blob in the pill, opened by
  hover (input-mask wired) and by `ryoku-shell plugin <id>` (new daemon verb +
  pill `pluginPopout` IpcHandler). Verified open/close and live render.
- DesktopWidget host: wallhaven as a draggable tile on the `WlrLayer.Bottom`
  layer (the `plugins` config, mirroring `widgets/`), position persisted via
  `ryoku-plugins-place`. Verified on the wallpaper alongside the shipped widgets.
- Hub Plugins page: enable toggle + host selector per plugin, in the hub dialect.
  Verified rendering and that a host change writes `plugins.json`.
- Extras: `ryoku-extras-install` installs/removes `plugin` items via
  `ryoku-hub extras plugin`. Packaged in `ryoku-desktop`; deploy wired.
- Wallhaven reworked (manifest + service + adaptive content + hub settings) with
  a live search backend.

Fast-follow status:

- Frame popout now grows from **any edge** (top/bottom/left/right) with `align`
  (start/center/end), selected live in the hub placement editor; the blob melts
  into the frame on every edge. Verified live on all four. This also unblocks the
  Island host (a top-edge popout variant).
- TopbarGlyph and Window hosts remain fast-follow (independent layers).
- Remote-catalogue browse/install of plugins inside the Hub page (the page
  manages installed plugins today; install is via the Extras bundle path).

Fixes landed (widget now renders fully and search works end-to-end):

- Sizing model rebuilt: a single `contentW` is propagated to every child
  explicitly (not `parent.width` through nested layouts), so the search box,
  chips, and grid no longer collapse to zero height. The widget renders all of
  WALLHAVEN eyebrow + styled search box (力 glyph + placeholder) + Latest/Top
  week/Top month chips + the result grid. Verified live.
- Search works: the service ran with an empty command path because (a) setting
  `Process.environment` to a dict cleared PATH (curl/jq vanished) and (b) a
  cached `commandPath` binding captured an empty `pluginDir` before the host
  wired `pluginApi`. Fixed by injecting the API key via an `env KEY=val` prefix
  (never replacing the environment) and computing the path fresh via `cmdPath()`
  at call time, plus a service-side `onReadyChanged` initial search. Verified:
  the search returns 24 results and the grid populates with 6 cells.
- Content is loaded via `PluginContent` (Qt.createComponent + createObject)
  rather than `Loader { source: url }`.

Resolved defect (image-texture compositing):

- Symptom: result-grid thumbnail `Image`s did not paint in any host. Root cause,
  isolated by a mock-service reproduction: **an `Image` inside an inline QML
  `component` (`component WhThumb: Rectangle { ... Image ... }`) used as a
  Repeater delegate does not composite its texture in Quickshell**, while the
  same `Image` in a plain inline delegate renders fine. Not clip, layer,
  network, sourceSize, loader, or `ComponentBehavior` related (all eliminated).
  Fix: the thumbnail delegate is a plain inline `Rectangle` + `Image` (no inline
  component). Verified live: real wallhaven thumbnails render in BOTH the desktop
  widget and the frame popout. Authoring guidance: plugin content should avoid
  inline `component` wrappers around `Image`; use a separate `.qml` file or an
  inline delegate.

## Decisions taken (defaults; confirm or override on review)

1. Core model: one adaptive `content/Widget.qml` at three densities; shell owns
   host/layer/size/motion.
2. v1 hosts: FramePopout + DesktopWidget + Island; fast-follow TopbarGlyph +
   Window.
3. Kit extraction into shared `qs.components` is in scope (required for plugins
   to import the signature style).

## Out of scope / follow-ups

- Plugin-to-plugin services (DMS-style background providers).
- Launcher-provider capability (search results), control-center cards.
- Plugin signing/sandboxing.
