# Three-Island Topbar Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the three-island topbar style (`bar.cornerStyle == 4`) and every non-toolkit mention of "three-island" or "Dynamic Island", while leaving the `Mod+S` toolkit folder, schema, keybind, and IPC plumbing literally untouched.

**Architecture:** The three-island bar is gated by `cornerStyle == 4` in `shell/modules/bar/Bar.qml`. The toolkit (`shell/modules/bar/threeIsland/dynamicIsland/tools/`) is a sibling subtree that is also imported by the regular bar's `UtilButtons.qml`. We drop the cornerStyle-4 branch first, delete the now-orphan QML files, scrub config + welcome + settings UI of the option, add a migration that flips existing user configs from 4 to 0 (Hug), and prune docs/tests. The toolkit subtree stays at its current path even though its parent directories now exist solely as containers; a follow-up will rehome it.

**Tech Stack:** QML/Quickshell, jq-driven JSON migrations, bash test harness (`tests/*.sh`), markdown docs.

**Spec reference:** `docs/superpowers/specs/2026-05-08-three-island-removal-design.md`.

**Pre-commit hook constraints (apply to every commit body and every file in this repo):**
- No `Co-Authored-By:` trailer in commit messages.
- No em-dash (`,`, `:`, or `.` instead). The hook scans staged content including specs/plans/scripts/configs/docs.
- No hard-coded personal home paths (use `$HOME`, `$RYOKU_PATH`, runtime discovery).
- All commit messages here use a one-line subject plus optional body. Never add an authorship trailer.

---

## File Map

**Files to delete (final state):**
- `shell/modules/bar/threeIsland/RyokuTopFrame.qml`
- `shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml`
- `shell/modules/bar/threeIsland/RyokuLeftIsland.qml`
- `shell/modules/bar/threeIsland/RyokuRightIsland.qml`
- `shell/modules/bar/threeIsland/RyokuCenterIsland.qml`
- `shell/modules/bar/threeIsland/RyokuClock.qml`
- `shell/modules/bar/threeIsland/RyokuDateLabel.qml`
- `shell/modules/bar/threeIsland/SecPulseIndicator.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/CavaWaveform.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/pills/` (entire directory: 7 files)
- `shell/services/RyokuSecPulse.qml`
- `shell/services/ryoku_sec_pulse.js`
- `tests/topbar-three-island.sh`
- `tests/ryoku-sec-pulse-listeners.sh`
- `docs/superpowers/specs/2026-05-07-dynamic-island-design.md`
- `docs/superpowers/plans/2026-05-07-dynamic-island-implementation.md`
- `docs/superpowers/specs/2026-05-07-listening-ports-hover-design.md`
- `docs/superpowers/plans/2026-05-07-listening-ports-hover.md`

**Files to modify:**
- `shell/modules/bar/Bar.qml` (drop import + cornerStyle-4 branches + threeIsland Component)
- `shell/modules/common/Config.qml` (drop `dynamicIsland.states`, `dynamicIsland.statePrecedence`, `bar.modules.secPulse`, `bar.secPulse` JsonObject; rewrite `cornerStyle` comment)
- `shell/defaults/config.json` (cornerStyle 4 to 0; drop dynamicIsland.states/statePrecedence; drop modules.secPulse and secPulse block)
- `shell/welcome.qml` (drop "Three-Island" picker option)
- `shell/modules/settings/BarConfig.qml` (drop `isThreeIslandStyle`/`threeIslandOnBottom`/`threeIslandOnVertical`; drop two ConflictNote blocks; drop customRounding gating)
- `install/config/ryoku-shell-branding.sh` (cornerStyle defaults; drop states/statePrecedence/secPulse defaults)
- `migrations/1778022724.sh` (replace body with retired-stub; preserves migration runner bookkeeping)
- `migrations/1778252246.sh` (drop the `dynamicIsland.states`/`statePrecedence` restoration; keep Mod+S keybind restoration)
- `tests/dynamic-island-ipc.sh` (relax cornerStyle==4 assertion if present; keep the rest)
- `tests/sidebar-openvpn.sh` (drop two SecPulseIndicator `assert_contains` lines)
- `tests/ryoku-shell-branding.sh` (drop `secPulse` jq assertions)
- `docs/keybindings.md` (rephrase Mod+S row)
- `docs/ui-patterns.md` (drop SecPulseIndicator row; rephrase Mod+S mention)
- `shell/docs/IPC.md` (rephrase `toolsMode` and screenshot lines)

**Files to create:**
- `migrations/1778256447.sh` (cornerStyle 4 to 0; strip orphaned dynamicIsland.states/statePrecedence; strip secPulse keys)
- `tests/topbar-removal-regression.sh` (asserts the post-removal invariants; runs in CI alongside other tests)

**Files NOT touched (toolkit carve-out):**
- `shell/modules/bar/threeIsland/dynamicIsland/tools/qmldir`
- `shell/modules/bar/threeIsland/dynamicIsland/tools/RyokuToolsMode.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/tools/ToolButton.qml`
- `shell/modules/bar/threeIsland/dynamicIsland/tools/ToolRegistry.qml`
- `shell/services/ToolsModeService.qml`
- `shell/scripts/lib/ipc-registry.sh` (kept as-is)
- `shell/GlobalStates.qml` (`toolsModeOpen` property kept)
- `shell/shell.qml` (`_toolsModeService` reference kept)
- `shell/modules/bar/UtilButtons.qml` (keep the `import qs.modules.bar.threeIsland.dynamicIsland.tools` line verbatim)
- `config/niri/config.d/70-binds.kdl` and `shell/defaults/niri/config.d/70-binds.kdl` (Mod+S binding kept)

---

## Task 1: Add the regression test that asserts the final state

This is the goal contract. It should fail today and pass after Task 23.

**Files:**
- Create: `tests/topbar-removal-regression.sh`

- [ ] **Step 1: Write the regression test**

Create `tests/topbar-removal-regression.sh`:

```bash
#!/bin/bash
# Asserts the post-three-island-removal invariants.
# Run from any working directory; resolves repo root via BASH_SOURCE.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

# 1. Default cornerStyle is 0 (Hug), not 4 (Three-Island).
jq -e '.bar.cornerStyle == 0' shell/defaults/config.json >/dev/null \
    || fail "shell/defaults/config.json should default bar.cornerStyle to 0"
ok "defaults bar.cornerStyle is 0"

# 2. dynamicIsland.tools.* schema is preserved (toolkit untouched).
jq -e '.bar.dynamicIsland.enabled == true and .bar.dynamicIsland.tools.enabled == true and .bar.dynamicIsland.tools.keybind == "Mod+S"' \
    shell/defaults/config.json >/dev/null \
    || fail "Mod+S toolkit schema must remain in shell/defaults/config.json"
ok "dynamicIsland.tools.* preserved"

# 3. Orphaned dynamicIsland.states/statePrecedence are gone from defaults.
jq -e 'has("bar") and (.bar.dynamicIsland | has("states") | not) and (.bar.dynamicIsland | has("statePrecedence") | not)' \
    shell/defaults/config.json >/dev/null \
    || fail "shell/defaults/config.json must not contain bar.dynamicIsland.states or .statePrecedence"
ok "dynamicIsland.states and .statePrecedence stripped"

# 4. SecPulse config keys are gone from defaults.
jq -e '(.bar.modules | has("secPulse") | not) and (.bar | has("secPulse") | not)' \
    shell/defaults/config.json >/dev/null \
    || fail "shell/defaults/config.json must not contain bar.modules.secPulse or bar.secPulse"
ok "secPulse keys stripped from defaults"

# 5. Welcome bar-style picker has no Three-Island option.
grep -q 'Three-Island' shell/welcome.qml \
    && fail "shell/welcome.qml still mentions Three-Island"
ok "welcome picker has no Three-Island option"

# 6. BarConfig has no three-island gating.
grep -qE 'isThreeIslandStyle|threeIslandOnBottom|threeIslandOnVertical' shell/modules/settings/BarConfig.qml \
    && fail "shell/modules/settings/BarConfig.qml still references three-island"
ok "BarConfig has no three-island flags"

# 7. Bar.qml has no useThreeIsland branch.
grep -q 'useThreeIsland\|threeIslandContentComponent' shell/modules/bar/Bar.qml \
    && fail "shell/modules/bar/Bar.qml still has the three-island branch"
ok "Bar.qml has no useThreeIsland branch"

# 8. Old test file is gone.
test ! -e tests/topbar-three-island.sh \
    || fail "tests/topbar-three-island.sh should be deleted"
ok "tests/topbar-three-island.sh is deleted"

# 9. The toolkit folder still exists (untouched carve-out).
for f in qmldir RyokuToolsMode.qml ToolButton.qml ToolRegistry.qml; do
    test -e "shell/modules/bar/threeIsland/dynamicIsland/tools/$f" \
        || fail "toolkit file shell/modules/bar/threeIsland/dynamicIsland/tools/$f is missing"
done
ok "toolkit folder is preserved"

# 10. UtilButtons still imports the toolkit (untouched).
grep -q 'import qs.modules.bar.threeIsland.dynamicIsland.tools' shell/modules/bar/UtilButtons.qml \
    || fail "shell/modules/bar/UtilButtons.qml lost its toolkit import"
ok "UtilButtons toolkit import is preserved"

# 11. SecPulseIndicator and its supporting service are deleted.
for f in \
    shell/modules/bar/threeIsland/SecPulseIndicator.qml \
    shell/services/RyokuSecPulse.qml \
    shell/services/ryoku_sec_pulse.js; do
    test ! -e "$f" || fail "$f should be deleted"
done
ok "SecPulse files deleted"

# 12. Three-island QML files are deleted (sample five anchors).
for f in \
    shell/modules/bar/threeIsland/RyokuTopFrame.qml \
    shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml \
    shell/modules/bar/threeIsland/RyokuLeftIsland.qml \
    shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml \
    shell/modules/bar/threeIsland/dynamicIsland/pills; do
    test ! -e "$f" || fail "$f should be deleted"
done
ok "three-island QML files deleted"

echo "PASS: topbar-removal-regression"
```

- [ ] **Step 2: Make it executable and run it (expect FAIL)**

```bash
chmod +x tests/topbar-removal-regression.sh
bash tests/topbar-removal-regression.sh
```

Expected: FAIL on assertion #1 (`shell/defaults/config.json should default bar.cornerStyle to 0`). This is the start of the goal trail; later tasks fix one or two assertions each.

- [ ] **Step 3: Commit**

```bash
git add tests/topbar-removal-regression.sh
git commit -m "test(topbar): add regression suite for three-island removal goal state"
```

---

## Task 2: Flip default cornerStyle and strip dynamicIsland.states from defaults config

**Files:**
- Modify: `shell/defaults/config.json` (lines 373 area for `cornerStyle`, lines 438 to ~462 area for `dynamicIsland.states` and `.statePrecedence`)

- [ ] **Step 1: Read the relevant slice**

```bash
grep -n '"cornerStyle"\|"dynamicIsland"\|"states"\|"statePrecedence"' shell/defaults/config.json
```

- [ ] **Step 2: Apply the edits**

Edit `shell/defaults/config.json`:

1. Change `"cornerStyle": 4,` to `"cornerStyle": 0,`.
2. Inside the `"dynamicIsland"` block, delete the `"states": { ... }` object and the `"statePrecedence": [ ... ]` array. Keep `"enabled"`, `"tools"`, and `"musicPopupContinuous"`.

The post-edit `dynamicIsland` block should look like:

```json
"dynamicIsland": {
  "enabled": true,
  "tools": {
    "enabled": true,
    "keybind": "Mod+S",
    "order": [
      "screenshot",
      "record",
      "lens",
      "colorPicker",
      "musicRecognize",
      "micToggle",
      "osk",
      "DIVIDER",
      "caffeine",
      "notepad",
      "screenCast",
      "darkMode",
      "powerProfile"
    ],
    "buttons": {
      "screenshot": true,
      "record": true,
      "lens": true,
      "colorPicker": true,
      "musicRecognize": true,
      "micToggle": true,
      "osk": true,
      "caffeine": true,
      "notepad": true,
      "screenCast": false,
      "darkMode": true,
      "powerProfile": false
    },
    "autoCloseAfterAction": true,
    "closeOnEsc": true
  },
  "musicPopupContinuous": true
}
```

- [ ] **Step 3: Verify the JSON parses and assertions 1 and 3 of the regression test pass**

```bash
jq empty shell/defaults/config.json
jq -e '.bar.cornerStyle == 0' shell/defaults/config.json >/dev/null && echo OK1
jq -e '(.bar.dynamicIsland | has("states") | not) and (.bar.dynamicIsland | has("statePrecedence") | not)' shell/defaults/config.json >/dev/null && echo OK3
jq -e '.bar.dynamicIsland.tools.keybind == "Mod+S"' shell/defaults/config.json >/dev/null && echo OK_TOOLKIT
```

Expected: `OK1`, `OK3`, `OK_TOOLKIT` printed; no jq errors.

- [ ] **Step 4: Commit**

```bash
git add shell/defaults/config.json
git commit -m "chore(defaults): flip bar.cornerStyle to Hug and drop dynamicIsland.states"
```

---

## Task 3: Strip secPulse defaults from defaults config

**Files:**
- Modify: `shell/defaults/config.json` (line 398 area for `modules.secPulse`, line 495 area for `secPulse` block)

- [ ] **Step 1: Locate the secPulse keys**

```bash
grep -n '"secPulse"\|"showVpn"\|"showOpenVpn"\|"showPublicIp"\|"showListening"\|"vpnClickCommand"' shell/defaults/config.json
```

- [ ] **Step 2: Delete `bar.modules.secPulse` (the boolean inside the modules block)**

Find the `"secPulse": true,` line inside the `"modules":` block (around line 398). Remove the line. If it leaves a trailing comma on the previous line, fix that comma.

- [ ] **Step 3: Delete the entire `bar.secPulse` block**

Find the top-level `"secPulse": { ... }` block (around line 495). Remove the whole block including its trailing comma if any. The block contains `showVpn`, `showOpenVpn`, `showPublicIp`, `showListening`, `vpnClickCommand`.

- [ ] **Step 4: Verify**

```bash
jq empty shell/defaults/config.json
jq -e '(.bar.modules | has("secPulse") | not) and (.bar | has("secPulse") | not)' shell/defaults/config.json >/dev/null && echo OK4
```

Expected: `OK4` printed; no jq errors.

- [ ] **Step 5: Commit**

```bash
git add shell/defaults/config.json
git commit -m "chore(defaults): drop bar.modules.secPulse and bar.secPulse from shell defaults"
```

---

## Task 4: Remove "Three-Island" option from welcome bar picker

**Files:**
- Modify: `shell/welcome.qml` line 1225 area

- [ ] **Step 1: Read the picker block**

```bash
sed -n '1215,1230p' shell/welcome.qml
```

- [ ] **Step 2: Apply the edit**

Delete the line:

```qml
                            { displayName: Translation.tr("Three-Island"), icon: "view_column_2", value: 4 }
```

The remaining options (Hug, Float, Full, Card) should still parse with no trailing comma issue. After the edit, the array ends with `{ displayName: Translation.tr("Card"), icon: "branding_watermark", value: 3 }` (no trailing comma).

- [ ] **Step 3: Verify the QML file still has matched braces**

```bash
grep -c 'Three-Island' shell/welcome.qml
```

Expected: `0`.

- [ ] **Step 4: Commit**

```bash
git add shell/welcome.qml
git commit -m "feat(welcome): drop Three-Island option from bar style picker"
```

---

## Task 5: Update branding script defaults

**Files:**
- Modify: `install/config/ryoku-shell-branding.sh` (lines around 171, 173, 177-182, 203-207, 232-244, 265-269)

- [ ] **Step 1: Read the affected blocks**

```bash
grep -nE 'cornerStyle|dynamicIsland|secPulse|put_default' install/config/ryoku-shell-branding.sh | head -60
```

- [ ] **Step 2: Apply the edits**

Make the following changes in `install/config/ryoku-shell-branding.sh`:

1. Line ~171: `.bar.cornerStyle = 4` to `.bar.cornerStyle = 0`.
2. Lines ~173: delete `.bar.modules.secPulse = (.bar.modules.secPulse // true)` (the modules.secPulse default).
3. Lines ~177 to 182: delete the six `.bar.dynamicIsland.states.*` initializers and the `.bar.dynamicIsland.statePrecedence` initializer.
4. Lines ~203 to 207: delete the five `.bar.secPulse.*` initializers (`showVpn`, `showOpenVpn`, `showPublicIp`, `showListening`, `vpnClickCommand`).
5. Lines ~232 to 233: replace the conditional `.bar.cornerStyle = (if (.bar.dynamicIsland == null and (.bar.cornerStyle == null or .bar.cornerStyle == 1)) then 4 elif .bar.cornerStyle == null then 4 else .bar.cornerStyle end)` with the literal `.bar.cornerStyle = (.bar.cornerStyle // 0)`.
6. Line ~235: delete `put_default(["bar", "modules", "secPulse"]; true)`.
7. Lines ~239 to 244: delete the six `put_default(["bar", "dynamicIsland", "states", ...])` calls and `put_default(["bar", "dynamicIsland", "statePrecedence"]; ...)`.
8. Lines ~265 to 269: delete the five `put_default(["bar", "secPulse", ...])` calls.

Keep all other `put_default` lines intact, including every `put_default(["bar", "dynamicIsland", "tools", ...])` line.

- [ ] **Step 3: Smoke-check the script syntax**

```bash
bash -n install/config/ryoku-shell-branding.sh && echo SYNTAX_OK
```

Expected: `SYNTAX_OK`.

- [ ] **Step 4: Commit**

```bash
git add install/config/ryoku-shell-branding.sh
git commit -m "chore(install): drop three-island and secPulse defaults from branding script"
```

---

## Task 6: Update dynamic-island-ipc test assertion

**Files:**
- Modify: `tests/dynamic-island-ipc.sh` (line 35 area)

- [ ] **Step 1: Read the assertion block**

```bash
sed -n '30,45p' tests/dynamic-island-ipc.sh
```

- [ ] **Step 2: Verify the assertion does not require cornerStyle == 4**

The current assertion is:

```bash
jq -e '.bar.dynamicIsland.enabled == true and .bar.dynamicIsland.tools.enabled == true and .bar.dynamicIsland.tools.keybind == "Mod+S"' shell/defaults/config.json >/dev/null
```

If the `jq -e` expression includes any reference to `cornerStyle == 4` or to `bar.dynamicIsland.states`, remove only those clauses. Keep the rest. If it is already exactly the expression above, no edit is needed; verify by running the test.

- [ ] **Step 3: Run the test**

```bash
bash tests/dynamic-island-ipc.sh
```

Expected: PASS. (After Task 2, the defaults already match the asserted shape.)

- [ ] **Step 4: Commit (only if a change was made)**

```bash
git add tests/dynamic-island-ipc.sh
git commit -m "test(dynamic-island-ipc): assert toolkit schema only, drop cornerStyle gate"
```

If Step 2 found no edit needed, skip the commit.

---

## Task 7: Add migration that flips existing user configs

**Files:**
- Create: `migrations/1778256447.sh`

- [ ] **Step 1: Inspect a sibling migration to copy its config-discovery pattern**

```bash
sed -n '1,80p' migrations/1778252246.sh
```

This shows how sibling migrations resolve the user shell config path. Reuse the same helper or pattern.

- [ ] **Step 2: Write the migration**

Create `migrations/1778256447.sh`:

```bash
#!/usr/bin/env bash
# Migrate users off the removed Three-Island bar style.
#  bar.cornerStyle == 4 becomes 0 (Hug). Other values left alone.
#  Strip orphaned bar.dynamicIsland.states and .statePrecedence keys.
#  Strip bar.modules.secPulse and the bar.secPulse block.
#  bar.dynamicIsland.tools.* (the Mod+S toolkit schema) is preserved.
# Idempotent.

set -euo pipefail

echo "Retire the three-island bar style and orphaned secPulse keys"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CFG="$CONFIG_HOME/ryoku/shell/config.json"

if [[ ! -f "$CFG" ]]; then
    echo "  no config at $CFG, skipping"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "  jq not available, skipping" >&2
    exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

jq '
    (if (.bar.cornerStyle? == 4) then .bar.cornerStyle = 0 else . end)
    | del(.bar.dynamicIsland.states)
    | del(.bar.dynamicIsland.statePrecedence)
    | del(.bar.modules.secPulse)
    | del(.bar.secPulse)
' "$CFG" > "$TMP"

if ! cmp -s "$CFG" "$TMP"; then
    cp "$TMP" "$CFG"
    echo "  patched $CFG"
else
    echo "  $CFG already clean"
fi
```

- [ ] **Step 3: Smoke test the migration with a synthetic config**

```bash
chmod +x migrations/1778256447.sh
TMPDIR_TEST="$(mktemp -d)"
mkdir -p "$TMPDIR_TEST/ryoku/shell"
cat > "$TMPDIR_TEST/ryoku/shell/config.json" <<'JSON'
{
  "bar": {
    "cornerStyle": 4,
    "modules": { "secPulse": true, "other": true },
    "secPulse": { "showVpn": true },
    "dynamicIsland": {
      "states": { "music": true },
      "statePrecedence": ["music"],
      "tools": { "enabled": true, "keybind": "Mod+S" }
    }
  }
}
JSON
XDG_CONFIG_HOME="$TMPDIR_TEST" bash migrations/1778256447.sh
jq -e '.bar.cornerStyle == 0
    and (.bar.dynamicIsland | has("states") | not)
    and (.bar.dynamicIsland | has("statePrecedence") | not)
    and (.bar.modules | has("secPulse") | not)
    and (.bar | has("secPulse") | not)
    and .bar.dynamicIsland.tools.keybind == "Mod+S"' \
    "$TMPDIR_TEST/ryoku/shell/config.json" \
    && echo MIGRATION_OK
XDG_CONFIG_HOME="$TMPDIR_TEST" bash migrations/1778256447.sh
echo IDEMPOTENT_OK
rm -rf "$TMPDIR_TEST"
```

Expected: `MIGRATION_OK` and `IDEMPOTENT_OK` printed; the second run does not error and does not rewrite the file (because `cmp -s` returns equal).

- [ ] **Step 4: Commit**

```bash
git add migrations/1778256447.sh
git commit -m "feat(migration): retire three-island bar style and orphaned secPulse keys"
```

---

## Task 8: Retire the cornerStyle-4 propagation migration

**Files:**
- Modify: `migrations/1778022724.sh` (replace body with a no-op stub)

- [ ] **Step 1: Read the current body**

```bash
cat migrations/1778022724.sh
```

- [ ] **Step 2: Replace the body**

Replace the file contents with:

```bash
#!/usr/bin/env bash
# Retired 2026-05-08. This migration originally propagated the three-island
# topbar (cornerStyle == 4) to existing user configs. The three-island bar
# style was removed; running its original logic now would re-set users to a
# style that no longer exists. Kept as a no-op so the migration runner still
# records it as applied for users who never ran it.
exit 0
```

- [ ] **Step 3: Verify**

```bash
bash migrations/1778022724.sh && echo NOOP_OK
```

Expected: `NOOP_OK`.

- [ ] **Step 4: Commit**

```bash
git add migrations/1778022724.sh
git commit -m "chore(migration): retire 1778022724 cornerStyle 4 propagation as a no-op"
```

---

## Task 9: Prune three-island-state restoration from migration 1778252246

**Files:**
- Modify: `migrations/1778252246.sh`

- [ ] **Step 1: Read the file in full**

```bash
cat migrations/1778252246.sh
```

- [ ] **Step 2: Remove only the three-island-state restoration**

Identify any block whose intent is to restore `bar.dynamicIsland.states.*` defaults or `bar.dynamicIsland.statePrecedence`. Remove that block entirely. Any block that restores `bar.dynamicIsland.tools.*` defaults, or the `Mod+S` niri keybind (the `if ! grep -qE 'Mod\+S[[:space:]]*\{[[:space:]]*spawn .*"toolsMode"' ... fi` block), is preserved verbatim.

If no `dynamicIsland.states` restoration block exists in the file, no edit is required for this task.

- [ ] **Step 3: Smoke-check syntax**

```bash
bash -n migrations/1778252246.sh && echo SYNTAX_OK
```

Expected: `SYNTAX_OK`.

- [ ] **Step 4: Commit (only if changed)**

```bash
git add migrations/1778252246.sh
git commit -m "chore(migration): drop dynamicIsland.states restoration from 1778252246"
```

If Step 2 found no edit needed, skip the commit.

---

## Task 10: Unwire the three-island branch in Bar.qml

This is the load-bearing edit. After this commit the regular bar (Hug/Float/Rect/Card) keeps working and the toolkit keeps opening on Mod+S, but cornerStyle 4 is no longer reachable.

**Files:**
- Modify: `shell/modules/bar/Bar.qml` (lines 15, 121 to 123, 146, 152 to 155, 187)

- [ ] **Step 1: Read the affected slice**

```bash
sed -n '10,20p;115,160p;180,195p' shell/modules/bar/Bar.qml
```

- [ ] **Step 2: Remove the threeIsland import (line 15)**

Delete the line:

```qml
import qs.modules.bar.threeIsland
```

- [ ] **Step 3: Remove the `useThreeIsland` property and switch the Loader sourceComponent**

In the `Loader { id: barContent ... }` block:

1. Delete the readonly property:

   ```qml
   readonly property bool useThreeIsland: (Config.options?.bar?.cornerStyle === 4)
       && !(Config.options?.bar?.bottom ?? false)
       && !(Config.options?.bar?.vertical ?? false)
   ```

2. Replace `sourceComponent: barContent.useThreeIsland ? threeIslandContentComponent : barContentComponent` with:

   ```qml
   sourceComponent: barContentComponent
   ```

3. Delete the inner `Component { id: threeIslandContentComponent ... }` block:

   ```qml
   Component {
       id: threeIslandContentComponent
       RyokuThreeIslandContent {}
   }
   ```

   Keep the `Component { id: barContentComponent; BarContent {} }` block.

- [ ] **Step 4: Drop the cornerStyle == 4 clause in the roundDecorators Loader**

Locate the `Loader { id: roundDecorators ... }` block (line 178 area). Find the `active:` line:

```qml
active: showBarBackground && ((Config.options?.bar?.cornerStyle ?? 0) === 0 || (Config.options?.bar?.cornerStyle ?? 0) === 4) // Hug or Three-Island
```

Replace it with:

```qml
active: showBarBackground && ((Config.options?.bar?.cornerStyle ?? 0) === 0) // Hug only
```

- [ ] **Step 5: Confirm exclusiveZone has no === 4 clause**

```bash
grep -nE 'cornerStyle.*=== 4|cornerStyle\s*===\s*4' shell/modules/bar/Bar.qml
```

Expected: no output. If output appears, remove that clause too.

- [ ] **Step 6: Run the regression test**

```bash
bash tests/topbar-removal-regression.sh
```

Expected: assertion #7 (Bar.qml has no useThreeIsland branch) passes; earlier assertions (#1, #3, #5) also pass from prior tasks; later assertions still fail.

- [ ] **Step 7: Smoke-check that Bar.qml still parses**

If the dev environment has `quickshell` available, run:

```bash
quickshell -c shell --check 2>&1 | head -40
```

Otherwise, sanity-check there are no dangling references to `useThreeIsland`, `threeIslandContentComponent`, or `RyokuThreeIslandContent`:

```bash
grep -nE 'useThreeIsland|threeIslandContentComponent|RyokuThreeIslandContent' shell/modules/bar/Bar.qml
```

Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add shell/modules/bar/Bar.qml
git commit -m "feat(bar): drop three-island Loader branch, regular bar is sole sourceComponent"
```

---

## Task 11: Strip three-island gating from BarConfig settings UI

**Files:**
- Modify: `shell/modules/settings/BarConfig.qml` (lines 19 to 21, 173 to 185, 196 area)

- [ ] **Step 1: Read the affected blocks**

```bash
sed -n '12,30p;165,205p' shell/modules/settings/BarConfig.qml
```

- [ ] **Step 2: Remove the three-island readonly properties**

Delete lines 19 to 21:

```qml
    readonly property bool isThreeIslandStyle: Config.options?.bar?.cornerStyle === 4
    readonly property bool threeIslandOnBottom: isThreeIslandStyle && (Config.options?.bar?.bottom ?? false)
    readonly property bool threeIslandOnVertical: isThreeIslandStyle && (Config.options?.bar?.vertical ?? false)
```

- [ ] **Step 3: Remove the two ConflictNote blocks gated on three-island**

Delete the two `ConflictNote` blocks whose `visible:` is `root.threeIslandOnBottom || root.threeIslandOnVertical` and `root.isThreeIslandStyle`. Keep all other `ConflictNote` blocks.

- [ ] **Step 4: Remove the customRounding three-island gating**

In the `ConfigSpinBox` for `Translation.tr("Custom bar rounding (px)")`, remove the two lines:

```qml
                enabled: !root.isThreeIslandStyle
                opacity: enabled ? 1 : 0.5
```

- [ ] **Step 5: Sweep for any remaining reference**

```bash
grep -nE 'isThreeIslandStyle|threeIslandOnBottom|threeIslandOnVertical|Three-Island' shell/modules/settings/BarConfig.qml
```

Expected: no output.

- [ ] **Step 6: Run regression test**

```bash
bash tests/topbar-removal-regression.sh
```

Expected: assertion #6 (BarConfig has no three-island flags) passes.

- [ ] **Step 7: Commit**

```bash
git add shell/modules/settings/BarConfig.qml
git commit -m "feat(settings): drop three-island branches and ConflictNotes from bar settings"
```

---

## Task 12: Delete the dynamicIsland pills directory

By this point Bar.qml no longer renders three-island, so deleting the QML files cannot break the running shell.

**Files:**
- Delete: `shell/modules/bar/threeIsland/dynamicIsland/pills/` (entire directory)

- [ ] **Step 1: List the files about to be removed**

```bash
ls shell/modules/bar/threeIsland/dynamicIsland/pills/
```

Expected: 7 files (`IdleStatePill.qml`, `MusicHoverPopup.qml`, `MusicStatePill.qml`, `RecordingStatePill.qml`, `ScreenshotToastPill.qml`, `TimerStatePill.qml`, `VoiceSearchPill.qml`).

- [ ] **Step 2: Confirm no imports outside of three-island reference these**

```bash
grep -rn 'StatePill\|MusicHoverPopup' --include='*.qml' shell/ \
    | grep -v 'shell/modules/bar/threeIsland/'
```

Expected: no output. If there are any matches, stop and surface them; the spec assumes pills are three-island-only.

- [ ] **Step 3: Delete via git**

```bash
git rm -r shell/modules/bar/threeIsland/dynamicIsland/pills
```

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(bar): delete dynamicIsland state-pill QML files"
```

---

## Task 13: Delete the dynamicIsland orchestrator and waveform

**Files:**
- Delete: `shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml`
- Delete: `shell/modules/bar/threeIsland/dynamicIsland/CavaWaveform.qml`

- [ ] **Step 1: Verify no external import**

```bash
grep -rn 'RyokuDynamicIsland\|CavaWaveform' --include='*.qml' shell/ \
    | grep -v 'shell/modules/bar/threeIsland/'
```

Expected: no output.

- [ ] **Step 2: Delete via git**

```bash
git rm shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
git rm shell/modules/bar/threeIsland/dynamicIsland/CavaWaveform.qml
```

- [ ] **Step 3: Verify the toolkit is still present at the same path**

```bash
ls shell/modules/bar/threeIsland/dynamicIsland/
```

Expected: only `tools/`.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(bar): delete dynamic island orchestrator and waveform"
```

---

## Task 14: Delete the seven top-level threeIsland QML files

**Files:**
- Delete: `RyokuTopFrame.qml`, `RyokuThreeIslandContent.qml`, `RyokuLeftIsland.qml`, `RyokuRightIsland.qml`, `RyokuCenterIsland.qml`, `RyokuClock.qml`, `RyokuDateLabel.qml` (all under `shell/modules/bar/threeIsland/`)

- [ ] **Step 1: Confirm no external imports**

```bash
grep -rn 'RyokuTopFrame\|RyokuThreeIslandContent\|RyokuLeftIsland\|RyokuRightIsland\|RyokuCenterIsland\|RyokuClock\|RyokuDateLabel' --include='*.qml' shell/ \
    | grep -v 'shell/modules/bar/threeIsland/'
```

Expected: no output. (`RyokuClock` may appear in `BarContent.qml` if a different component was named the same, in which case stop and reconsider; based on current grep history it does not.)

- [ ] **Step 2: Delete via git**

```bash
git rm shell/modules/bar/threeIsland/RyokuTopFrame.qml \
       shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml \
       shell/modules/bar/threeIsland/RyokuLeftIsland.qml \
       shell/modules/bar/threeIsland/RyokuRightIsland.qml \
       shell/modules/bar/threeIsland/RyokuCenterIsland.qml \
       shell/modules/bar/threeIsland/RyokuClock.qml \
       shell/modules/bar/threeIsland/RyokuDateLabel.qml
```

- [ ] **Step 3: Confirm the toolkit subtree is intact**

```bash
ls -R shell/modules/bar/threeIsland/
```

Expected output (exact):

```
shell/modules/bar/threeIsland/:
dynamicIsland  SecPulseIndicator.qml

shell/modules/bar/threeIsland/dynamicIsland:
tools

shell/modules/bar/threeIsland/dynamicIsland/tools:
qmldir  RyokuToolsMode.qml  ToolButton.qml  ToolRegistry.qml
```

(`SecPulseIndicator.qml` will be deleted in Task 15.)

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(bar): delete three-island frame and island QML files"
```

---

## Task 15: Delete SecPulseIndicator and its supporting service

**Files:**
- Delete: `shell/modules/bar/threeIsland/SecPulseIndicator.qml`
- Delete: `shell/services/RyokuSecPulse.qml`
- Delete: `shell/services/ryoku_sec_pulse.js`

- [ ] **Step 1: Verify there are no remaining consumers**

```bash
grep -rln 'RyokuSecPulse\|SecPulseIndicator\|ryoku_sec_pulse' --include='*.qml' --include='*.js' shell/
```

Expected: only the three files about to be deleted (and possibly a `qmldir` for services if it lists the singleton).

- [ ] **Step 2: Check the services qmldir for a stale entry**

```bash
grep -n 'RyokuSecPulse' shell/services/qmldir 2>/dev/null
```

If a singleton entry for `RyokuSecPulse` exists, remove that line from `shell/services/qmldir`.

- [ ] **Step 3: Delete via git**

```bash
git rm shell/modules/bar/threeIsland/SecPulseIndicator.qml \
       shell/services/RyokuSecPulse.qml \
       shell/services/ryoku_sec_pulse.js
```

- [ ] **Step 4: Run the regression test**

```bash
bash tests/topbar-removal-regression.sh
```

Expected: assertion #11 (SecPulse files deleted) passes.

- [ ] **Step 5: Commit**

```bash
git add shell/services/qmldir 2>/dev/null || true
git commit -m "feat(bar): delete SecPulseIndicator and supporting RyokuSecPulse service"
```

---

## Task 16: Update sidebar-openvpn test to drop SecPulseIndicator assertions

**Files:**
- Modify: `tests/sidebar-openvpn.sh` (lines 73 to 74)

- [ ] **Step 1: Read the affected slice**

```bash
sed -n '60,80p' tests/sidebar-openvpn.sh
```

- [ ] **Step 2: Delete the two assertions referencing SecPulseIndicator**

Remove lines 73 and 74:

```bash
assert_contains   "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "ovpnItem"
assert_contains   "shell/modules/bar/threeIsland/SecPulseIndicator.qml" "RyokuOpenVpn.activeProfile"
```

- [ ] **Step 3: Run the test**

```bash
bash tests/sidebar-openvpn.sh
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add tests/sidebar-openvpn.sh
git commit -m "test(sidebar-openvpn): drop SecPulseIndicator assertions"
```

---

## Task 17: Drop secPulse assertions from ryoku-shell-branding test

**Files:**
- Modify: `tests/ryoku-shell-branding.sh` (lines around 126 and 151 to 154)

- [ ] **Step 1: Read the affected blocks**

```bash
grep -nE 'secPulse|showVpn|showOpenVpn|showPublicIp|showListening' tests/ryoku-shell-branding.sh
```

- [ ] **Step 2: Remove the secPulse fixture and the four jq clauses**

In the JSON fixture (around line 126), delete the `"secPulse": { ... }` object. Inside the jq predicate (around lines 151 to 154), delete the four conjuncts: `.bar.secPulse.showVpn == false`, `.bar.secPulse.showOpenVpn == false`, `.bar.secPulse.showPublicIp == false`, `.bar.secPulse.showListening == false`. Keep all other clauses and any `and` chaining intact.

If the test asserts `.bar.modules.secPulse`, also remove that conjunct.

- [ ] **Step 3: Run the test**

```bash
bash tests/ryoku-shell-branding.sh
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add tests/ryoku-shell-branding.sh
git commit -m "test(branding): drop secPulse assertions"
```

---

## Task 18: Delete tests for the removed SecPulse listener parser

**Files:**
- Delete: `tests/ryoku-sec-pulse-listeners.sh`

- [ ] **Step 1: Confirm the parser is gone**

```bash
test ! -e shell/services/ryoku_sec_pulse.js && echo PARSER_GONE
```

Expected: `PARSER_GONE`.

- [ ] **Step 2: Confirm no other test or harness references this test**

```bash
grep -rn 'ryoku-sec-pulse-listeners' tests/ scripts/ install/ bin/ iso/ 2>/dev/null
```

Expected: only the file itself, if anything (delete handles that).

- [ ] **Step 3: Delete via git**

```bash
git rm tests/ryoku-sec-pulse-listeners.sh
```

- [ ] **Step 4: Commit**

```bash
git commit -m "test(sec-pulse): delete listener-parser test alongside service removal"
```

---

## Task 19: Delete the topbar-three-island test

**Files:**
- Delete: `tests/topbar-three-island.sh`

- [ ] **Step 1: Confirm no harness references it**

```bash
grep -rn 'topbar-three-island' tests/ scripts/ install/ bin/ iso/ shell/scripts/ 2>/dev/null
```

Expected: only the file itself, if anything.

- [ ] **Step 2: Delete via git**

```bash
git rm tests/topbar-three-island.sh
```

- [ ] **Step 3: Run the regression test**

```bash
bash tests/topbar-removal-regression.sh
```

Expected: assertion #8 (`tests/topbar-three-island.sh` is deleted) passes.

- [ ] **Step 4: Commit**

```bash
git commit -m "test(topbar): delete obsolete three-island regression test"
```

---

## Task 20: Update keybindings, ui-patterns, and IPC docs

**Files:**
- Modify: `docs/keybindings.md` (line 27)
- Modify: `docs/ui-patterns.md` (lines 113 and 170)
- Modify: `shell/docs/IPC.md` (lines 119 and 135)

- [ ] **Step 1: Edit `docs/keybindings.md`**

Replace the `Mod+S` row at line 27:

```
| `Mod+S` | Toggle Dynamic Island tools mode (screenshot, record, lens, color picker, mic, OSK, caffeine, ...). |
```

with:

```
| `Mod+S` | Toggle the toolkit pill (screenshot, record, lens, color picker, mic, OSK, caffeine, ...). |
```

- [ ] **Step 2: Edit `docs/ui-patterns.md`**

1. Around line 113, delete the row whose right cell is `shell/modules/bar/threeIsland/SecPulseIndicator.qml`. Keep the surrounding table structure intact.
2. Around line 170, change `required feature keybinds like `Mod+S` for Dynamic Island tools` to `required feature keybinds like `Mod+S` for the toolkit`.

- [ ] **Step 3: Edit `shell/docs/IPC.md`**

1. Line 119: replace `Dynamic Island tools mode. Toggles a wide tools pill in the topbar center notch (Mod+S).` with `Toolkit mode. Toggles the wide tools pill in the topbar (Mod+S).`.
2. Line 135: replace `Used by the Dynamic Island to flash a brief success toast.` with `Used to flash a brief screenshot success toast.`.

- [ ] **Step 4: Verify no `Dynamic Island` mention remains**

```bash
grep -nE 'Dynamic Island|dynamic island' docs/keybindings.md docs/ui-patterns.md shell/docs/IPC.md
```

Expected: no output. (Checking case-insensitively because both forms appear in the source.)

- [ ] **Step 5: Commit**

```bash
git add docs/keybindings.md docs/ui-patterns.md shell/docs/IPC.md
git commit -m "docs: scrub Dynamic Island mentions from keybindings, ui-patterns, IPC docs"
```

---

## Task 21: Delete the four three-island spec/plan docs

**Files:**
- Delete: `docs/superpowers/specs/2026-05-07-dynamic-island-design.md`
- Delete: `docs/superpowers/plans/2026-05-07-dynamic-island-implementation.md`
- Delete: `docs/superpowers/specs/2026-05-07-listening-ports-hover-design.md`
- Delete: `docs/superpowers/plans/2026-05-07-listening-ports-hover.md`

- [ ] **Step 1: Confirm none of the four are referenced from anywhere live**

```bash
grep -rn '2026-05-07-dynamic-island\|2026-05-07-listening-ports-hover' \
    --include='*.qml' --include='*.sh' --include='*.md' --include='*.kdl' --include='*.json' \
    | grep -v 'docs/superpowers/'
```

Expected: no output.

- [ ] **Step 2: Delete via git**

```bash
git rm docs/superpowers/specs/2026-05-07-dynamic-island-design.md \
       docs/superpowers/plans/2026-05-07-dynamic-island-implementation.md \
       docs/superpowers/specs/2026-05-07-listening-ports-hover-design.md \
       docs/superpowers/plans/2026-05-07-listening-ports-hover.md
```

- [ ] **Step 3: Commit**

```bash
git commit -m "docs(superpowers): delete obsolete three-island specs and plans"
```

---

## Task 22: Clean up Config.qml schema

**Files:**
- Modify: `shell/modules/common/Config.qml` (line 635 comment, line 669 `bar.modules.secPulse`, lines 711 to 727 area for `dynamicIsland.states` and `.statePrecedence`, lines 773 to 786 area for `bar.secPulse` JsonObject)

- [ ] **Step 1: Read the affected slices**

```bash
sed -n '630,640p;665,680p;705,735p;770,790p' shell/modules/common/Config.qml
```

- [ ] **Step 2: Rewrite the cornerStyle comment (line 635)**

Change:

```qml
property int cornerStyle: 0 // 0: Hug | 1: Float | 2: Plain rectangle | 3: Card | 4: Three-Island (TODO: surface as configurator choice so users can pick three-island + dynamic-island bar at install time)
```

to:

```qml
property int cornerStyle: 0 // 0: Hug, 1: Float, 2: Plain rectangle, 3: Card
```

- [ ] **Step 3: Delete `bar.modules.secPulse` (line 669)**

Remove the line:

```qml
property bool secPulse: true     // Three-Island only: VPN/IP/listening cluster
```

- [ ] **Step 4: Delete `bar.dynamicIsland.states` and `.statePrecedence`**

Inside the `dynamicIsland: JsonObject` (line 711), delete the `states: JsonObject { ... }` block (line 714 area, with `voiceSearch`, `recording`, `timer`, `screenshotToast`, `music` properties) and the `statePrecedence` list (line 723 area). Keep `enabled`, `tools`, `musicPopupContinuous`, and any other surviving property.

- [ ] **Step 5: Delete the `bar.secPulse` JsonObject (line 773 area)**

Remove the entire block:

```qml
property JsonObject secPulse: JsonObject {
    property bool showVpn: true
    property bool showOpenVpn: true
    property bool showPublicIp: false
    property bool showListening: false
    property string vpnClickCommand: "xdg-open https://login.tailscale.com/admin/machines"
}
```

(Including its full multi-line comment about `nm-connection-editor` etc.)

- [ ] **Step 6: Confirm the toolkit migration block is intact**

```bash
grep -n '_migrateDynamicIslandIfNeeded\|dynamicIslandMigrated' shell/modules/common/Config.qml
```

Expected: matches at the bottom of the file (lines around 1751 to 1789). These are the toolkit's one-shot defaults migration; do not edit.

- [ ] **Step 7: Sweep for any remaining three-island reference**

```bash
grep -nE 'Three-Island|three-island|three.island|dynamicIsland\.states|statePrecedence|bar\.secPulse|secPulse' shell/modules/common/Config.qml
```

Expected: only mentions of `bar.dynamicIsland.tools` (preserved schema) and the `_migrateDynamicIslandIfNeeded` migration comments.

- [ ] **Step 8: Commit**

```bash
git add shell/modules/common/Config.qml
git commit -m "chore(config): drop three-island and secPulse schema, keep toolkit"
```

---

## Task 23: Final verification grep and regression run

**Files:**
- None (verification only).

- [ ] **Step 1: Run the regression suite**

```bash
bash tests/topbar-removal-regression.sh
```

Expected: `PASS: topbar-removal-regression`. All 12 assertions green.

- [ ] **Step 2: Run the related test suites**

```bash
bash tests/dynamic-island-ipc.sh
bash tests/sidebar-openvpn.sh
bash tests/ryoku-shell-branding.sh
```

Expected: each prints its own success line and exits 0.

- [ ] **Step 3: Repo-wide grep for stragglers**

```bash
grep -rIn -E 'threeIsland|three-island|three_island|Three-Island|Dynamic Island|dynamic island' \
    --include='*.qml' --include='*.sh' --include='*.md' --include='*.kdl' --include='*.json' --include='*.js'
```

Allowed matches:
1. Anything under `shell/modules/bar/threeIsland/dynamicIsland/tools/` (the toolkit folder).
2. The `import qs.modules.bar.threeIsland.dynamicIsland.tools` line in `shell/modules/bar/UtilButtons.qml`.
3. References to `bar.dynamicIsland.{enabled,tools,musicPopupContinuous}` keys in `shell/defaults/config.json`, `shell/modules/common/Config.qml`, `install/config/ryoku-shell-branding.sh`, `tests/dynamic-island-ipc.sh`, `tests/topbar-removal-regression.sh`, and the `_migrateDynamicIslandIfNeeded` comments.
4. `migrations/1778256447.sh`'s idempotency comments (it strips `dynamicIsland.states` and `dynamicIsland.statePrecedence`).
5. `migrations/1778022724.sh`'s retired-stub comment (mentions three-island for context).
6. `migrations/1778252246.sh`'s remaining `dynamicIsland.tools` references if any.
7. The plan and spec under `docs/superpowers/{plans,specs}/2026-05-08-three-island-removal*.md`.

If matches appear outside this allow-list, address them before declaring complete.

- [ ] **Step 4: Manual smoke test**

If the dev environment has `quickshell`:

```bash
quickshell -c shell --check
```

Then launch the shell, observe the bar renders in Hug style, press `Mod+S` and confirm the toolkit pill opens with all enabled buttons. Press Esc and right-click in the pill area to confirm both close it.

If `quickshell` is not available locally, document this manual step as pending in the final commit message of the run.

- [ ] **Step 5: Commit (only if any verification turned up an edit)**

```bash
git add -p
git commit -m "chore(verify): apply post-removal cleanups surfaced by regression sweep"
```

If everything is already clean and no edits were needed, skip this commit.

---

## Self-Review

This section is for the planner; agentic workers may skip.

**Spec coverage check:**
- "Files to Delete > Three-island bar QML": Tasks 12, 13, 14 cover the pills directory, dynamic-island orchestrator/waveform, and the seven top-level threeIsland QML files.
- "Files to Delete > SecPulse service & test": Tasks 15 and 18 cover service+parser+test deletion.
- "Files to Delete > Tests": Task 19 deletes `topbar-three-island.sh`.
- "Files to Delete > Docs": Task 21 deletes the four 2026-05-07 spec/plan files.
- "Files to Edit > Bar.qml": Task 10.
- "Files to Edit > Config.qml": Task 22.
- "Files to Edit > defaults/config.json": Tasks 2 and 3.
- "Files to Edit > branding script": Task 5.
- "Files to Edit > welcome.qml": Task 4.
- "Files to Edit > BarConfig.qml": Task 11.
- "Files to Edit > QuickConfig.qml": spec marked verify-only; Task 23 grep covers it.
- "Files to Edit > 1778022724.sh": Task 8.
- "Files to Edit > 1778252246.sh": Task 9.
- "Files to Edit > dynamic-island-ipc.sh": Task 6.
- "Files to Edit > sidebar-openvpn.sh": Task 16.
- "Files to Edit > ryoku-shell-branding.sh test": Task 17.
- "Files to Edit > docs/keybindings.md, ui-patterns.md, shell/docs/IPC.md": Task 20.
- "New migration": Task 7.
- "Verification": Task 23.

All spec sections map to a task.

**Placeholder scan:** No "TBD", "TODO", "implement later". Every step has either exact code or an exact command.

**Type/name consistency:** Migration filename `1778256447.sh` is referenced consistently (Task 7 creates it; Task 23 allow-list mentions it). Toolkit folder path `shell/modules/bar/threeIsland/dynamicIsland/tools/` is used identically across tasks. Function name `_migrateDynamicIslandIfNeeded` matches the actual Config.qml symbol.
