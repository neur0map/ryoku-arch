import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property string title: ""
    property string icon: ""
    property bool expanded: true
    property bool collapsible: true
    property int animationDuration: Appearance.animation.elementMove.duration
    default property alias contentData: sectionContent.data

    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1
    property bool sectionTabsManaged: false
    property bool sectionTabsSelected: true
    property var sectionTabsPage: null
    property bool sectionTabsIncludeInTabBar: true
    property string sectionTabGroup: ""
    property string sectionTabGroupIcon: ""
    property int sectionTabGroupOrder: -1
    readonly property bool sectionTabsRenderActive: !root.sectionTabsManaged || root.sectionTabsSelected

    Layout.fillWidth: true
    Layout.preferredHeight: root.implicitHeight
    Layout.maximumHeight: root.implicitHeight
    implicitHeight: root.sectionTabsManaged && !root.sectionTabsSelected ? 0 : card.implicitHeight
    enabled: !root.sectionTabsManaged || root.sectionTabsSelected
    clip: root.sectionTabsManaged && !root.sectionTabsSelected

    function _findSettingsContext() {
        var page = null;
        var p = root.parent;
        while (p) {
            if (!page && p.hasOwnProperty("settingsPageIndex")) {
                page = p;
                break;
            }
            p = p.parent;
        }
        return { page: page };
    }

    function activateFromSettingsSearch() {
        if (root.sectionTabsManaged && root.sectionTabsPage && root.sectionTabsPage.activateSectionTab)
            root.sectionTabsPage.activateSectionTab(root);
        root.expanded = true;
    }

    function focusFromSettingsSearch() {
        root.activateFromSettingsSearch();
        root.forceActiveFocus();
    }

    Component.onCompleted: {
        var ctx = _findSettingsContext();
        var page = ctx.page;
        root.sectionTabsPage = page;

        if (root.title && root.sectionTabsIncludeInTabBar && page && page.sectionTabsEnabled && page.isDirectSectionTabChild && page.isDirectSectionTabChild(root)) {
            root.sectionTabsManaged = true;
            root.sectionTabsSelected = false;
            root.collapsible = false;
            root.expanded = true;
            root.sectionTabsPage.registerSectionTab(root);
        }

        if (!enableSettingsSearch || !root.title)
            return;
        if (typeof SettingsSearchRegistry === "undefined")
            return;

        if (!root.sectionTabsManaged && SettingsSearchRegistry.registerCollapsibleSection) {
            SettingsSearchRegistry.registerCollapsibleSection(root);
        }

        settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: page && page.settingsPageIndex !== undefined ? page.settingsPageIndex : -1,
            pageName: page && page.settingsPageName ? page.settingsPageName : "",
            section: root.title,
            label: root.title,
            description: "",
            keywords: []
        });
    }

    Component.onDestruction: {
        if (root.sectionTabsManaged && root.sectionTabsPage && root.sectionTabsPage.unregisterSectionTab) {
            root.sectionTabsPage.unregisterSectionTab(root);
        }
        if (typeof SettingsSearchRegistry !== "undefined") {
            if (SettingsSearchRegistry.unregisterCollapsibleSection) {
                SettingsSearchRegistry.unregisterCollapsibleSection(root);
            }
            SettingsSearchRegistry.unregisterControl(root);
        }
    }

    onVisibleChanged: {
        if (root.sectionTabsManaged && root.sectionTabsPage && root.sectionTabsPage.refreshSectionTabs)
            root.sectionTabsPage.refreshSectionTabs();
    }

    onTitleChanged: {
        if (root.sectionTabsManaged && root.sectionTabsPage && root.sectionTabsPage.refreshSectionTabs)
            root.sectionTabsPage.refreshSectionTabs();
    }

    onIconChanged: {
        if (root.sectionTabsManaged && root.sectionTabsPage && root.sectionTabsPage.refreshSectionTabs)
            root.sectionTabsPage.refreshSectionTabs();
    }

    onSectionTabGroupChanged: {
        if (root.sectionTabsManaged && root.sectionTabsPage && root.sectionTabsPage.refreshSectionTabs)
            root.sectionTabsPage.refreshSectionTabs();
    }

    onSectionTabGroupIconChanged: {
        if (root.sectionTabsManaged && root.sectionTabsPage && root.sectionTabsPage.refreshSectionTabs)
            root.sectionTabsPage.refreshSectionTabs();
    }

    onSectionTabGroupOrderChanged: {
        if (root.sectionTabsManaged && root.sectionTabsPage && root.sectionTabsPage.refreshSectionTabs)
            root.sectionTabsPage.refreshSectionTabs();
    }

    // Shadow — lightweight offset for material/aurora, escalonado for angel
    // Material/aurora: simple offset rectangle instead of GPU-blurred RectangularShadow
    // for much better performance (especially with many cards visible at once).
    Rectangle {
        visible: root.sectionTabsRenderActive && !Appearance.angelEverywhere && Appearance.effectsEnabled
        x: card.x + 0.5
        y: card.y + 1.5
        width: card.width
        height: card.height
        radius: card.radius
        color: Appearance.colors.colShadow
        z: -1
    }
    Loader {
        active: root.sectionTabsRenderActive && Appearance.angelEverywhere
        sourceComponent: EscalonadoShadow {
            target: card
            hovered: root.expanded
        }
    }

    // Subtle left accent bar when expanded
    Rectangle {
        id: accentBar
        visible: root.sectionTabsRenderActive && !Appearance.angelEverywhere
        anchors {
            left: card.left
            top: card.top
            bottom: card.bottom
            leftMargin: 0
            topMargin: SettingsMaterialPreset.cardRadius
            bottomMargin: SettingsMaterialPreset.cardRadius
        }
        width: 2
        radius: 1
        color: SettingsMaterialPreset.accentColor
        opacity: root.expanded ? 0.6 : 0
        z: 1

        Behavior on opacity {
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    Rectangle {
        id: card

        opacity: root.sectionTabsRenderActive ? 1 : 0
        anchors.fill: parent
        implicitHeight: cardColumn.implicitHeight + SettingsMaterialPreset.cardPadding * 2
        radius: SettingsMaterialPreset.cardRadius
        color: SettingsMaterialPreset.cardColor
        border.width: Appearance.angelEverywhere ? 0
                     : (Appearance.ryokuEverywhere ? 1
                     : (Appearance.auroraEverywhere ? 1 : 1))
        border.color: Appearance.angelEverywhere ? "transparent" : SettingsMaterialPreset.cardBorderColor

        // Angel partial border
        AngelPartialBorder {
            targetRadius: card.radius
            hovered: root.expanded
        }

        ColumnLayout {
            id: cardColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: SettingsMaterialPreset.cardPadding
            }
            spacing: SettingsMaterialPreset.groupSpacing

            Rectangle {
                id: headerBackground
                Layout.fillWidth: true
                implicitHeight: headerRow.implicitHeight + SettingsMaterialPreset.headerPaddingY * 2
                radius: SettingsMaterialPreset.headerRadius
                color: headerMouseArea.containsMouse && root.collapsible && !root.sectionTabsManaged
                    ? SettingsMaterialPreset.headerHoverColor
                    : "transparent"

                Behavior on color {
                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                RowLayout {
                    id: headerRow
                    anchors.fill: parent
                    anchors.leftMargin: SettingsMaterialPreset.headerPaddingX
                    anchors.rightMargin: SettingsMaterialPreset.headerPaddingX
                    spacing: 8

                    // Icon with expand-state color
                    Loader {
                        active: root.icon && root.icon.length > 0
                        visible: active
                        Layout.alignment: Qt.AlignVCenter

                        readonly property color _iconColor: root.expanded
                            ? SettingsMaterialPreset.iconExpandedColor
                            : SettingsMaterialPreset.iconCollapsedColor

                        sourceComponent: MaterialSymbol {
                            text: root.icon
                            iconSize: Appearance.font.pixelSize.hugeass
                            color: parent._iconColor

                            Behavior on color {
                                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                        }
                    }

                    StyledText {
                        text: root.title
                        font.pixelSize: Appearance.font.pixelSize.larger
                        font.weight: Font.Medium
                        color: root.expanded
                            ? SettingsMaterialPreset.titleExpandedColor
                            : SettingsMaterialPreset.titleCollapsedColor
                        Layout.fillWidth: true

                        Behavior on color {
                            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    MaterialSymbol {
                        visible: root.collapsible && !root.sectionTabsManaged
                        text: root.expanded ? "expand_less" : "expand_more"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.angelEverywhere
                            ? Appearance.angel.colTextMuted
                            : Appearance.colors.colSubtext
                        Behavior on text {
                            enabled: false
                        }
                    }
                }

                MouseArea {
                    id: headerMouseArea
                    anchors.fill: parent
                    hoverEnabled: root.collapsible && !root.sectionTabsManaged
                    cursorShape: root.collapsible && !root.sectionTabsManaged ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.collapsible && !root.sectionTabsManaged) {
                            root.expanded = !root.expanded;
                        }
                    }
                }
            }

            Item {
                id: contentContainer
                Layout.fillWidth: true
                implicitHeight: root.sectionTabsManaged ? sectionContent.implicitHeight : (root.expanded ? sectionContent.implicitHeight : 0)
                clip: true

                Behavior on implicitHeight {
                    animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
                }

                ColumnLayout {
                    id: sectionContent
                    width: parent.width
                    spacing: 8
                    opacity: root.sectionTabsManaged || root.expanded ? 1 : 0

                    Behavior on opacity {
                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
            }
        }
    }
}
