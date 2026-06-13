# Stage 0 Inventory: Design Map: `Appearance` (legacy) → Ryoku Tokens/Colours

**Axis:** the legacy design singleton `shell/modules/common/Appearance.qml` (the end-4 / "ii"
era shell-wide theme API) mapped onto the canonical layer: `Ryoku.Config` `Tokens`
(`shell/plugin/src/Ryoku/Config/tokens.hpp`, `anim.hpp`) + `services/Colours.qml`
(`Colours.palette` / `Colours.tPalette`).

**Method:** static walk of `*.qml` under `shell/modules`, `shell/components`, `shell/dashboard`,
matching `\bAppearance\.<member>`. Counts are exact occurrence counts (a member referenced
twice on one line counts twice).

**Totals:** `Appearance.*` is referenced **1057×** across **49 files**, over **167 distinct
member-paths**. Top-level buckets:

| bucket | refs | files |
|---|---:|---:|
| `Appearance.animation.*` | 271 | 29 |
| `Appearance.colors.col*` | 196 | 34 |
| `Appearance.angel.*` | 100 | 20 |
| `Appearance.angelEverywhere` (ternary gate) | 92 | 20 |
| `Appearance.font.*` | 71 | 18 |
| `Appearance.inirEverywhere` (ternary gate) | 70 | 18 |
| `Appearance.inir.*` | 65 | 18 |
| `Appearance.animationsEnabled` | 51 | 14 |
| `Appearance.auroraEverywhere` (ternary gate) | 34 | 15 |
| `Appearance.rounding.*` | 29 | 20 |
| `Appearance.aurora.*` | 22 | 13 |
| `Appearance.m3colors.*` | 20 | 12 |
| `Appearance.effectsEnabled` | 15 | 5 |
| `Appearance.sizes.*` | 15 | 3 |
| `Appearance.animationCurves.*` | 3 | 3 |
| `Appearance.calcEffectiveDuration` | 2 | 2 |
| `Appearance.backgroundTransparency` | 1 | 1 |

`Appearance.qml` is *already* a thin façade over the canonical layer, every member is
defined in terms of `Colours.palette.*` / `Tokens.*` (see `Appearance.qml:31-248`). Migration
= deleting the façade and rewriting consumers to the canonical name. No semantic re-derivation
needed except where flagged **NEEDS NEW TOKEN**.

---

## 1. Colours: `Appearance.colors.col*` (196 refs / 34 files) → `Colours.palette.*`

Each `col*` is a verbatim alias of a `Colours.palette.m3*` role (`Appearance.qml:32-73`). The
"Layer0..4 / Hover / Active" ladder collapses onto the M3 surface-container tones. Where the
target surface is meant to be translucent, the consumer should pull from `Colours.tPalette.*`
(the transparentized mirror) instead of `palette`, flagged below.

| Appearance member | refs | canonical (`Colours.palette.*` unless noted) | rep. site | NEEDS NEW TOKEN? |
|---|---:|---|---|---|
| `colors.colLayer0` | 1 | `m3surface` (or `tPalette.m3surface`) | `modules/ii/overlay/notifications/Notifications.qml:96` | no |
| `colors.colLayer0Base` | 6 | `m3surface` | `common/widgets/GlassBackground.qml:93` | no |
| `colors.colLayer0Border` | 1 | `m3outlineVariant` | `common/widgets/NotificationItem.qml:132` | no |
| `colors.colLayer1` | 4 | `m3surfaceContainer` | `common/widgets/GlassBackground.qml:16` | no |
| `colors.colLayer1Base` | 2 | `m3surfaceContainer` | `modules/ii/overlay/StyledOverlayWidget.qml:208` | no |
| `colors.colLayer1Hover` | 4 | `m3surfaceContainerHigh` | `common/widgets/SecondaryTabButton.qml:22` | no |
| `colors.colLayer1Active` | 1 | `m3surfaceContainerHighest` | `common/widgets/SecondaryTabButton.qml:24` | no |
| `colors.colLayer2` | 8 | `m3surfaceContainerHigh` | `common/widgets/NotificationGroup.qml:154` | no |
| `colors.colLayer2Base` | 1 | `m3surfaceContainerHigh` | `modules/ii/overlay/OverlayBackground.qml:10` | no |
| `colors.colLayer2Hover` | 3 | `m3surfaceContainerHighest` | `modules/ii/sidebarRight/volumeMixer/VolumeDialogContent.qml:25` | no |
| `colors.colLayer2Active` | 3 | `m3surfaceContainerHighest` | `…/VolumeDialogContent.qml:26` | no |
| `colors.colLayer3` | 10 | `m3surfaceContainerHighest` | `common/widgets/NotificationItem.qml:126` | no |
| `colors.colLayer3Hover` | 10 | `m3surfaceContainerHighest` | `common/widgets/StyledToolTipContent.qml:40` | no |
| `colors.colLayer3Active` | 8 | `m3surfaceContainerHighest` | `modules/ii/overlay/discord/Discord.qml:79` | no |
| `colors.colLayer4` | 1 | `m3surfaceContainerHighest` | `common/widgets/NotificationActionButton.qml:21` | no |
| `colors.colLayer4Hover` | 1 | `m3surfaceContainerHighest` | `…/NotificationActionButton.qml:27` | no |
| `colors.colLayer4Active` | 1 | `m3surfaceContainerHighest` | `…/NotificationActionButton.qml:33` | no |
| `colors.colOnLayer0` | 1 | `m3onSurface` | `modules/ii/overlay/notifications/Notifications.qml:82` | no |
| `colors.colOnLayer1` | 11 | `m3onSurface` | `common/widgets/MaterialShapeWrappedMaterialSymbol.qml:19` | no |
| `colors.colOnLayer2` | 18 | `m3onSurface` | `common/widgets/NotificationGroup.qml:299` | no |
| `colors.colOnLayer3` | 3 | `m3onSurface` | `common/widgets/NotificationItem.qml:169` | no |
| `colors.colOnPrimary` | 1 | `m3onPrimary` | `modules/ii/overlay/recorder/Recorder.qml:549` | no |
| `colors.colOnPrimaryContainer` | 3 | `m3onPrimaryContainer` | `common/widgets/NotificationAppIcon.qml:44` | no |
| `colors.colOnSecondaryContainer` | 8 | `m3onSecondaryContainer` | `common/widgets/IconToolbarButton.qml:21` | no |
| `colors.colOnSurface` | 4 | `m3onSurface` | `modules/ii/overlay/OverlayTaskbar.qml:129` | no |
| `colors.colOnSurfaceVariant` | 3 | `m3onSurfaceVariant` | `common/widgets/IconToolbarButton.qml:21` | no |
| `colors.colOutline` | 1 | `m3outline` | `common/widgets/NotificationItem.qml:131` | no |
| `colors.colOutlineVariant` | 8 | `m3outlineVariant` | `common/widgets/ContextMenu.qml:197` | no |
| `colors.colPrimary` | 11 | `m3primary` | `common/widgets/ContextMenu.qml:220` | no |
| `colors.colPrimaryContainer` | 2 | `m3primaryContainer` | `common/widgets/NotificationAppIcon.qml:30` | no |
| `colors.colError` | 7 | `m3error` | `modules/ii/overlay/OverlayTaskbar.qml:143` | no |
| `colors.colErrorActive` | 1 | `m3error` | `modules/ii/overlay/recorder/Recorder.qml:273` | no |
| `colors.colErrorContainer` | 4 | `m3errorContainer` | `modules/ii/overlay/recorder/Recorder.qml:91` | no |
| `colors.colOnErrorContainer` | 4 | `m3onErrorContainer` | `…/Recorder.qml:119` | no |
| `colors.colScrim` | 1 | `m3scrim` | `modules/ii/overlay/OverlayContent.qml:37` | no |
| `colors.colShadow` | 2 | `m3shadow` | `common/widgets/ScrollEdgeFade.qml:10` | no |
| `colors.colSecondaryContainer` | 11 | `m3secondaryContainer` | `common/widgets/IconToolbarButton.qml:12` | no |
| `colors.colSecondaryContainerHover` | 4 | `m3secondaryContainer` | `…/IconToolbarButton.qml:16` | no |
| `colors.colSecondaryContainerActive` | 4 | `m3secondaryContainer` | `…/IconToolbarButton.qml:20` | no |
| `colors.colSubtext` | 16 | `m3onSurfaceVariant` | `common/widgets/MaterialPlaceholderMessage.qml:113` | no |
| `colors.colSurfaceContainer` | 2 | `m3surfaceContainer` | `common/widgets/ContextMenu.qml:163` | no |
| `colors.colSurfaceContainerHighest` | 1 | `m3surfaceContainerHighest` | `common/widgets/ContextMenu.qml:174` | no |

> Note the lossy collapse: `colLayer2/2Base`, `colLayer3/3Hover/3Active`, `colLayer4*`,
> `colSecondaryContainer{,Hover,Active}` all already resolve to the *same* tone. The Hover/Active
> distinctions are dead and can be dropped during migration (no canonical equivalent is needed -
> they are just `m3surfaceContainerHighest` / `m3secondaryContainer`).

## 2. `Appearance.m3colors.*` (20 refs / 12 files) → `Colours.palette.*`

| member | refs | canonical | rep. site | NNT? |
|---|---:|---|---|---|
| `m3colors.darkmode` | 2 | `!Colours.light` | `common/widgets/ScrollEdgeFade.qml:9` | no |
| `m3colors.m3onPrimary` | 2 | `palette.m3onPrimary` | `common/widgets/StyledSlider.qml:51` | no |
| `m3colors.m3onSecondaryContainer` | 2 | `palette.m3onSecondaryContainer` | `common/widgets/StyledSlider.qml:49` | no |
| `m3colors.m3onSurface` | 8 | `palette.m3onSurface` | `common/widgets/ContextMenu.qml:253` | no |
| `m3colors.m3onSurfaceVariant` | 3 | `palette.m3onSurfaceVariant` | `common/widgets/NotificationActionButton.qml:38` | no |
| `m3colors.m3outline` | 1 | `palette.m3outline` | `common/widgets/StyledTextArea.qml:13` | no |
| `m3colors.m3primary` | 1 | `palette.m3primary` | `common/widgets/shapes/ShapeCanvas.qml:7` | no |
| `m3colors.m3surfaceContainer` | 1 | `palette.m3surfaceContainer` | `modules/ii/overlay/OverlayTaskbar.qml:23` | no |

## 3. `Appearance.rounding.*` (29 refs / 20 files) → `Tokens.rounding.*`

(`Appearance.qml:87-95`; `tokens.hpp:44-57`, extraSmall 4 / small 12 / normal 17 / large 25 / full 1000)

| member | refs | canonical | rep. site | NNT? |
|---|---:|---|---|---|
| `rounding.verysmall` | 1 | `Tokens.rounding.extraSmall` | `common/widgets/StyledToolTipContent.qml:35` | no |
| `rounding.unsharpen` | 1 | `Tokens.rounding.extraSmall` | `common/widgets/StyledSlider.qml:52` | no |
| `rounding.small` | 14 | `Tokens.rounding.small` | `common/widgets/ContextMenu.qml:214` | no |
| `rounding.normal` | 6 | `Tokens.rounding.normal` | `common/widgets/ContextMenu.qml:168` | no |
| `rounding.large` | 1 | `Tokens.rounding.large` | `modules/ii/overlay/OverlayTaskbar.qml:26` | no |
| `rounding.full` | 5 | `Tokens.rounding.full` | `common/widgets/NotificationAppIcon.qml:97` | no |
| `rounding.windowRounding` | 1 | `Tokens.rounding.large` | `modules/ii/overlay/StyledOverlayWidget.qml:36` | no |

> `verysmall`/`unsharpen` are duplicate aliases of `extraSmall`; `windowRounding` is an alias of
> `large`. Collapse on migration.

## 4. `Appearance.font.*` (71 refs / 18 files) → `Tokens.font.*`

(`Appearance.qml:97-125`. **Critical:** `pixelSize.*` applies a pt→px ×1.333 conversion of
`Tokens.font.size.*`, which are POINT sizes, `Appearance.qml:98-105`.)

| member | refs | canonical | rep. site | NNT? |
|---|---:|---|---|---|
| `font.pixelSize.smallest` | 2 | `Tokens.font.size.smaller` ×pxScale | `modules/ii/overlay/notifications/Notifications.qml:95` | **YES (px)** |
| `font.pixelSize.smaller` | 9 | `Tokens.font.size.smaller` ×pxScale | `common/widgets/NotificationGroup.qml:277` | **YES (px)** |
| `font.pixelSize.smallie` | 3 | `Tokens.font.size.smaller` ×pxScale | `modules/ii/overlay/notifications/Notifications.qml:109` | **YES (px)** |
| `font.pixelSize.small` | 16 | `Tokens.font.size.small` ×pxScale | `common/widgets/ContextMenu.qml:270` | **YES (px)** |
| `font.pixelSize.normal` | 9 | `Tokens.font.size.normal` ×pxScale | `common/widgets/ContextMenu.qml:251` | **YES (px)** |
| `font.pixelSize.large` | 2 | `Tokens.font.size.large` ×pxScale | `common/widgets/MaterialPlaceholderMessage.qml:100` | **YES (px)** |
| `font.pixelSize.larger` | 5 | `Tokens.font.size.larger` ×pxScale | `common/widgets/NotificationItem.qml:281` | **YES (px)** |
| `font.pixelSize.huge` | 5 | `Tokens.font.size.extraLarge` ×pxScale | `common/widgets/SecondaryTabButton.qml:166` | **YES (px)** |
| `font.family.main` | 4 | `Tokens.font.family.sans` | `common/widgets/StyledText.qml:13` | no |
| `font.family.numbers` | 6 | `Tokens.font.family.mono` | `common/widgets/StyledSlider.qml:310` | no |
| `font.family.monospace` | 1 | `Tokens.font.family.mono` | `modules/ii/overlay/recorder/Recorder.qml:120` | no |
| `font.variableAxes.main` | 4 | `({})` stub, drop / `font.variableAxis` rich-axis | `common/widgets/StyledText.qml:19` | **YES** |
| `font.variableAxes.numbers` | 5 | `({})` stub, drop / `font.variableAxis` rich-axis | `common/widgets/StyledSlider.qml:311` | **YES** |

> **NEEDS NEW TOKEN, pixel sizes.** Ryoku `Tokens.font.size.*` are point sizes; every
> `font.pixelSize.*` consumer (51 refs) sets `font.pixelSize:` on Text and expects px. A clean
> cutover needs either a `Tokens.font.pixelSize.*` accessor (pt→px) or each callsite switched to
> `font.pointSize: Tokens.font.size.*`. The `smallest`/`smaller`/`smallie` trio all collapse to
> `smaller`. `font.variableAxes.*` are empty `({})` stubs, no canonical token; drop the bindings
> (no Ryoku variable-axis token exists).

## 5. `Appearance.sizes.*` (15 refs / 3 files)

(`Appearance.qml:127-131`)

| member | refs | canonical | rep. site | NNT? |
|---|---:|---|---|---|
| `sizes.elevationMargin` | 2 (+1 bare `sizes`) | hardcoded `8` | `common/widgets/StyledRectangularShadow.qml:16` | **YES** |
| `sizes.spacingSmall` | 3 | `Tokens.spacing.small` (7) | `…/VolumeDialogContent.qml:65` | no |
| `sizes.spacingMedium` | 9 | `Tokens.spacing.normal` (12) | `…/VolumeDialogContent.qml:16` | no |

> `elevationMargin: 8` is a literal with no token; add `Tokens.spacing`/`Tokens.sizes` entry or
> inline the constant. Only 3 consumer files, so low blast radius.

## 6. `Appearance.animation.*` (271 refs / 29 files) → `Tokens.anim.*` / `Anim.Type`

(`Appearance.qml:133-172`. Each sub-object is `{ duration:int, type:Easing.BezierSpline, bezierCurve:var }`.
The two curves are `_curve=[0.34,0.80,0.34,1.00,1,1]` and `_decel=[0.05,0.7,0.1,1.0,1,1]`.
Matching `tokens.hpp:39-41,30-35`: `_curve` == `AnimCurves.expressiveDefaultEffects`,
`_decel` == `AnimCurves.emphasizedDecel`. Durations map to `Tokens.anim.durations.*`,
`tokens.hpp:109-118`.)

| member (sub-object, consumed as `.duration`/`.type`/`.bezierCurve`) | refs | dur | canonical | rep. site | NNT? |
|---|---:|---:|---|---|---|
| `animation.elementMoveFast` | 174 (4 bare) | 150 | `Tokens.anim.durations.expressiveFastEffects` + `Tokens.anim.expressiveDefaultEffects` (≈`Anim.FastSpatial` family) | `common/widgets/ContextMenu.qml:122` | no |
| `animation.elementMove` | 57 | 200 | `durations.expressiveDefaultEffects` (200) + `Tokens.anim.expressiveDefaultEffects` | `common/widgets/NotificationListView.qml:25` | no |
| `animation.elementMoveEnter` | 16 | 300 | `durations.expressiveSlowEffects` (300) + `Tokens.anim.emphasizedDecel` | `common/widgets/MaterialPlaceholderMessage.qml:32` | no |
| `animation.elementMoveExit` | 3 | 200 | `durations.expressiveDefaultEffects` + `Tokens.anim.expressiveDefaultEffects` | `common/widgets/ContextMenu.qml:132` | no |
| `animation.elementResize` | 9 | 200 | `durations.expressiveDefaultEffects` + `Tokens.anim.expressiveDefaultEffects` | `common/widgets/RippleButton.qml:57` | no |
| `animation.clickBounce` | 6 | 200 | `durations.expressiveDefaultEffects` + `Tokens.anim.expressiveDefaultEffects` | `common/widgets/GroupButton.qml:67` | no |
| `animation.scroll` | 6 | 200 | `durations.expressiveDefaultEffects` + `Tokens.anim.emphasizedDecel` | `common/widgets/StyledFlickable.qml:41` | no |

> No new token required, all durations/curves exist. But this bucket is the **highest-effort**
> migration: consumers destructure `.duration` / `.type` / `.bezierCurve` into hand-rolled
> `NumberAnimation`/`Behavior` blocks rather than using the canonical `Anim {}` component
> (`shell/components/Anim.qml`). Cleanest target is to replace each `Behavior`/`NumberAnimation`
> with `Anim { type: Anim.<Type> }`, which reads `Tokens.anim` internally. The pt-exact curve
> mapping (`_curve`→`expressiveDefaultEffects`, `_decel`→`emphasizedDecel`) means values are
> preserved.

## 7. `Appearance.animationCurves.*` (3 refs / 3 files) → `Tokens.anim.*`

(`Appearance.qml:174-177`)

| member | refs | canonical | rep. site | NNT? |
|---|---:|---|---|---|
| `animationCurves.standardDecel` | 1 | `Tokens.anim.emphasizedDecel` (value is `_decel`, **not** `standardDecel`) | `common/widgets/SecondaryTabButton.qml:31` | no (name mismatch) |
| `animationCurves.expressiveFastSpatial` | 2 | `Tokens.anim.expressiveDefaultEffects` (value is `_curve`, **not** FastSpatial) | `common/widgets/NotificationGroup.qml:171` | no (name mismatch) |

> ⚠️ Naming trap: the legacy names do **not** match their Ryoku-token namesakes. Map by *value*
> (curve control points), not by name, or the animation feel will shift.

## 8. Scalar flags

| member | refs | files | canonical | rep. site | NNT? |
|---|---:|---:|---|---|---|
| `animationsEnabled` | 51 | 14 | `!(GameMode.enabled && GlobalConfig.gameMode.shellAnimations)` (`Appearance.qml:22-23`) | `common/widgets/RippleButton.qml` | no |
| `effectsEnabled` | 15 | 5 | same expression (`Appearance.qml:24`) | `common/widgets/GlassBackground.qml` | no |
| `calcEffectiveDuration(d)` | 2 | 2 | helper: `animationsEnabled ? d : 0` (`Appearance.qml:27-29`) |, | no |
| `backgroundTransparency` | 1 | 1 | hardcoded `0` → `GlobalConfig.appearance.transparency.*` | `modules/ii/...` | **maybe** |

> `animationsEnabled`/`effectsEnabled` are pure GameMode gates. A canonical home would be a
> `GameMode`-derived readonly or a `Tokens`/service helper; both inputs already exist, so no new
> token, just a relocation decision. `backgroundTransparency` is a dead `0`; `appearanceconfig.hpp`
> has an `AppearanceTransparency` subobject (`:247`) as the real home.

---

## Stage 2a: Dead-variant ternary inventory (collapse-to-Material)

`angelEverywhere`/`inirEverywhere`/`auroraEverywhere` are **hardwired `false`**
(`Appearance.qml:15-17`). Every consumer wraps them in a `cond ? variantValue : materialValue`
ternary (verified pattern, `common/widgets/IconToolbarButton.qml:9-21`). Because the flags are
const-false, **the variant branches are statically dead**, Stage 2a is: delete the ternary,
keep the trailing Material fallback, then delete the `angel`/`inir`/`aurora` sub-objects from
`Appearance.qml` (`:179-248`) and the `*Everywhere` flags.

**Gate-reference totals:** `angelEverywhere` 92 + `inirEverywhere` 70 + `auroraEverywhere` 34 =
**196 ternary gate references** across **22 distinct files** (union). Plus the variant *value*
reads that vanish with them: `angel.*` 100, `inir.*` 65, `aurora.*` 22 = **187** value refs.

**Files touched by Stage 2a (union of all `*Everywhere` sites), with gate-ref counts:**

| file | angel | inir | aurora |
|---|---:|---:|---:|
| `modules/common/widgets/ContextMenu.qml` | 8 | 8 | 1 |
| `modules/common/widgets/NotificationGroup.qml` | 7 | 8 | 7 |
| `modules/common/widgets/NotificationItem.qml` | 5 | 5 | 3 |
| `modules/common/widgets/IconToolbarButton.qml` | 3 | 5 | 3 |
| `modules/common/widgets/StyledSlider.qml` | 5 | 5 | 1 |
| `modules/common/widgets/StyledToolTipContent.qml` | 5 | 4 | 2 |
| `modules/common/widgets/NotificationActionButton.qml` | 4 | 4 | 3 |
| `modules/common/widgets/NotificationGroupExpandButton.qml` | 3 | 3 | 3 |
| `modules/common/widgets/MaterialShapeWrappedMaterialSymbol.qml` | 2 | 2 | 2 |
| `modules/common/widgets/RippleButton.qml` | 5 |, |, |
| `modules/common/widgets/StyledProgressBar.qml` | 3 |, |, |
| `modules/common/widgets/StyledRectangularShadow.qml` | 3 |, |, |
| `modules/common/widgets/AngelPartialBorder.qml` | 1 |, |, |
| `modules/common/widgets/GlassBackground.qml` | 1 | 1 | 1 |
| `modules/common/widgets/MaterialPlaceholderMessage.qml` |, | 8 |, |
| `modules/common/widgets/SecondaryTabBar.qml` |, | 2 |, |
| `modules/sidebarRight/notifications/NotificationStatusButton.qml` | 5 | 6 | 3 |
| `modules/ii/overlay/OverlayTaskbar.qml` | 15 | 4 |, |
| `modules/ii/overlay/StyledOverlayWidget.qml` | 14 | 2 | 2 |
| `modules/ii/overlay/OverlayBackground.qml` | 1 | 1 | 1 |
| `modules/ii/sidebarRight/volumeMixer/VolumeDialogContent.qml` | 1 | 1 | 1 |
| `modules/ii/sidebarRight/volumeMixer/VolumeMixerEntry.qml` | 1 | 1 | 1 |

> `AngelPartialBorder.qml` and `StyledProgressBar.qml`/`GlassBackground.qml`'s glass/inset-glow
> machinery exist *only* to serve the angel variant, once the gates are gone, those widgets
> (and `angel`'s glass/escalonado tokens) become deletable wholesale. Coordinate with SurfaceMap.

---

## Recommended first sub-stage (smallest cluster)

**Migrate `Appearance.m3colors.*` first**, only **20 refs across 12 files**, every one a
1:1 verbatim alias to `Colours.palette.m3*` (no Hover/Active collapse, no px conversion, no
ternary entanglement, no new token). It is the lowest-risk, lowest-blast-radius flip and
establishes the `Colours.palette` import path in the consumer files.

Immediately after, do **`rounding.*`** (29 refs / 20 files, all → `Tokens.rounding.*`, two
trivial alias collapses) and **`sizes.spacing*`** (12 refs / `Tokens.spacing.*`).

**Defer** the two hard buckets: `animation.*` (271 refs, requires `Anim {}`-component rewrites)
and `font.pixelSize.*` (51 refs, **needs a px token decision**). **Do Stage 2a (dead-variant
ternary collapse) before** the `colors.*` migration, collapsing the ternaries first strips
~196 gate refs + 187 variant value-reads, shrinking the `colors.*` surface to just its Material
fallback arm and avoiding double-editing the same lines.
