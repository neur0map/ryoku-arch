# The frame

The frame is the rounded border that hugs every display edge, and the surface
everything grows out of: the module bar riding one edge, and every popout that
bar opens. It is one continuous blob body. The border and every open popout share
a single signed-distance field and **melt into each other** through a
smooth-minimum, so a popout reads as the frame swelling open at its trigger, never
as a panel stacked on top. The bar itself paints on top of that swollen frame, so
it stays visible and clickable while a popout is open.

## The blob field

The merge is real geometry, not layered translucency. It is a compiled Quickshell
plugin, `Ryoku.Blobs` (C++ scene-graph, SDF metaball shader), because the
smooth-min and the per-shape spring cannot be done in pure QML at this quality.
Like the rest of the desktop it **ships as a signed package** (`ryoku-blobs`):
built by `ryoku/shell/plugin/build.sh` and installed onto the QML import path
(`ryoku-shell` points `QML2_IMPORT_PATH` there for the components it supervises),
so the target builds nothing.

The plugin is a handful of types; everything in one `BlobGroup` is one fused
surface:

- **`BlobGroup`** the field. `color` (the body fill), `smoothing` (the blend
  radius: how far two shapes reach to fuse, default 32), an optional
  `borderColor` / `borderWidth` outline traced along the field's silhouette, and
  `shadowStrength` / `shadowSize` for a soft drop shadow. It owns the shapes and
  the one inverted rect.
- **`BlobShape`** the base every shape derives from (a `QQuickItem`, so it sizes
  and positions like any Item, via `x`/`y`/`width`/`height`/`implicitWidth`).
  Carries `group`, `radius`, and a read-only **`deformMatrix`**: the per-shape
  squash transform to hand to the content so it deforms *with* the blob
  (`transform: Matrix4x4 { matrix: someBlob.deformMatrix }`).
- **`BlobInvertedRect`** the border. A full-bleed rect with a rounded rectangular
  hole; the hole is the window area, the leftover ring is the frame. Per-edge
  thickness (`borderTop` / `borderBottom` / `borderLeft` / `borderRight`), so one
  edge can thicken (the bar band) while the others stay a hairline.
- **`BlobRect`** a body (a popout). A rounded rect with per-corner radii
  (`topLeftRadius` … `bottomRightRadius`; `-1` falls back to `radius`) and a
  **velocity spring** (`stiffness` 200, `damping` 16, `deformScale`) that squashes
  it along its travel and settles at rest. `exclude` lists sibling rects it must
  not fuse with.
- **`BlobMaterial`** the shader BlobGroup runs internally. Sums the field and
  smooth-mins the shapes (up to 16 per group) so overlaps fuse into one silhouette
  instead of stacking.

## One field, in the shell

The SDF field is per-process, so everything that must fuse lives in one scene and
one `BlobGroup`, hosted in the shell overlay (`quickshell/pill/shell.qml`). Per
monitor the overlay layer holds:

- a **`BlobGroup`** (`blobGroup`) whose `color` is the wallust-matched surface (or
  `Config.surfaceColor`), with `Wallust.border` / `1.5` as the silhouette outline,
  so the border and every popout are one material;
- a **`BlobInvertedRect`** screen border, oversized by 50px so its outer edge
  clips off-screen and only the inner (window) edge shows. It sits in Hyprland's
  outer gap (`general:gaps_out`, a touch larger than the border so tiles sit a
  sliver inside), reserves no space, and retracts on fullscreen. The bar's edge
  gets `frameBorder + barBand`, so the border swells into a band there; the other
  edges stay `frameBorder`. Turning `Config.frameEnabled` off collapses every edge
  to the 50px oversize, so no ring or shadow shows and a bar sits flush at the
  screen edge (the `frameBorder` value is kept for when it comes back);
- the **`Bar`**, drawn in the same scene above the popouts (no separate program,
  no seam), see `docs/bar.md`;
- the **popouts**, each a `BlobRect` in `blobGroup` (see below).

There is no longer a centre pill or a floating island: the bar is the resting
face, and every surface it used to host is a bar-edge popout.

## Bar-edge popouts

A popout grows out of the frame edge at its trigger and melts into the border
through the **same** group. They live in `quickshell/pill/popouts/`, one file per
popup, wrapped by the reusable `Popout.qml`:

- **`Popout.qml`** the machinery: the blob body (a `BlobRect` in the shared
  group), a content slot, and the reveal. Its edge-side corners are zeroed and a
  **neck** of the frame thickness plus smoothing reaches past the body into the
  border field, so smooth-min welds body and frame into one continuous edge: no
  separate rounded edge, no gap. `edge` picks the frame side; `alongCenter` slides
  the body along that edge to emerge from the triggering module (the bar hands it
  the module's centre); `openW` / `openH` track the content's implicit size, so
  the body melts to fit as content grows.
- The content files (`Mixer`, `Power`, `CalendarPopout`, `NetworkPopout`,
  `MediaPopout`, …) are plain transparent `Item`s that fill the popout; the blob
  behind them IS the surface, so painting a background would double it. Each takes
  an `s` scale and an `open` flag (`somePop.prog > 0.5`) that gates any live work
  (a scanner, a position poll) so a closed popout costs nothing.

Opening is a **curtain**: a clip widens inward from the border, so fixed-size
content reveals edge-first without ever reflowing. Open rides `Motion.spatial`
(the spring-overshoot curve); close eases out on `Motion.morph` so the body melts
flush into the border with no re-grow under a pointer that just left.

## Triggering a popout

Two paths, both routed through `shell.qml`:

- **Click / keybind**: a bar module (or a `ryoku-shell` IPC command) calls
  `togglePopoutAt(mon, name, center)`, which pins `popout`; the matching `Popout`
  is `pinned` and opens at `center`. Re-issuing the same one closes it.
- **Hover**: a module reports its hover and centre, and `setHoverPopout` drives
  the matching `Popout`'s `triggerHovered`; the body's own hover latch keeps it
  open while the pointer is on the panel, with a short grace so the pointer can
  cross the bar edge from the module to the body. The now-playing `MediaPopout` is
  the reference.

Input routing is the overlay window mask: the bar strip and every open popout
body are unioned into `barRegion`, so they catch input while the rest of the
screen clicks through. A keyboard popout (search / password field) instead clears
the mask to a full region so a backdrop press dismisses it, and takes keyboard
focus on demand so Escape closes it.

## The sidebars

Two full-height side panels melt out of the left and right frame edges, each
opened by pushing the cursor into that side's top corner. Both are `Popout`s in `fullSpan`
mode: where a normal popout insets from the frame and rounds its inner corners,
`fullSpan` makes a left/right body fill the frame top-to-bottom and fuse into the
top and bottom borders too. The blob overshoots both screen edges so its
silhouette outline clips off-screen (only the inner edge is drawn), reading as
the whole side of the frame swelling open with no gap at either end.

- **Left is Features, right is System.** The left sidebar
  (`popouts/SidebarFeatures.qml`) holds the Stash file board and leaves room for
  future feature panes; with a single pane its tab rail folds away. The right
  sidebar (`popouts/SidebarSystem.qml`) is the control centre: a 力 masthead
  (clock, date, weather) over the full `DeckControls` toggles, the screen-capture
  Tools and a Clipboard button (the `DeckTools` quick-action strip), and a volume
  fader, all above a tab rail that swaps the pane between the notification digest,
  the month calendar (reusing `Calendar`), the now-playing player, the weather
  forecast, and screen recording.
- Ryoku Settings' Shell section has a **Sidebar** tab: `sidebarLeftEnabled` /
  `sidebarRightEnabled` arm each corner, `sidebarLeftPanes` / `sidebarRightPanes`
  pick which panes each shows and their order, `sidebarClickless` opens on hover
  (else click), and `sidebarWidth` / `sidebarCornerSize` size the panels and their
  hit-regions.
- Each trigger is a small always-masked hit region at that side's top corner
  (`sidebarLeftCorner` / `sidebarRightCorner` in `shell.qml`). In hover mode the
  pointer has to reach the very corner (a few px, where it clamps when flung
  there), not just enter the region, so grazing the top frame never opens it; a
  short intent timer then arms the popout and the body's own hover
  latch (a `closeDelay` grace) holds it open until the pointer leaves; a bare
  `HoverHandler` lets a click fall through to the bar. In click mode a `TapHandler`
  on the corner toggles it instead.
- The `sidebarLeft` / `sidebarRight` IPC commands toggle them (`togglePopout`);
  `stash` and the file manager's `stashSend` jump the left sidebar straight to its
  Stash pane. Content components take `panes` (the enabled pane keys), `pane` (the
  shell-owned current pane) and report taps back via `paneSelected`; `topInset` /
  `botInset` clear a top/bottom bar, since the blob runs edge to edge.

## Adding a popout

1. Add `quickshell/pill/popouts/Foo.qml`: a transparent `Item` (`anchors.fill:
   parent`, with `s` and `open` properties), holding the content built from the
   pill's `Singletons` and components. Report `implicitWidth` / `implicitHeight`
   so the blob melts to fit.
2. In `pill/shell.qml`, inside the overlay's blob field, add a `Popout`:

       Popout {
           id: fooPop
           group: blobGroup
           frameThickness: overlay.barVisibleH
           radius: Config.frameRadius
           smoothing: Config.frameSmoothing
           edge: overlay.barPos
           hoverOpen: false
           alongCenter: root.popoutCenter
           s: overlay.s
           active: !overlay.monFullscreen
           pinned: root.popout === "foo" && root.popoutMon === overlay.modelData.name
           openW: fooContent.implicitWidth
           openH: fooContent.implicitHeight
           Foo { id: fooContent; s: overlay.s; open: fooPop.prog > 0.5 }
       }

   For a hover popout, replace `pinned:` with `triggerHovered:` and drive it from
   the bar's hover (see `MediaPopout` and `mediaPop`).
3. Union the popout's `bodyX/Y/W/H` (and `triggerX/Y/W/H` if it uses an edge
   hover band) into `barRegion`, so its open body catches input while the rest
   stays click-through. Forgetting this makes the body render but ignore the
   pointer.
4. Trigger it: route a `ryoku-shell` command to `togglePopout`, and/or wire a bar
   module's click (`popoutRequested`) or hover (`hoverPopoutRequested`).
