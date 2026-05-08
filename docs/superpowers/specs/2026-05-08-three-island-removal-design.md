# Three-Island Topbar Removal

**Date:** 2026-05-08
**Owner:** Carlos (ryoku-arch maintainer)
**Status:** Design, pending user review

## Goal

Fully remove the three-island topbar style (`bar.cornerStyle == 4`) and every user-facing or documentation mention of "three-island" / "Dynamic Island". The `Mod+S` toolkit (the `RyokuToolsMode` palette and its supporting plumbing) must keep working byte-identically and is to be left literally untouched. Improvements that decouple the toolkit from the legacy folder layout are explicitly **out of scope** for this change and will be done in a follow-up.

## Non-Goals

- No refactor or rename of the `Mod+S` toolkit.
- No new bar style. Existing styles (Hug / Float / Rect / Card, values `0`–`3`) are unchanged.
- No change to the `Mod+S` keybind, IPC handler, `GlobalStates.toolsModeOpen`, or `bar.dynamicIsland.tools.*` config schema.

## Toolkit Carve-Out (Untouched)

These paths and identifiers are off-limits in this change:

- `shell/modules/bar/threeIsland/dynamicIsland/tools/` (whole directory)
  - `qmldir`, `RyokuToolsMode.qml`, `ToolButton.qml`, `ToolRegistry.qml`
- `shell/services/ToolsModeService.qml`
- `shell/scripts/lib/ipc-registry.sh` `[toolsMode]=` entry
- `GlobalStates.toolsModeOpen` in `shell/GlobalStates.qml`
- `shell/shell.qml` line that pins `_toolsModeService: ToolsModeService`
- `config/niri/config.d/70-binds.kdl` and `shell/defaults/niri/config.d/70-binds.kdl`: the `Mod+S { spawn "ryoku-shell" "toolsMode" "toggle"; }` line
- `shell/modules/bar/UtilButtons.qml` line 5: `import qs.modules.bar.threeIsland.dynamicIsland.tools` (kept verbatim, moves later)
- Config schema: `bar.dynamicIsland.enabled`, `bar.dynamicIsland.tools.*`, `bar.dynamicIsland.musicPopupContinuous`
- The `RyokuToolsMode.qml` header comment about "lives INSIDE the center notch" is **not** edited, stale wording is acceptable until the follow-up.

The `threeIsland/` and `threeIsland/dynamicIsland/` directories survive on disk as containers because the `tools/` subtree must stay where it is.

## Files to Delete

### Three-island bar QML (entire bar style implementation)

- `shell/modules/bar/threeIsland/RyokuTopFrame.qml`
- `shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml`
- `shell/modules/bar/threeIsland/RyokuLeftIsland.qml`
- `shell/modules/bar/threeIsland/RyokuRightIsland.qml`
- `shell/modules/bar/threeIsland/RyokuCenterIsland.qml`
- `shell/modules/bar/threeIsland/RyokuClock.qml`
- `shell/modules/bar/threeIsland/RyokuDateLabel.qml`
- `shell/modules/bar/threeIsland/SecPulseIndicator.qml` *(see Open Question 1)*
- `shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/CavaWaveform.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/pills/IdleStatePill.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/pills/MusicStatePill.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/pills/MusicHoverPopup.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/pills/RecordingStatePill.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/pills/ScreenshotToastPill.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/pills/TimerStatePill.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/pills/VoiceSearchPill.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/pills/` (empty after the above; remove the directory)

### SecPulse service & test (conditional on Open Question 1)

- `shell/services/RyokuSecPulse.qml`
- `shell/services/ryoku_sec_pulse.js`
- `tests/ryoku-sec-pulse-listeners.sh`

### Tests

- `tests/topbar-three-island.sh` (whole file)

### Docs (three-island specs / plans)

- `docs/superpowers/specs/2026-05-07-dynamic-island-design.md`
- `docs/superpowers/plans/2026-05-07-dynamic-island-implementation.md`
- `docs/superpowers/specs/2026-05-07-listening-ports-hover-design.md`
- `docs/superpowers/plans/2026-05-07-listening-ports-hover.md`

## Files to Edit

### `shell/modules/bar/Bar.qml`

- Remove line 15: `import qs.modules.bar.threeIsland`
- Remove the `useThreeIsland` property (lines ~121–123)
- Replace `sourceComponent: barContent.useThreeIsland ? threeIslandContentComponent : barContentComponent` with `sourceComponent: barContentComponent`
- Remove the `threeIslandContentComponent` Component block (lines ~152–155)
- In the `roundDecorators` Loader (`active:` line ~187), drop the `|| (Config.options?.bar?.cornerStyle ?? 0) === 4` clause and the trailing `// Hug or Three-Island` comment. Keep the Hug check (`=== 0`); update comment to `// Hug only`.
- `exclusiveZone` (line ~74) currently checks `=== 1 || === 3` (Float and Card) for extra gap padding, those values are unrelated to three-island. **No edit required** unless a `=== 4` clause exists at execution time (verify by reading the file).

### `shell/modules/common/Config.qml`

- Line 635 comment: remove `| 4: Three-Island (TODO: surface as configurator choice ...)` from the `cornerStyle` doc comment. Default `cornerStyle: 0` stays.
- Leave `bar.dynamicIsland.tools.*`, `bar.dynamicIsland.enabled`, and `bar.dynamicIsland.musicPopupContinuous` declarations alone.
- Remove `bar.dynamicIsland.states.*` and `bar.dynamicIsland.statePrecedence` declarations if present (verify by reading the JsonObject during execution).

### `shell/defaults/config.json`

- `"cornerStyle": 4` → `"cornerStyle": 0`
- Inside the `dynamicIsland` block, delete the `states` object and `statePrecedence` array. Keep `enabled`, `tools`, and `musicPopupContinuous`.

### `install/config/ryoku-shell-branding.sh`

- Line 171 (`.bar.cornerStyle = 4`) → `.bar.cornerStyle = 0`
- Lines 177–182 (the six `.bar.dynamicIsland.states.*` and `.bar.dynamicIsland.statePrecedence` initializers): delete
- Lines 232–233 (the `.bar.cornerStyle =  if (.bar.dynamicIsland == null …) then 4 elif … then 4 else …` conditional): replace with `.bar.cornerStyle = (.bar.cornerStyle // 0)`
- Lines 239–244 (`put_default(["bar","dynamicIsland","states",…])` and the `statePrecedence` put_default): delete
- If Open Question 1 resolves to **delete SecPulse**, also delete lines 173, 203–207, 235, 265–269 (`bar.modules.secPulse` and `bar.secPulse.*` defaults)

### `shell/welcome.qml`

- Around line 1225: remove the `{ displayName: Translation.tr("Three-Island"), icon: "view_column_2", value: 4 }` entry from the bar-style picker `options` array
- Verify the four remaining options (Hug / Float / Full / Card) render correctly with no trailing comma

### `shell/modules/settings/BarConfig.qml`

- Lines 19–21: delete `isThreeIslandStyle`, `threeIslandOnBottom`, `threeIslandOnVertical` properties
- Around lines 173–185: delete the two `ConflictNote` blocks gated on `threeIslandOnBottom || threeIslandOnVertical` and `isThreeIslandStyle`
- Around line 196 (the `ConfigSpinBox` for "Custom bar rounding"): remove `enabled: !root.isThreeIslandStyle` and `opacity: enabled ? 1 : 0.5`
- Sweep the rest of the file for any other `isThreeIslandStyle` reference and remove the gating
- If a "Dynamic Island" settings card exists that targets the bar's center-notch states (states/statePrecedence/voiceSearch/recording/timer/screenshotToast/music), remove that card. Keep any "Dynamic Island Tools" card that drives `bar.dynamicIsland.tools.*`.

### `shell/modules/settings/QuickConfig.qml`

- Already exposes only Hug/Float/Rect/Card, no edit expected. Verify during execution.

### `migrations/1778022724.sh`

- Replace body with a no-op stub plus a comment explaining it is retired (so any user who has not yet run it doesn't get re-set to cornerStyle 4). The file must remain present or the migration runner's bookkeeping breaks.

### `migrations/1778252246.sh`

- Keep the `Mod+S` niri keybind restoration block (the `if ! grep -qE 'Mod\+S[[:space:]]*\{[[:space:]]*spawn .*"toolsMode"' …` portion).
- Remove any block that restores `bar.dynamicIsland.states` or `bar.dynamicIsland.statePrecedence` defaults (verify against the file during execution).

### `tests/dynamic-island-ipc.sh`

- Keep all assertions about `target: "toolsMode"`, the `[toolsMode]=` IPC registry entry, the `Mod+S` niri bind, the `GlobalStates.toolsModeOpen` property, and the three QML files (`ToolRegistry`, `ToolButton`, `RyokuToolsMode`).
- Update the `defaults/config.json` jq assertion (line 35–36): drop the `bar.cornerStyle == 4` part if present and keep only `bar.dynamicIsland.enabled == true and bar.dynamicIsland.tools.enabled == true and bar.dynamicIsland.tools.keybind == "Mod+S"`.

### `tests/sidebar-openvpn.sh`

- Lines 73–74: delete the two `assert_contains` lines that reference `shell/modules/bar/threeIsland/SecPulseIndicator.qml` (file is being deleted).

### `tests/ryoku-shell-branding.sh`

- If Open Question 1 resolves to **delete SecPulse**, prune the `secPulse:` section (lines ~126 and ~151–154) and any matching jq assertions.

### `docs/keybindings.md`

- Line 27: rephrase `Mod+S` row to: `| `Mod+S` | Toggle the toolkit pill (screenshot, record, lens, color picker, mic, OSK, caffeine, ...). |`, drop "Dynamic Island".

### `docs/ui-patterns.md`

- Line 113 row pointing at `shell/modules/bar/threeIsland/SecPulseIndicator.qml`: remove the row.
- Line 170 mention of "required feature keybinds like `Mod+S` for Dynamic Island tools": rephrase to "required feature keybinds like `Mod+S` for the toolkit".

### `shell/docs/IPC.md`

- Line 119: replace "Dynamic Island tools mode. Toggles a wide tools pill in the topbar center notch (Mod+S)." with "Toolkit mode. Toggles the wide tools pill in the topbar (Mod+S).".
- Line 135: replace "Used by the Dynamic Island to flash a brief success toast." with "Used to flash a brief screenshot success toast." (or remove the dependent toast wiring if Open Question 2 resolves that way).

## New Migration

**Filename:** `migrations/1778256447.sh` (timestamp greater than the latest existing `1778252246`)

**Behaviour (idempotent):**

```sh
# Migrate users off the removed Three-Island bar style.
# - bar.cornerStyle 4 → 0 (Hug). Other values are left alone.
# - Strip orphaned bar.dynamicIsland.states and bar.dynamicIsland.statePrecedence
#   keys (the Mod+S toolkit's bar.dynamicIsland.tools.* schema is preserved).
# Targets the active user-shell config used by the rest of the migrations
# in this directory (resolve via the same helper used by 1778252246.sh).
```

The script must:
1. Locate the user shell config via the same discovery pattern used by sibling migrations (`$RYOKU_PATH` / `$HOME` / runtime-discovered path, never hard-code a personal home directory).
2. Patch the JSON with `jq` if `bar.cornerStyle` equals `4` → set to `0`.
3. Patch the JSON with `jq` to `del(.bar.dynamicIsland.states)` and `del(.bar.dynamicIsland.statePrecedence)` when those keys exist.
4. Be safe to re-run: skip when neither condition matches; never error if the config file is absent.
5. If Open Question 1 resolves to delete SecPulse: also `del(.bar.modules.secPulse)` and `del(.bar.secPulse)` if present.

Pre-commit-hook compliance: no Co-Authored-By trailer, no personal home paths.

## Verification

The change is complete when **all** of the following pass:

1. `bash tests/dynamic-island-ipc.sh` exits 0 (after its `defaults/config.json` assertion is updated).
2. `tests/topbar-three-island.sh` is gone and no script references it (`grep -rn 'topbar-three-island' tests/ scripts/ install/ bin/ iso/`).
3. `tests/sidebar-openvpn.sh` exits 0 with the two SecPulseIndicator assertions removed.
4. `bash tests/ryoku-shell-branding.sh` exits 0 (with the secPulse section pruned if Open Question 1 resolves that way).
5. The repo-wide grep `grep -rIn -E 'threeIsland|three-island|three_island|Three-Island|Dynamic Island|dynamic island' --include='*.qml' --include='*.sh' --include='*.md' --include='*.kdl' --include='*.json' --include='*.js'` returns matches **only** in:
   - the toolkit folder `shell/modules/bar/threeIsland/dynamicIsland/tools/`
   - import statements pointing at that toolkit folder (e.g., `UtilButtons.qml`)
   - kept `bar.dynamicIsland.{enabled,tools,musicPopupContinuous}` config keys
   - the new migration file's idempotency markers
6. `quickshell` launches with the default `shell/defaults/config.json` and renders the bar in Hug style with no QML errors.
7. Pressing `Mod+S` opens the toolkit pill (rendered by `UtilButtons`) over the regular bar; all 13 currently-enabled tool buttons appear; right-click and Esc both close it.
8. The bar-style picker in Settings → Bar exposes only Hug / Float / Rect / Card.
9. The bar-style picker in Welcome exposes only Hug / Float / Full / Card.
10. The repo's pre-commit hook passes (no Co-Authored-By trailer, no personal home paths in any committed content).

## Open Questions

### 1. SecPulse indicator: delete or preserve?

`shell/modules/bar/threeIsland/SecPulseIndicator.qml` is the security-pulse widget (TCP listener count, Tailscale/OpenVPN status, public IP indicator). It is **only** consumed by the three-island bar, `RyokuRightIsland.qml` mounts it. Its supporting service `shell/services/RyokuSecPulse.qml` and parser `shell/services/ryoku_sec_pulse.js` likewise have no other consumers (`RyokuOpenVpn.qml` is unrelated and stays, it powers the sidebar OpenVPN UI).

By the literal "remove all mentions for [three-island]" instruction the indicator and its service should be deleted, along with the orphaned `bar.modules.secPulse` and `bar.secPulse.*` config keys, plus `tests/ryoku-sec-pulse-listeners.sh`.

But ryoku-arch is positioned as a security workstation, so this widget's *functionality* may be valuable enough to keep, relocated to the regular bar, even though that's a bigger change.

**Default in this spec:** delete (matches the literal request and keeps the change small). The follow-up "improve toolkit / move out of legacy folder" pass can also re-introduce a SecPulse indicator in the regular bar if desired.

**Reviewer action:** confirm delete, or override to "preserve", in which case the spec gets a §"SecPulse re-mounting" section before plan-writing.

### 2. ScreenshotToastPill ↔ screenshot IPC

`shell/docs/IPC.md` line 135 documents the screenshot completion event as something the Dynamic Island consumes for a toast. After removal there is no toast consumer. The IPC channel itself stays (other consumers exist, verify during execution). The doc line gets reworded; no functional impact expected. Flagging only because the wording change is mechanical and might mask a missed dependent.

**Default in this spec:** reword the doc line. If the verification grep reveals additional consumers tied to the toast, surface them then.

## Out of Scope

- Renaming `bar.dynamicIsland.tools.*` to `bar.toolsMode.*`.
- Moving `shell/modules/bar/threeIsland/dynamicIsland/tools/` to a non-legacy path.
- Refreshing the `RyokuToolsMode.qml` header comment.
- Adding new bar styles or visual treatments.
- Re-introducing a SecPulse indicator in the regular bar (covered by Open Question 1's "preserve" override path, if chosen).
