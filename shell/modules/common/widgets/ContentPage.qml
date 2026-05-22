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
    property int currentSectionTab: 0
    property int sectionTabsCompactThreshold: 5
    property var sectionTabSections: []
    property var sectionTabVisibleSections: []
    property var sectionTabButtons: []

    default property alias contentData: contentColumn.data

    clip: true
    contentHeight: contentColumn.implicitHeight + root.bottomContentPadding
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
        var index = root.sectionTabVisibleSections.indexOf(section);
        if (index < 0)
            return;

        root.currentSectionTab = index;
        applySectionTabSelection();
    }

    function applySectionTabSelection() {
        var visibleSections = root.sectionTabVisibleSections;
        var selectedSection = visibleSections.length > 0 ? visibleSections[Math.max(0, Math.min(root.currentSectionTab, visibleSections.length - 1))] : null;

        for (var i = 0; i < root.sectionTabSections.length; i++) {
            var section = root.sectionTabSections[i];
            if (!section)
                continue;

            section.sectionTabsSelected = !selectedSection || section === selectedSection;
        }
    }

    function refreshSectionTabs() {
        var previousSelectedSection = root.sectionTabVisibleSections.length > 0
            ? root.sectionTabVisibleSections[Math.max(0, Math.min(root.currentSectionTab, root.sectionTabVisibleSections.length - 1))]
            : null;
        var visibleSections = [];
        var buttons = [];

        for (var i = 0; i < root.sectionTabSections.length; i++) {
            var section = root.sectionTabSections[i];
            if (!section || !section.visible)
                continue;

            visibleSections.push(section);
            buttons.push({
                name: section.title || "",
                icon: section.icon || ""
            });
        }

        root.sectionTabVisibleSections = visibleSections;
        root.sectionTabButtons = buttons;

        if (root.currentSectionTab < 0 && visibleSections.length > 0)
            root.currentSectionTab = 0;
        else if (previousSelectedSection && visibleSections.indexOf(previousSelectedSection) >= 0)
            root.currentSectionTab = visibleSections.indexOf(previousSelectedSection);
        else if (root.currentSectionTab >= visibleSections.length)
            root.currentSectionTab = Math.max(0, visibleSections.length - 1);

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
            topMargin: 20
            bottomMargin: 20
            leftMargin: root._horizontalMargin
            rightMargin: root._horizontalMargin
        }
        spacing: SettingsMaterialPreset.pageSpacing

        ToolbarTabBar {
            id: sectionTabBar
            visible: root.sectionTabButtons.length > 1
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
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
