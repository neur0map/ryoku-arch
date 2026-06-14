pragma Singleton

import QtQuick
import Ryoku.Config
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.UI

Singleton {
  id: root

  property bool isWindowOpen: false

  // Reference to the window (set by SettingsPanelWindow)
  property var settingsWindow: null

  property int requestedTab: 0

  // Requested subtab when opening (-1 means no specific subtab)
  property int requestedSubTab: -1

  property var requestedEntry: null

  signal windowOpened
  signal windowClosed

  function openToEntry(entry, screen) {
    if (GlobalConfig.ui.settingsPanelMode === "window") {
      requestedEntry = entry;
      if (settingsWindow) {
        settingsWindow.visible = true;
        isWindowOpen = true;
        windowOpened();
        settingsWindow.navigateToEntry(entry);
      }
    } else {
      if (!screen) {
        Logger.w("SettingsPanelService", "Screen parameter required for panel mode");
        return;
      }
      var settingsPanel = PanelService.getPanel("settingsPanel", screen);
      if (settingsPanel) {
        settingsPanel.requestedEntry = entry;
        settingsPanel.open();
      }
    }
  }

  // Unified function to open settings to a specific tab and subtab
  // Respects user's settingsPanelMode setting (window vs panel)
  // For panel mode, screen parameter is required
  function openToTab(tab, subTab, screen) {
    const tabId = tab !== undefined ? tab : 0;
    const subTabId = subTab !== undefined ? subTab : -1;

    if (GlobalConfig.ui.settingsPanelMode === "window") {
      requestedTab = tabId;
      requestedSubTab = subTabId;
      if (settingsWindow) {
        settingsWindow.visible = true;
        isWindowOpen = true;
        windowOpened();
        settingsWindow.navigateTo(tabId, subTabId);
      }
    } else {
      if (!screen) {
        Logger.w("SettingsPanelService", "Screen parameter required for panel mode");
        return;
      }
      var settingsPanel = PanelService.getPanel("settingsPanel", screen);
      if (settingsPanel) {
        settingsPanel.openToTab(tabId, subTabId);
      }
    }
  }

  function openWindow(tab) {
    requestedTab = tab !== undefined ? tab : 0;
    requestedSubTab = -1;
    if (settingsWindow) {
      settingsWindow.visible = true;
      isWindowOpen = true;
      windowOpened();
      settingsWindow.navigateTo(requestedTab, -1);
    }
  }

  function closeWindow() {
    if (settingsWindow) {
      settingsWindow.visible = false;
      isWindowOpen = false;
      windowClosed();
    }
  }

  function toggleWindow(tab) {
    if (isWindowOpen) {
      closeWindow();
    } else {
      openWindow(tab);
    }
  }

  // Unified toggle: opens to tab/subtab if closed, closes if open
  // Respects settingsPanelMode setting
  function toggle(tab, subTab, screen) {
    const tabId = tab !== undefined ? tab : 0;
    const subTabId = subTab !== undefined ? subTab : -1;

    if (GlobalConfig.ui.settingsPanelMode === "window") {
      if (isWindowOpen) {
        closeWindow();
      } else {
        openToTab(tabId, subTabId);
      }
    } else {
      if (!screen) {
        Logger.w("SettingsPanelService", "Screen parameter required for panel mode");
        return;
      }
      var settingsPanel = PanelService.getPanel("settingsPanel", screen);
      if (settingsPanel?.isPanelOpen) {
        settingsPanel.close();
      } else {
        settingsPanel?.openToTab(tabId, subTabId);
      }
    }
  }

  function close(screen) {
    if (GlobalConfig.ui.settingsPanelMode === "window") {
      closeWindow();
    } else {
      if (!screen)
        return;
      var settingsPanel = PanelService.getPanel("settingsPanel", screen);
      settingsPanel?.close();
    }
  }
}
