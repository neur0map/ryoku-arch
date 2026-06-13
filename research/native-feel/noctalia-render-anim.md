# Noctalia: GPU render, animation, blob chrome, blur/transparency

Source root: `~/Work/noctalia-shell/src`. Noctalia is a from-scratch C++/Wayland
compiled shell with its own GLES2 scene-graph renderer. All UI is drawn by hand-written
GL programs; there is **no QML/QtQuick scenegraph**.

---

## 1. Rendering model: retained scene graph + per-node GL programs, vsync-driven

**Retained scene graph.** A tree of `Node` subtypes is the single source of truth:
`RectNode`, `TextNode`, `GlyphNode`, `ImageNode`, `ScreenCornerNode`, `EffectNode`,
`GraphNode`, `SpinnerNode`, `AudioSpectrumNode`, `WallpaperNode` (the `switch` in
`render_context.cpp:325-487`). Each node stores a style struct and is marked dirty on
mutation, e.g. `rect_node.h:12-18` (`setStyle` → `markPaintDirty()` only if changed).

**Frame walk.** `RenderContext::renderScene` (`render_context.cpp:177-221`) calls
`m_backend->beginFrame`, recursively `renderNode(...)`, then `endFrame`. `renderNode`
(`render_context.cpp:303-547`) multiplies a `Mat3` transform and a scalar opacity *down*
the tree (`worldTransform = parentTransform * nodeLocalTransform`,
`effectiveOpacity = parentOpacity * node->opacity()`, lines 311-312), applies scissor
clips, then dispatches each node to a GL draw call on `RenderBackend`
(`GlesRenderBackend`): `drawRect`, `drawImage`, `drawScreenCorner`, `drawEffect`, etc.
Opacity is folded into each style's alpha before the draw (`style.fill.a *= effectiveOpacity`,
line 329). Children are rendered in `zIndex` order with a fast-path that skips sorting/
allocation when already ordered (lines 489-512), zero per-frame heap churn in the common case.

**Frame scheduling = Wayland frame callbacks (vsync-paced), not a timer.**
- A surface requests the next frame inside `render()` via `wl_surface_frame`
  (`surface.cpp:847,861-870`).
- The compositor's `wl_callback` "done" lands in `Surface::handleFrameDone`
  (`surface.cpp:251-269`): it computes a wall-clock `deltaMs` and calls
  `queueFrameWork(true, deltaMs)`.
- The epoll-style main loop (`main_loop.cpp:281-656`) is a single `poll()` over the
  Wayland fd + every `PollSource`. After dispatch it drains queued work:
  `Surface::drainPendingFrameWork()` then `Surface::drainPendingRenders()`
  (`main_loop.cpp:617-637`).
- `processQueuedFrameWork` (`surface.cpp:978-1026`) ticks the animation manager, runs the
  prepare-frame/layout callback, then `queueRenderIfNeeded()`.

**Render only on change.** `queueRenderIfNeeded` (`surface.cpp:1028-1034`):
```
const bool invalidated = m_sceneRoot && (paintDirty() || layoutDirty());
const bool animating = m_animationManager && m_animationManager->hasActive();
if (m_redrawRequested || invalidated || animating) queueRender();
```
When idle the frame loop *stops* (`surface.cpp:1025` comment "Frame loop stops here when
idle. Restarted by requestRedraw()."). Node mutations call back into `requestRedraw`/
`requestLayout` via the invalidation callback wired in `setSceneRoot`
(`surface.cpp:362-376`). So the shell is event-driven: 0% GPU at rest, vsync-locked when
animating.

**Why this beats a QML scenegraph for "smoothness":** (a) one tight GL pass draws the
entire UI with premultiplied-alpha SDF primitives, no QtQuick batching/atlas/sync
overhead, no JS engine on the render path; (b) animations advance on a real wall-clock
delta (see §2) so a fixed duration stays correct even when the compositor delivers sparse
frame callbacks (`animation_manager.cpp:138-142`); (c) dirty-tracked retained tree means a
hover/animation touches only the affected node's alpha and re-renders in microseconds;
(d) the loop never busy-spins and never renders a frame that changed nothing.

---

## 2. Animation engine: `AnimationManager` (tested by `tests/animation_manager_test.cpp`)

The test includes `render/animation/animation_manager.h` + `motion_service.h`
(`animation_manager_test.cpp:1-2`). It is **time-driven, value-interpolating**, not a
keyframe/property system.

**Declaration.** `animate(from, to, durationMs, easing, setter, onComplete, owner)`
(`animation_manager.h:21-34`). Three flavors: `animate` (scaled by motion speed, respects
reduce-motion), `animateUnscaled`, `animateTimer` (real elapsed time, for timeouts not
visuals). Each becomes an `Entry{id, owner, respectMotionEnabled, Animation}`
(`animation.h:19-29`: startValue/endValue/durationMs/startedAt/easing/setter/onComplete).

**Tick.** `AnimationManager::tick` (`animation_manager.cpp:125-166`) runs each entry off
the steady_clock:
```
const float wallElapsedMs = duration<float,milli>(now - anim.startedAt).count();
float t = anim.durationMs > 0 ? wallElapsedMs / anim.durationMs : 1.0f;
... easedT = applyEasing(anim.easing, t); value = start + (end-start)*easedT;
anim.setter(value);          // pushes value into the scene node
```
Completed callbacks are deferred (collected then run after the erase) so an `onComplete`
that starts a new animation can't invalidate the iterator (lines 126-128,156-165).

**Easing curves** (`animation.cpp:5-46`): Linear, EaseInQuad, EaseOutQuad, EaseInOutQuad,
EaseOutCubic, EaseInOutCubic, EaseOutBack (overshoot, `c1=1.70158`). **Durations**
(`style.h:7-9`): `animFast=100ms`, `animNormal=200ms`, `animSlow=400ms`.

**Global motion control.** `MotionService` singleton (`motion_service.cpp`): `setEnabled`
+ `setSpeed` (clamped 0.05–4.0, line 42). Disabling fires `reduceMotion()` which snaps
live anims to target over `kReducedMotionDurationMs=1.0f` (`animation_manager.cpp:97-116`).
Effective duration = `durationMs / motion.speed()` (line 51).

**Lifetime safety.** Animations carry an `owner` raw pointer; `cancelForOwner` is called
from `Node`'s destructor so an animation can never outlive the node it mutates
(`animation_manager.h:38-40`, `animation_manager.cpp:118-123`).

**Where bar/panel open-close is driven.** A surface owns an `AnimationManager`
(`surface.h:110`, ticked in `processQueuedFrameWork`, `surface.cpp:995-996`).
- Panel open (attached to bar): `m_animations.animate(reveal 0→1, animNormal,
  EaseOutCubic, applyAttachedReveal, owner=clipNode)` (`panel_manager.cpp:1405-1408`).
- Panel close: `reveal →0, animNormal, EaseInOutQuad` (`panel_manager.cpp:890-901`);
  detached close `animFast` (905).
- Detached open scale 0.95→1.0: `animNormal, EaseOutCubic` (`panel_manager.cpp:1788-1791`,
  and `applyDetachedReveal` scales the scene root 0.95→1.0, comment lines 1387-1404).
- Bar reveal/hide opacity: `EaseOutCubic` show / `EaseInQuad` hide, `animNormal`
  (`bar.cpp:1910-1914,1970-1974`); first-show slide `animSlow, EaseOutCubic`
  (`bar.cpp:2106-2110`).

---

## 3. The "blob" look: SDF rounded rect + outer shadow + concave bar-attach corners

**Shadow geometry (the bleed).** `popup_chrome::computeGeometry`
(`popup_chrome.cpp:31-52`) grows the surface by a "bleed" margin so the soft shadow has
room: bleed = `kBlurRadius(12) + directional offset + 2px safety` (`shadow.cpp:11-22`,
`popup_chrome.cpp:41-44`). The popup's Wayland offset is shifted to keep the *content*
anchored while the surface is larger (`adjustedOffsetX/Y`, lines 54-82). The input region
is set to just the content rect, not the shadow (`setContentInputRegion`, lines 91-93).

**Shadow node.** `addShadow` (`popup_chrome.cpp:95-116`) adds a `RectNode` at zIndex −1
with `shadow::style` (`shadow.cpp:24-41`): fill = black × `shadow.alpha × backgroundOpacity`,
`softness = kBlurRadius(12)`, `outerShadow = true`, plus a `shadowCutoutOffset`.

**All shape + shadow + AA is one GPU fragment shader**, `RectProgram`
(`rect_program.cpp:32-400`):
- `rounded_rect_distance` = per-corner-radius signed distance field
  (`rect_program.cpp:64-78`).
- `shape_distance_with_corner` adds **concave corners** (lines 87-213), this is what makes
  the panel's bar-side edge curve *into* the bar (the "blob" fillet) rather than a plain
  rounded rect.
- Anti-aliasing: `coverage_for` (lines 276-283) uses `smoothstep` over an AA window;
  axis-aligned edges snap to a ±0.5px pixel-grid window (no semi-transparent edge leakage),
  curved corners widen the window by `aa = max(softness, 0.85)` (line 310).
- **Outer shadow path** (lines 319-337): `shadow_outer_coverage = 1-smoothstep(-aa,aa,
  shadowDistance)` gives the soft falloff; a `cutout_mask` punches a hole where the content
  sits so the shadow is a ring, with an optional second `shadow_exclusion` cutout for an
  adjacent surface (e.g. the bar). Output is premultiplied alpha.
- Borders are drawn in the same pass as a disjoint ring vs fill (lines 358-398), so a
  translucent fill never sits on an opaque border backplane.

**Attached "grows out of the bar" effect.** `attached_panel_context.h` defines, per bar
edge, the corner topology: bar-side corners `Concave`, away-side `Convex`
(`attached_panel_context.h:31-63`), a `logicalInset` (65-81), and an animated `bulgeRadius`
that "ramps to cornerRadius as the bulges slide into view near the end of the open
animation" (comment lines 23-26). The reveal itself is a **clip node** (`setClipChildren(true)`,
`panel_manager.cpp:1717-1723`) whose content node slides; `applyAttachedReveal`
(`panel_manager.cpp:1328-1372`) resizes the clip and slides content with the eased progress.

**Screen corners.** Separate layer-shell surfaces, one per physical corner per output
(`screen_corners.cpp:83-163`). `ScreenCornerProgram` (`screen_corner_program.cpp:31-68`)
draws a **superellipse**: `shape = pow(nx,exp) + pow(ny,exp) - 1`, AA via
`smoothstep(-aa,aa,shape)` where `aa` scales with pixel scale (lines 56-61), fills the
anti-corner wedge with the surface color to round the display's physical corners.

---

## 4. Transparency & blur: two independent mechanisms

**(a) Compositor backdrop blur (the real one) via `ext_background_effect`.**
`Surface::setBlurRegion` (`surface.cpp:499-525`) lazily creates an
`ext_background_effect_surface_v1` and calls `set_blur_region(region)`, the **compositor**
blurs whatever is behind the translucent surface; the shell does no blur work and pays no
shader cost. `clearBlurRegion` tears it down (lines 777-783). The region is shaped to match
the visible blob and kept "in lockstep with what is actually on screen" during the reveal:
`panel_manager.cpp:1496-1570` builds strips from `m_attachedRevealProgress` and clips them.
Requires compositor support (`hasBackgroundEffectBlur()`, line 500); otherwise transparency
shows the raw desktop unblurred.

**(b) In-shell separable Gaussian (for textures, not arbitrary backdrop).**
`BlurProgram` (`blur_program.cpp:21-43`) is a **fixed 81-tap (-40..40) separable Gaussian**,
`sigma = radius/2`, taps beyond `u_radius` skipped. `BlurCache` (`blur_cache.cpp:7-64`)
ping-pongs a target and scratch framebuffer `rounds` times (horizontal then vertical pass
per round, lines 46-54), multi-pass iterated Gaussian (stronger blur with more rounds),
**not dual-kawase**. Used to pre-blur captured textures (backdrop/wallpaper), invoked via
`GlesRenderBackend::drawFramebufferBlur` (`gles_render_backend.cpp:552-561`).

**How opacity composites.** Opacity flows top-down in `renderNode` (`effectiveOpacity`,
§1) and is baked into every style alpha before the draw; shaders emit premultiplied alpha
(`gl_FragColor = vec4(rgb*a, a)`, e.g. `rect_program.cpp:335,354,398`).

**How a "transparency" value flows into the render.** `barConfig.backgroundOpacity` (a
0..1 config value) becomes the bar background fill alpha:
`style.fill = colorForRole(ColorRole::Surface, instance.barConfig.backgroundOpacity)`
(`bar.cpp:1873`, also 2130). `colorForRole(role, alpha)` multiplies the role color's alpha
(`palette.cpp:61-65`). Lower opacity ⇒ lower fill alpha ⇒ blurred desktop shows through the
blur region. So the slider is *just* a fill-alpha multiplier on the surface role color, it
"feels like nothing" without (a) an active blur region behind it and (b) a visibly different
desktop behind the bar.

---

## 5. How theme colors reach the renderer

A single global `Palette palette` of 16 `Color` fields keyed by `ColorRole`
(`palette.h:11-28,70-108`). Access is `colorForRole(role)` / `colorForRole(role, alpha)`
(`palette.cpp:22-65`) and `resolveColorSpec(ColorSpec{role|fixed, alpha})`
(`palette.cpp:94-98`), a `ColorSpec` lets a widget bind to a *role* or a fixed color
plus an alpha multiplier. `ThemeService` calls `setPalette(p)` (`palette.cpp:111`), which
no-ops if unchanged and otherwise fires the `paletteChanged()` `Signal<>`
(`palette.h:129-131`). Controls subscribe in their constructor and, on emit, re-apply
role-derived colors to their scene-node styles (e.g. `RoundedRectStyle.fill`), which marks
the node paint-dirty → triggers a redraw. `lerpPalette` (`palette.h:133-135`) interpolates
palettes field-by-field so theme switches **cross-fade** via an animation driving `t`.
`theme/color.cpp` is the HSL/hex/ARGB math (`fromHex`, `toHsl`, `fromHsl`, `shiftHue`,
`adjustSurface`) used to *derive* palettes upstream.

---

## What makes open/close feel native here

1. **Vsync-locked, change-only rendering.** Frames are driven by `wl_surface.frame`
   callbacks and only emitted when a node is dirty or an animation is active; the loop goes
   fully idle otherwise (`surface.cpp:1028-1034,1025`). No tearing, no idle wakeups.
2. **Wall-clock animation timing.** `t = (now - startedAt)/duration` (not accumulated
   frame deltas) keeps a 200ms open *exactly* 200ms even under sparse/janky frame delivery
   (`animation_manager.cpp:138-142`).
3. **Tuned curves + short durations.** Opens use `EaseOutCubic`/`EaseOutBack` (decelerate /
   slight overshoot), closes `EaseInOutQuad`/`EaseInQuad`; 100/200/400ms tiers
   (`style.h:7-9`).
4. **The panel physically grows out of the bar.** Animated concave bar-side corners +
   bulgeRadius + a clip-node reveal make the popup look attached to the chrome, not a
   floating rectangle (`attached_panel_context.h`, `panel_manager.cpp:1328-1408`).
5. **GPU SDF shapes + soft shadow + AA in one pass**, premultiplied alpha, so translucent
   blobs and their soft shadows are crisp at any radius/scale (`rect_program.cpp`).
6. **Compositor-side backdrop blur** kept region-locked to the animating shape, so
   transparency reads as real frosted glass (`surface.cpp:499-525`,
   `panel_manager.cpp:1496-1570`).
7. **Cheap, lifetime-safe per-property tweens** that snap correctly under reduce-motion and
   global speed control (`motion_service.cpp`, `animation_manager.cpp:97-116`).

---

## Portable to ryoku (QML / QtQuick)

**Maps cleanly to QML (no shaders needed):**
- **Time-correct, curve-tuned transitions.** QML `Behavior`/`NumberAnimation`/
  `PropertyAnimation` already use wall-clock time; mirror Noctalia's tiers (100/200/400ms)
  and curves (`Easing.OutCubic` open, `Easing.InOutQuad`/`Easing.InQuad` close,
  `Easing.OutBack` for a tasteful overshoot). This is the single highest-leverage,
  lowest-cost change.
- **Global motion service.** A `MotionService` singleton exposing `enabled` + `speed`,
  with every `duration:` bound to `Style.animNormal / motion.speed` and a reduce-motion
  path that sets durations→1ms, directly portable (`motion_service.cpp`).
- **Grows-out-of-the-bar reveal.** A `Clip{ clip:true }` wrapper whose child slides +
  scales from the bar edge, with corner radii animated from 0→full as it opens, reproduces
  the attached blob feel in pure QML (`panel_manager.cpp:1328-1408`,
  `attached_panel_context.h`). Animate the popup's content from the bar edge, not a fade.
- **Transparency that actually reads.** Make the bar/panel background a role color with an
  alpha multiplier (`colorForRole(Surface, backgroundOpacity)` → QML `Qt.rgba(c.r,c.g,c.b,
  c.a*opacity)`), AND ensure a blur sits behind it (see below). The slider feeling like
  "nothing" is the missing backdrop, not the alpha.
- **Role-based theming with cross-fade.** A palette singleton of named roles + a
  `paletteChanged` signal that re-applies colors; animate a `lerpPalette` `t` for smooth
  theme switches (`palette.cpp`, `lerpPalette`).
- **Soft drop shadow + screen corners.** QtQuick already has `MultiEffect`/
  `DropShadow`/layer effects and rounded `Rectangle`; rounded screen corners can be 4 small
  layer-shell windows each masked by an `OpacityMask`/`Canvas` superellipse, no custom GL
  required.

**Requires GPU shaders Noctalia hand-wrote, harder/limited in QML:**
- **Real backdrop blur** is *not* shader work in Noctalia: it delegates to the compositor
  via `ext_background_effect`. ryoku should prefer the same protocol if its compositor
  supports it (Hyprland blur on layer rules, or quickshell's blur), rather than trying to
  sample the framebuffer behind a QML item (QtQuick can't read the backdrop). This is the
  one feature that most defines "frosted glass" and is best solved at the compositor level.
- **Concave-corner SDF blobs with sub-pixel AA** (`rect_program.cpp:87-213`), QML rounded
  rects don't do concave fillets; approximate with a `ShaderEffect` (a small GLSL/RHI SDF
  shader is feasible in QtQuick) or pre-baked corner images. Full fidelity needs a shader.
- **Ringed shadow with a content cutout / second-surface exclusion**
  (`rect_program.cpp:319-337`), QML drop-shadow effects don't cut out the occluded region;
  acceptable to drop, but a `ShaderEffect` would be needed for exact parity.
- **Multi-round separable Gaussian on captured textures** (`blur_cache.cpp`), only needed
  if ryoku blurs its own wallpaper/backdrop textures; QtQuick `MultiEffect.blur` covers most
  cases without writing the kernel.
