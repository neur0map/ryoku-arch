# Online Research: native-feel & smoothness techniques for a quickshell shell

Scope: external/primary-source context to help ryoku (quickshell/QML) feel as native and
smooth as noctalia-shell (native C++/Wayland) and end-4 dots-hyprland (quickshell). Every
claim cites a URL. Quotes are short paraphrases/excerpts of the cited source.

---

## 1. noctalia-shell: philosophy & why it's a native C++/Wayland shell

Source: README, https://github.com/noctalia-dev/noctalia-shell/blob/main/README.md
(raw: https://raw.githubusercontent.com/noctalia-dev/noctalia-shell/main/README.md)

- **One cohesive shell, not a stack of panels/scripts.** "the UI, rendering, configuration,
  and IPC model are designed as one cohesive shell instead of a collection of unrelated
  panels and scripts." Motivation: separate bar/launcher/notifd/lockscreen "makes a complete
  desktop feel fragile and hard to keep visually consistent."
- **Renderer: native Wayland + OpenGL ES, NO Qt/GTK.** "built directly on Wayland and OpenGL
  ES with no Qt or GTK dependency." Deps confirm it: `libglvnd`, `libEGL/GLES`, `cairo pango
  harfbuzz`, `wayland-protocols`, i.e. it owns its own GL scene-graph/text stack rather than
  riding a toolkit. (This is the structural reason it can feel "native": no QtQuick
  scene-graph overhead, custom shaders incl. blur/rounded-corners per the task brief.)
- **Smoothness/long-session levers it ships:** `jemalloc` "recommended but optional. It
  reduces memory fragmentation in long-running sessions", relevant to perceived sluggishness
  over time. Vendored Material Color Utilities + Luau for scripted widgets (config/theming is
  first-class, not bolted on).
- **Propagation model:** "TOML configuration with hot reload, GUI-managed overrides … and IPC
  for runtime control" + "Direct Wayland integration for layer-shell, session lock, idle …
  fractional scaling." So changes propagate via file hot-reload AND socket IPC, not restart.
- Scope is deliberately a *shell* (bars/panels/launcher/notifications/lock/OSD/wallpaper),
  leaving WM/tiling to the compositor, same boundary ryoku should respect.
- Project site: https://noctalia.dev/ ; docs: https://docs.noctalia.dev/v5/ .

**Portable to ryoku:** ryoku can't swap QtQuick for a custom GL renderer, but it can copy
noctalia's *design stance*: unify config + IPC + theming as one model; make every setting
propagate live (hot-reload/IPC, never restart); consider jemalloc-style memory hygiene for the
quickshell process; lean on the compositor for blur/corners rather than re-implementing in QML.

---

## 2. end-4 / illogical-impulse dots-hyprland: design, matugen workflow, animation, perf

Stack: Hyprland + Quickshell UI + matugen Material-You color generation; config at
`dots/.config/quickshell/ii`. Overview: https://deepwiki.com/end-4/dots-hyprland and
https://deepwiki.com/end-4/dots-hyprland/5-theming-and-customization

- **Material-You / matugen workflow.** matugen extracts a Material 3 palette from the current
  wallpaper and propagates it across the shell AND to Qt/GTK/terminal apps; supports dynamic
  light/dark. https://deepwiki.com/end-4/dots-hyprland/5.1-material-you-color-system
  Native Qt/GTK theming is done via Kvantum/kdeglobals so apps match the shell (per task brief).
- **Reload model:** colors apply by regenerating templates then "Restart Quickshell
  (Ctrl+Super+R) to apply" for some changes; most settings live in the in-shell settings GUI.
  https://ii.clsty.link/en/ii-qs/03config/ (config dir = `dots/.config/quickshell/ii`).
- **Animation approach, codified M3 curves (HIGH VALUE, directly portable).** end-4 defines a
  single `Appearance.qml` singleton with an `animationCurves` table using `Easing.BezierSpline`
  cubic curves and fixed durations, then every component references it. Raw:
  https://raw.githubusercontent.com/end-4/dots-hyprland/main/dots/.config/quickshell/ii/modules/common/Appearance.qml
  Concrete values it ships:
  - `expressiveFastSpatial` `[0.42,1.67,0.21,0.90,1,1]` @ **350ms**
  - `expressiveDefaultSpatial` `[0.38,1.21,0.22,1.00,1,1]` @ **500ms**
  - `expressiveSlowSpatial` `[0.39,1.29,0.35,0.98,1,1]` @ **650ms**
  - `expressiveEffects` `[0.34,0.80,0.34,1.00,1,1]` @ **200ms**
  - `standard` `[0.2,0,0,1,1,1]`, `standardAccel` `[0.3,0,1,1,1,1]`, `standardDecel`
    `[0,0,0,1,1,1]`; `emphasizedAccel` `[0.3,0,0.8,0.15,1,1]`, `emphasizedDecel`
    `[0.05,0.7,0.1,1,1,1]` (the spatial overshoot >1 on the expressive curves is what reads as
    "springy/native").
  - Animations are exposed as reusable `Component { NumberAnimation { duration/easing... } }`
    objects (e.g. `animation.elementMove` @ 500ms BezierSpline) so widgets share one motion language.
- **Transparency done right (why ryoku's slider "feels like nothing").** end-4 derives a
  *wallpaper-aware* transparency: `autoBackgroundTransparency` = quadratic of wallpaper vibrancy
  `y = 0.5768x² − 0.759x + 0.2896`, clamped 0–0.22, and composites layers with
  `ColorUtils.solveOverlayColor`/`transparentize` per layer (Layer0..Layer4). i.e. transparency
  is a *composited multi-layer system tied to real blur behind it*, not a single opacity on one
  rectangle. (Same Appearance.qml file as above.)

**Portable to ryoku:** adopt the single-source `animationCurves`/`animation` singleton pattern;
make transparency a layered, blur-backed system (slider feels real only when there's actual
compositor blur behind the surface, see §4); keep matugen-style palette→template propagation.

---

## 3. quickshell: performance, animation & layer-shell guidance; jank causes

Source: quickshell FAQ, https://quickshell.org/docs/v0.3.0/guide/faq/
Architecture patterns, https://deepwiki.com/quickshell-mirror/quickshell/9.3-architecture-patterns-and-best-practices
Qt Quick perf, https://doc.qt.io/qt-6/qtquick-performance.html
KDAB QML tips, https://www.kdab.com/10-tips-to-make-your-qml-code-faster-and-more-maintainable/

- **Process-per-widget is an anti-pattern.** "Using a process per widget will use significantly
  more memory than using a single process." (FAQ) → consolidate `Process` usage.
- **Loader / LazyLoader for load/unload.** "use Loaders … create objects only when needed, and
  destroy them when not needed." Use `Loader` for `Item`-derived, `LazyLoader` for non-Item.
  (FAQ "Reduce memory usage" / "Show widgets conditionally".) Conditionally swap a Loader's
  `sourceComponent` instead of keeping both trees alive. NOTE the trade-off: re-instantiating a
  Loader on every open causes churn/stutter, for hot popups prefer keeping the tree and
  toggling `visible`/opacity; reserve Loader unloading for genuinely cold/heavy surfaces.
- **Opaque vs transparent window surface.** "If a window is created with an opaque background
  color, Quickshell will use a window surface format that is opaque … to reduce the amount of
  processing the gpu must do." If you toggle bg between opaque/transparent you must set
  `QsWindow.surfaceFormat` opaque=false. (FAQ "My window should not be opaque") → declare
  transparency intent once; don't flip opaque/transparent at runtime.
- **Shadows:** use `RectangularShadow` for rect/rounded-rect/circular shadows; only fall back to
  the heavier `MultiEffect` (shadowEnabled) for arbitrary shapes. (FAQ "Add a drop-shadow") →
  MultiEffect/blur per-widget is expensive; avoid for simple cards.
- **Rounded windows = transparent square window + inner rounded Rectangle** (FAQ). Watch
  QTBUG-137166: a `transparent` Rectangle whose `border` is touched turns everything beneath
  invisible, work around with `border.width: 0`.
- **Lists:** `Repeater`+`RowLayout/ColumnLayout` for short lists; `ListView` (delegate
  recycling) for long/scrolled lists. (FAQ "Make a list of widgets")
- **General QML jank causes (Qt/KDAB):** heavy/!cheap property bindings re-evaluated often;
  binding loops; per-frame JS in bindings; not using `Image.sourceSize` (over-decoding images);
  animating layout/anchors instead of `x/y/scale/opacity`; overuse of `Layer`/effects; clipping;
  software vs GPU rendering. Prefer animating transform/opacity (composited) over geometry;
  cache static content with `layer.enabled` only where it actually reduces overdraw.

**Portable to ryoku:** audit for process-per-widget; keep hot popups resident and toggle
visibility (animate opacity/scale, not anchors); set surfaceFormat transparency once; replace
ad-hoc MultiEffect shadows with RectangularShadow; verify `sourceSize` on all images; hunt
binding loops/expensive bindings (the likely cause of "weak/janky" animations under load).

---

## 4. Native-feel techniques on Wayland for a quickshell shell

### 4a. Backdrop blur: compositor (Hyprland) vs QML
**The native path is Hyprland layer rules, NOT QML blur.** The quickshell author confirms it:
"how do you make transparent PanelWindows blurred in hyprland?? … see layer rules in the
hyprland wiki.", outfoxxed, https://github.com/quickshell-mirror/quickshell/issues/24

Working layer-rule reference (incl. outfoxxed's own quickshell setup):
https://github.com/hyprwm/Hyprland/discussions/12748 and end-4's rules
https://deepwiki.com/end-4/dots-hyprland/4.1-window-rules-and-layer-rules
- A quickshell `PanelWindow` shows up as a layer-shell surface; its namespace (e.g.
  `quickshell:overview`, or a custom `WlrLayershell.namespace`) is what you match.
- outfoxxed's rules: `layerrule = blur, shell:bar` / `layerrule = ignorezero, shell:bar` /
  `layerrule = blur, shell:notifications` / `layerrule = ignorealpha 0.1, shell:notifications`.
- end-4's: `blur` + `ignorealpha 0.5` + `dimaround` on `launcher`; `blur`+`ignorealpha 0.69` on
  `notifications`; `xray 1` globally (blur samples the wallpaper, not windows behind).
- **Launchers/overviews must be FAST → disable layer animation:** `layerrule = noanim,
  quickshell:overview` (and walker/selection/overview/osk/hyprpicker). Compositor open/close
  anim on a transient surface is a common source of "laggy popup" feel.
- `ignorezero`/`ignorealpha N` make blur ignore fully/near-transparent pixels so only the card
  region blurs (no rectangular halo). `dimaround` adds the modal scrim cheaply.

This is why ryoku's transparency slider "does nothing": with no compositor blur layerrule on the
surface's namespace, lowering opacity just reveals raw wallpaper/windows with no frosted effect.
QML `MultiEffect` blur can fake it but is per-frame-GPU-expensive and doesn't sample windows
behind the layer, the layerrule path is both cheaper and more native.

### 4b. Material 3 motion: easing curves + standard durations (ms)
Spec: https://m3.material.io/styles/motion/easing-and-duration/tokens-specs (JS-only page).
Exact cubic-beziers (material-web reference impl):
https://github.com/material-components/material-web/blob/main/internal/motion/animation.ts
- `STANDARD` `cubic-bezier(0.2, 0, 0, 1)`
- `STANDARD_ACCELERATE` `cubic-bezier(0.3, 0, 1, 1)`
- `STANDARD_DECELERATE` `cubic-bezier(0, 0, 0, 1)`
- `EMPHASIZED` `cubic-bezier(0.3, 0, 0, 1)` (note: M3 "emphasized" is officially a 2-part
  spline; this is the single-curve approximation)
- `EMPHASIZED_ACCELERATE` `cubic-bezier(0.3, 0, 0.8, 0.15)`
- `EMPHASIZED_DECELERATE` `cubic-bezier(0.05, 0.7, 0.1, 1)`

Durations + which curve to pair (Flutter/material_design M3Motion tokens):
https://pub.dev/documentation/material_design/latest/material_design/M3Motion-class.html
- `standard` = **300ms** (medium2) + standard, element stays on screen.
- `standardIncoming` = **250ms** (medium1) + standardDecelerate, entering.
- `standardOutgoing` = **200ms** (short4) + standardAccelerate, exiting.
- `emphasized` = **500ms** (long2) + emphasized, hero/persistent element.
- `emphasizedIncoming` = **450ms** (long1) + emphasizedDecelerate, entering.
- `emphasizedOutgoing` = **150ms** (short3) + emphasizedAccelerate, exiting (fast out).
Rule of thumb: **decelerate on enter, accelerate on exit, exit shorter than enter.** That
asymmetry is most of "feels native." See end-4's concrete BezierSpline table in §2 for a
quickshell-ready encoding (incl. expressive spatial overshoot curves @ 350/500/650ms).

### 4c. Reducing subprocess / polling churn
- Don't poll: for streaming WM/IPC use `Process` + `SplitParser` (datum-as-it-arrives) and for
  one-shot output use `StdioCollector`; "Use IpcHandler" to drive show/hide of windows from
  commands instead of polling state. (FAQ "Run a program or script" / "Open/close windows".)
- Prefer native quickshell service singletons / DBus property bindings over shelling out on a
  Timer (Quickshell ships PipeWire, MPRIS, UPower, Network, Bluetooth, SNI tray, Notifications
  as reactive services):
  https://deepwiki.com/quickshell-mirror/quickshell/5-service-integration-layer
- One process, many widgets (FAQ §1). Collapse repeated `Process`/`Timer` polls into a single
  long-lived subscription; reuse the result via a singleton property.

---

## Prioritized techniques for ryoku

### Free wins (pure QML/quickshell: no compositor dependency)
1. **One motion singleton.** Add an `animationCurves`/`animation` table (copy end-4's
   BezierSpline values + M3 durations from §4b) and route every transition through it. Use
   decelerate-in / accelerate-out, exit < enter. Biggest "weak animation" fix. (§2, §4b)
2. **Animate opacity/scale/transform, never anchors/layout geometry**; kill binding loops and
   expensive per-frame bindings. (§3)
3. **Keep hot popups resident; toggle `visible`/opacity** instead of re-Loading their tree;
   reserve `Loader`/`LazyLoader` unload for cold/heavy surfaces only. (§3)
4. **Set window transparency intent once** via `QsWindow.surfaceFormat` (opaque=false); stop
   flipping opaque↔transparent at runtime. (§3)
5. **Replace per-widget `MultiEffect` shadows with `RectangularShadow`.** (§3)
6. **Set `Image.sourceSize`** everywhere to stop over-decoding; use `ListView` (recycling) for
   long lists. (§3)
7. **Collapse subprocess polling** into single long-lived `Process`+`SplitParser` / native
   service singletons + IPC-driven show/hide. (§4c)
8. **Layered, composited transparency model** (Layer0..N w/ overlay-solve), wallpaper-vibrancy
   auto value, so the slider visibly changes frosted depth. (§2) (full effect needs §9 blur)
9. **Live propagation**: ensure every setting applies via file-watch/IPC, never restart. (§1)

### Requires Hyprland / compositor support
10. **Backdrop blur via layer rules** on ryoku's layer-shell namespaces:
    `layerrule = blur, <ns>` + `ignorealpha 0.x` (+ `dimaround` for modals, `xray 1` to blur
    wallpaper only). This is THE native frosted-glass effect and what makes the transparency
    slider feel meaningful. (§4a)
11. **Set stable, matched `WlrLayershell.namespace`** per surface so rules can target bar /
    notifications / launcher individually. (§4a)
12. **`layerrule = noanim, <launcher/overview ns>`** so transient surfaces open instantly;
    let ryoku's own QML animation own the motion instead of the compositor's. (§4a)
13. **Native Qt/GTK app theming** (matugen → Kvantum/kdeglobals) so apps match the shell
    palette, completes the "native" feel beyond the shell surfaces. (§2)

---

### Source URLs (for the manager)
- noctalia README https://github.com/noctalia-dev/noctalia-shell/blob/main/README.md · site https://noctalia.dev/ · docs https://docs.noctalia.dev/v5/
- end-4 overview https://deepwiki.com/end-4/dots-hyprland · Material You https://deepwiki.com/end-4/dots-hyprland/5.1-material-you-color-system · theming https://deepwiki.com/end-4/dots-hyprland/5-theming-and-customization · layer rules https://deepwiki.com/end-4/dots-hyprland/4.1-window-rules-and-layer-rules · config https://ii.clsty.link/en/ii-qs/03config/ · Appearance.qml https://raw.githubusercontent.com/end-4/dots-hyprland/main/dots/.config/quickshell/ii/modules/common/Appearance.qml
- quickshell FAQ https://quickshell.org/docs/v0.3.0/guide/faq/ · arch patterns https://deepwiki.com/quickshell-mirror/quickshell/9.3-architecture-patterns-and-best-practices · services https://deepwiki.com/quickshell-mirror/quickshell/5-service-integration-layer · blur issue https://github.com/quickshell-mirror/quickshell/issues/24
- Qt Quick perf https://doc.qt.io/qt-6/qtquick-performance.html · KDAB https://www.kdab.com/10-tips-to-make-your-qml-code-faster-and-more-maintainable/
- Hyprland layer rules https://github.com/hyprwm/Hyprland/discussions/12748 · wiki keywords https://wiki.hyprland.org/0.42.0/Configuring/Keywords/ · blur amount RFE https://github.com/hyprwm/Hyprland/issues/6775
- M3 motion spec https://m3.material.io/styles/motion/easing-and-duration/tokens-specs · easing impl https://github.com/material-components/material-web/blob/main/internal/motion/animation.ts · durations/tokens https://pub.dev/documentation/material_design/latest/material_design/M3Motion-class.html
