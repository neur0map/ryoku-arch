# Tailscale and Trayscale Integration

Date: 2026-05-08
Status: Approved (pending implementation plan)

## Summary

Surface Tailscale connection state in two places that share one data source: the OpenVPN sidebar tab gains a Tailscale status card with an "Open Trayscale" action, and the topbar SecPulse indicator becomes unified-multi-state, reflecting OpenVPN and Tailscale together with a richer hover tooltip. A new `RyokuTailscale` singleton owns the polling and parse; both surfaces bind to it.

## Motivation

The user runs both OpenVPN (security workstation positioning) and Tailscale (mesh access). Today the bar surfaces only OpenVPN, and the OpenVPN sidebar tab is the natural home for VPN-class controls but lacks any Tailscale presence. Trayscale is the GTK4 GUI that ships with the install (`install/config/tailscale.sh` enables `tailscaled.service` at install time and `trayscale` is in `install/ryoku-aur.packages`), but launching it from the keyboard or bar requires either knowing the binary name or going through System Tray, which is itself unreliable after shell restarts.

The deleted-last-week SecPulse failed because it tried to surface Tailscale + public IP + listening sockets + multi-provider VPN detection in one widget. This iteration stays Tailscale-and-OpenVPN-only.

## Non-goals

1. No public IP, listening-sockets, multi-provider VPN detection, or any state source beyond OpenVPN and Tailscale. Those killed the previous SecPulse.
2. No exit-node selector, no tailnet routing UI, no Tailscale connect/disconnect controls in this shell. Trayscale exists for that; we launch it, we do not replicate it.
3. No new `bar.modules.*` toggle. `bar.modules.secPulse` (added in commit `32520bf2`) covers Tailscale visibility on the topbar too. Tailscale-only or OpenVPN-only topbar views are a future feature if requested.
4. No SystemTray re-host fix for `trayscale` (the SNI-after-shell-restart issue covered earlier this session). Out of scope.
5. No two-icon split mode in SecPulse. The user explicitly picked unified-icon-with-rich-tooltip.
6. No new umbrella service. The deleted `RyokuSecPulse` umbrella conflated unrelated state sources; we keep `RyokuOpenVpn` and `RyokuTailscale` as separate singletons.

## Architecture

Eight file changes, two new files. The new singleton is the only piece of new logic; the two QML surfaces are bindings into it.

```
shell/
  services/
    RyokuTailscale.qml                                 NEW   singleton, polls tailscale status --json
    qmldir                                             EDIT  register the singleton
  modules/
    sidebarRight/
      BottomWidgetGroup.qml                            EDIT  drive RyokuTailscale.tabOpen, parallel to the existing RyokuOpenVpn.tabOpen Binding
      CompactSidebarRightContent.qml                   EDIT  same, for the compact sidebar layout
      openvpn/
        TailscaleStatusCard.qml                        NEW   sidebar status card + Open Trayscale action
        OpenVpnTab.qml                                 EDIT  slot the new card and a not-installed stub
    bar/
      SecPulseIndicator.qml                            EDIT  read both services, two-line tooltip
install/
  ryoku-aur.packages                                   EDIT  re-add trayscale (was added in commit 7f617c79, removed during the secPulse purge)
tests/
  sidebar-tailscale.sh                                 NEW   static asserts: service, qmldir, card, slot, packages
  bar-secpulse.sh                                      EDIT  add assertion for RyokuTailscale binding in topbar
```

### Boundaries

| Unit | Responsibility | Depends on |
|---|---|---|
| `RyokuTailscale.qml` | Poll `tailscale status --json`, expose typed properties, expose `openTrayscale()` action | `tailscale` binary, `Quickshell.Process`, `Config.options.bar.modules.secPulse` for polling gate |
| `TailscaleStatusCard.qml` | Render Tailscale state inside the OVPN sidebar tab | `RyokuTailscale` |
| `SecPulseIndicator.qml` | Render combined OVPN + Tailscale state on the bar | `RyokuOpenVpn`, `RyokuTailscale`, `GlobalStates` |
| `OpenVpnTab.qml` | Slot Tailscale surfaces above OVPN surfaces | `TailscaleStatusCard.qml`, `RyokuTailscale` |

Each unit owns one purpose and exposes a stable interface. The card and indicator can be understood without reading service internals; the service can be tested without reading either consumer.

## Service: `RyokuTailscale`

Singleton, registered in `shell/services/qmldir` as `singleton RyokuTailscale 1.0 RyokuTailscale.qml`. Mirrors the shape of `shell/services/RyokuOpenVpn.qml`: gated polling via `Process` + `Timer`, no internal state machine beyond what `tailscale status --json` already exposes.

### Public surface

```qml
property bool installed       // tailscale binary present
property bool connected       // BackendState == "Running" && Self.Online === true
property bool transitioning   // BackendState in {"Starting", "NoState"} (Tailscale has no "Stopping" state)
property string hostname      // Self.HostName
property string tailIp        // first IPv4 in Self.TailscaleIPs, "" if none
property string relay         // Self.Relay (DERP region code), "" if direct
property string exitNode      // first peer with ExitNode === true, "" if none
property bool tabOpen: false  // driven by parent sidebar layout, see Polling section

function openTrayscale(): void
```

The full `BackendState` enum from upstream Tailscale: `NoState`, `NeedsLogin`, `NeedsMachineAuth`, `Stopped`, `Starting`, `Running`. The transitioning set is `Starting` (visible briefly during `tailscale up`) plus `NoState` (transient at daemon startup). `Stopped`, `NeedsLogin`, and `NeedsMachineAuth` all collapse to `connected = false, transitioning = false`. Disconnect goes Running to Stopped instantaneously, no transitioning frame needed.

### Polling

The singleton runs three processes:

1. One-shot `presenceProc` at `Component.onCompleted`: `command -v tailscale >/dev/null 2>&1 && echo y || echo n` to set `installed`.
2. Periodic `statusProc` every 30 seconds, gated on the same boolean as `RyokuOpenVpn`:
   ```
   readonly property bool _gateActive: (Config.options?.bar?.modules?.secPulse ?? true) || tabOpen
   ```
   `tabOpen` is driven by the sidebar's parent layout. Two files own this responsibility today (one per sidebar shape) and BOTH need a parallel Tailscale binding:
   - `shell/modules/sidebarRight/BottomWidgetGroup.qml:121-124` already has a `Binding { target: RyokuOpenVpn; property: "tabOpen"; value: root.currentTabType === "openvpn" && !root.collapsed }`. Add a sibling `Binding` with `target: RyokuTailscale` and the same `value`.
   - `shell/modules/sidebarRight/CompactSidebarRightContent.qml:704-707` has the analogous binding for the compact layout. Add a sibling `Binding` there too.
   Both must mirror the OVPN gate exactly: the Tailscale card lives inside the OVPN tab, so the gate condition is identical. Polling uses `tailscale status --json`.
3. The status reader applies the same parse the deleted `RyokuSecPulse` used (verified in commit `cc80dd8c^:shell/services/RyokuSecPulse.qml`):
   ```
   const data = JSON.parse(raw)
   const self = data?.Self ?? {}
   const state = data?.BackendState ?? ""
   connected     = (state === "Running") && (self.Online === true)
   transitioning = state === "Starting" || state === "NoState"
   hostname      = self.HostName ?? ""
   tailIp        = (self.TailscaleIPs && self.TailscaleIPs.length > 0) ? self.TailscaleIPs[0] : ""
   relay         = self.Relay ?? ""
   const peers   = data?.Peer ?? {}
   let exit = ""
   for (const k in peers) {
       if (peers[k]?.ExitNode === true) {
           exit = peers[k]?.HostName ?? ""
           break
       }
   }
   exitNode = exit
   ```

### Action

```qml
function openTrayscale(): void {
    Quickshell.execDetached(["trayscale"])
}
```

`execDetached` is the existing pattern (`RyokuOpenVpn.qml` uses it for `systemctl start/stop` and `ryoku-openvpn-import`). No PATH heroics: `trayscale` is at `/usr/bin/trayscale` from the AUR package; if it is missing, `execDetached` silently fails, and the card's "Open Trayscale" action is gated on `installed` to avoid that.

### Why not extend `RyokuOpenVpn`

These are independent VPN technologies with different control planes (`systemctl` versus `tailscale up`/`tailscaled`), different state shapes (profile-list versus mesh-membership), and different failure modes. Conflating them produced the umbrella `RyokuSecPulse` that got deleted. Two singletons stay focused; both consumers compose them.

## Sidebar: `TailscaleStatusCard.qml`

Peer file to `OpenVpnStatusCard.qml`, in the same directory (`shell/modules/sidebarRight/openvpn/`). Authoring it in that folder keeps the cohesive "VPN-ish things" layout and matches the existing import surface (`import qs.modules.sidebarRight.openvpn` is already in `BottomWidgetGroup.qml`).

### Visual shape

A `Rectangle` card matching `OpenVpnStatusCard`'s padding and rounding:

```
TailscaleStatusCard
  RowLayout (header)
    MaterialSymbol "lan"
    StyledText "Tailscale" (bold)
    Rectangle (status pill: "connected" accent / "off" subtext / "starting..." accent)
  ColumnLayout (detail, visible: connected)
    StyledText hostname
    StyledText tailIp + ", via " + relay
    StyledText "exit: " + exitNode (visible: exitNode.length > 0)
  RowLayout (action)
    DialogButton (buttonText: "Open Trayscale")
      enabled: RyokuTailscale.installed
      onClicked: RyokuTailscale.openTrayscale()
```

Plus a single `MouseArea` behind the content area (not the action button) so clicking anywhere on the card body also calls `openTrayscale()`. Same target, two affordances. The `MouseArea`'s `cursorShape` is `Qt.PointingHandCursor` only when `RyokuTailscale.installed` is true.

`DialogButton` is the canonical Material-3 button primitive in `shell/modules/common/widgets/DialogButton.qml`; its label property is `buttonText` (verified at the OpenVpnStatusCard Disconnect button, lines 142-146). The `lan` MaterialSymbol has codebase precedent (`Network.qml`, `GlobalActions.qml`); `vpn_key` stays reserved for OpenVPN-class profile-based VPNs to keep the visual language distinct.

### Not-installed stub

A minimal `Rectangle` peer to the existing OpenVPN-not-installed stub (`OpenVpnTab.qml:49-79`):

```
visible: !RyokuTailscale.installed
text: "Tailscale not installed"
hint: "Install with: pacman -S tailscale"
```

### Tab order in `OpenVpnTab.qml`

```
ColumnLayout (existing)
  TailscaleNotInstalledStub      NEW, visible: !RyokuTailscale.installed
  TailscaleStatusCard            NEW, visible: RyokuTailscale.installed
  OpenVpnNotInstalledStub        existing
  OpenVpnStatusCard              existing
  Profiles section               existing
  OpenVpnLogTail                 existing
```

Reads top-to-bottom from "is my mesh up" to "OpenVPN profile management".

## Topbar: `SecPulseIndicator` rework

The widget keeps its peer-pattern shape (MouseArea root, Rectangle pill, single MaterialSymbol). State sources expand to read both services; the icon represents combined VPN state.

### State derivations

```qml
readonly property bool _anyTransitioning: RyokuOpenVpn.transitioning || RyokuTailscale.transitioning
readonly property bool _anyConnected:     (RyokuOpenVpn.activeProfile.length > 0) || RyokuTailscale.connected
readonly property bool _bothMissing:      !RyokuOpenVpn.openvpnInstalled && !RyokuTailscale.installed
```

### Icon mapping

| Condition | Icon | fill | color | Animation |
|---|---|---|---|---|
| `_anyTransitioning` | `sync` | 0 | accentColor | `RotationAnimation on rotation` |
| `_anyConnected` (and not transitioning) | `vpn_key` | 1 | accentColor | none |
| `_bothMissing` | `vpn_key_off` | 0 | `Appearance.m3colors.m3error` | none |
| else (both off, at least one installed) | `vpn_key_off` | 0 | `Appearance.colors.colSubtext` | none |

### Tooltip text

A single `StyledToolTip` whose text is two lines, one per VPN. Each line is one of:

| Service state | Line |
|---|---|
| OVPN connected | `OpenVPN: {activeProfile}, {activeIp}, since {activeSince}` |
| OVPN transitioning to target | `OpenVPN: Connecting to {transitionTarget}...` |
| OVPN transitioning (disconnect) | `OpenVPN: Disconnecting...` |
| OVPN transitioning (switch) | `OpenVPN: Switching {activeProfile} to {transitionTarget}...` |
| OVPN off, installed | `OpenVPN: off` |
| OVPN missing | `OpenVPN: not installed` |
| Tailscale connected | `Tailscale: {hostname}, {tailIp}, via {relay}` (append `, exit {exitNode}` if non-empty) |
| Tailscale transitioning | `Tailscale: starting...` |
| Tailscale off, installed | `Tailscale: off` |
| Tailscale missing | `Tailscale: not installed` |

Lines are joined with a literal newline. `StyledToolTip.text` is a multi-line string. `StyledToolTipContent.qml:67` already sets `wrapMode: Text.Wrap` on the underlying StyledText, so long lines wrap inside the tooltip surface without manual layout work.

### Click

Unchanged: `onClicked: GlobalStates.sidebarRightOpen = true`. No tab-forcing. The user lands on whichever sidebar tab they had open last; if it was the OVPN tab, both surfaces (Tailscale card top, OVPN content below) are visible.

## Data flow

```
tailscale daemon (tailscaled.service)
    |  tailscale status --json (every 30s, gated)
    v
RyokuTailscale (singleton)
    properties: installed, connected, transitioning, hostname, tailIp, relay, exitNode
    action:     openTrayscale()
    |                                |
    v                                v
SecPulseIndicator (topbar)     TailscaleStatusCard (sidebar)
    + RyokuOpenVpn                  status pill, detail rows, "Open Trayscale" button
    icon, color, tooltip            click on body or button -> RyokuTailscale.openTrayscale()
    click -> sidebar opens
```

The card and the indicator never share a parent and never communicate directly. Both react to changes in `RyokuTailscale` properties. The "same icon" intent translates to both consumers using the same MaterialSymbol family: `lan` for Tailscale-specific glyphs in the sidebar; `vpn_key` family for combined-state on the topbar.

## Error handling

There is essentially no failure mode local to this design:

1. `tailscale` binary missing: `installed` is `false`; both surfaces render the not-installed branch.
2. `tailscaled.service` not running: `tailscale status --json` exits non-zero or returns a `BackendState` that is neither Running nor a transitioning value; `connected` is `false`, `transitioning` is `false`, the indicator shows the off state, the sidebar card shows "off".
3. `tailscale status --json` returns malformed output: the JSON parse `try`/`catch` already handles this in the deleted-RyokuSecPulse pattern; we copy that, falling all properties back to defaults.
4. `trayscale` binary missing when the user clicks the action: the action is gated on `installed` (which checks `tailscale`, not `trayscale`). If `trayscale` is missing despite `tailscale` being present, `execDetached` silently no-ops. Acceptable: install scripts ship them together; a missing `trayscale` indicates user-side modification.
5. Polling while sidebar OVPN tab is open and `tailscaled` becomes unhealthy: the next poll updates state; no special unhealthy state needed.

## Tests

`tests/sidebar-tailscale.sh` (new) asserts:

1. `shell/services/RyokuTailscale.qml` exists.
2. `shell/services/qmldir` registers the singleton: `singleton RyokuTailscale 1.0 RyokuTailscale.qml`.
3. The singleton parses `BackendState` and reads `Self.HostName`, `Self.TailscaleIPs`, `Self.Relay`.
4. The singleton exposes `openTrayscale` as a function.
5. The singleton declares `tabOpen` as a property.
6. `shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml` exists.
7. `OpenVpnTab.qml` instantiates `TailscaleStatusCard` and a `Tailscale not installed` stub gated on `RyokuTailscale.installed`.
8. `BottomWidgetGroup.qml` and `CompactSidebarRightContent.qml` each contain a `Binding { target: RyokuTailscale; property: "tabOpen"; ... }` driver.
9. `install/ryoku-aur.packages` contains `trayscale`.

`tests/bar-secpulse.sh` (edit) gains:

10. `SecPulseIndicator.qml` reads both `RyokuTailscale.connected` and `RyokuTailscale.transitioning`.
11. `SecPulseIndicator.qml` tooltip text contains both `OpenVPN:` and `Tailscale:` markers.

Run: `bash tests/sidebar-tailscale.sh && bash tests/bar-secpulse.sh && bash tests/sidebar-openvpn.sh && bash tests/topbar-removal-regression.sh && fish shell/scripts/qml-check.fish`.

## Risks and rollback

1. **Polling cost while sidebar is open.** Adds one `tailscale status --json` per 30 seconds. Tailscale's CLI is fast; cost is negligible.
2. **Tooltip too dense at small bar font sizes.** Resolved: `StyledToolTipContent.qml` already sets `wrapMode: Text.Wrap` on the underlying StyledText, so long lines wrap inside the tooltip surface automatically. Lines stay short anyway.
3. **Topbar-only Tailscale visibility couples to `bar.modules.secPulse`.** A user who turns SecPulse off loses both OVPN and Tailscale at-a-glance. Acceptable: that is what "the SecPulse module is off" means. Future refinement can split.
4. **`RyokuTailscale` polling continues while user is in any tab of the right sidebar, not just OVPN.** Gate is `barIndicatorEnabled || tabOpen`; `tabOpen` is OVPN-tab specific. Acceptable since the SecPulse module is on by default and the bar gate is the dominant condition.

Rollback is a revert of the listed files plus deleting the two new QML files and the new test. No persistent state is created on disk; no migrations to undo.

## Open questions resolved during brainstorming

| Question | Decision |
|---|---|
| One unified topbar icon or two side-by-side? | Unified, with rich two-line tooltip. |
| Where in the OVPN sidebar tab? | Top, above the existing OpenVpnStatusCard. |
| Service shape? | New `RyokuTailscale` singleton; do not extend `RyokuOpenVpn` and do not revive the umbrella `RyokuSecPulse`. |
| Tailscale icon glyph? | `lan` (codebase precedent in `Network.qml` and `GlobalActions.qml`); `vpn_key` family stays as the combined-state glyph on the topbar. |
| New module toggle? | No. `bar.modules.secPulse` covers both. |
| Migration? | No. Purely additive properties; runtime fallbacks already accept missing keys. |
| Where does the `tabOpen` binding live? | Two parallel `Binding` blocks: one in `BottomWidgetGroup.qml`, one in `CompactSidebarRightContent.qml`. Same condition as the existing `RyokuOpenVpn.tabOpen` Bindings in those files. |
| Tooltip wrap behavior? | Resolved: automatic via `Text.Wrap` already set in `StyledToolTipContent.qml:67`. |
| Does `trayscale` need a package-list addition? | Yes. `install/ryoku-aur.packages` does not currently contain `trayscale` (it was added in commit `7f617c79` and removed during the secPulse purge). Re-add to fix new installs. The user's local install still has the binary because pacman cache hasn't garbage-collected it. |
