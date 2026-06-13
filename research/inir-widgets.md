# iNiR Desktop-Widget Design Study

**Repo identified as canonical iNiR:** [`snowarch/iNiR`](https://github.com/snowarch/iNiR), ~1.1k stars, 64 forks, v2.27.0, actively developed (branches `main`/`prerelease`/`dev`/`future`, 142 KB CHANGELOG). Self-describes as "A Niri shell illogical-impulse based" and "Started as end-4's Hyprland dots, became a full rewrite for Niri." Has a first-class **desktop-widget layer** (clock, weather, media, system monitor, battery, notes, calendar, visualizer) living in `modules/background/widgets/`.

**Rejected candidates:** `alexindigo/iNiR`, `vytorags/iNiR`, `kirisaki-vk/iNiR`, `Urbeis-Magna/iNiR` are forks/empty mirrors; `YzmmQwQ/dots-niri` is a personal dotfile set, not a widget shell. Only snowarch has the maintained Quickshell widget source. (`snowarch/quickshell-ii-niri` is the same project's old name/redirect.)

All file paths below are under `https://github.com/snowarch/iNiR/blob/main/`. Source read via raw.githubusercontent.com.

---

## CROSS-CUTTING SYSTEMS

### Card material: `modules/background/widgets/WidgetSurface.qml`
One style-aware surface backs every desktop widget. It branches on a global `globalStyle` token (`material` | `cards` | `aurora` | `inir` | `angel`):
- **Glass/blur (aurora & angel):** `color: "transparent"`, then an `Image` of the wallpaper positioned by `x:-screenX, y:-screenY` (so it samples the exact pixels *behind* the card), run through `MultiEffect { blurEnabled:true; blurMax:64; blur: 0.8 }` with `saturation: 0.15`. The whole Rectangle has `layer.enabled` + `layer.effect: OpacityMask { maskSource: rounded Rectangle }` so the frosted wallpaper is clipped to the rounded-card shape. This is the proven "blur the wallpaper inside the card" technique (same as our DesktopClock).
- **Tinted overlay** over the blur: `ColorUtils.transparentize(colLayer0Base, aurora.popupTransparentize*1.2)` (≈0.32–0.42 alpha), keeps text legible on busy wallpapers.
- **angel extras:** a top **inset glow** strip (`height: insetGlowHeight`, `color: colInsetGlow`) for a lit top edge, plus an `AngelPartialBorder` (border drawn on only some sides, neo-brutalist).
- **inir (TUI):** transparent fill + a 1px border at `inir.colBorder` (= `outlineVariant` transparentized 0.3); optional faint `colLayer1` fill at `surfaceOpacity*2`.
- **material/cards:** flat `ColorUtils.applyAlpha(surfaceColor, surfaceOpacity)` (default opacity **0.06**) with a separate 1px border overlay at opacity **0.08** drawn as its own Rectangle (avoids Qt's interior border bleed on transparent rects).
- **Per-widget overrides** (`AbstractBackgroundWidget.qml`): `backgroundOpacity`, `borderWidth` (0–8), `borderOpacity`, `cornerRadius`, `useBlur` toggle, `widgetOpacity`, `widgetScale` (0.5–2.0). So a user can have a frosted clock but a flat resources card.
- **Elevation** is never a CSS shadow, it's `StyledRectangularShadow`/`StyledDropShadow` (a real soft drop shadow component), only drawn for material/cards/angel, never for inir/aurora (glass needs no shadow).

**Reproduce for us:** our DesktopClock already does the masked-blur trick; generalize it into one `WidgetSurface`-style component with `surfaceOpacity/borderWidth/useBlur` props and a `RectangularShadow` for elevation, reading all colors from the live M3 palette.

### Motion language: `modules/common/Appearance.qml` (`animation`/`animationCurves`)
Tokens that map 1:1 onto ours:
- **Spatial w/ overshoot:** `expressiveFastSpatial` bezier `[0.42,1.67,0.21,0.90]` @350ms, `expressiveDefaultSpatial` `[0.38,1.21,0.22,1.00]` @500ms, `expressiveSlowSpatial` `[0.39,1.29,0.35,0.98]` @650ms (note the >1 control points = bounce). These match our existing `expressive*Spatial` tokens.
- **Entrance:** `elementMoveEnter` = `emphasizedDecel` @400ms (decelerate-in, no bounce). **Exit:** `elementMoveExit` = `emphasizedAccel` @200ms.
- **Value/color changes:** `elementMoveFast` = `expressiveEffects` `[0.34,0.80,0.34,1.00]` @200ms.
- **Click feedback:** `clickBounce` uses the spatial-overshoot curve @400ms; physical press bump is `scaleFactor: containsPress ? 1.05 : 1.0` (scale the *layout dim*, not `Item.scale`, to avoid bitmap blur).
- **Physical follow (Class B):** `SmoothedAnimation` velocity 1400/2600 for retargetable values, and a real `SpringAnimation` (`spring 3.2, damping 0.28, mass 1.0, epsilon 0.25`) for drag-follow/indicators.
- **Entrance pattern:** widgets fade via `Behavior on opacity` (elementMoveFast); position changes (auto-placement, snap zones) animate `x`/`y` with the spatial curve.
- **Power gating:** a `WidgetPowerManager` disables blur FBOs, animations, and Cava when fullscreen/covered/gamemode; paused widgets desaturate (`saturation -0.7`) + dim (`brightness -0.15`) via a `layer.effect`. Worth copying so ambient motion never costs battery when hidden.

### Color usage
- **Accent vs neutral:** widgets pick a **per-style accent triad** with one ternary helper, e.g. clock/monitor use `colPrimary` (CPU/hour), `colSecondary` (RAM/minute), `colTertiary` (GPU/second), `colError` (temp). Neutrals come from the layered surface system (`colLayer0..4`, each `solveOverlayColor`-composited so translucency stacks correctly).
- **Wallpaper-reactive:** `ColorQuantizer` extracts the dominant wallpaper color (`wallpaperDominantColor`); `wallpaperVibrancy` drives an **auto-transparency** curve `y = 0.5768x² − 0.759x + 0.2896` (clamped ≤0.22) so vibrant wallpapers get less see-through cards. Everything reads from the live M3 scheme, zero hardcoded hex in widget code.
- **Album-art recoloring:** media widgets build a whole *local* M3 scheme from the cover art via `AdaptedMaterialScheme { color: artDominantColor }` (`blendedColors`), so the player retints to the song, independent of the wallpaper theme.
- **Readability guards:** `ColorUtils.ensureReadable(fg,bg,4.5)` / `readableSubtext` enforce WCAG contrast; aurora-dark forces lighter text, aurora-light uses warm "sumi-e ink" tones instead of pure black.

---

## PER-WIDGET TREATMENTS

### CLOCK: `modules/background/widgets/clock/`
**(a) Cookie analog clock (`CookieClock.qml`)**, the hero/default style.
- *Looks like:* a Material **cookie/blob polygon** dial (a rounded N-sided polygon, default 14 sides) filled with `primaryContainer`, layered hands, optional minute marks, center number column, and a date bubble.
- *Technique:* dial is a `MaterialCookie`/`SineCookie` rounded-polygon shape (sides configurable 6–23) wrapped in a `StyledDropShadow`. Hands are separate `Item`s rotated by `rotation: 360/60*sec + 90` etc. Colors: `colHourHand=primary`, `colMinuteHand=tertiary`, `colSecondHand=primary`. Hand/feature styles (`fill`/`hollow`/`dot`/`classic`/`bold`) swap via `FadeLoader` (cross-fading loaders). Center dot, hour marks, minute marks, and a `DateIndicator` (bubble/border/rect) are independent toggleable loaders stacked by `z`.
- *Motion:* second hand normally **snaps** per second (animating every second is called out as too expensive); only when `constantlyRotate` is on does it get a `RotationAnimation` (1000ms InOutQuad) and the whole dial slowly rotates (`RotationAnimation` 30000ms Linear, infinite) for ambient life, paused by `WidgetPowerManager`. Hand-style changes tween width/length with `elementResize` (300ms emphasized). An **AI styling** hook (`setClockPreset`) picks dial/hand presets per wallpaper *category* (anime/city/minimalist/landscape…) read from a generated file.

**(b) Digital clock (`ClockWidget.qml`)**
- *Looks like:* a giant 90px time numeral + 20px date, optional quote line, optional card behind it.
- *Technique:* `ClockText` (a `StyledText`) at `pixelSize: 90 * timeScale/100 * scaleFactor`. Auto-alignment: left/center/right chosen by the widget's x-position thirds (`x < screenW/3 → AlignLeft`). Optional `WidgetSurface` card appears only in digital mode. Raised text shadow (`style: Text.Raised; styleColor: colShadow`) when `showShadow`. `SystemClock` precision drops to Minutes under power-save.
- *Motion:* digit changes can animate (`digital.animateChange`); lock-screen "center clock" springs the widget to screen center via a `Binding`.

**Reproduce:** the cookie dial = a rounded-polygon `Shape` (or `MaterialShape`) + `RotationAnimation`-driven hands; per-feature `FadeLoader` swaps give the "alive, configurable" feel. The slow infinite dial rotation is a cheap, classy ambient motion.

### WEATHER: `modules/background/widgets/weather/WeatherWidget.qml`
**(a) Shape/pill mode (default).**
- *Looks like:* a single **Material expressive shape** (pill, circle, diamond, **heart, flower, cookie, sunny, clover, gem, puffy**, 12 shapes) filled with `primaryContainer`, big temp number top-right, weather icon bottom-left, optional condition text centered-bottom.
- *Technique:* `MaterialShape { shape: pillShapeEnum; color: accentPrimaryContainer }` under a `StyledDropShadow`. Temp uses the **expressive** font (`Space Grotesk`) at `tempSize*scaleFactor`, colored `accentPrimary`; icon is a `MaterialSymbol` via `Icons.getWeatherIcon(wCode, isNight)` colored `onPrimaryContainer`. Day/night aware icon selection.
- *Motion:* shape swap and resize ride the standard Behaviors; dim factor fades content `opacity: 1 - dim*0.6`.

**(b) Card mode.** Adaptive translucent rounded rect (`max(backgroundOpacity,0.14)` over `colText`) with a min-1px border, same temp/icon/condition layout but neutral surface instead of accent blob.

**Reproduce:** swap our flat weather rect for a `MaterialShape` accent blob (pill/cookie/sunny) with `primaryContainer` fill + drop shadow + expressive-font temp. The 12 selectable shapes are a cheap personality win.

### MEDIA / NOW-PLAYING: `modules/background/widgets/mediaControls/` + `modules/mediaControls/presets/` + `.../components/`
Six swappable presets (`full`, `compact`, `minimal`, **`albumart`**, **`visualizer`**, `classic`) chosen by a `Loader`/`Component` switch.

**(a) AlbumArtPlayer (`presets/AlbumArtPlayer.qml`), full-bleed cover.**
- *Looks like:* edge-to-edge blurred album art filling the card, dark bottom gradient, white overlaid title/artist/seekbar/transport, audio visualizer along the bottom edge.
- *Technique:* card is `clip:true` + `OpacityMask` rounding. Art `Image` (`PreserveAspectCrop`, `mipmap`) gets `MultiEffect { blur:0.3; blurMax:32; saturation:0.5 }` as a soft background. **Readability gradient:** a `Gradient` overlay `transparent → black@0.5 → black@0.2`. Controls are white-on-art. Fallback when no art = `blendedColors.colLayer0` + centered `music_note`.
- *Motion:* see album-art **blur cross-fade** below.

**(b) VisualizerPlayer (`presets/VisualizerPlayer.qml`).**
- *Looks like:* compact 80px art tile left, title/artist/seekbar/transport right, and a prominent **wave or VU-bar** visualizer (top/bottom/fill).
- *Technique:* `WaveVisualizer` (sine canvas) or `CavaVisualizer` (`barCount:32, barSpacing:2, barRadius:2`) fed `points` from a `CavaProcess` (`active: visible && isPlaying`). Bars are tri-color by amplitude: `colorLow = artColor@0.3`, `colorMed = @0.1`, `colorHigh = artColor`, so loud bands glow the accent. `maxVisualizerValue:1000, smoothing:2`.

**(c) Album-art handling (`components/PlayerArtwork.qml`)**, reusable, with a signature transition:
- On track change it **blurs in → swaps source → blurs out**: `MultiEffect.blur` animates 0→1 (150ms InOutQuad), a 150ms timer swaps `coverArt.source`, a 50ms timer clears `transitioning` → blur animates back to 0. Gives a smooth defocus/refocus on every song change instead of a hard cut. `OpacityMask` rounds it; `music_note` placeholder when undownloaded.

**(d) Seekbar (`components/PlayerProgress.qml` → `StyledSlider.qml` + `WavyLine.qml`), the standout.**
- *Looks like:* the **filled portion of the progress bar is a moving sine wave** while playing; the remaining track is flat. A thin pill handle.
- *Technique:* `StyledSlider` in `Configuration.Wavy`. The left fill is a `WavyLine` `Canvas`: `waveY = centerY + amplitude*sin(frequency*2π*x/fullLength + phase)` with `phase = Date.now()/400`, `frequency 6`, `amplitude = lineWidth*0.5`. A `FrameAnimation { running: animateWave }` calls `requestPaint()` at ~60fps **only while playing** (`wavy: enableWavy && isPlaying`). The unfilled side is a plain rounded rect in `secondaryContainer`. Corners use asymmetric radii (`trackRadius` outer, tiny `unsharpen` inner). Position is bound directly to `position/length` (instant, no lag).
- *Transport (`components/PlayerControls.qml`):* circular buttons (`buttonRadius: rounding.full`), 36px side / 48px play, ripple via `buttonRippleColor`, M3 state-layer hover. *Title (`components/PlayerInfo.qml` / `StyledText.animateChange`):* title text slides/cross-fades on change (`animateChange:true, animationDistanceX:6`), that's iNiR's "smooth media title scrolling."

**Reproduce:** the wavy animated seekbar + the album-art blur-crossfade are two high-impact, cheap signatures. The wave is ~15 lines of Canvas; gate the `FrameAnimation` on `isPlaying` to keep it free when idle.

### RESOURCES / SYSTEM MONITOR: `modules/background/widgets/systemMonitor/SystemMonitorWidget.qml`
Four display modes, all reading `ResourceUsage` (cpu/mem/gpu/temp/disk) with `keepAlive()` ref-counting.
**(a) Rings mode**, circular gauges.
- *Technique:* `CircularProgress` (`common/widgets/CircularProgress.qml`) = `QtQuick.Shapes` with two `ShapePath`+`PathAngleArc`. Track arc sweeps `-(360 - degree - 2*gap)`; value arc sweeps `degree = value*360` from `startAngle:-90`; `gapAngle = 360/18` leaves a tidy gap between track and fill; `capStyle: RoundCap`; `preferredRendererType: Shape.CurveRenderer` for smooth AA. `lineWidth ≈ ringSize*0.09`. Percentage number centered inside in the `numbers` font, `Font.DemiBold`. Each resource gets its accent color; track = same color @ low alpha.
- *Motion:* value is smoothed through `Behavior on _animatedValue { NumberAnimation 1200ms OutCubic }`, gauges glide, never jump.

**(b) Bars mode**, horizontal fill bars: a track rect at `applyAlpha(color, trackAlpha≈0.08)` + a fill rect `width: parent.width*value` with `Behavior on width { 1200ms OutCubic }`, icon + right-aligned % in numbers font.

**(c) Graph mode**, stacked area history: three `Graph` components plot `cpuUsageHistory`/`memoryUsageHistory`/`gpuUsageHistory` with decreasing `fillOpacity` (0.35/0.30/0.25) so they layer; faint 25/50/75% gridlines (`applyAlpha(colText,0.06)`) + Y labels.

**(d) Text mode**, compact **chips**: rounded rects tinted `applyAlpha(color, trackAlpha)` with icon + label + value.

**Reproduce:** `CircularProgress` is directly liftable for our resources widget (gauge math above). The `1200ms OutCubic` value-smoothing on bars/rings is what makes telemetry feel "alive" instead of twitchy. Color = primary/secondary/tertiary/error per metric.

### BATTERY PILL / NOTES / CALENDAR
Live under `modules/background/widgets/{battery,notes,calendar,visualizer}`, same `AbstractBackgroundWidget` + `WidgetSurface` chassis (draggable, snap-zoned, per-widget opacity/scale/blur, power-managed). Battery is a pill consistent with the weather pill treatment.

---

## WHAT iNiR DOES DIFFERENTLY / BETTER THAN end-4

1. **A real desktop-widget layer with a drag/resize/snap editor.** end-4 mostly puts info in bar/sidebar; iNiR has free-floating wallpaper-layer widgets with 9 snap zones, **auto-placement by wallpaper busyness** (`leastBusy`/`mostBusy` via image analysis), per-widget scale/opacity/blur/border, and an edit mode (`WidgetManagerPanel`).
2. **One style engine, five skins.** `globalStyle` (material/cards/aurora/inir/angel) reskins *every* widget through `WidgetSurface` + ternary accent helpers, you get frosted-glass, flat, TUI-mono, or neo-brutalist from one switch. end-4 is essentially single-style.
3. **The wavy, animated M3 seekbar** (`WavyLine` canvas, painting only while playing), far more expressive than a flat progress bar.
4. **Album-art-derived theming per song** (`AdaptedMaterialScheme` on `artDominantColor`) plus a **blur-crossfade artwork transition** on track change.
5. **Material expressive shapes everywhere** (cookie clock dial, 12-shape weather blob, `MaterialShape` placeholders) instead of plain rounded rects.
6. **Disciplined power management** (`WidgetPowerManager`): blur FBOs, ambient rotation, Cava, and animations all suspend when covered/fullscreen, with a desaturate+dim "paused" visual, ambient motion stays cheap.
7. **Wallpaper-vibrancy-driven auto-transparency** (quadratic curve) so glass cards stay readable on busy/vibrant wallpapers automatically.
8. **Layered translucency done correctly** via `solveOverlayColor` so stacked semi-transparent surfaces composite to the intended M3 tone rather than muddying.

---

## SOURCE FILES CITED
- `modules/common/Appearance.qml` (tokens, motion, color, transparency curve)
- `modules/background/widgets/WidgetSurface.qml` (card material)
- `modules/background/widgets/AbstractBackgroundWidget.qml` (drag/snap/scale/power)
- `modules/background/widgets/clock/{ClockWidget,CookieClock,SecondHand}.qml`
- `modules/background/widgets/weather/WeatherWidget.qml`
- `modules/background/widgets/mediaControls/MediaControlsWidget.qml`
- `modules/background/widgets/systemMonitor/SystemMonitorWidget.qml`
- `modules/mediaControls/presets/{AlbumArtPlayer,VisualizerPlayer}.qml`
- `modules/mediaControls/components/{PlayerProgress,PlayerArtwork}.qml`
- `modules/common/widgets/{CircularProgress,StyledSlider,WavyLine}.qml`
