# Native-feel v2: Micro-interactions (hover / press / ripple / focus)

Scope: the subtle feedback that makes widgets feel "alive", M3 hover wash, press
ripple, scale/colour/elevation shifts, cursor changes, easing on small elements.
Investigation only; Main implements + owns the build/verify gate.

## Reference primitives (how the two shells do it everywhere)

- **dots-hyprland** (QML quickshell, vertical bar, closest match): every interactive
  surface is a `RippleButton` (`modules/common/widgets/RippleButton.qml:11-39`). One
  primitive carries: a hover background wash (`colBackground` transparent →
  `colBackgroundHover = colLayer1Hover`, `:26-38`), a toggled state (`colPrimary` /
  `colSecondaryContainer`), a radial **ripple** on press (`:41-52`, `:94-181`), and a
  colour `Behavior` cross-fade on `buttonColor` (`elementMoveFast.colorAnimation`,
  `:140-142`). The vertical bar's status cluster (network/bt/mic/notif) is literally
  wrapped in one `RippleButton` whose icon text colour also cross-fades
  (`modules/ii/verticalBar/VerticalBarContent.qml:193-288`, `colText` + `Behavior`
  `:213-215`). Bar groups get hover via their section MouseArea feeding
  `colBackground` (`:70-74`, `:204-209`).
- **noctalia-shell** (C++ rewrite): the shared `Button` resolves a per-state colour
  set, normal / **hover** (`ColorRole::Hover` bg + `OnHover` label) / **pressed**
  (`Primary` bg) / selected / disabled (`src/ui/controls/button.cpp:531-557`,
  palettes `:30-170`) and **cross-fades** bg+border+label over `Style::animFast`
  (100 ms) with `Easing::EaseOutCubic` (`:597-606`). Every bar widget is built from
  this Button/InputArea base (`src/shell/bar/widgets/*`), so hover wash + press
  feedback is universal, not per-widget.

Takeaway shared by both: **interactive surfaces always have (a) a hover background
wash, (b) a press ripple/pressed-tone, and (c) the icon/label colour cross-fades with
the background.** Ryoku already owns an equivalent primitive, `StateLayer.qml` (hover
wash `stateOpacity` 0.08 `:14`, radial ripple `:44-52`/`:106-181`, pointing-hand
cursor `:56`, `Behavior on stateOpacity` `:184-189`). The gap is **inconsistent
adoption**: the bar widgets, the exact surface in the user's screenshot, mostly skip
it. Only `Power` uses it (`modules/bar/components/Power.qml:14-22`).

> Wiring note: `StateLayer` is already wired to live config, colours come from
> `Colours.palette`/`Colours.tPalette` (live theme), timing from `Tokens.anim.*`
> (live `AppearanceTokens` curves/durations in `plugin/.../tokens.hpp:10-123`). So the
> bar fixes below are **consistency fixes that reuse `StateLayer`, no new key**. The
> only genuinely missing wiring is reduce-motion coverage (F8) and an optional
> opacity-tuning key (noted at end).

---

## Ranked findings (impact-per-risk)

### F1: Bar status-icons cluster has zero hover/press feedback  ★ top
1. The whole status column (audio, mic, kb, network, bt, battery, lock) is a static
   `StyledRect` with no MouseArea/StateLayer; hovering it (which opens a popout via the
   bar's central hit-test) produces no visual response at all. It is the densest,
   most-hovered cluster on the bar and feels dead.
2. Reference: dots wraps the equivalent vertical status cluster in a `RippleButton`
   with hover wash + ripple + icon-colour cross-fade -
   `dots:modules/ii/verticalBar/VerticalBarContent.qml:193-219` (+ `colText` Behavior
   `:213-215`), primitive at `dots:modules/common/widgets/RippleButton.qml:26-39`.
   noctalia: every bar widget hovers via the shared Button -
   `noctalia:src/ui/controls/button.cpp:548-551`.
3. Ryoku current: `shell/modules/bar/components/StatusIcons.qml:13-24`, `StyledRect`,
   no interaction layer; icons `:106-254` are bare `MaterialIcon`s.
4. Fix: drop a `StateLayer { radius: parent.radius; color: Colours.palette.m3onSurface }`
   as the first child of the root `StyledRect` (mirror `Power.qml:14-22`). It coexists
   with the bar's pointer-driven popout hit-test (Power/OsIcon already prove this, the
   global `Interactions` area reads pointer position, it does not depend on event
   propagation). Optionally route the cluster's existing popout-open through the
   StateLayer's `onClicked` for click-to-pin.
5. Key: consistency fix, reuse `StateLayer` (live `Colours.palette` + `Tokens.anim`).
   No new key. Popout itself stays gated by `Config.bar.popouts.statusIcons`.
6. Risk: low. No compositor.

### F2: Bar OsIcon (logo / launcher button): bare MouseArea, no wash/ripple  ★ top
1. The logo opens the launcher but gives no hover wash, no press ripple, only a cursor
   change. It is the single most clicked bar control after workspaces.
2. Reference: dots' left-sidebar/start button is a Ripple/AcrylicButton with hover +
   ripple, `dots:modules/ii/verticalBar/VerticalBarContent.qml:70-74`,
   `dots:modules/waffle/bar/BarButton.qml:8-37` (AcrylicButton base). noctalia
   launcher_widget is a Button (hover+press), `noctalia:src/shell/bar/widgets/launcher_widget.*`.
3. Ryoku current: `shell/modules/bar/components/OsIcon.qml:17-24`, `MouseArea` with
   only `cursorShape: Qt.PointingHandCursor` and `onClicked`.
4. Fix: replace the bare `MouseArea` with a `StateLayer` (radius `Tokens.rounding.full`,
   `color: Colours.palette.m3onSurface`, `onClicked` toggles the launcher), exactly
   like `Power.qml:14-22`.
5. Key: consistency fix, reuse `StateLayer`. No new key.
6. Risk: low.

### F3: Bar Clock: fully static, no hover affordance  ★ top
1. `Clock` has no MouseArea at all, yet the bar exposes a clock-hover path
   (`Bar.qml:91-94 isClockHover`, `TopNotch.qml:80-82`). Hovering the clock to peek its
   popout shows nothing on the clock surface itself, no wash, no cursor.
2. Reference: dots `ClockWidget` has a hover MouseArea driving its popout
   (`dots:modules/ii/bar/ClockWidget.qml:40-48`) and lives inside a hoverable BarGroup;
   noctalia `clock_widget` is a Button with hover state.
3. Ryoku current: `shell/modules/bar/components/Clock.qml:8-19`, `StyledRect`, no
   interaction layer.
4. Fix: add a `StateLayer { radius: parent.radius; color: Colours.palette.m3onSurface }`
   child so hovering the clock gives the M3 wash + pointing-hand, and (optionally) a
   ripple. Pairs naturally with the existing `Config.bar.clock.background` look.
5. Key: consistency fix, reuse `StateLayer`. No new key.
6. Risk: low.

### F4: Bar tray items: bare MouseArea, no hover/press feedback
1. Each tray icon is a bare `MouseArea`; no hover wash, no press ripple. Tray rows are
   a primary interaction target and read as flat next to references.
2. Reference: dots `TrayButton` (`dots:modules/waffle/bar/tray/TrayButton.qml`) and
   noctalia `tray_widget` give each item hover feedback via their button base.
3. Ryoku current: `shell/modules/bar/components/TrayItem.qml:10-33`, `MouseArea` +
   `ColouredIcon`, no StateLayer.
4. Fix: nest the icon inside a `StyledRect` (radius full) + `StateLayer`, or add a
   `StateLayer` sibling sized to the item, keeping the existing left/right-click
   `activate`/`secondaryActivate` on its `onClicked`. Keep implicit size unchanged so
   `Tray.qml` layout math (`:22-35`, `Bar.qml:56-71`) is untouched.
5. Key: consistency fix, reuse `StateLayer`. No new key.
6. Risk: low–med (verify the tray layout/childAt hit-test in `Bar.qml:56-71` still
   maps rows after adding the wrapper, keep geometry identical).

### F5: Workspace dots: no per-dot hover/press feedback
1. Inactive workspace dots give no hover wash and clicking gives no ripple/scale; only
   the shared active indicator animates. References make each workspace pill respond on
   hover and press.
2. Reference: dots workspace buttons animate hover/active state
   (`dots:modules/ii/bar/Workspaces.qml`); noctalia `workspaces_widget` discs animate
   hover + active opacity (`taskbar_widget.cpp` workspace path, opacities `:151,160`).
3. Ryoku current: dots are `ColumnLayout` text only
   (`shell/modules/bar/components/workspaces/Workspace.qml:41-65`); a single shared
   `MouseArea` over the whole column handles clicks
   (`workspaces/Workspaces.qml:99-113`), no per-dot feedback.
4. Fix (lowest-risk): give each `Workspace` a hover-wash `Rectangle`/`StateLayer`
   *behind* the label driven by a `hovered` flag, and a scale-on-press pulse
   (`scale: 0.9` while the shared MouseArea is pressed over this dot, `Behavior on
   scale` with `Tokens.anim` `EmphasizedDecel`). Prefer a non-interactive hover wash
   driven by `Workspaces.qml`'s MouseArea `containsMouse`+position rather than a
   per-dot MouseArea, so the bar's `childAt` geometry hit-test (`Bar.qml:78-87`,
   `Workspaces.qml:102`) is unaffected.
5. Key: consistency fix using existing `Tokens.anim` + `Colours.palette`. No new key.
   (`Config.bar.workspaces.activeIndicator` already governs the active marker.)
6. Risk: med, workspace geometry feeds the bar's popout hit-test; do not add per-dot
   MouseAreas or change implicit sizes.

### F6: Bar ActiveWindow: cursor only, no hover wash
1. The active-window bar item sets `cursorShape` but no hover wash; clicking to pin/
   unpin its popout has no visual feedback.
2. Reference: noctalia `active_window_widget` is a hoverable Button; dots active-window
   sits in a hoverable BarGroup.
3. Ryoku current: `shell/modules/bar/components/ActiveWindow.qml:46-64`, `MouseArea`
   with only `cursorShape` + `onClicked`.
4. Fix: when `!Config.bar.activeWindow.showOnHover` (i.e. the click-to-open mode that
   builds the MouseArea), back it with a `StateLayer` for hover wash + ripple; keep the
   `showOnHover` mode purely pointer-driven.
5. Key: consistency fix, reuse `StateLayer`. No new key (mode already gated by
   `Config.bar.activeWindow.showOnHover`).
6. Risk: low.

### F7: Settings-GUI buttons cross-fade on hover but have NO press state
1. `NButton`/`NIconButton` cross-fade bg+fg on hover (good) but have no pressed/active
   visual, clicking produces no scale, no pressed-tone, no ripple. Feels less tactile
   than noctalia, whose shared Button flips to `Primary` on press.
2. Reference: noctalia Button resolves a distinct **pressed** state → `Primary` bg
   (`noctalia:src/ui/controls/button.cpp:540-543`; pressed palette entries
   `:42-45,61-63,98-100`), cross-faded over `Style::animFast`.
3. Ryoku current: `shell/settingsgui/Widgets/NButton.qml:59-74` and
   `NIconButton.qml:55-57` switch only on `hovered`/`hovering`; no `down`/pressed
   branch; MouseArea (`NButton.qml:134-167`) never sets a pressed flag.
4. Fix: add a `pressed` branch (MouseArea `pressed` → darker/`mPrimary` tone or
   `scale: 0.97`) to both, cross-faded with the existing `Style.animationFast` /
   `OutCubic` Behaviors already present.
5. Key: consistency fix reusing `Style.animationFast` token. No new config key.
6. Risk: low. (Note: the settings GUI uses its own feedback convention, N-widget
   colour cross-fade, separate from the shell's `StateLayer`; acceptable as a distinct
   surface, but the missing press state is a real parity gap.)

### F8: StateLayer ripple + hover wash ignore `appearance.reduceMotion` (cleanup)
1. `StateLayer`'s ripple and hover-fade set `duration:` *explicitly*, bypassing `Anim`'s
   reduce-motion zero-duration path; with reduce-motion ON the ripple still animates.
2. Reference: ryoku's own `Anim.qml:23-24` zeroes duration when
   `GlobalConfig.appearance.reduceMotion`, but only when the duration is left to the
   computed binding.
3. Ryoku current: `shell/components/StateLayer.qml:79` (rippleAnim `duration:
   ...expressiveSlowEffects * 2`) and `:187` (stateOpacity Behavior `duration:
   ...expressiveDefaultEffects`) hard-set duration.
4. Fix: gate both durations on `GlobalConfig.appearance.reduceMotion ? 0 : <token>`.
5. Key: wires to the **existing** `appearance.reduceMotion`
   (`plugin/.../appearanceconfig.hpp:242`). No new key.
6. Risk: low. Overlaps the already-shipped reduce-motion work, list as cleanup, not a
   feature.

---

## Optional new key (only if tunability is wanted)

The state-layer hover/ripple opacities are hardcoded (`StateLayer.qml:14`
`stateOpacity ... 0.08`, `:49` ripple `0.1`). If a user-facing "interaction intensity"
control is desired, add `CONFIG_GLOBAL_PROPERTY(qreal, stateLayerOpacity, 0.08)` (and
optionally `pressOpacity`) under a new `AppearanceInteraction` sub-object in
`plugin/src/Ryoku/Config/appearanceconfig.hpp` (next to `AppearanceTransparency`,
`:223-234`) and bind `StateLayer.stateOpacity` to it. Not required for parity, the
references hardcode these too, so default recommendation is **no new key**; ship F1–F6
as consistency fixes reusing `StateLayer`.

## Verification hooks for Main
- After each bar fix: hover + click the widget; confirm M3 wash appears and ripple
  pulses, and that the existing popout still opens (bar `childAt` hit-test intact).
- Toggle `appearance.reduceMotion`: after F8, ripple/hover-fade should snap (0 ms).
- Confirm no implicit-size changes on Tray/Workspaces (bar layout + popout geometry).
