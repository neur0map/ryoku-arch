import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.functions

ComboBox {
    id: root

    // Settings search integration (optional)
    property bool enableSettingsSearch: true
    property int settingsSearchOptionId: -1
    property string settingsSearchLabel: ""
    property string settingsSearchDescription: ""
    property list<string> settingsSearchKeywords: []

    property real baseHeight: 38
    property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
        : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
        : Appearance.rounding.small

    hoverEnabled: true
    opacity: root.enabled ? 1 : 0.4

    readonly property color _bgColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer2
    readonly property color _bgHoverColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceHover
        : Appearance.colors.colLayer2Hover
    readonly property color _bgActiveColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer2Active
    readonly property color _textColor: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer2
    readonly property color _subtextColor: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color _borderColor: Appearance.angelEverywhere ? Appearance.angel.colBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : "transparent"
    readonly property real _borderWidth: (Appearance.angelEverywhere || Appearance.inirEverywhere) ? 1 : 0
    readonly property color _popupColor: Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.colors.colLayer3Base
    readonly property color _popupBorderColor: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder
        : Appearance.auroraEverywhere ? Appearance.aurora.colPopupBorder
        : Appearance.colors.colLayer0Border
    readonly property color _selectedColor: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colPrimaryContainer
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colPrimaryContainer

    background: Rectangle {
        implicitHeight: root.baseHeight
        radius: root.radius
        color: root.down ? root._bgActiveColor
            : root.hovered ? root._bgHoverColor
            : root._bgColor
        border.width: root._borderWidth
        border.color: root.activeFocus
            ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                : Appearance.inirEverywhere ? Appearance.inir.colBorderFocus
                : root._borderColor)
            : root._borderColor

        Behavior on color {
            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
    }

    contentItem: RowLayout {
        spacing: 6

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            text: root.displayText
            color: root._textColor
            font.pixelSize: Appearance.font.pixelSize.small
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }

        MaterialSymbol {
            Layout.rightMargin: 8
            text: "expand_more"
            iconSize: Appearance.font.pixelSize.normal
            color: root._subtextColor
            rotation: root.popup.visible ? 180 : 0
            Behavior on rotation {
                enabled: Appearance.animationsEnabled
                RotationAnimation {
                    duration: Appearance.animation.elementMoveFast.duration
                    direction: RotationAnimation.Shortest
                    easing.type: Appearance.animation.elementMoveFast.type
                    easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                }
            }
        }
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 300)
        padding: 4

        background: Rectangle {
            id: popupBg
            radius: root.radius
            color: root._popupColor
            border.width: 1
            border.color: root._popupBorderColor
        }

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: contentHeight > 290 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
        }
    }

    delegate: ItemDelegate {
        id: delegateItem
        required property int index
        required property var modelData

        width: root.width - 8
        height: 36
        highlighted: root.highlightedIndex === index
        hoverEnabled: true

        background: Rectangle {
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                : Appearance.rounding.unsharpenmore
            color: delegateItem.index === root.currentIndex ? root._selectedColor
                : delegateItem.hovered ? root._bgHoverColor
                : "transparent"

            Behavior on color {
                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }

        contentItem: RowLayout {
            spacing: 6

            MaterialSymbol {
                Layout.leftMargin: 8
                text: "check"
                iconSize: Appearance.font.pixelSize.small
                color: root._textColor
                visible: delegateItem.index === root.currentIndex
            }

            Item {
                Layout.leftMargin: 8
                implicitWidth: Appearance.font.pixelSize.small
                visible: delegateItem.index !== root.currentIndex
            }

            StyledText {
                Layout.fillWidth: true
                text: {
                    if (typeof delegateItem.modelData === "object" && delegateItem.modelData !== null) {
                        return delegateItem.modelData[root.textRole] ?? delegateItem.modelData.toString()
                    }
                    return delegateItem.modelData?.toString() ?? ""
                }
                font.pixelSize: Appearance.font.pixelSize.small
                color: root._textColor
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    function _findSettingsContext() {
        var page = null;
        var sectionTitle = "";
        var groupTitle = "";
        var p = root.parent;
        while (p) {
            if (!page && p.hasOwnProperty("settingsPageIndex")) {
                page = p;
            }
            if (p.hasOwnProperty("title")) {
                if (!sectionTitle && p.hasOwnProperty("icon")) {
                    sectionTitle = p.title;
                } else if (!groupTitle && !p.hasOwnProperty("icon")) {
                    groupTitle = p.title;
                }
            }
            p = p.parent;
        }
        return { page: page, sectionTitle: sectionTitle, groupTitle: groupTitle };
    }

    function focusFromSettingsSearch() {
        var p = root.parent;
        while (p) {
            if (p.hasOwnProperty("expanded") && p.hasOwnProperty("collapsible")) {
                p.expanded = true;
                break;
            }
            p = p.parent;
        }
        root.forceActiveFocus();
    }

    Component.onCompleted: {
        if (!enableSettingsSearch)
            return;
        if (typeof SettingsSearchRegistry === "undefined")
            return;

        var ctx = _findSettingsContext();
        var page = ctx.page;
        var pageIndex = page && page.settingsPageIndex !== undefined ? page.settingsPageIndex : -1;
        if (pageIndex < 0)
            return;

        var sectionTitle = ctx.sectionTitle;
        var label = root.settingsSearchLabel || ctx.groupTitle || sectionTitle;

        settingsSearchOptionId = SettingsSearchRegistry.registerOption({
            control: root,
            pageIndex: pageIndex,
            pageName: page && page.settingsPageName ? page.settingsPageName : "",
            section: sectionTitle,
            label: label,
            description: root.settingsSearchDescription || "",
            keywords: root.settingsSearchKeywords || []
        });
    }

    Component.onDestruction: {
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.unregisterControl(root);
        }
    }
}
