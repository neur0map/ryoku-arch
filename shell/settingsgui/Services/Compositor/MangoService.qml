import QtQuick
import Quickshell

// RYOKU STUB. Upstream MangoService uses module "Quickshell.DWL" (the MangoWC /
// dwl compositor backend) which is not present in quickshell-ryoku. ryoku targets
// Hyprland, so CompositorService never selects this backend at runtime — the type
// only needs to compile. The CompositorService backend interface is mirrored as
// no-ops so nothing breaks even if it were instantiated.
// TODO: restore the real MangoService if MangoWC/dwl support is ever desired.
Item {
  id: root

  property ListModel workspaces: ListModel {}
  property var windows: []
  property int focusedWindowIndex: -1
  property bool initialized: false
  property bool overviewActive: false
  property var globalWorkspaces: []
  property var keyboardLayouts: []
  property string selectedMonitor: ""
  property string currentLayoutSymbol: ""

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
