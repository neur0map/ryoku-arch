import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.settingsgui.Commons
import qs.settingsgui.Modules.Panels.Settings.Tabs
import qs.settingsgui.Modules.Panels.Settings.Tabs.About
import qs.settingsgui.Modules.Panels.Settings.Tabs.Audio
import qs.settingsgui.Modules.Panels.Settings.Tabs.Bar
import qs.settingsgui.Modules.Panels.Settings.Tabs.ColorScheme
import qs.settingsgui.Modules.Panels.Settings.Tabs.Connections
import qs.settingsgui.Modules.Panels.Settings.Tabs.ControlCenter
import qs.settingsgui.Modules.Panels.Settings.Tabs.Display
import qs.settingsgui.Modules.Panels.Settings.Tabs.Extras
import qs.settingsgui.Modules.Panels.Settings.Tabs.Idle
import qs.settingsgui.Modules.Panels.Settings.Tabs.Launcher
import qs.settingsgui.Modules.Panels.Settings.Tabs.LockScreen
import qs.settingsgui.Modules.Panels.Settings.Tabs.Notifications
import qs.settingsgui.Modules.Panels.Settings.Tabs.Osd
import qs.settingsgui.Modules.Panels.Settings.Tabs.Plugins
import qs.settingsgui.Modules.Panels.Settings.Tabs.Region
import qs.settingsgui.Modules.Panels.Settings.Tabs.SystemMonitor
import qs.settingsgui.Modules.Panels.Settings.Tabs.UserInterface
import qs.settingsgui.Modules.Panels.Settings.Tabs.Wallpaper
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Services.Power
import qs.settingsgui.Services.System
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

Item {
  id: root

  Component.onDestruction: SystemStatService.unregisterComponent("settings")

  property var screen

  // Input: which tab to show initially
  property int requestedTab: 0

  property int currentTabIndex: 0
  property var tabsModel: []
  property var activeScrollView: null
  property var activeTabContent: null
  property bool sidebarExpanded: true
  // Track if sidebar was collapsed before searching started
  property bool wasCollapsedBeforeSearch: false

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

  signal closeRequested

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

    let items = [];
    for (let j = 0; j < SettingsSearchService.searchIndex.length; j++) {
      const entry = SettingsSearchService.searchIndex[j];
      if (!SettingsSearchService.isEntryVisible(entry))
        continue;
      items.push({
                   "labelKey": entry.labelKey,
                   "descriptionKey": entry.descriptionKey,
                   "widget": entry.widget,
                   "tab": entry.tab,
                   "tabLabel": entry.tabLabel,
                   "subTab": entry.subTab,
                   "subTabLabel": entry.subTabLabel || null,
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

  property int _pendingSubTab: -1

  function navigateToResult(entry) {
    // Resolve the tab by its stable tabLabel rather than the entry's positional index:
    // the static search index numbers drift whenever tabsModel is reordered (e.g. when a
    // tab is removed), so position is unreliable. Fall back to entry.tab if no label match.
    var tabIndex = entry.tab;
    for (var i = 0; i < tabsModel.length; i++) {
      if (tabsModel[i].label === entry.tabLabel) {
        tabIndex = i;
        break;
      }
    }

    if (tabIndex < 0 || tabIndex >= tabsModel.length)
      return;

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

    highlightClearTimer.restart();
  }

  // Navigate to a tab and optionally a subtab (simpler than navigateToResult, no highlighting)
  function navigateToTab(tabId, subTabIndex) {
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

    const alreadyOnTab = (currentTabIndex === tabIndex);

    currentTabIndex = tabIndex;

    if (alreadyOnTab && activeTabContent && hasSubTab) {
      // Tab is already loaded, apply subtab directly
      setSubTabIndex(subTabIndex);
      _pendingSubTab = -1;
    }
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

  function findAndHighlightWidget(item, labelKey) {
    if (!item)
      return null;

    // Skip hidden branches to avoid highlighting controls that are not on screen.
    if (!isEffectivelyVisible(item))
      return null;

    if (item.hasOwnProperty("label") && item.label === I18n.tr(labelKey) && item.width > 0 && item.height > 0) {
      return item;
    }

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
    sidebarExpanded = ShellState.getSettingsSidebarExpanded();
  }

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
    id: hyprlandTab
    HyprlandTab {}
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
    id: extrasTab
    ExtrasTab {}
  }
  Component {
    id: gameModeTab
    GameModeTab {}
  }
  Component {
    id: idleTab
    IdleTab {}
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

  function updateTabsModel() {
    let newTabs = [
          {
            "id": SettingsPanel.Tab.General,
            "label": "common.general",
            "icon": "settings-general",
            "source": generalTab
          },
          {
            "id": SettingsPanel.Tab.UserInterface,
            "label": "panels.user-interface.title",
            "icon": "settings-user-interface",
            "source": userInterfaceTab
          },
          {
            "id": SettingsPanel.Tab.ColorScheme,
            "label": "panels.color-scheme.title",
            "icon": "settings-color-scheme",
            "source": colorSchemeTab
          },
          {
            "id": SettingsPanel.Tab.Wallpaper,
            "label": "common.wallpaper",
            "icon": "settings-wallpaper",
            "source": wallpaperTab
          },
          {
            "id": SettingsPanel.Tab.Bar,
            "label": "panels.bar.title",
            "icon": "settings-bar",
            "source": barTab
          },
          {
            "id": SettingsPanel.Tab.DesktopWidgets,
            "label": "panels.desktop-widgets.title",
            "icon": "clock",
            "source": desktopWidgetsTab
          },
          {
            "id": SettingsPanel.Tab.ControlCenter,
            "label": "panels.control-center.title",
            "icon": "settings-control-center",
            "source": controlCenterTab
          },
          {
            "id": SettingsPanel.Tab.Launcher,
            "label": "panels.launcher.title",
            "icon": "settings-launcher",
            "source": launcherTab
          },
          {
            "id": SettingsPanel.Tab.Notifications,
            "label": "common.notifications",
            "icon": "settings-notifications",
            "source": notificationsTab
          },
          {
            "id": SettingsPanel.Tab.OSD,
            "label": "panels.osd.title",
            "icon": "settings-osd",
            "source": osdTab
          },
          {
            "id": SettingsPanel.Tab.LockScreen,
            "label": "panels.lock-screen.title",
            "icon": "settings-lock-screen",
            "source": lockScreenTab
          },
          {
            "id": SettingsPanel.Tab.Idle,
            "label": "panels.idle.title",
            "icon": "settings-idle",
            "source": idleTab
          },
          {
            "id": SettingsPanel.Tab.Audio,
            "label": "panels.audio.title",
            "icon": "settings-audio",
            "source": audioTab
          },
          {
            "id": SettingsPanel.Tab.Display,
            "label": "panels.display.title",
            "icon": "settings-display",
            "source": displayTab
          },
          {
            "id": SettingsPanel.Tab.Hyprland,
            "label": "panels.hyprland.title",
            "icon": "settings-display",
            "source": hyprlandTab
          },
          {
            "id": SettingsPanel.Tab.Connections,
            "label": "panels.connections.title",
            "icon": "settings-network",
            "source": connectionsTab
          },
          {
            "id": SettingsPanel.Tab.Location,
            "label": "panels.region.title",
            "icon": "settings-location",
            "source": regionTab
          },
          {
            "id": SettingsPanel.Tab.System,
            "label": "panels.system.title",
            "icon": "settings-system-monitor",
            "source": systemMonitorTab,
            "disabled": true // TODO: upstream system-monitor thresholds/colors config has no ryoku backend (ryoku has SystemUsage but not this schema)
          },
          {
            "id": SettingsPanel.Tab.Plugins,
            "label": "panels.plugins.title",
            "icon": "plugin",
            "source": pluginsTab,
          },
          {
            "id": SettingsPanel.Tab.Extras,
            "label": "panels.extras.title",
            "icon": "package",
            "source": extrasTab
          },
          {
            "id": SettingsPanel.Tab.GameMode,
            "label": "panels.game-mode.tab",
            "icon": "device-gamepad",
            "source": gameModeTab
          },
          {
            "id": SettingsPanel.Tab.About,
            "label": "panels.about.title",
            "icon": "settings-about",
            "source": aboutTab
          }
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

  function initialize() {
    ProgramCheckerService.checkAllPrograms();
    // Guard _pendingSubTab during model rebuild: updateTabsModel() triggers
    // a ListView model reset which can set currentTabIndex=0 via the sidebar
    // sync handler, causing the wrong tab to load and consume _pendingSubTab.
    const savedPendingSubTab = _pendingSubTab;
    _pendingSubTab = -1;
    updateTabsModel();
    _pendingSubTab = savedPendingSubTab;
    // RYOKU: honor a one-shot tab request (e.g. the desktop-widget edit toolbar's
    // settings button opening straight to the Desktop Widgets tab).
    if (Visibilities.pendingSettingsTab === "DesktopWidgets")
      requestedTab = SettingsPanel.Tab.DesktopWidgets;
    if (Visibilities.pendingSettingsTab === "Connections")
      requestedTab = SettingsPanel.Tab.Connections;
    if (Visibilities.pendingSettingsTab.length > 0)
      Visibilities.pendingSettingsTab = "";
    selectTabById(requestedTab);
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

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Style.marginL

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

        ColumnLayout {
          anchors.fill: parent
          spacing: Style.marginS
          anchors.margins: root.sidebarCardStyle ? Style.marginM : 0

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
                readonly property bool selected: index === root.searchSelectedIndex
                readonly property bool effectiveHover: !root.ignoreMouseHover && resultMouseArea.containsMouse
                color: (effectiveHover || selected) ? Color.mHover : "transparent"

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

                  NText {
                    text: I18n.tr(modelData.labelKey)
                    pointSize: Style.fontSizeM
                    font.weight: Style.fontWeightSemiBold
                    color: (resultItem.effectiveHover || resultItem.selected) ? Color.mOnHover : Color.mOnSurface
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
                    color: (resultItem.effectiveHover || resultItem.selected) ? Color.mOnHover : Color.mOnSurfaceVariant
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
                // RYOKU: tabs with no backend yet are dimmed as a marker, but stay
                // navigable so their content can be previewed (greyed) — see content Loader below.
                opacity: isDisabled ? 0.6 : 1.0
                color: selected ? Color.mPrimary : (tabItem.hovering ? Color.mHover : "transparent")
                readonly property bool selected: index === root.currentTabIndex
                readonly property bool isDisabled: modelData.disabled === true
                property bool hovering: false
                property color tabTextColor: selected ? Color.mOnPrimary : (tabItem.hovering ? Color.mOnHover : Color.mOnSurface)

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
                    // RYOKU: disabled tabs stay navigable as a greyed, read-only preview
                    if (tabItem.isDisabled)
                      TooltipService.show(tabItem, I18n.tr(modelData.label) + " — preview only, not available in ryoku yet");
                    else if (!root.sidebarExpanded)
                      TooltipService.show(tabItem, I18n.tr(modelData.label));
                  }
                  onExited: {
                    tabItem.hovering = false;
                    // RYOKU: always hide — disabled tabs show a hint tooltip even when
                    // the sidebar is expanded, so the guard left the bubble stuck.
                    TooltipService.hide();
                  }
                  onCanceled: {
                    tabItem.hovering = false;
                    TooltipService.hide();
                  }
                  onClicked: {
                    root.currentTabIndex = index;
                    TooltipService.hide();
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

          RowLayout {
            id: headerRow
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: root.tabsModel[currentTabIndex]?.icon ?? ""
              color: Color.mPrimary
              pointSize: Style.fontSizeXXL
            }

            NText {
              text: root.tabsModel[root.currentTabIndex]?.label ? I18n.tr(root.tabsModel[root.currentTabIndex].label) : ""
              pointSize: Style.fontSizeXL
              font.weight: Style.fontWeightBold
              color: Color.mPrimary
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

                  Loader {
                    active: true
                    // RYOKU: disabled tabs render as a greyed, non-interactive preview
                    // (NScrollView stays scrollable so the whole tab can be seen).
                    enabled: !(root.tabsModel[index]?.disabled === true)
                    opacity: (root.tabsModel[index]?.disabled === true) ? 0.45 : 1.0
                    sourceComponent: root.tabsModel[index]?.source
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
                  }
                }
              }
            }

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
