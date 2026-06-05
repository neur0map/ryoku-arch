import QtQuick
import Quickshell

// RYOKU STUB. Upstream NiriService uses module "Quickshell.Niri" (the Niri
// compositor backend) which is not present in quickshell-ryoku. ryoku targets
// Hyprland, so CompositorService never selects this backend at runtime — the
// type only needs to compile. The full CompositorService backend interface is
// mirrored as no-ops so nothing breaks even if it were instantiated.
// TODO: restore the real NiriService if Niri support is ever desired.
Item {
  id: root

  property int floatingWindowPosition: Number.MAX_SAFE_INTEGER
  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1
  property bool overviewActive: false
  property var globalWorkspaces: []
  property var keyboardLayouts: []

  signal workspaceChanged
  signal activeWindowChanged
  signal windowListChanged
  signal displayScalesChanged

  function initialize() {}
  function queryDisplayScales() {}
  function getFocusedScreen() {
    return null;
  }
  function switchToWorkspace(workspace) {}
  function scrollWorkspaceContent(direction) {}
  function focusWindow(window) {}
  function closeWindow(window) {}
  function spawn(cmdArray) {}
  function logout() {}
}
