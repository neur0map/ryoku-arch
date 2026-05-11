# SecPulse OpenVPN Indicator (Bar Module)

Date: 2026-05-08
Status: Approved (pending implementation plan)

## Summary

Add a new bar module, `secPulse`, that surfaces the live OpenVPN connection state as a single icon in the right island of the topbar. The module sits alongside the existing System Tray (both toggleable independently from Settings, Bar, Modules) and reuses the state already published by `RyokuOpenVpn`. No new service, no new schema, no migration.

## Motivation

The deleted-last-week SecPulse tried to surface Tailscale, public IP, and listening sockets in one widget; it shipped tied to a now-removed bar style and got cut. The user still wants a small, focused security signal on the bar: did I remember to bring up my VPN. OpenVPN is the right anchor because it is the security feature the workstation positions around, and the service surface for it is already in place.

The widget keeps the SecPulse name as a deliberate seam: future signals (Tailscale, listening ports, public IP) can land in the same module without the indicator having to be renamed or relocated.

## Non-goals

1. No Tailscale, public IP, listening-sockets, or other state sources beyond OpenVPN. That overscope killed the previous SecPulse.
2. No popover, status card, or context menu in the widget itself. Click opens the right sidebar; the rich UI already lives in the OpenVPN tab there.
3. No SystemTray rename, no SNI host changes, no bluetooth filtering. The System Tray module is left untouched.
4. No new IPC handler, no new singleton service, no schema versioning.

## Architecture

Five files touched, one file new. Slot the widget into the same right-island region that hosts ShellUpdateIndicator and the existing SysTray. The widget binds straight to RyokuOpenVpn properties; the service has had everything we need since the OpenVPN sidebar tab was added.

```
shell/
  modules/
    bar/
      SecPulseIndicator.qml             NEW
      BarContent.qml                    EDIT (slot the indicator)
    settings/
      BarConfig.qml                     EDIT (Modules row + Bar settings text)
  services/
    RyokuOpenVpn.qml                    EDIT (one line: repoint bar gate)
  defaults/
    config.json                         EDIT (add bar.modules.secPulse default)
tests/
  bar-secpulse.sh                       NEW
```

The peer pattern is `shell/modules/bar/ShellUpdateIndicator.qml`. Match its structure: MouseArea root with hover and cursor wiring, a Rectangle pill for hover and press states, a single MaterialSymbol icon, color tokens declared once as `readonly property color`. Do not reinvent.

### State to icon mapping

The widget reads four properties on `RyokuOpenVpn` (already published, no changes needed): `transitioning`, `transitionTarget`, `activeProfile`, `activeIp`, `activeSince`, `openvpnInstalled`.

| Service state | MaterialSymbol text | fill | color token | Animation | Tooltip line |
|---|---|---|---|---|---|
| transitioning | sync | 0 | accentColor | RotationAnimation on rotation | "Connecting to {target}", "Switching {a} to {b}", or "Disconnecting" |
| activeProfile not empty (and not transitioning) | vpn_key | 1 | accentColor | none | "{activeProfile}, {activeIp}, since {activeSince}" |
| openvpnInstalled is false | vpn_key_off | 0 | Appearance.m3colors.m3error | none | "OpenVPN not installed" |
| else (disconnected, installed) | vpn_key_off | 0 | Appearance.colors.colSubtext | none | "VPN: not connected" |

`accentColor` follows the per-skin ternary cascade documented in ShellUpdateIndicator:

```qml
readonly property color accentColor:
    Appearance.angelEverywhere ? Appearance.angel.colPrimary
    : Appearance.ryokuEverywhere ? (Appearance.ryoku?.colAccent ?? Appearance.m3colors.m3primary)
    : Appearance.auroraEverywhere ? (Appearance.aurora?.colAccent ?? Appearance.m3colors.m3primary)
    : Appearance.m3colors.m3primary
```

Spinner is the same shape ShellUpdateIndicator uses for in-progress updates: a `RotationAnimation on rotation` running while `RyokuOpenVpn.transitioning` is true.

### Click and hover

| Interaction | Result |
|---|---|
| Left click anywhere on the icon | `GlobalStates.sidebarRightOpen = true` (matches the deleted SecPulseIndicator's pattern; user lands on whichever sidebar tab they had open last) |
| Hover | `StyledToolTip` with `extraVisibleCondition: root.containsMouse`, single line of text from the table above |
| Right click | No-op for now (reserved for a future menu; not in scope) |

`StyledToolTip` is the right primitive per ui-patterns. The information is single-line; `StyledPopup` would be overkill.

### Bar slot and visibility

In `BarContent.qml`, insert the indicator immediately after the existing `SysTray { ... }` block and before `TimerIndicator`. The right-island order becomes:

```
indicators row
SysTray
SecPulseIndicator
TimerIndicator
ShellUpdateIndicator
spacer (Layout.fillWidth)
Weather
```

Visibility is gated only on the module toggle:

```qml
SecPulseIndicator {
    visible: Config.options?.bar?.modules?.secPulse ?? true
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignVCenter
}
```

Do not gate on `useShortenedForm`. The widget is a single high-signal icon and stays useful at every bar width. SysTray gates on `useShortenedForm === 0` because it can balloon to many icons; SecPulse cannot.

### Settings UI

`BarConfig.qml`, the Modules section, currently has a row with a `SettingsSwitch` for System tray and a flex `Item` filler. Replace the filler with a sibling `SettingsSwitch`:

```qml
ConfigRow {
    uniform: true
    SettingsSwitch {
        buttonIcon: "shelf_auto_hide"
        text: Translation.tr("System tray")
        checked: Config.options?.bar?.modules?.sysTray ?? true
        onCheckedChanged: Config.setNestedValue("bar.modules.sysTray", checked)
    }
    SettingsSwitch {
        buttonIcon: "vpn_key"
        text: Translation.tr("SecPulse")
        checked: Config.options?.bar?.modules?.secPulse ?? true
        onCheckedChanged: Config.setNestedValue("bar.modules.secPulse", checked)
    }
}
```

The existing System Tray detail panel further down `BarConfig.qml` (pinned items, monochrome icons, debug item id) stays unchanged. SecPulse has no detail panel in this iteration; if future state sources need toggles, they get their own panel then.

### Service-side change

`shell/services/RyokuOpenVpn.qml` line 34 currently reads:

```qml
property bool barIndicatorEnabled: Config.options?.bar?.secPulse?.showOpenVpn ?? true
```

The `bar.secPulse` schema was deleted in commit `cb0d3907`; the optional-chained read is dead. Repoint the gate to the new module key:

```qml
property bool barIndicatorEnabled: Config.options?.bar?.modules?.secPulse ?? true
```

This keeps polling cost honest: the 5 second status poll and 30 second profile rescan stay gated on `barIndicatorEnabled || tabOpen`, so disabling the SecPulse module while the sidebar OpenVPN tab is closed yields zero polls. The `?? true` fallback covers user configs that have not yet seen the new key.

### Defaults

`shell/defaults/config.json`, under `bar.modules`, add the new key alphabetically near the existing entries:

```json
"secPulse": true
```

The runtime fallback `?? true` in `BarContent.qml`, `BarConfig.qml`, and `RyokuOpenVpn.qml` already handles legacy user configs that predate this key. No migration script is required: the key is purely additive, and adding it to defaults is the canonical way to pick up new bar modules. This matches how `taskbar`, `kanjiClock`, and `weatherIcon` were introduced.

### Tests

Add `tests/bar-secpulse.sh` mirroring the assertion shape of `tests/sidebar-openvpn.sh`. Required assertions:

1. `shell/modules/bar/SecPulseIndicator.qml` exists.
2. `shell/modules/bar/BarContent.qml` instantiates `SecPulseIndicator` and gates it on `bar.modules.secPulse`.
3. `shell/modules/settings/BarConfig.qml` exposes a SettingsSwitch bound to `bar.modules.secPulse`.
4. `shell/defaults/config.json` includes `bar.modules.secPulse` set to `true`.
5. `shell/services/RyokuOpenVpn.qml` reads `bar.modules.secPulse` (not the dead `bar.secPulse.showOpenVpn`).
6. `tests/topbar-removal-regression.sh` continues to pass: SecPulse is allowed; references to the deleted `RyokuSecPulse` service or `threeIsland/SecPulseIndicator` path remain forbidden.

Run: `bash tests/bar-secpulse.sh && bash tests/sidebar-openvpn.sh && bash tests/topbar-removal-regression.sh && fish shell/scripts/qml-check.fish`.

## Data flow

```
RyokuOpenVpn (singleton)
    activeProfile, activeIp, activeSince, transitioning,
    transitionTarget, openvpnInstalled
        |
        v
SecPulseIndicator (binds, no internal state)
    icon, fill, color, rotation, tooltip
        |
        v
User hover, click
    StyledToolTip text
    GlobalStates.sidebarRightOpen = true
```

The widget owns no state of its own. Every visible property is a Binding into `RyokuOpenVpn`. This is intentional: it lets the indicator and the sidebar tab stay in lockstep, and it keeps the polling-active gate honest (one source of truth for "is anyone watching").

## Error handling

There is essentially no failure mode local to this widget:

1. `RyokuOpenVpn` not installed in the QML import graph: would be a build break; caught by `qml-check.fish`.
2. `RyokuOpenVpn.openvpnInstalled === false`: rendered as the warning state ("OpenVPN not installed"). No crash, no broken icon.
3. User clicks while the sidebar layer-shell is unavailable (no display): `GlobalStates.sidebarRightOpen = true` is a no-op assignment; QML does not throw.
4. `Config.options.bar.modules.secPulse` missing in user config: `?? true` fallback shows the indicator. The migration story is "do nothing"; the runtime fallback is the migration.

## Risks and rollback

1. **Cluttered right island.** SecPulse adds one icon next to the existing tray and timer. If the bar feels crowded on small screens, mitigation is the per-module toggle the user already has from Settings, not a layout change.
2. **Per-skin color drift.** If a future skin lacks `colAccent`, the cascade falls through to `Appearance.m3colors.m3primary`. This is the same fallback pattern ShellUpdateIndicator uses; consistent risk profile.
3. **Polling gate regression.** Repointing `barIndicatorEnabled` to a new config key briefly resets the gate to its default (true) for users whose old config had explicitly set `bar.secPulse.showOpenVpn = false`. Acceptable: the old key was already dead at the schema level; nobody has a meaningfully different value there.

Rollback is a revert of the listed files plus deleting `shell/modules/bar/SecPulseIndicator.qml` and `tests/bar-secpulse.sh`. No persistent state is created on disk; no migrations to undo.

## Open questions resolved during brainstorming

| Question | Decision |
|---|---|
| Replace SystemTray, coexist, or repurpose? | Coexist as separate modules. |
| When is the icon visible? | Always visible when the module is on; four states (connected, transitioning, not installed, disconnected). |
| Reinvent the bar slot or follow the peer pattern? | Follow ShellUpdateIndicator.qml verbatim. Single icon, no hover popup beyond a tooltip. |
| Does click force the OVPN tab? | No. Open the sidebar; user lands on their last-selected tab. |
| Is a migration needed? | No. Purely additive default key, runtime fallback handles legacy configs. |
