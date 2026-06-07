pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs.settingsgui.Services.Platform

// Per-screen host for every installed plugin that registers a `framePanel`. It fills the
// drawer content area, builds one FramePanelWrapper per frame plugin, and owns which one
// is open. Interactions feeds it hover hits; Regions and ContentWindow read `panels` to
// add input regions and blob deform. Only one frame panel is open at a time.
Item {
  id: root

  required property ShellScreen screen

  // pluginId of the open panel, "" when none. shortcutActive keeps it open when it was
  // toggled by IPC rather than hover, so leaving the hover zone does not close it.
  property string activeId: ""
  property bool shortcutActive: false

  property var panels: []
  readonly property bool anyActive: activeId.length > 0
  readonly property bool anyNeedsKeyboard: activeId.length > 0

  property var frameModel: []

  function rebuild(): void {
    const out = [];
    const loaded = PluginService.loadedPlugins;
    for (const id in loaded) {
      const p = loaded[id];
      if (p && p.manifest && p.manifest.entryPoints && p.manifest.entryPoints.framePanel) {
        out.push({
          pluginId: id,
          pluginApi: p.api,
          panelPath: PluginRegistry.getPluginDir(id) + "/" + p.manifest.entryPoints.framePanel,
          frame: p.manifest.frame || ({})
        });
      }
    }
    frameModel = out;
  }

  function panelById(id: string): var {
    for (let i = 0; i < panels.length; i++)
      if (panels[i].pluginId === id)
        return panels[i];
    return null;
  }

  // Called from Interactions with the pluginId whose activation zone is hovered ("" = none).
  function hover(id: string): void {
    if (shortcutActive) {
      if (id.length > 0) {
        shortcutActive = false;
        activeId = id;
      }
      return;
    }
    activeId = id;
  }

  function clearHover(): void {
    if (!shortcutActive)
      activeId = "";
  }

  function closeAll(): void {
    activeId = "";
    shortcutActive = false;
  }

  function toggle(id: string): bool {
    if (!panelById(id))
      return false;
    if (activeId === id) {
      closeAll();
    } else {
      activeId = id;
      shortcutActive = true;
    }
    return true;
  }

  function _refreshPanels(): void {
    const a = [];
    for (let i = 0; i < rep.count; i++) {
      const it = rep.itemAt(i);
      if (it)
        a.push(it);
    }
    panels = a;
  }

  Component.onCompleted: {
    Visibilities.loadFramePlugins(screen, root);
    rebuild();
  }

  Connections {
    target: PluginService

    function onPluginLoaded(): void {
      root.rebuild();
    }
    function onPluginUnloaded(): void {
      root.rebuild();
    }
    function onPluginReloaded(): void {
      root.rebuild();
    }
    function onAllPluginsLoaded(): void {
      root.rebuild();
    }
  }

  Repeater {
    id: rep

    model: root.frameModel

    delegate: FramePanelWrapper {
      required property var modelData

      screen: root.screen
      pluginId: modelData.pluginId
      pluginApi: modelData.pluginApi
      panelPath: modelData.panelPath
      frame: modelData.frame
      active: root.activeId === modelData.pluginId
    }

    onItemAdded: root._refreshPanels()
    onItemRemoved: root._refreshPanels()
  }
}
