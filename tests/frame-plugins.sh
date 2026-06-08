#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1" pattern="$2" message="$3"
  [[ -f $file ]] || fail "missing file: $file"
  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_absent() {
  local file="$1" pattern="$2" message="$3"
  [[ -f $file ]] || fail "missing file: $file"
  ! grep -Eq "$pattern" "$file" || fail "$message"
}

# The wallhaven popout is now a plugin; the shell must not carry its old in-tree wiring.
[[ ! -e shell/modules/wallhaven ]] || fail "shell/modules/wallhaven should be removed (now a plugin)"
[[ ! -e shell/services/Wallhaven.qml ]] || fail "shell/services/Wallhaven.qml should be removed (now a plugin)"
[[ ! -e bin/ryoku-wallhaven-search ]] || fail "bin/ryoku-wallhaven-search should be removed (ships with the plugin)"
assert_absent shell/components/DrawerVisibilities.qml 'property bool wallhaven' \
  "DrawerVisibilities should no longer hardcode a wallhaven panel"

# Generic frame-plugin host.
assert_contains shell/modules/drawers/FramePlugins.qml 'entryPoints && p\.manifest\.entryPoints\.framePanel' \
  "FramePlugins should discover plugins that register a framePanel"
assert_contains shell/modules/drawers/FramePlugins.qml 'function hover' \
  "FramePlugins should accept hover hits from Interactions"
assert_contains shell/modules/drawers/FramePlugins.qml 'function closeAll' \
  "FramePlugins should expose closeAll for mutual exclusion"
assert_contains shell/modules/drawers/FramePlugins.qml 'function toggle' \
  "FramePlugins should expose toggle for IPC/shortcuts"
assert_contains shell/modules/drawers/FramePlugins.qml 'Visibilities\.loadFramePlugins' \
  "FramePlugins should register itself for the active screen"
assert_contains shell/modules/drawers/FramePanelWrapper.qml 'source: "file://" \+ root\.panelPath' \
  "FramePanelWrapper should load the plugin's framePanel QML"
assert_contains shell/modules/drawers/FramePanelWrapper.qml 'property matrix4x4 deformMatrix' \
  "FramePanelWrapper should accept the frame deform transform"
assert_contains shell/modules/drawers/FramePanelWrapper.qml 'active: true' \
  "FramePanelWrapper should build the panel eagerly so hovering opens it instantly, not lazily on first hover"

# Wiring into the drawer frame.
assert_contains shell/modules/drawers/Panels.qml 'FramePlugins \{' \
  "drawer panels should host the frame-plugin container"
assert_contains shell/modules/drawers/Panels.qml 'readonly property alias framePlugins: framePlugins' \
  "drawer panels should expose framePlugins for regions and deform"
assert_absent shell/modules/drawers/Panels.qml 'import qs\.modules\.wallhaven' \
  "drawer panels should not import the old wallhaven module"
assert_contains shell/modules/drawers/ContentWindow.qml 'panels\.framePlugins\.anyActive' \
  "content window focus should follow active frame plugins"
assert_contains shell/modules/drawers/ContentWindow.qml 'panels\.framePlugins\.closeAll\(\)' \
  "content window should close frame plugins on fullscreen/clear"
assert_contains shell/modules/drawers/ContentWindow.qml 'model: panels\.framePlugins\.panels' \
  "content window should deform every frame plugin panel"
assert_contains shell/modules/drawers/Regions.qml 'component FrameR' \
  "regions should define an edge-pinned frame-plugin region"
assert_contains shell/modules/drawers/Regions.qml 'root\.panels\.framePlugins\.panels' \
  "regions should subtract each frame plugin's surface"
assert_contains shell/modules/drawers/Interactions.qml 'function inFramePanel' \
  "interactions should compute a generic frame activation zone"
assert_absent shell/modules/drawers/Interactions.qml 'inWallhavenPanel' \
  "interactions should not retain the wallhaven-specific activation helper"
assert_contains shell/modules/drawers/Interactions.qml 'panels\.framePlugins\.hover' \
  "interactions should feed hover hits to the frame host"

# IPC / shortcuts route by plugin id through the registered host.
assert_contains shell/modules/Shortcuts.qml 'framePluginsForActive' \
  "IPC toggle should resolve the active screen's frame host"
assert_contains shell/modules/Shortcuts.qml 'fp\.toggle\(drawer\)' \
  "IPC toggle should toggle a frame plugin by id"
assert_contains shell/services/Visibilities.qml 'function framePluginsForActive' \
  "Visibilities should expose the active frame host"

# The plugin system must be wired into the running scene.
assert_contains shell/shell.qml 'PluginService\.pluginContainer' \
  "shell root should provide the plugin container"
assert_contains shell/shell.qml 'PluginService\.screenDetector' \
  "shell root should provide the plugin screen detector"

# Wallhaven plugin in the sibling catalogue (skipped when not checked out).
extras="${RYOKU_EXTRAS_DIR:-$HOME/Work/ryoku-extras}"
[[ -d $extras ]] || extras="../ryoku-extras"
if [[ -d $extras ]]; then
  man="$extras/plugins/wallhaven/manifest.json"
  [[ -f $man ]] || fail "wallhaven plugin manifest missing"
  jq -e '.entryPoints.framePanel and .entryPoints.main and .frame.edge == "top" and .frame.align == "end"' "$man" >/dev/null \
    || fail "wallhaven manifest should declare a top/end frame panel"
  [[ -x "$extras/plugins/wallhaven/bin/ryoku-wallhaven-search" ]] \
    || fail "wallhaven plugin command should be executable"
  jq -e '[.plugins[] | select(.id == "wallhaven") | .path] == ["plugins/wallhaven"]' "$extras/plugins/registry.json" >/dev/null \
    || fail "wallhaven should be listed in the plugins registry at plugins/wallhaven"
  panel="$extras/plugins/wallhaven/ui/Panel.qml"
  [[ -f $panel ]] || fail "wallhaven plugin panel missing"
  menus=$(grep -c 'Menu {' "$panel" || true)
  (( menus == 1 )) || fail "wallhaven Panel.qml should declare one shared Menu, not one per grid delegate (found $menus)"
  grep -q 'function openImageMenu' "$panel" || fail "wallhaven Panel.qml should target the shared menu via openImageMenu()"
  grep -Eq 'imageMenu\.expanded = false' "$panel" || fail "wallhaven Panel.qml should dismiss the context menu when the popout closes"
else
  echo "SKIP: ryoku-extras not found; skipping wallhaven plugin assertions"
fi

echo "PASS: frame plugins"
