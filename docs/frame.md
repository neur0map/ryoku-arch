# The frame

The frame is the rounded border that hugs every display edge, and the surface
that everything grows out of: the centre pill, and the edge popouts (the mixer on
the left, power on the right). It is one continuous blob body. The border, the
pill, and every open popout share a single signed-distance field and **melt into
each other** through a smooth-minimum, so each reads as the frame swelling open,
never as a panel stacked on top.

## The blob field

The merge is real geometry, not layered translucency. It is a compiled Quickshell
plugin, `Ryoku.Blobs` (C++ scene-graph, SDF metaball shader), because the
smooth-min and the per-shape physics cannot be done in pure QML at this quality.
Like the Go binaries it **ships prebuilt**: built by `ryoku/shell/plugin/build.sh`
and installed onto the QML import path (`ryoku-shell` points `QML2_IMPORT_PATH`
there for the components it supervises), so the target builds nothing.

Four pieces, one field:

- `BlobGroup` the field itself. Holds the shapes, the body `color`, and
  `smoothing` (the blend radius: how far two shapes reach to fuse). Everything in
  one group is one surface.
- `BlobInvertedRect` the border. A full-bleed rect with a rounded rectangular
  hole; the hole is the window area, the leftover ring is the frame.
- `BlobRect` a body (the pill, or a popout). A rounded rect with per-corner radii
  and a velocity spring (`stiffness`, `damping`, `deformScale`) that squashes it
  as it moves.
- `BlobMaterial` the shader that sums the field and smooth-mins the shapes (up to
  16 per group), so overlaps fuse instead of stacking.

## One field, in the pill shell

The SDF field is per-process, so everything that must fuse has to live in one
scene and one `BlobGroup`. Ryoku hosts it inside the **pill shell**
(`quickshell/pill/shell.qml`), not a standalone config. Its overlay layer holds:

- a `BlobGroup` whose body `color` is `Theme.cardTop` (the shell card surface, the
  same token the island uses, so border + pill + popouts are one material);
- a `BlobInvertedRect` screen border, oversized by 50px so the outer edge clips
  off-screen and only the inner (window) edge shows. It lives in Hyprland's outer
  gap (`general:gaps_out`, set a touch larger than the border so tiles sit a
  sliver inside it), reserves no space, and retracts to nothing on fullscreen;
- the pill body as a `BlobRect` running from the screen top down through the pill,
  its neck fused into the top border (the island is the frame swelling open at
  top-centre);
- the edge popouts (see below).

A second `BlobGroup` (`islandGroup`) carries the music island, deliberately kept
out of the frame field so it never fuses the border. The pill draws no background
of its own; every state is just the blob growing.

## Edge popouts

A surface popout grows out of a vertical frame edge on hover and melts into the
border through the **same** group. They live in `quickshell/pill/popouts/`, one
file per popup:

- `Popout.qml` the reusable machinery: the blob body (a `BlobRect` in the shared
  group), a content slot, the pixel-perfect edge hover trigger, and the reveal. It
  tracks its content and extends a **neck** into the border, clamped to the body's
  own width so it retracts in lockstep and never snaps off as a flickering sliver.
  Opening is a curtain (a clip widens inward from the border, so fixed-size content
  reveals edge-first without resizing).
- `Mixer.qml` the left popout: brightness/vibrance/volume/mic ink-faders plus the
  DND and Keep-Awake chips.
- `Power.qml` the right popout: a vertical session column with Shutdown enlarged at
  the centre and press-and-hold on the destructive actions.

Content is a plain transparent `Item` that fills the popout; the blob behind it is
the surface, so painting a background would double it.

## The reveal

Open and close are **directional**:

- **Open** eases cleanly into place with the project morph curve
  (`cubic-bezier(0.16, 1, 0.3, 1)`), with no end-overshoot.
- **Close** uses a lightly-damped `SpringAnimation`, not a curve. A bezier cannot
  bounce against a flush (zero) close; its overshoot only clamps away invisibly.
  The spring melts the body fully into the border, then springs back a touch and
  settles, for the slight close bounce, while the resting state stays exactly
  flush.

Hover is **pixel-perfect to the frame**: the activation zone is exactly the border
thickness, sitting in the border with no inward overshoot, so it opens only when
the cursor is on the visible frame. An open popout keeps itself open through its
own `HoverHandler` until the pointer leaves both.

## Adding a popout

1. Add `quickshell/pill/popouts/Foo.qml`: a transparent `Item` (`anchors.fill:
   parent`, an `s` scale property) holding the content, using the pill's
   `Singletons` and components.
2. In `pill/shell.qml`, inside the overlay's blob field, add `Popout { group:
   blobGroup; frameThickness: 16; radius: 16; smoothing: 30; edge: "left"|"right";
   Foo {} }`.
3. Union the popout's `triggerX/Y/W/H` and `bodyX/Y/W/H` into the overlay input
   mask, so its edge and open body catch input while the rest stays click-through.
4. Trigger it by hover (built in) and, if it needs a keybind, route the
   `ryoku-shell` command to `togglePopout` rather than a centre surface.
