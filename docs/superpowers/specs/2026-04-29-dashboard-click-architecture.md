# Dashboard click-routing architecture

> Living memo. Re-read this *before* touching `Dashboard.qml`'s `mask`,
> `visible`, or `WlrLayershell.layer`, or the `WlrLayershell.layer`
> binding on `TopBar.qml`. The "dashboard closes when I click anything
> inside it" bug has resurfaced multiple times under different root
> causes; below is the full set of pieces that have to line up.

## Surfaces involved

| Surface | Layer | Visibility binding | Notes |
|---|---|---|---|
| `Frame` | `Bottom` | always | Decorative cutout. Yields to fullscreen. |
| `TopBar` | **dynamic**: `Popups.dashboardVisible ? Overlay : Top` | always | On `Top` it yields to fullscreen apps (screensaver, video). Promotes to `Overlay` while the dashboard card is on screen so the bar's pill paints above the card's top `notchHeight` strip. |
| `Dashboard` | `Top` | `Popups.dashboardOpen \|\| card.visible` | Surface unmaps entirely when the dashboard is fully closed; only mapped during open animation, while open, and during close animation. |
| `PopupDismiss` | `Top` | `Popups.anyOpen \|\| (screenRecord && !recording)` | Full-screen mask with cutouts for the bar's notch slots; clicks in the masked area call `Popups.closeAll()`. |
| `ConfirmDialog` | `Overlay` | `confirmOpen \|\| confirmRunning` | Stays in `hyprctl layers` even when `visible=false` on this Quickshell version - Quickshell appears not to unmap it. Treat its input region as effectively absent when `visible=false`. |

## How a click inside the dashboard reaches QML handlers

1. Click coordinate `(x, y)`.
2. Wayland routes the event to the topmost mapped surface whose **input region** covers `(x, y)`.
3. If `(x, y)` is in the bar's 32px-tall strip at the top of the screen, the bar grabs the click - its `TapHandler` runs `Popups.closeAll(); Popups.dashboardOpen = !old` and the dashboard closes. **This is by design** for the bar's pill, but it also means clicks on the bar's notch area visually overlap the dashboard's top strip, and the bar wins.
4. Outside the bar strip, the next candidate is `Dashboard`. Its mask (`Region { item: card }`) covers exactly the visible card geometry. If the click is inside, QML hit-tests `card → DashHome → ...` and a child `MouseArea` / `TapHandler` runs.
5. If the click is **outside the card mask but inside the dashboard window**, it falls through to `PopupDismiss`, which calls `closeAll()`. **This is by design** - clicks on transparent dashboard window space close the dashboard.

If clicks "everywhere" close the dashboard, exactly one of:
- (a) the dashboard surface isn't mapped when you expect it to be, so all clicks fall through to PopupDismiss;
- (b) the dashboard surface is mapped but its input region (mask) doesn't cover the visible card, so clicks fall through;
- (c) the dashboard surface is below PopupDismiss in stacking order, so PopupDismiss catches first;
- (d) something inside DashHome calls `Popups.closeAll()` or sets `Popups.dashboardOpen = false` from a click.

## What works (current implementation)

```qml
PanelWindow {
    visible: windowVisible
    property bool windowVisible: false

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (Popups.dashboardOpen) { closeTimer.stop(); windowVisible = true }
            else                      { closeTimer.restart() }
        }
    }
    Timer {
        id: closeTimer
        interval: Theme.motionExpandDuration + 50
        onTriggered: windowVisible = false
    }

    mask: Region { item: maskProxy }
    Item {
        id: maskProxy
        x: card.x; y: card.y
        width: card.width
        height: card.visible ? card.height : -1
    }

    WlrLayershell.layer: WlrLayer.Top

    Item { id: card; visible: root.expandScale > 0; ... }
}
```

- `windowVisible` is a manual flag, not a binding to `card.visible`.
  Connections sets it true on open, a Timer flips it false ~360 ms +
  buffer after close. **Don't** replace this with a direct binding like
  `visible: Popups.dashboardOpen || card.visible` - see tombstone
  below; that pattern desyncs the Wayland input region after a rapid
  remap.
- The mask reads from `maskProxy`, not directly from `card`. The proxy
  shadows `card`'s `x/y/width` and forces `height: -1` when the card is
  hidden - Quickshell's Region treats negative height as an empty
  region, so clicks fall through cleanly when the dashboard is gone.
- `WlrLayershell.layer: Top` on the dashboard, dynamic on TopBar (see
  below). Don't put the dashboard on `Overlay`.

## Tombstones - what does NOT work

These have been tried in this order and broke clicks each time. Don't
reintroduce them without reading the corresponding hypothesis:

### `mask: Region { item: card.visible ? card : null }`
Looks right. Isn't. When the binding initially evaluates with
`card.visible == false`, `item` is `null`; Quickshell installs an
"empty / undefined" Wayland input region. When `card.visible` later
flips to `true`, the binding re-evaluates and `item` becomes `card`,
**but the surface's input region does not refresh** - it stays at
whatever was first installed. End state: dashboard mapped, but no input
ever reaches its surface. Every click bypasses to PopupDismiss → close.

### Explicit geometry conditional on visibility
```qml
mask: Region {
    x: card.x
    y: card.y
    width:  card.visible ? card.width  : 0
    height: card.visible ? card.height : 0
}
```
Also broken. Same symptom as above. Why explicit `width`/`height` on a
`Region` without `item:` doesn't latch correctly is unclear (possibly
the same install-once issue), but the empirical answer is: when
combined with the dashboard surface being permanently mapped, the
0×0 → real-size transition does not propagate to the Wayland input
region. Don't bother debugging it; just unmap the surface instead.

### Permanently-mapped surface with any conditional mask
This is the meta-pattern: **a permanently mapped Dashboard surface +
"empty mask while closed" is the wrong architecture**. Every other
PanelWindow in the shell that has a "shown / not shown" state
(`PopupDismiss`, intended `ConfirmDialog`, etc.) binds `visible:` and
lets Quickshell unmap the layer-shell surface. The Dashboard had been
the lone permanently-mapped exception, and that's where these bugs
live. Don't go back.

### `visible: Popups.dashboardOpen || card.visible` (direct binding)
Tried after the conditional-mask attempts. `hyprctl layers` confirmed
the surface unmaps when closed. But the user reported clicks inside
the dashboard still close it after a second open/close cycle.
Hypothesis: when Quickshell unmaps then immediately remaps the
layer-shell surface (which happens during `Popups.closeAll(); Popups.dashboardOpen = next`
on a pill tap), the `mask` value at the moment of remap doesn't get
re-pushed as the new surface's `wl_surface.set_input_region`. The
result is a mapped surface with no input region - every click falls
through to PopupDismiss → closeAll. Use the manual `windowVisible`
flag + Timer pattern instead: it gives the surface a stable lifetime
window per open/close cycle, with no rapid remap.

## Hyprland event triggers in PopupDismiss

`PopupDismiss.qml` listens to `Hyprland.onRawEvent` and calls
`Popups.closeAll()` for `workspace`, `activemonitor`, `activespecial`,
`openwindow`. Verified empirically (April 2026) that
`hyprctl keyword monitor <name>,<res>@<hz>,...` does **not** fire any
of those events - only `windowtitle` / `activewindow` - so the
`PowerProfile` refresh-rate switch is safe to invoke while the
dashboard is open. If you add a power-profile action that does fire one
of those events (e.g., a workspace dispatch), guard it with a
short-lived `_modeChangeInFlight` flag and skip the `closeAll()` while
the flag is set.

## Bar dynamic layer

`TopBar.qml` flips its layer on `Popups.dashboardVisible`:
- **Top** (default): bar yields to fullscreen apps (screensaver, video,
  games). Without this, fullscreen content is covered by a 32px black
  strip - the bug that prompted introducing the dynamic layer.
- **Overlay** while dashboard is on screen: bar paints above the
  dashboard surface so the pill keeps painting over the card's top
  `notchHeight` strip during open and close.

`Popups.dashboardVisible` is driven by `Dashboard.qml`'s
`Binding { target: Popups; property: "dashboardVisible"; value: card.visible }`
so the bar holds the `Overlay` position through the entire close
animation, then drops back to `Top` once the card has fully retracted.

## Debug recipe (when this bug returns)

1. `hyprctl layers` with the dashboard closed. Expected: only `TopBar`
   (32px tall) on level 2; no Dashboard surface listed. If Dashboard is
   listed despite being closed → `visible:` binding is wrong.
2. `hyprctl layers` with the dashboard open. Expected:
   - level 2: `Dashboard` (1280x480) and `PopupDismiss` (1280x800).
   - level 3: `TopBar` (1280x32) (promoted) + whatever Overlay surfaces.
   If TopBar is still on level 2 → `Popups.dashboardVisible` binding
   broke.
3. Tail Hyprland events:
   `socat -u UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock -`
   while clicking. If `closeAll` fires, look for `workspace`,
   `activemonitor`, `activespecial`, `openwindow` events triggered by
   the click side-effects.
4. Verify the QML binding evaluated correctly: add
   `console.log("dashboard visible binding:", visible)` to
   `Dashboard.qml`'s `onVisibleChanged` to confirm the surface is
   actually mapping when expected.
5. Check `services/home/*.qml`, `services/PowerMenu.qml`, and any new
   button code for `Popups.closeAll()` or `Popups.dashboardOpen = false`
   side effects you might have inherited or added inside DashHome.
