import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root
    property real bottomContentPadding: 100
    // Metadatos opcionales para páginas de Settings
    property int settingsPageIndex: -1
    property string settingsPageName: ""
    property bool sectionTabsEnabled: true
    property bool sectionTabsSticky: true
    property int currentSectionTab: 0
    property int sectionTabsCompactThreshold: 5
    property var sectionTabSections: []
    property var sectionTabVisibleSections: []
    property var sectionTabVisibleGroups: []
    property var sectionTabButtons: []
    readonly property bool sectionTabsVisible: root.sectionTabButtons.length > 1
    readonly property real sectionTabsReservedHeight: root.sectionTabsVisible && root.sectionTabsSticky
        ? sectionTabBarShell.implicitHeight + SettingsMaterialPreset.pageSpacing
        : 0
    readonly property real _contentTopMargin: 20 + root.sectionTabsReservedHeight

    default property alias contentData: contentColumn.data

    clip: true
    contentHeight: root._contentTopMargin + contentColumn.implicitHeight + root.bottomContentPadding
    implicitWidth: contentColumn.implicitWidth

    // Responsive horizontal margins: more breathing room on wider containers
    readonly property real _horizontalMargin: {
        const w = root.width
        if (w > 1200) return 48
        if (w > 900) return 32
        if (w > 600) return 24
        return 16
    }

    function isDirectSectionTabChild(item) {
        return item && item.parent === contentColumn;
    }

    function sectionTabChildOrder(item) {
        var children = contentColumn.children;
        for (var i = 0; i < children.length; i++) {
            if (children[i] === item)
                return i;
        }
        return 9999;
    }

    function sectionTabGroupKey(section) {
        var group = String(section?.sectionTabGroup || "");
        if (group.length > 0)
            return group;
        return String(section?.title || "");
    }

    function sectionTabGroupIcon(section) {
        var icon = String(section?.sectionTabGroupIcon || "");
        if (icon.length > 0)
            return icon;
        return String(section?.icon || "");
    }

    function sectionTabGroupOrder(section) {
        if (section && section.sectionTabGroupOrder >= 0)
            return section.sectionTabGroupOrder;
        return root.sectionTabChildOrder(section);
    }

    function registerSectionTab(section) {
        if (!section || !root.sectionTabsEnabled)
            return;
        if (!root.isDirectSectionTabChild(section))
            return;
        if (root.sectionTabSections.indexOf(section) !== -1)
            return;

        var sections = root.sectionTabSections.slice();
        sections.push(section);
        sections.sort(function(a, b) {
            return root.sectionTabChildOrder(a) - root.sectionTabChildOrder(b);
        });
        root.sectionTabSections = sections;
        refreshSectionTabs();
    }

    function unregisterSectionTab(section) {
        if (!section)
            return;

        var sections = [];
        for (var i = 0; i < root.sectionTabSections.length; i++) {
            if (root.sectionTabSections[i] !== section)
                sections.push(root.sectionTabSections[i]);
        }
        root.sectionTabSections = sections;
        refreshSectionTabs();
    }

    function activateSectionTab(section) {
        if (!section)
            return;

        refreshSectionTabs();
        var groupKey = root.sectionTabGroupKey(section);
        if (!groupKey.length)
            return;

        for (var i = 0; i < root.sectionTabVisibleGroups.length; i++) {
            if (root.sectionTabVisibleGroups[i].key !== groupKey)
                continue;
            root.currentSectionTab = i;
            break;
        }
        applySectionTabSelection();
    }

    function applySectionTabSelection() {
        var visibleGroups = root.sectionTabVisibleGroups;
        var selectedGroup = visibleGroups.length > 0 ? visibleGroups[Math.max(0, Math.min(root.currentSectionTab, visibleGroups.length - 1))] : null;

        for (var i = 0; i < root.sectionTabSections.length; i++) {
            var section = root.sectionTabSections[i];
            if (!section)
                continue;

            section.sectionTabsSelected = !selectedGroup || root.sectionTabGroupKey(section) === selectedGroup.key;
        }
    }

    function refreshSectionTabs() {
        var previousSelectedGroup = root.sectionTabVisibleGroups.length > 0
            ? root.sectionTabVisibleGroups[Math.max(0, Math.min(root.currentSectionTab, root.sectionTabVisibleGroups.length - 1))]
            : null;
        var previousSelectedGroupKey = previousSelectedGroup ? previousSelectedGroup.key : "";
        var visibleSections = [];
        var visibleGroups = [];
        var visibleGroupsByKey = ({});
        var buttons = [];

        for (var i = 0; i < root.sectionTabSections.length; i++) {
            var section = root.sectionTabSections[i];
            if (!section || !section.visible)
                continue;

            visibleSections.push(section);
            var key = root.sectionTabGroupKey(section);
            if (!key.length)
                continue;

            var group = visibleGroupsByKey[key];
            if (!group) {
                group = {
                    key: key,
                    name: key,
                    icon: root.sectionTabGroupIcon(section),
                    order: root.sectionTabGroupOrder(section),
                    sections: []
                };
                visibleGroupsByKey[key] = group;
                visibleGroups.push(group);
            }

            group.sections.push(section);
            group.order = Math.min(group.order, root.sectionTabGroupOrder(section));
            if (!group.icon.length)
                group.icon = root.sectionTabGroupIcon(section);
        }

        visibleGroups.sort(function(a, b) {
            return a.order - b.order;
        });
        for (var j = 0; j < visibleGroups.length; j++) {
            buttons.push({
                name: visibleGroups[j].name,
                icon: visibleGroups[j].icon
            });
        }

        root.sectionTabVisibleSections = visibleSections;
        root.sectionTabVisibleGroups = visibleGroups;
        root.sectionTabButtons = buttons;

        if (root.currentSectionTab < 0 && visibleGroups.length > 0)
            root.currentSectionTab = 0;
        else if (previousSelectedGroupKey.length > 0) {
            var preservedGroupIndex = -1;
            for (var k = 0; k < visibleGroups.length; k++) {
                if (visibleGroups[k].key === previousSelectedGroupKey) {
                    preservedGroupIndex = k;
                    break;
                }
            }
            if (preservedGroupIndex >= 0)
                root.currentSectionTab = preservedGroupIndex;
            else if (root.currentSectionTab >= visibleGroups.length)
                root.currentSectionTab = Math.max(0, visibleGroups.length - 1);
        } else if (root.currentSectionTab >= visibleGroups.length)
            root.currentSectionTab = Math.max(0, visibleGroups.length - 1);

        applySectionTabSelection();
        Qt.callLater(() => {
            if (sectionTabBar.currentIndex !== root.currentSectionTab)
                sectionTabBar.setCurrentIndex(root.currentSectionTab);
        });
    }

    onCurrentSectionTabChanged: Qt.callLater(() => {
        if (sectionTabBar.currentIndex !== root.currentSectionTab)
            sectionTabBar.setCurrentIndex(root.currentSectionTab);
    })

    ColumnLayout {
        id: contentColumn
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: root._contentTopMargin
            bottomMargin: 20
            leftMargin: root._horizontalMargin
            rightMargin: root._horizontalMargin
        }
        spacing: SettingsMaterialPreset.pageSpacing
    }

    Item {
        id: sectionTabBarShell
        visible: root.sectionTabsVisible
        x: root._horizontalMargin
        y: root.sectionTabsSticky ? root.contentY + 20 : 0
        z: 10
        width: Math.max(0, root.width - root._horizontalMargin * 2)
        implicitHeight: sectionTabBar.implicitHeight

        Rectangle {
            visible: root.sectionTabsSticky
            anchors {
                fill: parent
                leftMargin: -8
                rightMargin: -8
                topMargin: -6
                bottomMargin: -6
            }
            radius: Appearance.rounding.full
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                 : Appearance.ryokuEverywhere ? Appearance.ryoku.colLayer0
                 : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                 : Appearance.colors.colLayer0
            opacity: 0.92
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                        : Appearance.ryokuEverywhere ? 1 : 0
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                        : Appearance.ryokuEverywhere ? Appearance.ryoku.colBorder
                        : "transparent"
        }

        ToolbarTabBar {
            id: sectionTabBar
            anchors.centerIn: parent
            width: parent.width
            maxWidth: parent.width
            tabButtonList: root.sectionTabButtons
            compactThreshold: root.sectionTabsCompactThreshold
            wheelNavigationEnabled: false
            initialIndex: root.currentSectionTab
            onCurrentIndexChanged: {
                if (root.currentSectionTab !== currentIndex) {
                    root.currentSectionTab = currentIndex;
                    root.applySectionTabSelection();
                }
            }
        }
    }
}
