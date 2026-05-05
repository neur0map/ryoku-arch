# Three-Island Topbar - Design

## Context

The Ryoku topbar currently supports four mutually exclusive corner styles -
`Hug` (0), `Float` (1), `Rect` (2), `Card` (3) - selected via
`Config.options.bar.cornerStyle`. Each renders one continuous bar surface with
left, center, and right sections inside it. The user wants a fifth
appearance/layout, "Three-Island", that splits the bar into three visually
distinct pills (two corner-hugged, one floating in the middle) with
transparent gaps between them, and that carries Ryoku-flavored content
(rice + cybersec) - without modifying any existing widget, file, or
behavior tied to the existing four styles.

A prior attempt (`docs/superpowers/specs/2026-05-03-topbar-three-island-frame-design.md`)
took a different approach (a single Canvas-drawn frame with three notches,
applied via a perl-regex branding-script patch on `BarContent.qml`). That
patch is not present in the current branch. This spec is a fresh,
non-destructive design: a new corner-style value selects a brand-new file
tree, the existing `BarContent.qml` is byte-untouched, and the new layout
ships its own widgets and its own per-pill background painting.

## Goals

- Add `cornerStyle: 4` ("Three-Island") as a fifth, mutually exclusive value.
- Render three separate pills: two hug the screen corners (top edge flush,
  inner corners rounded), one floats in the middle with full rounding.
- Keep all existing files in `shell/modules/bar/` byte-identical except
  `Bar.qml`, which receives two small edits: (1) wrap the inline
  `BarContent {}` in a `Loader` that switches between `BarContent` and the
  new `RyokuThreeIslandContent`, and (2) extend the existing
  `roundDecorators` Loader condition from `cornerStyle === 0` to
  `cornerStyle === 0 || cornerStyle === 4`.
- Reuse existing widgets (`Logo`, `ActiveWindow`, `BarTaskbar`, `Workspaces`)
  composed into the new layout without modification.
- Add two new Ryoku-flavored widgets (`RyokuKanjiClock`, `RyokuSecPulse`)
  registered as first-class modules under `bar.modules.*`, mirroring the
  existing module-toggle pattern.
- Per-pill color / border / rounding / blur honors the existing global-style
  decision tree (Material / Aurora / Ryoku-shell / Cards / Angel) using the
  same rules `BarContent.qml`'s `barBackground` already applies.
- Preserve all existing topbar behavior: scroll regions, right-click context
  menu, autohide animations, IPC, global shortcuts, screen-corner decorators,
  per-monitor variants, scroll-hint icons.
- Top-edge orientation only in v1 (`bar.bottom = false && bar.vertical = false`).
  When the user has Three-Island selected and switches to bottom or vertical,
  the layout falls back to the existing `BarContent.qml` and a `ConflictNote`
  in settings explains the limitation.
- Three-Island is opt-in. Default `cornerStyle` stays `0` (Hug).

## Non-Goals

- Do not modify `BarContent.qml`, `BarGroup.qml`, `Workspaces.qml`,
  `ActiveWindow.qml`, `Logo.qml`, `ClockWidget.qml`, or any other existing
  widget file.
- Do not change the default `bar.cornerStyle` for Ryoku-shell users in
  `default/ryoku-shell/config-overrides.json`. Existing users updating to
  this version see no change unless they pick `4`.
- Do not redesign the right sidebar or move sidebar-owned controls.
- Do not implement bottom-edge or vertical Three-Island in v1.
- Do not patch `BarContent.qml` via a branding-script regex (the prior
  Canvas-frame approach is rejected - too fragile, too entangled with the
  existing source).
- Do not add a new global style. Three-Island is a corner-style value, not
  a global style.

## Architecture

### Single Loader switch in `Bar.qml`

`Bar.qml` currently instantiates `BarContent { id: barContent; ...anchors;
Behavior on topMargin; states... }` inside the hover region. The properties
set at that use-site (id, height, anchors, animations, states) are not
internal to `BarContent.qml` - they live in `Bar.qml`. They move onto a new
`Loader` that takes BarContent's place:

```qml
Loader {
    id: barContent
    height: Appearance.sizes.barHeight
    anchors { /* unchanged - same right/left/top + topMargin currently here */ }
    Behavior on anchors.topMargin { /* unchanged */ }
    Behavior on anchors.bottomMargin { /* unchanged */ }
    states: State { /* unchanged - "bottom" state with AnchorChanges */ }

    sourceComponent: (Config.options?.bar?.cornerStyle === 4
                     && !(Config.options?.bar?.bottom ?? false)
                     && !(Config.options?.bar?.vertical ?? false))
        ? threeIslandComponent
        : barContentComponent
}
Component { id: barContentComponent; BarContent {} }
Component { id: threeIslandComponent; RyokuThreeIslandContent {} }
```

Both loaded components fill the Loader (the Loader has explicit `height`
and edge-anchors). `BarContent.qml` itself is not edited - the only change
is in `Bar.qml`, where the inline `BarContent { ... }` becomes a `Loader`
with the same id and the same outer properties. Surrounding code that
references `barContent` by id (`hoverMaskRegion.fill: barContent`,
`roundDecorators.anchors.top: barContent.bottom`) continues to bind to the
Loader, so it reads geometry identically.

The `roundDecorators` Loader (Bar.qml line 169) currently activates when
`cornerStyle === 0` (Hug). Its condition extends to
`cornerStyle === 0 || cornerStyle === 4` so the corner-hug decorators draw
under the Three-Island corner pills as well.

When Three-Island is not selected, the Loader's source is `BarContent` and
the bar behaves identically to today (the Loader wrap adds one extra QML
node in the tree but no rendered pixels change).

### New file tree

Everything new lives under one isolated directory:

```
shell/modules/bar/threeIsland/
├── RyokuThreeIslandContent.qml   # the layout swap target; owns 3 islands + 3 scroll regions
├── RyokuIsland.qml               # one pill: bg/border/rounding/blur (mirrors BarContent.barBackground)
├── RyokuLeftIsland.qml           # composes Logo + ActiveWindow/Taskbar (existing widgets)
├── RyokuCenterIsland.qml         # composes Workspaces (existing widget)
├── RyokuRightIsland.qml          # composes RyokuKanjiClock + RyokuSecPulse + rightSidebarButton
├── RyokuKanjiClock.qml           # NEW widget
├── RyokuSecPulse.qml             # NEW widget
└── qmldir                        # module registration
```

`RyokuIsland.qml` re-implements the same color / border / radius / blur
decision tree that `BarContent.qml`'s `barBackground` uses, but applied
per-pill instead of bar-wide. The decision tree is copied, not refactored,
so the existing `barBackground` keeps its tested code path. This costs
duplication, but it eliminates the risk of a refactor regressing any of
the four existing styles.

### Service for `RyokuSecPulse`

`shell/services/RyokuSecPulse.qml` - a singleton service exposing:

- `vpnActive` (bool) - derived from `wg show interfaces` having any output
- `publicIp` (string) - populated only when `bar.secPulse.showPublicIp` is on
- `listeningCount` (int) - populated only when `bar.secPulse.showListening` is on

Uses `Quickshell.Io.Process` for subprocess execution. Polling: VPN every
30s (cheap), public IP every 5 min (network-bound), listening count every
30s (subprocess-cheap but spawn-cost matters). No process is spawned on
startup until the first reader subscribes - `Component.onCompleted` only
triggers the first poll if the corresponding `bar.secPulse.show*` toggle
is on at startup. This keeps the default loadout (VPN-only) at one
30-second poll and zero subprocesses for the opt-in features.

## Layout

Three pills inside a transparent bar surface:

```
┌───────────────────────────────────────────────────────────────────────┐
│ ┌─────────────┐         ┌────────────┐         ┌────────────────────┐ │
│ │ 力  ActiveWin│  gap →  │ Workspaces │  ← gap  │ KanjiClock | Pulse │ │
│ └─────────────┘         └────────────┘         └────────────────────┘ │
└───────────────────────────────────────────────────────────────────────┘
   hug TL                  fully rounded                    hug TR
```

- **Left island**: anchored to `parent.left`, top edge flush with `parent.top`.
  Inner corners (top-right + bottom-right) rounded. Outer corners (top-left
  + bottom-left) follow the existing Hug rule - top-left flush; bottom-left
  uses the same `RoundCorner` decorator path Hug already uses (the
  `roundDecorators` Loader in `Bar.qml` is preserved and applies whenever
  the loaded component reports `cornerStyle === 0 || cornerStyle === 4`).
- **Right island**: mirrored - anchored to `parent.right`, top edge flush,
  inner corners rounded, outer-right corners hugged.
- **Center island**: horizontally centered, top edge **not** flush - sits
  with a top inset of `Appearance.sizes.hyprlandGapsOut`, fully rounded
  (`Appearance.rounding.windowRounding`).
- **Gaps**: pure transparency. The bar-wide `barBackground` does not render
  in `cornerStyle === 4` (the Three-Island content owns its own per-pill
  backgrounds).
- **Bar height**: `Appearance.sizes.barHeight` - same as Hug. The center
  pill's top inset fits inside that band; no extra height is required.
- **Per-pill scroll regions**: each pill is wrapped in a
  `FocusedScrollMouseArea` (same component used by the existing left/right
  scroll regions) so brightness / volume / workspace scroll actions apply
  per-pill. Right-click on any pill opens the existing `barContextMenu`
  (anchored to the click position, same as today). Scroll-hint icons
  surface on hover at the inner edge of each side pill.

## Content per island (Loadout 1 - Signature)

- **Left**: `Logo` (the 力 kanji button) + `ActiveWindow` (or `BarTaskbar`
  if `bar.modules.taskbar` is on) - composes existing widgets unmodified.
- **Center**: `Workspaces` only. The existing `Workspaces.qml` is reused
  as-is. Default number style remains whatever the user has configured at
  `bar.workspaces.numberMap` (we do not force Japanese numerals - that's
  an independent existing toggle).
- **Right**: `RyokuKanjiClock` + `RyokuSecPulse` + the existing
  `rightSidebarButton`. The right-island sidebar button retains the
  notification-unread / mic-mute / volume-mute / network / bluetooth
  indicator cluster it already carries today.

## Configuration schema

Added to `shell/modules/common/Config.qml` inside the existing `bar`
JsonObject. The change to `cornerStyle` is comment-only.

```qml
property int cornerStyle: 0  // 0: Hug | 1: Float | 2: Rect | 3: Card | 4: Three-Island

property JsonObject modules: JsonObject {
    // ...existing keys unchanged...
    property bool kanjiClock: true   // NEW - used by Three-Island only
    property bool secPulse: true     // NEW - used by Three-Island only
}

property JsonObject kanjiClock: JsonObject {
    property bool showDate: true
    property bool useKanjiDigits: true   // 一二三 vs 1 2 3
}

property JsonObject secPulse: JsonObject {
    property bool showVpn: true
    property bool showPublicIp: false    // opt-in (network query)
    property bool showListening: false   // opt-in (subprocess to ss)
}
```

The `bar.modules.kanjiClock` and `bar.modules.secPulse` keys mirror how
`bar.modules.weather` works today: always-visible toggle, inert when its
parent feature is off (in this case, when `cornerStyle ≠ 4`). The new
widgets read both gates: they render only when
`cornerStyle === 4 && bar.modules.kanjiClock` (resp. `secPulse`).

## Settings UI

### `shell/modules/settings/BarConfig.qml`

Three additions; nothing existing is removed.

1. The corner-style `ConfigSelectionArray` at line ~120 gets one new entry:
   `{ displayName: tr("Three-Island"), icon: "view_column_2", value: 4 }`.
2. The Modules `SettingsCardSection` gets two new `SettingsSwitch` entries
   alongside Weather/Taskbar - one for `bar.modules.kanjiClock`, one for
   `bar.modules.secPulse`. A `ConflictNote` next to each shows
   *"Active only in Three-Island corner style"* when the toggle is on but
   `cornerStyle ≠ 4`.
3. Two new collapsible `SettingsCardSection`s - *"Kanji Clock"* and
   *"Security Pulse"* - mirroring the existing per-module sections
   (Resources, Media, Workspaces, System Tray, Utility Buttons). They
   expose the `bar.kanjiClock.*` and `bar.secPulse.*` knobs. Both sections
   are visible only when `cornerStyle === 4` (consistent with how the rest
   of the page behaves - modules irrelevant to current selection stay
   hidden).
4. A `ConflictNote` near the corner-style picker: visible when
   `cornerStyle === 4 && (bar.bottom || bar.vertical)`, message
   *"Three-Island layout is top-edge only. Switch position to Top to
   enable it."* The Loader falls back to `BarContent` in those cases.

### `shell/modules/settings/QuickConfig.qml:1483`

Same one-entry addition to its corner-style `ConfigSelectionArray`.

### `shell/welcome.qml:1218`

Same one-entry addition to its corner-style `ConfigSelectionArray`.

## Defaults

- `bar.cornerStyle: 0` - unchanged.
- `bar.modules.kanjiClock: true` - so a fresh switch to Three-Island shows
  the signature clock immediately.
- `bar.modules.secPulse: true` - same reason.
- `bar.kanjiClock.showDate: true`, `useKanjiDigits: true`.
- `bar.secPulse.showVpn: true` - `wg show` is cheap and runs even when no
  VPN exists (returns empty).
- `bar.secPulse.showPublicIp: false` - explicit opt-in; this hits the
  network.
- `bar.secPulse.showListening: false` - explicit opt-in; this spawns
  `ss` as a subprocess.

`default/ryoku-shell/config-overrides.json` is not modified. Ryoku-shell
distro users continue to ship with whatever default they have today.

## Migration

No `migrations/<timestamp>.sh` script is required. `cornerStyle === 4` is
opt-in, and the new `bar.modules.kanjiClock` / `bar.modules.secPulse`
keys default to `true` only matter when a user has selected Three-Island.
Existing user `config.json` files that do not contain these keys read the
defaults from `Config.qml` and continue working unchanged.

## Data flow

No new data sources are introduced for layout. New data sources for
`RyokuSecPulse`:

- `wg show interfaces` - VPN active flag (default-on, polled 30s).
- `curl -s ifconfig.me` - public IP (opt-in, polled 5 min, only when
  `bar.secPulse.showPublicIp` is on).
- `ss -lntH | wc -l` - listening socket count (opt-in, polled 30s, only
  when `bar.secPulse.showListening` is on).

`RyokuKanjiClock` reads existing `DateTime` / clock state - no new service.

All existing data sources used by reused widgets (active window text,
workspace state, network/Bluetooth/notifications/mic/volume in
`rightSidebarButton`) are unchanged.

## Testing

### Static (`tests/three-island-bar.sh`, new file)

- `Bar.qml` wraps the bar-content rendering in a `Loader` whose source
  switches on `cornerStyle === 4 && !bar.bottom && !bar.vertical`.
- `Bar.qml`'s `roundDecorators` Loader condition includes
  `cornerStyle === 4` alongside `cornerStyle === 0`.
- `BarContent.qml` is byte-identical to the previous commit
  (`git show HEAD~:shell/modules/bar/BarContent.qml` diff is empty).
- Files exist at every path under `shell/modules/bar/threeIsland/`.
- `Config.qml` declares the new keys with the documented defaults.
- `BarConfig.qml`, `QuickConfig.qml`, and `welcome.qml` each contain
  exactly one `value: 4` corner-style option.
- `RyokuSecPulse.qml` does not call `process.start()` /
  `process.startDetached()` unconditionally inside `Component.onCompleted`
  - only inside the per-feature gated branches.
- `tests/ryoku-shell-branding.sh` continues to pass (no regression of the
  existing branding-script test surface).

### Manual

Restart the shell on each scenario:

1. Default config (`cornerStyle = 0`): bar identical to today.
2. Cycle `cornerStyle = 1, 2, 3`: Float / Rect / Card all unchanged.
3. `cornerStyle = 4`: three pills appear; gaps transparent; brightness /
   volume / workspace scroll work per-pill; right-click context menu still
   opens; autohide hides/shows all three pills together.
4. `cornerStyle = 4 && bar.bottom = true`: conflict note shows; bar
   re-renders via `BarContent.qml` at the bottom edge. Toggle bottom off:
   Three-Island returns.
5. Cycle `appearance.globalStyle` through `material`, `aurora`,
   `ryoku-shell`, `cards`, `angel` while in Three-Island: each pill
   respects that global style's color / border / blur rules.
6. `bar.secPulse.showPublicIp = false && bar.secPulse.showListening = false`:
   confirm via `pgrep -P $(pgrep -x quickshell) | xargs -I {} ps -p {} -o comm=`
   that no `curl` or `ss` child process exists.

## Risk

The largest risk is `RyokuIsland.qml` duplicating the per-style color /
border / rounding / blur logic from `BarContent.qml`. If those upstream
rules are tweaked later (e.g., a new global style is added, or Aurora's
blur formula changes), the Three-Island pills will not pick up the change
automatically. Mitigation: a comment in both files cross-references the
other, and `tests/three-island-bar.sh` includes a string-grep assertion
that the Aurora / Ryoku / Material / Cards / Angel branch names listed
inside `RyokuIsland.qml` match the set listed in `BarContent.qml`'s
`barBackground` color block. If the upstream set changes, the test fails
and the new style is added explicitly to both files.

## Open follow-ons (out of scope for this spec)

- Bottom-edge Three-Island layout (mirrored geometry).
- Vertical Three-Island layout (left/right edge).
- Additional Ryoku widgets (`RyokuLoadStrip`, `RyokuFirewallStatus`,
  `RyokuNetIndicator` from Loadout 2/3 of the brainstorming).
- Ryoku-shell distro shipping with `cornerStyle: 4` as the default.
