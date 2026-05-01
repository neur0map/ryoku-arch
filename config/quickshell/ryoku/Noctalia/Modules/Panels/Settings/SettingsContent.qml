import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Noctalia.Commons
import qs.Noctalia.Modules.Panels.Settings.Tabs
import qs.Noctalia.Modules.Panels.Settings.Tabs.About
import qs.Noctalia.Modules.Panels.Settings.Tabs.Audio
import qs.Noctalia.Modules.Panels.Settings.Tabs.Bar
import qs.Noctalia.Modules.Panels.Settings.Tabs.ColorScheme
import qs.Noctalia.Modules.Panels.Settings.Tabs.Connections
import qs.Noctalia.Modules.Panels.Settings.Tabs.ControlCenter
import qs.Noctalia.Modules.Panels.Settings.Tabs.Display
import qs.Noctalia.Modules.Panels.Settings.Tabs.Dock
import qs.Noctalia.Modules.Panels.Settings.Tabs.Hooks
import qs.Noctalia.Modules.Panels.Settings.Tabs.Idle
import qs.Noctalia.Modules.Panels.Settings.Tabs.Launcher
import qs.Noctalia.Modules.Panels.Settings.Tabs.LockScreen
import qs.Noctalia.Modules.Panels.Settings.Tabs.Notifications
import qs.Noctalia.Modules.Panels.Settings.Tabs.Osd
import qs.Noctalia.Modules.Panels.Settings.Tabs.Plugins
import qs.Noctalia.Modules.Panels.Settings.Tabs.Region
import qs.Noctalia.Modules.Panels.Settings.Tabs.SessionMenu
import qs.Noctalia.Modules.Panels.Settings.Tabs.SystemMonitor
import qs.Noctalia.Modules.Panels.Settings.Tabs.UserInterface
import qs.Noctalia.Modules.Panels.Settings.Tabs.Wallpaper
import qs.Noctalia.Services.Compositor
import qs.Noctalia.Services.Power
import qs.Noctalia.Services.Ryoku
import qs.Noctalia.Services.System
import qs.Noctalia.Services.UI
import qs.Noctalia.Widgets

Item {
  id: root

  Component.onDestruction: SystemStatService.unregisterComponent("settings")

  // Screen reference for child components
  property var screen

  // Input: which tab to show initially
  property int requestedTab: 0
  property int requestedTabIndex: -1
  property string requestedRoute: ""

  // Exposed state for parent to access
  property int currentTabIndex: 0
  property var tabsModel: []
  property var activeScrollView: null
  property var activeTabContent: null
  property bool sidebarExpanded: true
  // Track if sidebar was collapsed before searching started
  property bool wasCollapsedBeforeSearch: false
  readonly property var currentTab: tabsModel[currentTabIndex] || ({})

  // Search state
  property string searchText: ""
  property var searchResults: []
  property int searchSelectedIndex: 0
  property string highlightLabelKey: ""
  property bool navigatingFromSearch: false

  // Mouse hover suppression during keyboard navigation
  property bool ignoreMouseHover: false
  property real _lastMouseX: 0
  property real _lastMouseY: 0
  property bool _mouseInitialized: false

  readonly property bool sidebarCardStyle: Settings.data.ui.settingsPanelSideBarCardStyle

  onSearchResultsChanged: {
    searchSelectedIndex = 0;
    ignoreMouseHover = true;
    _mouseInitialized = false;
  }

  // Signal when close button is clicked
  signal closeRequested

  // Search function
  onSearchTextChanged: {
    if (searchText.trim() === "") {
      searchResults = [];
      if (wasCollapsedBeforeSearch) {
        root.sidebarExpanded = false;
        wasCollapsedBeforeSearch = false;
      }
      return;
    }

    // Auto-expand sidebar when searching
    if (!root.sidebarExpanded) {
      if (root.activeFocus) {
        // If we are typing and the sidebar is collapsed and focused, we assume the user is typing to search
        wasCollapsedBeforeSearch = true;
      }
      root.sidebarExpanded = true;
    }

    if (SettingsSearchService.searchIndex.length === 0)
      return;

    // Build searchable items with resolved translations, filtering out invisible entries
    let items = [];
    for (let j = 0; j < SettingsSearchService.searchIndex.length; j++) {
      const entry = SettingsSearchService.searchIndex[j];
      if (!SettingsSearchService.isEntryVisible(entry))
        continue;
      const tabIndex = entry.tab;
      if (tabIndex < 0 || tabIndex >= tabsModel.length)
        continue;
      const tabModel = tabsModel[entry.tab];
      if (tabModel.searchable === false)
        continue;
      items.push({
                   "labelKey": entry.labelKey,
                   "descriptionKey": entry.descriptionKey,
                   "widget": entry.widget,
                   "tab": entry.tab,
                   "tabIndex": tabIndex,
                   "tabLabel": entry.tabLabel,
                   "subTab": entry.subTab,
                   "subTabLabel": entry.subTabLabel || null,
                   "featureAvailable": tabModel.featureAvailable,
                   "disabledReason": tabModel.disabledReason,
                   "label": I18n.tr(entry.labelKey),
                   "description": entry.descriptionKey ? I18n.tr(entry.descriptionKey) : "",
                   "subTabName": entry.subTabLabel ? I18n.tr(entry.subTabLabel) : ""
                 });
    }

    const results = FuzzySort.go(searchText.trim(), items, {
                                   "keys": ["label", "subTabName", "description"],
                                   "limit": 20,
                                   "scoreFn": function (r) {
                                     // r[0]=label, r[1]=subTabName, r[2]=description
                                     // Boost subTabName matches by 1.5x
                                     const labelScore = r[0].score;
                                     const subTabScore = r[1].score * 1.5;
                                     const descScore = r[2].score;
                                     return Math.max(labelScore, subTabScore, descScore);
                                   }
                                 });

    let extracted = [];
    for (let i = 0; i < results.length; i++) {
      extracted.push(results[i].obj);
    }
    searchResults = extracted;
  }

  // Navigate to a search result
  property int _pendingSubTab: -1

  function navigateToResult(entry) {
    const tabIndex = entry.tabIndex !== undefined ? entry.tabIndex : entry.tab;
    if (tabIndex < 0 || tabIndex >= tabsModel.length)
      return;

    if (tabsModel[tabIndex]?.featureAvailable === false) {
      clearHighlightImmediately();
      highlightLabelKey = "";
      _pendingSubTab = -1;
      activeTabContent = null;
      navigatingFromSearch = true;
      currentTabIndex = tabIndex;
      navigatingFromSearch = false;
      return;
    }

    highlightLabelKey = entry.labelKey;
    _pendingSubTab = (entry.subTab !== null && entry.subTab !== undefined) ? entry.subTab : -1;

    const alreadyOnTab = (currentTabIndex === tabIndex);
    navigatingFromSearch = true;
    currentTabIndex = tabIndex;
    navigatingFromSearch = false;

    if (alreadyOnTab && activeTabContent) {
      if (_pendingSubTab >= 0) {
        navigatingFromSearch = true;
        setSubTabIndex(_pendingSubTab);
        navigatingFromSearch = false;
        _pendingSubTab = -1;
      }
      highlightScrollTimer.targetKey = highlightLabelKey;
      highlightScrollTimer.restart();
    }

    // Clear highlight after a delay
    highlightClearTimer.restart();
  }

  // Navigate to a tab and optionally a subtab (simpler than navigateToResult, no highlighting)
  function navigateToTab(tabId, subTabIndex) {
    // Find the tab index by tab ID
    let tabIndex = -1;
    for (let i = 0; i < tabsModel.length; i++) {
      if (tabsModel[i].id === tabId) {
        tabIndex = i;
        break;
      }
    }

    if (tabIndex < 0)
      return;

    const hasSubTab = subTabIndex !== null && subTabIndex !== undefined && subTabIndex >= 0;
    _pendingSubTab = hasSubTab ? subTabIndex : -1;

    // Check if we're already on this tab
    const alreadyOnTab = (currentTabIndex === tabIndex);

    currentTabIndex = tabIndex;

    if (alreadyOnTab && activeTabContent && hasSubTab) {
      // Tab is already loaded, apply subtab directly
      setSubTabIndex(subTabIndex);
      _pendingSubTab = -1;
    }
  }

  function routeToTab(route) {
    switch (route) {
    case "about":
      return SettingsPanel.Tab.About;
    case "audio":
      return SettingsPanel.Tab.Audio;
    case "bar":
      return SettingsPanel.Tab.Bar;
    case "color-scheme":
      return SettingsPanel.Tab.ColorScheme;
    case "control-center":
      return SettingsPanel.Tab.ControlCenter;
    case "desktop-widgets":
      return SettingsPanel.Tab.DesktopWidgets;
    case "display":
      return SettingsPanel.Tab.Display;
    case "dock":
      return SettingsPanel.Tab.Dock;
    case "hooks":
      return SettingsPanel.Tab.Hooks;
    case "idle":
      return SettingsPanel.Tab.Idle;
    case "launcher":
      return SettingsPanel.Tab.Launcher;
    case "location":
      return SettingsPanel.Tab.Location;
    case "lock-screen":
      return SettingsPanel.Tab.LockScreen;
    case "notifications":
      return SettingsPanel.Tab.Notifications;
    case "osd":
      return SettingsPanel.Tab.OSD;
    case "plugins":
      return SettingsPanel.Tab.Plugins;
    case "session-menu":
      return SettingsPanel.Tab.SessionMenu;
    case "system":
      return SettingsPanel.Tab.System;
    case "user-interface":
      return SettingsPanel.Tab.UserInterface;
    case "wallpaper":
      return SettingsPanel.Tab.Wallpaper;
    case "wifi":
    case "bluetooth":
    case "connections":
      return SettingsPanel.Tab.Connections;
    default:
      return SettingsPanel.Tab.General;
    }
  }

  function routeToSubTab(route) {
    switch (route) {
    case "wifi":
      return 0;
    case "bluetooth":
      return 1;
    default:
      return -1;
    }
  }

  function openRoute(route) {
    requestedRoute = route || "general";
    navigateToTab(routeToTab(requestedRoute), routeToSubTab(requestedRoute));
  }

  function tabIndexForId(tabId) {
    for (let i = 0; i < tabsModel.length; i++) {
      if (tabsModel[i].id === tabId)
        return i;
    }
    return -1;
  }

  function searchSelectNext() {
    if (searchResults.length === 0)
      return;
    ignoreMouseHover = true;
    _mouseInitialized = false;
    searchSelectedIndex = Math.min(searchSelectedIndex + 1, searchResults.length - 1);
    searchResultsList.positionViewAtIndex(searchSelectedIndex, ListView.Contain);
  }

  function searchSelectPrevious() {
    if (searchResults.length === 0)
      return;
    ignoreMouseHover = true;
    _mouseInitialized = false;
    searchSelectedIndex = Math.max(searchSelectedIndex - 1, 0);
    searchResultsList.positionViewAtIndex(searchSelectedIndex, ListView.Contain);
  }

  function searchActivate() {
    if (searchSelectedIndex >= 0 && searchSelectedIndex < searchResults.length) {
      navigateToResult(searchResults[searchSelectedIndex]);
      searchInput.text = "";
    }
  }

  // Set sub-tab on the currently loaded tab content. Returns true if an NTabBar was found.
  function setSubTabIndex(subTabIndex) {
    if (activeTabContent) {
      return setSubTabRecursive(activeTabContent, subTabIndex);
    }
    return false;
  }

  function setSubTabRecursive(item, subTabIndex) {
    if (!item)
      return false;

    if (item.objectName === "NTabBar") {
      // Prepare the sibling NTabView so the index change doesn't animate
      if (item.parent) {
        for (let j = 0; j < item.parent.children.length; j++) {
          const sibling = item.parent.children[j];
          if (sibling.objectName === "NTabView" && sibling.setIndexWithoutAnimation) {
            sibling.setIndexWithoutAnimation(subTabIndex);
            break;
          }
        }
      }
      item.currentIndex = subTabIndex;
      return true;
    }

    const childCount = item.children ? item.children.length : 0;
    for (let i = 0; i < childCount; i++) {
      if (setSubTabRecursive(item.children[i], subTabIndex))
        return true;
    }
    return false;
  }

  onCurrentTabIndexChanged: {
    if (!navigatingFromSearch) {
      clearHighlightImmediately();
    }
  }

  property var currentSubTabBar: null

  onActiveTabContentChanged: {
    if (currentSubTabBar) {
      try {
        currentSubTabBar.currentIndexChanged.disconnect(onSubTabChanged);
      } catch (e) {}
      currentSubTabBar = null;
    }

    if (activeTabContent) {
      const tabBar = findNTabBar(activeTabContent);
      if (tabBar) {
        currentSubTabBar = tabBar;
        currentSubTabBar.currentIndexChanged.connect(onSubTabChanged);
      }
    }
  }

  function onSubTabChanged() {
    if (!navigatingFromSearch) {
      clearHighlightImmediately();
    }
  }

  function findNTabBar(item) {
    if (!item)
      return null;

    if (item.objectName === "NTabBar") {
      return item;
    }

    const childCount = item.children ? item.children.length : 0;
    for (let i = 0; i < childCount; i++) {
      const found = findNTabBar(item.children[i]);
      if (found)
        return found;
    }
    return null;
  }

  function clearHighlightImmediately() {
    highlightClearTimer.stop();
    highlightScrollTimer.stop();
    highlightAnimation.stop();
    highlightLabelKey = "";
    highlightOverlay.opacity = 0;
  }

  function isEffectivelyVisible(item) {
    var current = item;
    while (current) {
      if (current.visible === false)
        return false;
      if (current.opacity !== undefined && current.opacity <= 0)
        return false;
      current = current.parent;
    }
    return true;
  }

  // Find and highlight a widget by its label key.
  function findAndHighlightWidget(item, labelKey) {
    if (!item)
      return null;

    // Skip hidden branches to avoid highlighting controls that are not on screen.
    if (!isEffectivelyVisible(item))
      return null;

    // Check if this item has a matching label.
    if (item.hasOwnProperty("label") && item.label === I18n.tr(labelKey) && item.width > 0 && item.height > 0) {
      return item;
    }

    // Recursively search children
    if (item.children) {
      for (let i = 0; i < item.children.length; i++) {
        const found = findAndHighlightWidget(item.children[i], labelKey);
        if (found)
          return found;
      }
    }
    return null;
  }

  Timer {
    id: highlightClearTimer
    interval: 3000
    onTriggered: root.highlightLabelKey = ""
  }

  Timer {
    id: highlightScrollTimer
    interval: 333
    property string targetKey: ""
    onTriggered: {
      if (root.activeTabContent && targetKey) {
        const widget = root.findAndHighlightWidget(root.activeTabContent, targetKey);
        if (widget && root.activeScrollView) {
          // Scroll widget into view using the Flickable directly
          const flickable = root.activeScrollView.contentItem;
          const mapped = widget.mapToItem(flickable.contentItem, 0, 0);
          const targetY = mapped.y - flickable.height / 3;
          flickable.contentY = Math.max(0, Math.min(targetY, flickable.contentHeight - flickable.height));

          // Position highlight overlay after scroll layout has settled
          Qt.callLater(function () {
            const overlayPos = widget.mapToItem(tabContentArea, 0, 0);
            highlightOverlay.x = overlayPos.x - Style.marginM;
            highlightOverlay.y = overlayPos.y - Style.marginM;
            highlightOverlay.width = widget.width + Style.margin2M;
            highlightOverlay.height = widget.height + Style.margin2M;
            highlightAnimation.restart();
          });
        }
      }
      targetKey = "";
    }
  }

  // Clear highlight when the user scrolls so the outline doesn't stay in place
  Connections {
    target: root.activeScrollView ? root.activeScrollView.contentItem : null
    enabled: root.highlightLabelKey !== "" && !highlightScrollTimer.running
    function onContentYChanged() {
      root.clearHighlightImmediately();
    }
  }

  // Save sidebar state when it changes
  onSidebarExpandedChanged: {
    ShellState.setSettingsSidebarExpanded(sidebarExpanded);
    if (!sidebarExpanded) {
      root.searchText = "";
      searchInput.text = "";
      root.forceActiveFocus();
    }
  }

  Component.onCompleted: {
    SystemStatService.registerComponent("settings");
    // Restore sidebar state
    sidebarExpanded = ShellState.getSettingsSidebarExpanded();
  }

  // Tab components
  Component {
    id: generalTab
    GeneralTab {}
  }
  Component {
    id: launcherTab
    LauncherTab {}
  }
  Component {
    id: barTab
    BarTab {}
  }
  Component {
    id: audioTab
    AudioTab {}
  }
  Component {
    id: displayTab
    DisplayTab {}
  }
  Component {
    id: osdTab
    OsdTab {}
  }
  Component {
    id: connectionsTab
    ConnectionsTab {}
  }
  Component {
    id: regionTab
    RegionTab {}
  }
  Component {
    id: colorSchemeTab
    ColorSchemeTab {}
  }
  Component {
    id: wallpaperTab
    WallpaperTab {}
  }
  Component {
    id: aboutTab
    AboutTab {}
  }
  Component {
    id: hooksTab
    HooksTab {}
  }
  Component {
    id: idleTab
    IdleTab {}
  }
  Component {
    id: dockTab
    DockTab {}
  }
  Component {
    id: notificationsTab
    NotificationsTab {}
  }
  Component {
    id: controlCenterTab
    ControlCenterTab {}
  }
  Component {
    id: userInterfaceTab
    UserInterfaceTab {}
  }
  Component {
    id: lockScreenTab
    LockScreenTab {}
  }
  Component {
    id: sessionMenuTab
    SessionMenuTab {}
  }
  Component {
    id: systemMonitorTab
    SystemMonitorTab {}
  }
  Component {
    id: pluginsTab
    PluginsTab {}
  }
  Component {
    id: desktopWidgetsTab
    DesktopWidgetsTab {}
  }

  function makeTab(tabId, label, icon, source, route) {
    const featureAvailable = RyokuFeatureAvailability.isRouteEnabled(route);
    return {
      "id": tabId,
      "label": label,
      "icon": icon,
      "source": source,
      "route": route,
      "searchable": true,
      "featureAvailable": featureAvailable,
      "disabledReason": RyokuFeatureAvailability.disabledReason(route)
    };
  }

  function updateTabsModel() {
    let newTabs = [
          makeTab(SettingsPanel.Tab.General, "common.general", "settings-general", generalTab, "general"),
          makeTab(SettingsPanel.Tab.UserInterface, "panels.user-interface.title", "settings-user-interface", userInterfaceTab, "user-interface"),
          makeTab(SettingsPanel.Tab.ColorScheme, "panels.color-scheme.title", "settings-color-scheme", colorSchemeTab, "color-scheme"),
          makeTab(SettingsPanel.Tab.Wallpaper, "common.wallpaper", "settings-wallpaper", wallpaperTab, "wallpaper"),
          makeTab(SettingsPanel.Tab.Bar, "panels.bar.title", "settings-bar", barTab, "bar"),
          makeTab(SettingsPanel.Tab.Dock, "panels.dock.title", "settings-dock", dockTab, "dock"),
          makeTab(SettingsPanel.Tab.DesktopWidgets, "panels.desktop-widgets.title", "clock", desktopWidgetsTab, "desktop-widgets"),
          makeTab(SettingsPanel.Tab.ControlCenter, "panels.control-center.title", "settings-control-center", controlCenterTab, "control-center"),
          makeTab(SettingsPanel.Tab.Launcher, "panels.launcher.title", "settings-launcher", launcherTab, "launcher"),
          makeTab(SettingsPanel.Tab.Notifications, "common.notifications", "settings-notifications", notificationsTab, "notifications"),
          makeTab(SettingsPanel.Tab.OSD, "panels.osd.title", "settings-osd", osdTab, "osd"),
          makeTab(SettingsPanel.Tab.LockScreen, "panels.lock-screen.title", "settings-lock-screen", lockScreenTab, "lock-screen"),
          makeTab(SettingsPanel.Tab.SessionMenu, "session-menu.title", "settings-session-menu", sessionMenuTab, "session-menu"),
          makeTab(SettingsPanel.Tab.Idle, "panels.idle.title", "settings-idle", idleTab, "idle"),
          makeTab(SettingsPanel.Tab.Audio, "panels.audio.title", "settings-audio", audioTab, "audio"),
          makeTab(SettingsPanel.Tab.Display, "panels.display.title", "settings-display", displayTab, "display"),
          makeTab(SettingsPanel.Tab.Connections, "panels.connections.title", "settings-network", connectionsTab, "connections"),
          makeTab(SettingsPanel.Tab.Location, "panels.region.title", "settings-location", regionTab, "location"),
          makeTab(SettingsPanel.Tab.System, "panels.system.title", "settings-system-monitor", systemMonitorTab, "system"),
          makeTab(SettingsPanel.Tab.Plugins, "panels.plugins.title", "plugin", pluginsTab, "plugins"),
          makeTab(SettingsPanel.Tab.Hooks, "panels.hooks.title", "settings-hooks", hooksTab, "hooks"),
          makeTab(SettingsPanel.Tab.About, "panels.about.title", "settings-about", aboutTab, "about")
        ];

    root.tabsModel = newTabs;
  }

  function selectTabById(tabId) {
    for (var i = 0; i < tabsModel.length; i++) {
      if (tabsModel[i].id === tabId) {
        currentTabIndex = i;
        return;
      }
    }
    currentTabIndex = 0;
  }

  function selectTabByIndex(tabIndex) {
    if (tabIndex >= 0 && tabIndex < tabsModel.length) {
      currentTabIndex = tabIndex;
      return;
    }
    currentTabIndex = 0;
  }

  function initialize() {
    ProgramCheckerService.checkAllPrograms();
    // Guard _pendingSubTab during model rebuild: updateTabsModel() triggers
    // a ListView model reset which can set currentTabIndex=0 via the sidebar
    // sync handler, causing the wrong tab to load and consume _pendingSubTab.
    const savedPendingSubTab = _pendingSubTab;
    _pendingSubTab = -1;
    updateTabsModel();
    _pendingSubTab = requestedTabIndex >= 0 ? -1 : savedPendingSubTab;
    if (requestedTabIndex >= 0) {
      selectTabByIndex(requestedTabIndex);
      requestedTabIndex = -1;
    } else {
      selectTabById(requestedTab);
    }
    // Skip auto-focus on Nvidia GPUs - cursor blink causes UI choppiness
    const isNvidia = SystemStatService.gpuType === "nvidia";
    if (sidebarExpanded && !isNvidia) {
      Qt.callLater(() => {
                     if (searchInput.inputItem)
                     searchInput.inputItem.forceActiveFocus();
                   });
    } else {
      // Ensure root has focus so it can catch typing
      Qt.callLater(() => root.forceActiveFocus());
    }
  }

  // Handle typing when sidebar is collapsed
  focus: true
  Keys.onPressed: event => {
                    if (!sidebarExpanded && event.text.length > 0 && event.text.trim() !== "") {
                      // Only capture if it looks like visible text
                      if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                      return;

                      // Explicitly ignore backspace and similar keys that might have text but shouldn't trigger search
                      if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Delete || event.key === Qt.Key_Escape)
                      return;

                      wasCollapsedBeforeSearch = true;
                      sidebarExpanded = true;
                      searchInput.text = event.text;
                      Qt.callLater(() => {
                                     if (searchInput.inputItem) {
                                       searchInput.inputItem.forceActiveFocus();
                                       // Cursor moves to end automatically usually, but let's be safe
                                       searchInput.inputItem.cursorPosition = 1;
                                     }
                                   });
                      event.accepted = true;
                    }
                  }

  // Scroll functions
  function scrollDown() {
    if (activeScrollView && activeScrollView.ScrollBar.vertical) {
      const scrollBar = activeScrollView.ScrollBar.vertical;
      const stepSize = activeScrollView.height * 0.1;
      scrollBar.position = Math.min(scrollBar.position + stepSize / activeScrollView.contentHeight, 1.0 - scrollBar.size);
    }
  }

  function scrollUp() {
    if (activeScrollView && activeScrollView.ScrollBar.vertical) {
      const scrollBar = activeScrollView.ScrollBar.vertical;
      const stepSize = activeScrollView.height * 0.1;
      scrollBar.position = Math.max(scrollBar.position - stepSize / activeScrollView.contentHeight, 0);
    }
  }

  function scrollPageDown() {
    if (activeScrollView && activeScrollView.ScrollBar.vertical) {
      const scrollBar = activeScrollView.ScrollBar.vertical;
      const pageSize = activeScrollView.height * 0.9;
      scrollBar.position = Math.min(scrollBar.position + pageSize / activeScrollView.contentHeight, 1.0 - scrollBar.size);
    }
  }

  function scrollPageUp() {
    if (activeScrollView && activeScrollView.ScrollBar.vertical) {
      const scrollBar = activeScrollView.ScrollBar.vertical;
      const pageSize = activeScrollView.height * 0.9;
      scrollBar.position = Math.max(scrollBar.position - pageSize / activeScrollView.contentHeight, 0);
    }
  }

  // Tab navigation functions
  function selectNextTab() {
    if (tabsModel.length > 0) {
      currentTabIndex = (currentTabIndex + 1) % tabsModel.length;
    }
  }

  function selectPreviousTab() {
    if (tabsModel.length > 0) {
      currentTabIndex = (currentTabIndex - 1 + tabsModel.length) % tabsModel.length;
    }
  }

  // Main UI
  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.marginL

      // Sidebar
      NBox {
        id: sidebar

        clip: true
        Layout.preferredWidth: Math.round(root.sidebarExpanded ? 200 * Style.uiScaleRatio : sidebarToggle.width + (root.sidebarCardStyle ? Style.margin2M : 0) + (sidebarList.verticalScrollBarActive ? Style.marginM : 0))
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop

        radius: root.sidebarCardStyle ? Style.radiusM : 0
        color: root.sidebarCardStyle ? Color.mSurfaceVariant : "transparent"
        border.color: root.sidebarCardStyle ? Style.boxBorderColor : "transparent"

        Behavior on Layout.preferredWidth {
          NumberAnimation {
            duration: Style.animationFast
            easing.type: Easing.InOutQuad
          }
        }

        // Sidebar content
        ColumnLayout {
          anchors.fill: parent
          spacing: Style.marginS
          anchors.margins: root.sidebarCardStyle ? Style.marginM : 0

          // Sidebar toggle button
          Item {
            id: toggleContainer
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(toggleRow.implicitHeight + Style.margin2S)

            Rectangle {
              id: sidebarToggle
              width: Math.round(toggleRow.implicitWidth + Style.margin2S)
              height: parent.height
              anchors.left: parent.left
              radius: Style.radiusS
              color: toggleMouseArea.containsMouse ? Color.mHover : "transparent"

              Behavior on color {
                enabled: !Color.isTransitioning
                ColorAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.InOutQuad
                }
              }

              RowLayout {
                id: toggleRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.marginS
                spacing: 0

                NIcon {
                  icon: root.sidebarExpanded ? "layout-sidebar-right-expand" : "layout-sidebar-left-expand"
                  color: toggleMouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
                  pointSize: Style.fontSizeXL
                }
              }

              MouseArea {
                id: toggleMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                  TooltipService.show(sidebarToggle, root.sidebarExpanded ? I18n.tr("tooltips.collapse") : I18n.tr("tooltips.expand"));
                }
                onExited: {
                  TooltipService.hide();
                }
                onClicked: {
                  TooltipService.hide();
                  root.sidebarExpanded = !root.sidebarExpanded;
                }
              }
            }
          }

          // Search container wrapper to prevent layout jumps
          Item {
            id: searchContainerWrapper
            Layout.fillWidth: true
            Layout.preferredHeight: searchInput.implicitHeight > 0 ? searchInput.implicitHeight : (Style.fontSizeXL + Style.margin2M)

            // Search input
            NTextInput {
              id: searchInput
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              placeholderText: I18n.tr("common.search")
              inputIconName: "search"
              visible: opacity > 0
              opacity: root.sidebarExpanded ? 1.0 : 0.0

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.InOutQuad
                }
              }

              onTextChanged: root.searchText = text
              onEditingFinished: {
                if (root.searchText.trim() !== "")
                  root.searchActivate();
              }
            }

            // Search button for collapsed sidebar
            Item {
              id: searchCollapsedContainer
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: Math.round(searchCollapsedRow.implicitHeight + Style.margin2S)
              visible: opacity > 0
              opacity: !root.sidebarExpanded ? 1.0 : 0.0

              Behavior on opacity {
                NumberAnimation {
                  duration: Style.animationFast
                  easing.type: Easing.InOutQuad
                }
              }

              Rectangle {
                id: searchCollapsedButton
                width: Math.round(searchCollapsedRow.implicitWidth + Style.margin2S)
                height: parent.height
                anchors.left: parent.left
                radius: Style.radiusS
                color: searchCollapsedMouseArea.containsMouse ? Color.mHover : "transparent"

                Behavior on color {
                  enabled: !Color.isTransitioning
                  ColorAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.InOutQuad
                  }
                }

                RowLayout {
                  id: searchCollapsedRow
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.leftMargin: Style.marginS
                  spacing: 0

                  NIcon {
                    icon: "search"
                    color: searchCollapsedMouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
                    pointSize: Style.fontSizeXL
                  }
                }

                MouseArea {
                  id: searchCollapsedMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.sidebarExpanded = true;
                    root.wasCollapsedBeforeSearch = false; // Expanding manually resets this
                    Qt.callLater(() => searchInput.inputItem.forceActiveFocus());
                  }
                  onEntered: {
                    TooltipService.show(searchCollapsedButton, I18n.tr("common.search"));
                  }
                  onExited: {
                    TooltipService.hide();
                  }
                }
              }
            }
          }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.bottomMargin: Style.marginXL

            // Search results list
            NListView {
              id: searchResultsList
              anchors.fill: parent
              model: root.searchResults
              spacing: Style.marginXS
              visible: root.searchText.trim() !== ""
              verticalPolicy: ScrollBar.AsNeeded
              gradientColor: "transparent"
              reserveScrollbarSpace: false

              HoverHandler {
                onPointChanged: {
                  if (!root._mouseInitialized) {
                    root._lastMouseX = point.position.x;
                    root._lastMouseY = point.position.y;
                    root._mouseInitialized = true;
                    return;
                  }

                  const deltaX = Math.abs(point.position.x - root._lastMouseX);
                  const deltaY = Math.abs(point.position.y - root._lastMouseY);
                  if (deltaX + deltaY >= 5) {
                    root.ignoreMouseHover = false;
                    root._lastMouseX = point.position.x;
                    root._lastMouseY = point.position.y;
                  }
                }
              }

              delegate: Rectangle {
                id: resultItem
                width: searchResultsList.width - (searchResultsList.verticalScrollBarActive ? Style.marginM : 0)
                height: resultColumn.implicitHeight + Style.margin2M
                radius: Style.iRadiusS
                readonly property bool featureAvailable: modelData.featureAvailable !== false
                readonly property bool selected: index === root.searchSelectedIndex
                readonly property bool effectiveHover: !root.ignoreMouseHover && resultMouseArea.containsMouse
                color: (effectiveHover || selected) ? Qt.alpha(Color.mHover, featureAvailable ? 1.0 : 0.45) : "transparent"

                Behavior on color {
                  enabled: !Color.isTransitioning
                  ColorAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.InOutQuad
                  }
                }

                ColumnLayout {
                  id: resultColumn
                  anchors.fill: parent
                  anchors.leftMargin: Style.marginL
                  anchors.rightMargin: Style.marginL
                  anchors.topMargin: Style.marginM
                  anchors.bottomMargin: Style.marginM
                  spacing: 0
                  opacity: resultItem.featureAvailable ? 1.0 : 0.55

                  NText {
                    text: I18n.tr(modelData.labelKey)
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: resultItem.featureAvailable ? ((resultItem.effectiveHover || resultItem.selected) ? Color.mOnHover : Color.mOnSurface) : Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }

                  NText {
                    text: {
                      let t = I18n.tr(modelData.tabLabel);
                      if (modelData.subTabLabel)
                        t += " › " + I18n.tr(modelData.subTabLabel);
                      return t;
                    }
                    pointSize: Style.fontSizeXS
                    color: resultItem.featureAvailable && (resultItem.effectiveHover || resultItem.selected) ? Color.mOnHover : Color.mOnSurfaceVariant
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    maximumLineCount: 1
                  }
                }

                MouseArea {
                  id: resultMouseArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onEntered: {
                    if (!root.ignoreMouseHover)
                      root.searchSelectedIndex = index;
                  }
                  onClicked: {
                    root.searchSelectedIndex = index;
                    root.navigateToResult(modelData);
                    searchInput.text = "";
                  }
                }
              }
            }

            // Tab list
            NListView {
              id: sidebarList
              visible: root.searchText.trim() === ""
              anchors.fill: parent
              model: root.tabsModel
              spacing: Style.marginXS
              currentIndex: root.currentTabIndex
              horizontalPolicy: ScrollBar.AlwaysOff
              verticalPolicy: ScrollBar.AlwaysOff
              gradientColor: "transparent"
              reserveScrollbarSpace: false

              delegate: Rectangle {
                id: tabItem
                width: sidebarList.width
                height: tabEntryRow.implicitHeight + Style.margin2XS
                radius: Style.iRadiusS
                readonly property bool featureAvailable: modelData.featureAvailable !== false
                color: featureAvailable ? (selected ? Color.mPrimary : (tabItem.hovering ? Color.mHover : "transparent")) : (tabItem.hovering ? Qt.alpha(Color.mHover, 0.45) : "transparent")
                readonly property bool selected: index === root.currentTabIndex
                property bool hovering: false
                property color tabTextColor: featureAvailable ? (selected ? Color.mOnPrimary : (tabItem.hovering ? Color.mOnHover : Color.mOnSurface)) : Color.mOnSurfaceVariant

                Behavior on color {
                  enabled: !Color.isTransitioning
                  ColorAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.InOutQuad
                  }
                }

                Behavior on tabTextColor {
                  enabled: !Color.isTransitioning
                  ColorAnimation {
                    duration: Style.animationFast
                    easing.type: Easing.InOutQuad
                  }
                }

                RowLayout {
                  id: tabEntryRow
                  anchors.fill: parent
                  anchors.leftMargin: Style.marginS
                  anchors.rightMargin: Style.marginS
                  spacing: Style.marginM
                  opacity: tabItem.featureAvailable ? 1.0 : 0.55

                  NIcon {
                    icon: modelData.icon
                    color: tabTextColor
                    pointSize: Style.fontSizeXL
                    Layout.alignment: Qt.AlignVCenter
                  }

                  NText {
                    text: I18n.tr(modelData.label)
                    color: tabTextColor
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.sidebarExpanded
                    opacity: root.sidebarExpanded ? 1.0 : 0.0

                    Behavior on opacity {
                      NumberAnimation {
                        duration: Style.animationFast
                        easing.type: Easing.InOutQuad
                      }
                    }
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.LeftButton
                  cursorShape: Qt.PointingHandCursor
                  onEntered: {
                    tabItem.hovering = true;
                    // Show tooltip when sidebar is collapsed
                    if (!root.sidebarExpanded) {
                      TooltipService.show(tabItem, modelData.featureAvailable ? I18n.tr(modelData.label) : modelData.disabledReason);
                    }
                  }
                  onExited: {
                    tabItem.hovering = false;
                    // Hide tooltip when sidebar is collapsed
                    if (!root.sidebarExpanded) {
                      TooltipService.hide();
                    }
                  }
                  onCanceled: {
                    tabItem.hovering = false;
                    if (!root.sidebarExpanded) {
                      TooltipService.hide();
                    }
                  }
                  onClicked: {
                    root.currentTabIndex = index;
                    // Hide tooltip on click
                    if (!root.sidebarExpanded) {
                      TooltipService.hide();
                    }
                  }
                }
              }

              onCurrentIndexChanged: {
                if (currentIndex !== root.currentTabIndex) {
                  root.currentTabIndex = currentIndex;
                }
              }

              Connections {
                target: root
                function onCurrentTabIndexChanged() {
                  if (sidebarList.currentIndex !== root.currentTabIndex) {
                    sidebarList.currentIndex = root.currentTabIndex;
                    sidebarList.positionViewAtIndex(root.currentTabIndex, ListView.Contain);
                  }
                }
              }
            }
          }
        }
      }

      // Content pane
      NBox {
        id: contentPane
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        radius: Style.radiusM
        color: Color.mSurfaceVariant

        ColumnLayout {
          id: contentLayout
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.margins: Style.marginL
          width: Math.min(parent.width - Style.marginL * 2, 780 * Style.uiScaleRatio)
          spacing: Style.marginS

          // Header row
          RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: root.tabsModel[currentTabIndex]?.icon ?? ""
              color: root.currentTab.featureAvailable === false ? Color.mOnSurfaceVariant : Color.mPrimary
              pointSize: Style.fontSizeXXL
            }

            NText {
              text: root.tabsModel[root.currentTabIndex]?.label ? I18n.tr(root.tabsModel[root.currentTabIndex].label) : ""
              pointSize: Style.fontSizeXL
              font.weight: Style.fontWeightBold
              color: root.currentTab.featureAvailable === false ? Color.mOnSurfaceVariant : Color.mPrimary
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
            }

            NIconButton {
              icon: "close"
              tooltipText: I18n.tr("common.close")
              Layout.alignment: Qt.AlignVCenter
              onClicked: root.closeRequested()
            }
          }

          // Tab content area
          Rectangle {
            id: tabContentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: -Style.marginM
            Layout.rightMargin: -Style.marginL
            color: "transparent"

            Repeater {
              id: contentRepeater
              model: root.tabsModel
              delegate: Loader {
                anchors.fill: parent
                active: index === root.currentTabIndex
                opacity: 0

                NumberAnimation on opacity {
                  id: fadeInAnim
                  from: 0
                  to: 1
                  duration: Style.animationSlowest
                  easing.type: Easing.OutCubic
                  running: false
                }

                onStatusChanged: {
                  if (status === Loader.Ready && item) {
                    fadeInAnim.start();
                    const scrollView = item.children[0];
                    if (scrollView && scrollView.toString().includes("ScrollView")) {
                      root.activeScrollView = scrollView;
                    }
                  }
                }

                sourceComponent: NScrollView {
                  id: scrollView
                  anchors.fill: parent
                  horizontalPolicy: ScrollBar.AlwaysOff
                  verticalPolicy: ScrollBar.AsNeeded
                  leftPadding: Style.marginL
                  topPadding: Style.marginL
                  bottomPadding: Style.marginL
                  userRightPadding: Style.marginL
                  reserveScrollbarSpace: false

                  Component.onCompleted: {
                    root.activeScrollView = scrollView;
                  }

                  Column {
                    width: scrollView.availableWidth
                    spacing: Style.marginL

                    Component.onCompleted: {
                      if (root.tabsModel[index]?.featureAvailable === false) {
                        root.activeTabContent = null;
                      }
                    }

                    NBox {
                      width: parent.width
                      visible: root.tabsModel[index]?.featureAvailable === false
                      implicitHeight: unavailableContent.implicitHeight + Style.margin2L
                      radius: Style.radiusM
                      color: Color.mSurface
                      border.color: Style.boxBorderColor

                      RowLayout {
                        id: unavailableContent
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Style.marginL
                        anchors.rightMargin: Style.marginL
                        spacing: Style.marginM

                        NIcon {
                          icon: "warning"
                          color: Color.mOnSurfaceVariant
                          pointSize: Style.fontSizeXL
                          Layout.alignment: Qt.AlignVCenter
                        }

                        NLabel {
                          label: "Unavailable in Ryoku"
                          description: root.tabsModel[index]?.disabledReason ?? ""
                          Layout.fillWidth: true
                          Layout.alignment: Qt.AlignVCenter
                        }
                      }
                    }

                    Loader {
                      id: guardedTabLoader
                      active: true
                      enabled: root.tabsModel[index]?.featureAvailable
                      opacity: root.tabsModel[index]?.featureAvailable ? 1.0 : 0.45
                      sourceComponent: root.tabsModel[index]?.featureAvailable ? root.tabsModel[index]?.source : null
                      width: scrollView.availableWidth
                      onLoaded: {
                        if (item && item.hasOwnProperty("screen")) {
                          item.screen = root.screen;
                        }
                        root.activeTabContent = item;
                        if (root._pendingSubTab >= 0) {
                          root.navigatingFromSearch = true;
                          if (root.setSubTabIndex(root._pendingSubTab))
                            root._pendingSubTab = -1;
                          root.navigatingFromSearch = false;
                        }
                        if (root.highlightLabelKey) {
                          highlightScrollTimer.targetKey = root.highlightLabelKey;
                          highlightScrollTimer.restart();
                        }
                      }

                      Behavior on opacity {
                        NumberAnimation {
                          duration: Style.animationFast
                          easing.type: Easing.InOutQuad
                        }
                      }
                    }
                  }
                }
              }
            }

            // Highlight overlay for search results
            Rectangle {
              id: highlightOverlay
              visible: opacity > 0
              opacity: 0
              color: Qt.alpha(Color.mSecondary, 0.2)
              border.color: Qt.alpha(Color.mSecondary, 0.6)
              border.width: Style.borderM
              radius: Style.radiusS
              z: 100

              SequentialAnimation {
                id: highlightAnimation

                NumberAnimation {
                  target: highlightOverlay
                  property: "opacity"
                  to: 1.0
                  duration: Style.animationSlow
                  easing.type: Easing.OutQuad
                }

                PauseAnimation {
                  duration: 2000
                }

                NumberAnimation {
                  target: highlightOverlay
                  property: "opacity"
                  to: 0
                  duration: Style.animationSlowest
                  easing.type: Easing.InQuad
                }
              }
            }
          }
        }
      }
    }
  }
}
