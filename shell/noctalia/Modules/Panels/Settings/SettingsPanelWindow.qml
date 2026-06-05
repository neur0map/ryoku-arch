import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.noctalia.Commons
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

FloatingWindow {
  id: root

  title: "Ryoku Settings"
  minimumSize: Qt.size(840 * Style.uiScaleRatio, 910 * Style.uiScaleRatio)
  implicitWidth: Math.round(840 * Style.uiScaleRatio)
  implicitHeight: Math.round(910 * Style.uiScaleRatio)
  color: "transparent"

  visible: false

  Component.onCompleted: {
    SettingsPanelService.settingsWindow = root;
  }

  property bool isInitialized: false

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

  // Works whether the window is already visible or just becoming visible.
  function navigateToEntry(entry) {
    if (isInitialized) {
      Qt.callLater(() => settingsContent.navigateToResult(entry));
    } else {
      settingsContent.requestedTab = entry.tab;
      settingsContent.initialize();
      Qt.callLater(() => settingsContent.navigateToResult(entry));
      isInitialized = true;
    }
  }

  onVisibleChanged: {
    if (visible) {
      SettingsPanelService.isWindowOpen = true;
    } else {
      isInitialized = false;
      SettingsPanelService.isWindowOpen = false;
    }
  }

  Shortcut {
    sequence: "Escape"
    enabled: !PanelService.isKeybindRecording
    onActivated: SettingsPanelService.closeWindow()
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

  Rectangle {
    anchors.fill: parent
    color: Qt.alpha(Color.mSurface, Settings.data.ui.panelBackgroundOpacity)
    radius: Style.radiusL

    SettingsContent {
      id: settingsContent
      anchors.fill: parent
      onCloseRequested: SettingsPanelService.closeWindow()
    }
  }
}
