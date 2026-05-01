import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Noctalia.Commons
import qs.Noctalia.Services.UI
import qs.Noctalia.Widgets

FloatingWindow {
  id: root

  readonly property int panelWidth: 840
  readonly property int panelHeight: 910

  title: "Noctalia"
  width: Math.min(panelWidth, screen ? screen.width - 24 : panelWidth)
  height: Math.min(panelHeight, screen ? screen.height - 24 : panelHeight)
  minimumSize: Qt.size(Math.min(panelWidth, screen ? screen.width - 24 : panelWidth), Math.min(panelHeight, screen ? screen.height - 24 : panelHeight))
  implicitWidth: panelWidth
  implicitHeight: panelHeight
  color: "transparent"

  visible: false

  // Register with RyokuSettingsPanelService
  Component.onCompleted: {
    RyokuSettingsPanelService.settingsWindow = root;
  }

  property bool isInitialized: false

  // Navigate to a specific tab and optional subtab.
  // Works whether the window is already visible or just becoming visible.
  function navigateTo(tab, subTab) {
    const tabId = tab !== undefined ? tab : 0;
    const subTabId = (subTab !== undefined && subTab !== null && subTab >= 0) ? subTab : -1;
    if (isInitialized) {
      settingsContent.navigateToTab(tabId, subTabId);
    } else {
      settingsContent.requestedTab = tabId;
      if (subTabId >= 0)
        settingsContent._pendingSubTab = subTabId;
      settingsContent.initialize();
      isInitialized = true;
      // Tab content persists in window mode; if no subtab specified and the
      // tab content is still loaded (same tab), reset to first subtab
      if (subTabId < 0 && settingsContent.activeTabContent)
        settingsContent.setSubTabIndex(0);
    }
  }

  // Navigate to a search result entry.
  // Works whether the window is already visible or just becoming visible.
  function navigateToEntry(entry) {
    if (isInitialized) {
      Qt.callLater(() => settingsContent.navigateToResult(entry));
    } else {
      settingsContent.requestedTabIndex = entry.tab;
      settingsContent.initialize();
      Qt.callLater(() => settingsContent.navigateToResult(entry));
      isInitialized = true;
    }
  }

  function navigateToRoute(route) {
    const targetRoute = route || "general";
    if (!isInitialized) {
      settingsContent.requestedRoute = targetRoute;
      settingsContent.initialize();
      isInitialized = true;
    }
    settingsContent.openRoute(targetRoute);
  }

  // Sync visibility with service
  onVisibleChanged: {
    if (visible) {
      RyokuSettingsPanelService.isWindowOpen = true;
    } else {
      isInitialized = false;
      RyokuSettingsPanelService.isWindowOpen = false;
    }
  }

  // Keyboard shortcuts
  Shortcut {
    sequence: "Escape"
    enabled: !PanelService.isKeybindRecording
    onActivated: RyokuSettingsPanelService.closeWindow()
  }

  Shortcut {
    sequence: "Tab"
    enabled: !PanelService.isKeybindRecording
    onActivated: settingsContent.selectNextTab()
  }

  Shortcut {
    sequence: "Backtab"
    enabled: !PanelService.isKeybindRecording
    onActivated: settingsContent.selectPreviousTab()
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyUp || []
    Shortcut {
      sequence: modelData
      enabled: !PanelService.isKeybindRecording
      onActivated: {
        if (settingsContent.searchText.trim() !== "")
          settingsContent.searchSelectPrevious();
        else
          settingsContent.scrollUp();
      }
    }
  }

  Instantiator {
    model: Settings.data.general.keybinds.keyDown || []
    Shortcut {
      sequence: modelData
      enabled: !PanelService.isKeybindRecording
      onActivated: {
        if (settingsContent.searchText.trim() !== "")
          settingsContent.searchSelectNext();
        else
          settingsContent.scrollDown();
      }
    }
  }

  // Main content
  Rectangle {
    anchors.fill: parent
    color: Qt.alpha(Color.mSurface, Settings.data.ui.panelBackgroundOpacity)
    radius: Style.radiusL

    SettingsContent {
      id: settingsContent
      anchors.fill: parent
      onCloseRequested: RyokuSettingsPanelService.closeWindow()
    }
  }
}
