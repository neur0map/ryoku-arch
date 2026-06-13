# end-4 dots-hyprland (illogical-impulse / quickshell:ii): animation, bar, blobs, transparency

Base path: `dots/.config/quickshell/ii` (abbreviated `ii/` below). All under `~/Work/dots-hyprland`.

## TL;DR of the architecture
- **One central `Appearance` singleton** (`ii/modules/common/Appearance.qml`) holds *all* curves, durations, rounding, sizes, fonts, colors, and the transparency math. Everything else references `Appearance.animation.*`, `Appearance.colors.*`, `Appearance.rounding.*`.
- **Animations are reusable `Component`s** baked into the singleton; widgets attach them with `Behavior on X { animation: Appearance.animation.foo.numberAnimation.createObject(this) }`. No ad-hoc durations scattered around.
- **Real blur is NOT QML-side** for panels, it is **Hyprland `layer_rule` blur** on the `quickshell:*` layer namespaces. Panels are drawn with semi-transparent colors; Hyprland blurs what's behind them.
- **Panel open/close slide-in is also Hyprland**, via `layer_rule` `animation = "slide right"` etc. keyed on the layershell namespace, not QML.

---

## 1. Animation system (`ii/modules/common/Appearance.qml`)

### Curves: Material 3 "expressive" + emphasized, as cubic/quintic bezier control-point lists
`animationCurves` (`Appearance.qml:251-268`):
```qml
readonly property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.90, 1, 1] // 350ms
readonly property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1.00, 1, 1] // 500ms
readonly property list<real> expressiveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1] // 650ms
readonly property list<real> expressiveEffects: [0.34, 0.80, 0.34, 1.00, 1, 1] // 200ms
readonly property list<real> emphasized: [0.05,0, 2/15,0.06, 1/6,0.4, 5/24,0.82, 0.25,1, 1,1]
readonly property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
readonly property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
readonly property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
```
Notes: the `Spatial` curves overshoot (control y > 1 → bouncy/springy "expressive" motion). `Effects`/`standard` do not overshoot (used for color/opacity). Durations are paired constants: `expressiveFastSpatialDuration: 350`, `Default: 500`, `Slow: 650`, `expressiveEffectsDuration: 200` (`Appearance.qml:264-267`).

### Standard named animations (`animation` QtObject, `Appearance.qml:270-385`)
Each is a `QtObject` exposing `duration`, `type: Easing.BezierSpline`, `bezierCurve`, and a prebuilt `Component { NumberAnimation {...} }` (and sometimes `ColorAnimation`). Representative blocks:

```qml
// elementMove, the default "move/resize" spatial anim, 500ms, springy
property QtObject elementMove: QtObject {
    property int duration: animationCurves.expressiveDefaultSpatialDuration   // 500
    property int type: Easing.BezierSpline
    property list<real> bezierCurve: animationCurves.expressiveDefaultSpatial
    property Component numberAnimation: Component { NumberAnimation {
        duration: root.animation.elementMove.duration
        easing.type: root.animation.elementMove.type
        easing.bezierCurve: root.animation.elementMove.bezierCurve
    }}
}                                                                  // :271-283
```
```qml
// elementMoveFast, 200ms, used for hover/color/opacity micro-feedback; ships BOTH a
// colorAnimation and numberAnimation; alwaysRunToEnd:true so feedback never gets cut off
property QtObject elementMoveFast: QtObject {
    property int duration: animationCurves.expressiveEffectsDuration            // 200
    property Component colorAnimation: Component { ColorAnimation {
        duration: root.animation.elementMoveFast.duration
        easing.type: root.animation.elementMoveFast.type
        easing.bezierCurve: root.animation.elementMoveFast.bezierCurve }}
    property Component numberAnimation: Component { NumberAnimation { alwaysRunToEnd: true ... }}
}                                                                  // :329-345
```
```qml
// Asymmetric enter/exit, decelerate in (400ms), accelerate out (200ms)
property QtObject elementMoveEnter: QtObject { property int duration: 400
    property list<real> bezierCurve: animationCurves.emphasizedDecel ... }      // :299-312
property QtObject elementMoveExit:  QtObject { property int duration: 200
    property list<real> bezierCurve: animationCurves.emphasizedAccel ... }      // :314-327
```
Also: `elementResize` (300ms, `emphasized`), `clickBounce` (400ms, springy `expressiveDefaultSpatial`, used for press bounce), `scroll` (200ms `standardDecel`), `menuDecel` (350ms `Easing.OutExpo`) (`Appearance.qml:347-384`).

### How widgets consume them: the universal pattern
Attach a prebuilt component to a `Behavior`:
```qml
Behavior on colText {                                              // BarContent.qml:247-249
    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
}
Behavior on width {                                                // SidebarLeft.qml:149-151
    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
}
Behavior on Layout.rightMargin {                                   // BarContent.qml:265-267
    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
}
```

### How panels appear/disappear "smoothly"
Two complementary mechanisms:
1. **Window-level slide = Hyprland** (see §4): `quickshell:sidebarLeft → slide left`, etc. The QML `PanelWindow` just flips `visible: GlobalStates.sidebarRightOpen` (`SidebarRight.qml:16`, `SidebarLeft.qml:89`). The compositor animates the layer surface in/out.
2. **In-content reveal = QML `Behavior`/`opacity`/margin**. E.g. the bar auto-hide slides via animated `anchors.topMargin` (`Bar.qml:113-122`); `Revealer` widgets animate `Layout.rightMargin`/`implicitWidth` for indicators appearing (`BarContent.qml:261-300`); OSD protection message fades via `opacity: root.protectionMessage !== "" ? 1 : 0` (`OnScreenDisplay.qml:167`).

The smooth-sliding active-workspace pill is a nice two-speed trick:
```qml
// AnimatedTabIndexPair.qml, leading edge animates faster than trailing edge → stretch/squash
property real idx1: index;  property int idx1Duration: 100
property real idx2: index;  property int idx2Duration: 300
Behavior on idx1 { NumberAnimation { duration: 100; easing.type: Easing.OutSine } }
Behavior on idx2 { NumberAnimation { duration: 300; easing.type: Easing.OutSine } }
```
Consumed in `Workspaces.qml:168-179`: `indicatorPosition` uses `min(idx1,idx2)`, `indicatorLength` uses `abs(idx1-idx2)` so the pill physically stretches between the two while moving.

---

## 2. Bar feel (`ii/modules/ii/bar/`)

- **Bar window**: `PanelWindow` with `color:"transparent"`, `WlrLayershell.namespace:"quickshell:bar"` (`Bar.qml:58,63`). Loaded lazily per-monitor via `LazyLoader { active: GlobalStates.barOpen && !screenLocked }` (`Bar.qml:26-28`), bar is fully unloaded when off, not just hidden.
- **Bar background** is a single `Rectangle` (`BarContent.qml:38-48`): `color: showBackground ? Appearance.colors.colLayer0 : "transparent"`, `radius` only in float style, `border.width:1`, `border.color: colLayer0Border`. An optional drop shadow is a `Loader`-gated `StyledRectangularShadow` (`BarContent.qml:29-36`), only instantiated in float style, avoiding shadow cost otherwise.
- **Capsule widget backgrounds** (`BarGroup.qml:13-24`): rounded `Rectangle`, `color: borderless ? "transparent" : Appearance.colors.colLayer1`, `radius: Appearance.rounding.small` (12). Each logical group (resources+media, workspaces, clock+battery) sits on its own capsule.
- **Hover/press feedback**:
  - Sidebar buttons swap background color on hover with a *transparentized-to-invisible* resting state so only the alpha animates: `colBackground: hovered ? colLayer1Hover : ColorUtils.transparentize(colLayer1Hover, 1)` (`BarContent.qml:89,238`), animated by `elementMoveFast.colorAnimation`.
  - `RippleButton` (`common/widgets/RippleButton.qml`): Material ripple via a `RadialGradient` `Item` grown by a `SequentialAnimation` (`:102-132`), `Behavior on color` (`:140-142`), and `layer.enabled:true` + `layer.effect: OpacityMask` to clip the ripple to the rounded rect (`:144-151`). Press radius can differ (`buttonRadiusPressed`).
- **Jank avoidance**:
  - `LazyLoader`/`Loader` + `active:` everywhere so inactive surfaces cost nothing (`Bar.qml:26`, shadow loader `BarContent.qml:30`, round decorators `Bar.qml:145-154`).
  - `visible: opacity > 0` paired with animated opacity so a faded-out element stops rendering (`Workspaces.qml:244`).
  - `layer.enabled` is used **only where a mask/effect needs it** (RippleButton), not blanket, avoids needless FBOs.
  - `mask: Region { item: <bg> }` on panel windows (`Bar.qml:60-62`, `SidebarLeft.qml:113-115`) restricts input/render region to the actual blob, not the full-screen layer.

---

## 3. Blob popups / sidebars (the look ryoku wants)

### Sidebar blob (`SidebarLeft.qml`, `SidebarRight.qml`)
The panel window spans full screen-edge height & is transparent; the visible "blob" is an inset rounded `Rectangle`:
```qml
StyledRectangularShadow { target: sidebarLeftBackground; radius: sidebarLeftBackground.radius }
Rectangle {
    id: sidebarLeftBackground
    anchors.top: parent.top; anchors.left: parent.left
    anchors.topMargin: Appearance.sizes.hyprlandGapsOut          // 5  → gap from screen edge
    anchors.leftMargin: Appearance.sizes.hyprlandGapsOut
    width:  panelWindow.sidebarWidth - hyprlandGapsOut - elevationMargin   // inset for shadow room
    height: parent.height - hyprlandGapsOut * 2
    color: Appearance.colors.colLayer0                            // semi-transparent (see §4)
    border.width: 1; border.color: Appearance.colors.colLayer0Border
    radius: Appearance.rounding.screenRounding - hyprlandGapsOut + 1   // matches screen corner radius
    Behavior on width { animation: Appearance.animation.elementMove.numberAnimation.createObject(this) }
}                                                                 // SidebarLeft.qml:132-151
```
Key blob recipe: **margins for the gap + shadow gutter (`hyprlandGapsOut`=5, `elevationMargin`=10), radius derived from `screenRounding` so the blob's corner radius visually matches the screen corner, a 1px subtle border (`colLayer0Border`), and a soft `RectangularShadow`.** Width changes animate (extend mode).

### Popup blob (`ii/modules/ii/bar/StyledPopup.qml`)
A `LazyLoader` (`active: hoverTarget.containsMouse`, `:16`) → `PanelWindow` (`quickshell:popup`, `WlrLayer.Overlay`). Body:
```qml
StyledRectangularShadow { target: popupBackground }
Rectangle {
    id: popupBackground
    anchors.fill: parent
    anchors.*Margin: Appearance.sizes.elevationMargin + popupBackgroundMargin*...  // shadow gutter
    color: Appearance.m3colors.m3surfaceContainer
    radius: Appearance.rounding.small
    border.width: 1; border.color: Appearance.colors.colLayer0Border
}                                                                 // StyledPopup.qml:57-79
```
Positioning maps the popup under its hover target with `root.QsWindow.mapFromItem(...)` (`:36-53`). Popups are reveal-animated by Hyprland (`quickshell:popup` has no slide but `notificationPopup → fade`, etc.).

### Shadow primitive (`common/widgets/StyledRectangularShadow.qml`)
```qml
RectangularShadow {
    anchors.fill: target; radius: target.radius
    blur: 0.9 * Appearance.sizes.elevationMargin       // ≈9
    offset: Qt.vector2d(0.0, 1.0); spread: 1
    color: Appearance.colors.colShadow                 // black @ 30% alpha
    cached: true                                       // cached → cheap
}
```

### Screen corners (`ii/modules/ii/screenCorners/ScreenCorners.qml`)
Four `PanelWindow`s (`quickshell:screenCorners`, `WlrLayer.Overlay`, `color:"transparent"`) per monitor, each drawing one `RoundCorner` of `implicitSize: Appearance.rounding.screenRounding` (`:51-58`). They mask to a tiny interaction region (`:30-32`) and double as click/hover/scroll hot-corners that toggle sidebars (`actionForCorner`, `:15-20,76-135`). Hidden on fullscreen (`:26,150`). Hyprland gives them a `popin 120%` entrance (§4).

The bar reuses the same `RoundCorner` widget as "round decorators" so the bar background blends into screen corners (`Bar.qml:145-211`).

---

## 4. Transparency + blur: the live wiring

### The QML-side opacity option → surface color
Config option (`ii/modules/common/Config.qml:119-124`):
```qml
property JsonObject transparency: JsonObject {
    property bool enable: false
    property bool automatic: true
    property real backgroundTransparency: 0.11
    property real contentTransparency: 0.57
}
```
Resolved into a live alpha in the `Appearance` singleton (`Appearance.qml:28-35`):
```qml
property real backgroundTransparency: Config.options.appearance.transparency.enable
    ? (transparency.automatic ? autoBackgroundTransparency : transparency.backgroundTransparency) : 0
property real contentTransparency: transparency.automatic ? autoContentTransparency : transparency.contentTransparency
```
`autoBackgroundTransparency` is *computed from the wallpaper*, a `ColorQuantizer` extracts the dominant color, derives `wallpaperVibrancy`, and a fitted quadratic `y = 0.5768x² − 0.759x + 0.2896` (clamped 0–0.22) picks an opacity (`Appearance.qml:19-32`). This is why "automatic" transparency tracks the wallpaper.

That alpha is then folded into every layer color:
```qml
property color colLayer0: ColorUtils.transparentize(colLayer0Base, root.backgroundTransparency)  // :115
property color colBackgroundSurfaceContainer: ColorUtils.transparentize(m3colors.m3surfaceContainer, backgroundTransparency) // :175
```
`transparentize(color, p)` multiplies alpha by `(1-p)` (`ColorUtils.qml:110-113`). Content layers use `solveOverlayColor(base, target, 1 - contentTransparency)` (`Appearance.qml:122,129,176-179`; `ColorUtils.qml:163`) so nested layers stay legible while the *background* shows through. **So the slider literally lowers the alpha of `colLayer0`/surface colors that every panel background binds to, instant, reactive, no reload.**

### The blur: Hyprland layer rules, not QML
`dots/.config/hypr/hyprland/rules.lua:130-159`:
```lua
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur_popups = true})
hl.layer_rule({ match = { namespace = "quickshell:.*" }, blur = true})
hl.layer_rule({ match = { namespace = "quickshell:.*" }, ignore_alpha = 0.79})
hl.layer_rule({ match = { namespace = "quickshell:bar" }, animation = "slide"})
hl.layer_rule({ match = { namespace = "quickshell:screenCorners" }, animation = "popin 120%"})
hl.layer_rule({ match = { namespace = "quickshell:notificationPopup" }, animation = "fade"})
hl.layer_rule({ match = { namespace = "quickshell:sidebarRight" }, animation = "slide right"})
hl.layer_rule({ match = { namespace = "quickshell:sidebarLeft" }, animation = "slide left"})
hl.layer_rule({ match = { namespace = "quickshell:dock" }, animation = "slide bottom"})
hl.layer_rule({ match = { namespace = "quickshell:popup" }, ignore_alpha = 1})  -- opaque tooltips
```
Global blur quality (`general.lua:77-93`): `enabled=true, size=10, passes=3, noise=0.05, contrast=0.89, vibrancy=0.5, xray=true, new_optimizations=true`. Layer shadow from `decoration.shadow` (`general.lua:94-101`).

**Mechanism:** every quickshell layer surface (matched by `namespace = "quickshell:.*"`) is blurred by Hyprland; `ignore_alpha = 0.79` means pixels below 0.79 alpha don't get blurred-behind (tunes how much shows through). The QML panel just draws a translucent rounded rect; Hyprland does the gaussian blur of the desktop behind it AND the slide/fade/popin entrance. There is **no `MultiEffect`/blur in the panel QML**, `StyledBlurEffect.qml` (a `MultiEffect blur` over the wallpaper, `:1-12`) is only used for in-shell wallpaper backdrops, not the panels. **Critical for ryoku:** to get this "native frosted" feel you set the quickshell layer namespace explicitly (`WlrLayershell.namespace`) and add a matching Hyprland `layerrule blur,namespace`.

---

## 5. Theme color usage from the singleton

- Single source: `Appearance.colors.*` (semantic, `Appearance.qml:111-199`) layered on raw Material3 tokens `Appearance.m3colors.*` (`:37-109`). M3 tokens are regenerated by matugen from the wallpaper; the `colors` block derives hover/active/border variants programmatically:
```qml
property color colLayer1Hover:  ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.92), contentTransparency)  // :125
property color colLayer1Active: ColorUtils.transparentize(ColorUtils.mix(colLayer1, colOnLayer1, 0.85), contentTransparency)  // :126
property color colLayer0Border: ColorUtils.mix(m3colors.m3outlineVariant, colLayer0, 0.4)                                      // :119
```
- A **layered elevation model**: `colLayer0` (bar/sidebar bg) → `colLayer1` (capsules) → `colLayer2..4` (nested controls), each with `Base/Hover/Active/OnLayerN` variants. Widgets pick the layer matching their nesting depth (e.g. `BarGroup` uses `colLayer1`, ripple buttons use `colLayer1Hover/Active`).
- Primary/secondary/tertiary/error containers all follow the same `col{Role}` / `col{Role}Hover` / `colOn{Role}` naming, so a widget reads e.g. `colSecondaryContainer` for a toggled state (`BarContent.qml:241-243`).
- `rounding` and `sizes` are likewise centralized (`Appearance.qml:201-212,387-415`): `rounding.small=12`, `normal=17`, `screenRounding=large=23`, `windowRounding=18`; `sizes.baseBarHeight=40`, `hyprlandGapsOut=5`, `elevationMargin=10`, `sidebarWidth=460`.

---

## Portable to ryoku: concrete QML patterns to adopt verbatim

1. **Central animation singleton with prebuilt `Component` animations.** Define curves as bezier control-point lists + paired durations, expose each named animation as a `QtObject` carrying a `Component { NumberAnimation/ColorAnimation }`, and attach with `Behavior on X { animation: Appearance.animation.foo.numberAnimation.createObject(this) }`. (Ryoku's `Anim.qml` likely hardcodes per-widget; consolidate.)
2. **Material 3 expressive curves**: spatial moves use overshooting beziers (e.g. `[0.38,1.21,0.22,1.00,1,1]` @500ms); color/opacity use non-overshoot `expressiveEffects` @200ms with `alwaysRunToEnd:true`. Asymmetric `enter`(decel,400ms)/`exit`(accel,200ms).
3. **Translucent-to-invisible resting hover color** so only alpha animates: `colBackground: hovered ? colLayer1Hover : ColorUtils.transparentize(colLayer1Hover, 1)` + `Behavior on color`.
4. **Two-speed sliding pill** (`AnimatedTabIndexPair`): animate a leading index (100ms) and trailing index (300ms); position = min, length = |diff|, → the active indicator stretches as it moves. Drop-in for ryoku workspace/tab indicators.
5. **Blob construction**: full-edge transparent `PanelWindow` (`color:"transparent"`) + inset rounded `Rectangle` with margins = gap(5)+shadow gutter(10), `radius` derived from `screenRounding`, 1px `colLayerNBorder`, and a `cached` `RectangularShadow` (`blur≈9, spread:1, offset(0,1), colShadow@30%`).
6. **`mask: Region { item: blobRect }`** on panel windows so only the blob takes input/draw, not the whole layer.
7. **Blur belongs to the compositor**: set an explicit `WlrLayershell.namespace: "quickshell:<role>"` per surface, then add Hyprland `layerrule blur,namespace:^(quickshell:...)$` + `ignore_alpha`. Do NOT stack a QML `MultiEffect` blur on panels.
8. **Surface-edge entrance via compositor too**: `layerrule animation slide left/right/bottom/fade/popin` keyed on namespace; QML only flips `visible`. Avoids QML reflow jank on open.
9. **Transparency slider must feed the *base layer color's alpha***: route the option through `ColorUtils.transparentize(baseColor, backgroundTransparency)` for `colLayer0`/surface, and `solveOverlayColor(base, target, 1-contentTransparency)` for nested layers, bound reactively so the slider is instantly visible. (Likely ryoku's slider "does nothing" because it isn't wired into the actual surface color binding, or panels are fully opaque so blur/alpha never shows.)
10. **`LazyLoader { active: ... }` for every transient surface** (popups, bar, decorators, shadows), instantiate on demand, destroy when hidden; pair animated `opacity` with `visible: opacity > 0`.
11. **Layered elevation color model** (`colLayer0..4` + Hover/Active/OnLayer variants) derived from M3 tokens via `mix`/`transparentize`, so theming is one matugen regen and all states stay consistent.
