pragma Singleton

import QtQuick
import Quickshell

Singleton {
  id: root

  property bool isWindowOpen: false
  property var settingsWindow: null
  property int requestedTab: 0
  property int requestedSubTab: -1
  property string requestedRoute: ""
  property var requestedEntry: null
  readonly property string statePath: `${Quickshell.env("HOME")}/.local/state/ryoku/noctalia-settings/state.json`

  signal windowOpened
  signal windowClosed

  function openToEntry(entry) {
    requestedEntry = entry;
    if (settingsWindow) {
      settingsWindow.visible = true;
    }
    isWindowOpen = true;
    windowOpened();
    if (settingsWindow) {
      settingsWindow.navigateToEntry(entry);
    }
  }

  function openToTab(tab, subTab) {
    const tabId = tab !== undefined && tab !== null ? tab : 0;
    const subTabId = subTab !== undefined && subTab !== null ? subTab : -1;
    requestedTab = tabId;
    requestedSubTab = subTabId;
    if (settingsWindow) {
      settingsWindow.visible = true;
    }
    isWindowOpen = true;
    windowOpened();
    if (settingsWindow) {
      settingsWindow.navigateTo(tabId, subTabId);
    }
  }

  function openWindow(tab) {
    openToTab(tab || 0, -1);
  }

  function openRoute(route) {
    requestedRoute = route || "general";
    if (settingsWindow) {
      settingsWindow.visible = true;
    }
    isWindowOpen = true;
    windowOpened();
    if (settingsWindow) {
      settingsWindow.navigateToRoute(requestedRoute);
    }
  }

  function closeWindow() {
    if (settingsWindow) {
      settingsWindow.visible = false;
    }
    isWindowOpen = false;
    windowClosed();
  }

  function toggle(tab, subTab) {
    if (isWindowOpen) {
      closeWindow();
    } else {
      openToTab(tab, subTab);
    }
  }

  function close() {
    closeWindow();
  }
}
