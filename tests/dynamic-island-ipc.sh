#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "OK: dynamic island IPC + schema"; }

# Schema: dynamicIsland exists in Config defaults
grep -q "dynamicIsland" shell/modules/common/Config.qml \
    || fail "bar.dynamicIsland missing from Config.qml"

# IPC handler defined for tools mode (lives in services/ToolsModeService so
# it registers once globally and stays alive even when tools mode is closed)
grep -q 'target: "toolsMode"' shell/services/ToolsModeService.qml \
    || fail "toolsMode IpcHandler not declared in ToolsModeService.qml"
grep -q 'singleton ToolsModeService' shell/services/qmldir \
    || fail "ToolsModeService singleton not registered in services/qmldir"

# IPC handler defined for screenshot events
grep -q 'target: "screenshotEvents"' shell/services/ScreenshotEvents.qml \
    || fail "screenshotEvents IpcHandler not declared"

# Both IPC targets registered in registry
grep -q '\[toolsMode\]=' shell/scripts/lib/ipc-registry.sh \
    || fail "toolsMode missing from ipc-registry.sh; run 'python3 shell/scripts/lib/generate-ipc-registry.py'"
grep -q '\[screenshotEvents\]=' shell/scripts/lib/ipc-registry.sh \
    || fail "screenshotEvents missing from ipc-registry.sh"

# niri Mod+S bind exists
grep -qE 'Mod\+S \{ spawn "ryoku-shell" "toolsMode"' config/niri/config.d/70-binds.kdl \
    || fail "Mod+S bind missing in niri config"

jq -e '.bar.dynamicIsland.enabled == true and .bar.dynamicIsland.tools.enabled == true and .bar.dynamicIsland.tools.keybind == "Mod+S"' shell/defaults/config.json >/dev/null \
    || fail "shell defaults should enable Dynamic Island tools on Mod+S"

# Tools registry + button + mode
for f in ToolRegistry ToolButton RyokuToolsMode; do
    test -f "shell/modules/bar/threeIsland/dynamicIsland/tools/${f}.qml" \
        || fail "${f}.qml missing"
done

# GlobalStates flag
grep -q "toolsModeOpen" shell/GlobalStates.qml \
    || fail "toolsModeOpen missing from GlobalStates.qml"

pass
