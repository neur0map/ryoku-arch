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
