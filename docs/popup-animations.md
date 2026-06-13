# Frame Popout Animations

Every Ryoku popup that emerges from the screen frame (the bar's inner edge, a
frame border, or one of the top-notch tabs) MUST animate as the frame itself
expanding. The panel's frame-side edge stays pinned at the frame from the first
rendered frame, and only the panel's size grows outward. Open and close begin
and end exactly at the frame, so the surface reads as the bar/notch stretching
into the panel and retracting back into it, never as a separate window that
appears in mid-air and then connects.

This is a hard contract for the shell's own surfaces and for plugin and
bar/frame additions. The reference adopters are the center dropdowns (island,
dashboard) and the plugin frame popouts (`FramePanelWrapper`).

## The rule

A frame popout MUST:

- Pin its frame-side edge at the frame from the first frame. For a top-edge
  surface the top stays at the bar's inner edge (or the notch); for a bottom
  edge the bottom stays there.
- Grow only its size. Height animates from `0` to full; width animates from the
  origin width (a notch or icon) to full when the surface has a narrower origin.
- Clip itself and hold its content at full size, top-anchored (or edge-anchored).
  The growing clip reveals the content; the content does not move or rescale.
- Drive open/close from a single `offsetScale` (`1` closed, `0` open) animated
  with `Anim { type: Anim.DefaultSpatial }`, so open and close are mirror images.
- Fuse to the frame with a blob neck (`PanelBg`) so the panel and the frame read
  as one continuous body.

A frame popout MUST NOT:

- Slide a full-size panel in from off-screen.
- Fade in or out with `opacity` tied to open progress.
- Center-zoom with a `scale` transform on the whole panel.
- Become visible at a fixed non-zero size before it has grown (a "popped slab").

## Why

A panel that slides or fades originates in mid-air: the motion starts away from
the frame and the fade hides where it came from, so it looks like an unrelated UI
appearing out of nowhere. Pinning the frame-side edge and animating only size
guarantees the open starts at the frame and the close ends at the frame. The blob
neck keeps the shape attached to the bar/notch the whole time, which produces the
"the notch is expanding" read instead of "a surface rose up to meet the notch."

## The two cooperating pieces

A correct frame popout is a wrapper (the panel's own box) plus a blob background
(`PanelBg`) that fuses it to the frame. Both are driven by the same `offsetScale`.

### 1. The wrapper (panel box)

Pin one edge, grow the rest from the origin, clip, hold content at full size.
Pattern from `shell/modules/island/Wrapper.qml` and
`shell/modules/dashboard/Wrapper.qml`:

```qml
// offsetScale: 1 = closed, 0 = open
property real offsetScale: shouldBeActive ? 0 : 1

// collapsedWidth is the origin width (the notch width); falls back to full so a
// surface with no narrow origin only grows in height.
property real collapsedWidth: 0
readonly property real startWidth: collapsedWidth > 0 ? collapsedWidth : implicitWidth

visible: offsetScale < 1
implicitWidth: content.implicitWidth || <fallback>
implicitHeight: content.implicitHeight
width: startWidth + (implicitWidth - startWidth) * (1 - offsetScale)
height: implicitHeight * (1 - offsetScale)   // grows 0 -> full, top pinned
clip: true

Behavior on offsetScale { Anim { type: Anim.DefaultSpatial } }

Loader {
    id: content
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top            // content is edge-anchored and full size
    active: root.shouldBeActive || root.visible
}
```

The wrapper is positioned by its parent (`Panels.qml`), which anchors it to the
frame edge (for top surfaces: `anchors.top: parent.top`, where `Panels` is inset
below the bar by `bar.thickness`). The wrapper never sets its own off-screen
start position.

### 2. The blob neck (`PanelBg` in `ContentWindow.qml`)

`PanelBg` is the metaball background that joins a panel to the frame field. Two
properties control how it attaches at a top-notch bar:

- `attachTop`: the blob reaches up behind the bar so it fuses with the thin top
  border instead of floating below the notches with a wallpaper gap above it.
  Set this on any top-edge panel.
- `pinReach`: keep that upward reach fully extended the whole time the panel is
  open, so the blob's top edge stays fused to the bar/notch from the first frame.
  Set this on surfaces that originate from the bar itself (the center dropdowns
  and the bar status-icon popouts), so they read as the notch/bar expanding
  straight down rather than a surface rising up to meet a static bar.

```qml
readonly property real maxReach: attachTop && bar.edge === "top" && !barFillsEdge
    ? barInsetTop - borderThickness : 0
property bool pinReach: false
readonly property real topReach: pinReach
    ? ((panel?.visible ?? false) ? maxReach : 0)        // pinned full while open
    : maxReach * (1 - (panel?.offsetScale ?? 0))        // grows with open progress
```

The pin is safe because at the open and close extremes the panel's own height is
`~0`, so the pinned neck is exactly the notch interior. Snapping it to full reach
coincides with the bar's notch (same surface color, same position), so nothing
pops; the clock and other notch content keep painting on top.

Whatever geometry a `PanelBg` (or its subclass) uses, gate **both** `implicitWidth`
and `implicitHeight` on `panel.visible` (the base `PanelBg` does this:
`panel.visible ? panel.width : 0`). A closed panel must contribute zero size. If
only the height is gated and the width is left non-zero, then when `visible` flips
false the pinned neck snaps to 0 and a width-by-zero-height rounded capsule lingers
at the bar edge as a 2-3px line that never merges away (the close flicker). If you
override the blob's `implicitWidth` or `x` (e.g. to track a clip), keep the
`panel.visible` gate.

## Variants

- **Center dropdowns (island, dashboard, settings/control-centre).** Origin is the
  center notch (the clock pill). `Panels.qml` passes `collapsedWidth: bar.islandWidth`
  (`BarWrapper.islandWidth` exposes `TopNotch.centerW`, the notch width). Width
  morphs notch to full, height `0` to full, top pinned at the bar inner edge.
  `PanelBg` uses `attachTop: true` and `pinReach: true`. Reads as the clock/notch
  pill expanding down. The settings panel (`shell/modules/controlcenter/Wrapper.qml`)
  is a glass `Rectangle` rather than a blob, so it holds that rectangle at full size,
  top-pinned and centred, and lets the morphing (clipping) root reveal it; it must
  NOT fade with `opacity` or slide in with `topMargin` (its previous close, which
  read as a separate window dropping away instead of retracting into the notch).
- **Top-right notifications.** `shell/modules/notifications/` hangs a card stack from
  the top-right. The WHOLE panel merges with the right frame: `Wrapper.qml` slides it
  out into the right border on close and emerges it from there on open, keyed on
  `hasPopups` (`Notifs.popups.some(n => !n.closed)`) and driven via
  `anchors.rightMargin` (`hasPopups ? 0 : -implicitWidth`) - NOT a `transform`, so the
  panel's real `x` moves and the blob (`notifsBg`, `x = panel.x`) travels with it
  instead of being left behind. `visible` is kept true through the slide
  (`hasPopups || anchors.rightMargin > -implicitWidth + 0.5`) so the close is not cut
  off. Combined with the container height collapse this retracts the panel into the
  top-right corner. The blob `notifsBg` uses `attachTop: true`, and because the notif
  wrapper has no `offsetScale`, the blob reach is tied to the panel height
  (`retractReach = min(maxReach, panel.height)`) so the neck shrinks with the stack on
  the last notification's collapse instead of leaving a full-width strip flashing at
  the corner. Do not let the reach stay pinned at `maxReach` here (no pill hides it).
  Per-card `x` stays reserved for the manual swipe-to-dismiss drag.
- **Plugin frame popouts and bar/frame additions.** Use
  `shell/modules/drawers/FramePanelWrapper.qml`. It already implements the
  contract: it pins to the manifest `edge` (`y: edge === "bottom" ? parent.height
  - height : 0`), grows `height: implicitHeight * (1 - offsetScale)`, clips, holds
  the plugin panel at full size, and binds its `transform` to the
  `PanelBg.deformMatrix`. A plugin authors only the panel content; the wrapper
  owns position, animation, and the blob deform.
- **Bar popouts (right-side status icons, tray menus, and the workspace activewindow peek).**
  They share one host and follow the same mechanism as the centre island/dashboard
  above. On a horizontal (top-notch) bar `shell/modules/bar/popouts/ClipWrapper.qml`
  morphs the box out of the notch it belongs to - width from the notch's width
  (`Wrapper.currentNotchWidth`) to full, height from `0` to full, centred on the notch
  (`Wrapper.currentCenter`, both set by the bar's `openPopout`) - and the close
  retracts back onto the notch footprint, so the end of the close IS the idle island.
  Three rules make the close land cleanly with no end-of-close flicker (the same three
  documented in `docs/ui-patterns.md` → *Top-notch popouts must collapse onto the idle
  island*):
  1. Visibility is `visible: offsetScale < 1`, NOT a geometry gate - the spatial easing
     overshoots past `1.0` on close, and a `width > 0 && height > 0` gate latches that
     degenerate overshoot frame as visible for one frame.
  2. The box width morphs down to the notch width on close (not height alone), so it
     never closes as a band wider than the island.
  3. The shared `popoutBg` reaches UP into the notch and stays pinned there
     (`attachTop: !isDetached`, `pinReach: !isDetached`), exactly like `islandBg`: the
     body retracts up into the notch and is hidden by the bar's notch pill (painted on
     top) as it vanishes, instead of pinching into a sliver in the open wallpaper gap
     below the notch. This is spill-free precisely because of rule 2 - the reaching-up
     strip is full width only while open (a bridge to the bar, like the island) and
     narrows to the notch width by the end. (There is no separate "neck" blob; that was
     a pre-morph workaround and is gone.)

  Horizontally the content is pinned in screen space at the fully-open position
  (`openX`) so the morphing box clips it in place rather than dragging it toward the
  notch, and the content-area x-clamp relaxes by `borderThickness × morphProg` because
  an edge island overlaps the frame's side-border stub. A vertical (sidebar) bar keeps
  its sideways away-axis grow and full-content blob unchanged; detached popouts
  (settings, window info) float centred and keep the default growing reach
  (`attachTop`/`pinReach` false).

## Adding a new frame-anchored popup

For a plugin, declare the surface in the manifest `frame` block (`edge`, `align`,
`activationWidth`, `activationHeight`); `FramePanelWrapper` loads the panel and
applies the whole animation contract for you. Author only the panel content and
its `pluginApi`/`screen` properties. Do not animate it yourself.

For a new built-in shell surface:

1. Build a wrapper that follows the wrapper pattern above: a single `offsetScale`,
   frame-side edge pinned, height (and width if it has a narrow origin) growing
   from the origin, `clip: true`, content at full size and edge-anchored.
2. Instantiate it in `Panels.qml` anchored to the frame edge. Pass
   `collapsedWidth: bar.islandWidth` only if it originates from the center notch.
3. Register a `PanelBg` for it in `ContentWindow.qml`. Set `attachTop: true` for a
   top-edge surface. Add `pinReach: true` if it originates from the bar itself (a notch or a bar icon).
4. Wire the deform: bind the wrapper's `transform` to that `PanelBg.deformMatrix`
   (see the `Matrix4x4` bindings in `ContentWindow.qml`).
5. Use `Anim { type: Anim.DefaultSpatial }` for `offsetScale` so it matches the
   other surfaces and respects the user's `appearance.anim.durations.scale`.

Do not introduce a second animation convention beside this one.

## Verification

Stills do not capture motion; verify the open and the close in slow motion.

```bash
cp ~/.config/ryoku/shell.json /tmp/shell.json.bak
python3 -c "import json;p='$HOME/.config/ryoku/shell.json';d=json.load(open(p));d['appearance']['anim']['durations']['scale']=9.0;json.dump(d,open(p,'w'),indent=2)"
sleep 4
ryoku-shell ipc drawers toggle island         # or: ipc drawers toggle dashboard
for i in $(seq 0 11); do grim -g "<region>" /tmp/f_$(printf %02d $i).png; sleep 0.3; done
cp /tmp/shell.json.bak ~/.config/ryoku/shell.json   # always restore the scale
```

Confirm in the frame sequence:

- The first visible frame is at the frame/notch, not below it.
- The frame-side edge stays put while the panel grows; nothing slides in.
- There is no opacity fade and no whole-panel zoom.
- The close mirrors the open back into the frame.

## Reference files

- `shell/modules/drawers/ContentWindow.qml`: `PanelBg`, `attachTop`, `pinReach`,
  `maxReach`, `topReach`, and the per-panel deform bindings.
- `shell/modules/drawers/Panels.qml`: where wrappers are anchored to the frame and
  `collapsedWidth` is passed.
- `shell/modules/drawers/FramePanelWrapper.qml`: the plugin frame popout host.
- `shell/modules/island/Wrapper.qml`, `shell/modules/dashboard/Wrapper.qml`: the
  center-notch wrapper pattern.
- `shell/modules/bar/BarWrapper.qml` (`islandWidth`) and
  `shell/modules/bar/TopNotch.qml` (`centerW`): the notch origin width.
- `shell/components/Anim.qml`: `Anim.DefaultSpatial` and the duration scale.
