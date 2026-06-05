pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.ambxst.modules.services
import qs.ambxst.modules.theme
import qs.ambxst.modules.components
import qs.ambxst.config

// BarPopup: A popup component that anchors to bar elements
// Inspired by end-4/dots-hyprland BarPopup implementation
PopupWindow {
    id: root

    required property Item anchorItem
    required property var bar

    default property alias contentData: contentContainer.data

    property int popupPadding: 8
    property int visualMargin: 8
    property int shadowMargin: 16
    property string variant: "popup"

    property bool closeOnFocusLost: true

    // Logical open state (changes immediately, not after animation)
    property bool isOpen: false

    signal closedExternally

    property real popupOpacity: 0
    property real popupScale: 0.9

    readonly property string barPosition: bar?.barPosition ?? "top"
    readonly property bool barAtTop: barPosition === "top"
    readonly property bool barAtBottom: barPosition === "bottom"
    readonly property bool barAtLeft: barPosition === "left"
    readonly property bool barAtRight: barPosition === "right"
    readonly property bool barVertical: barAtLeft || barAtRight

    readonly property int totalWidth: contentWidth + shadowMargin * 2
    readonly property int totalHeight: contentHeight + shadowMargin * 2
    property int contentWidth: 220
    property int contentHeight: 150

    implicitWidth: totalWidth
    implicitHeight: totalHeight

    readonly property bool frameEnabled: Config.bar?.frameEnabled ?? false
    readonly property bool containBar: Config.bar?.containBar ?? false
    readonly property int frameThickness: Config.bar?.frameThickness ?? 0
    readonly property int frameOffset: (frameEnabled && containBar) ? frameThickness : 0
    readonly property int effectiveFrameOffset: (frameEnabled && containBar) ? frameOffset : 0

    anchor.item: anchorItem
    anchor.rect.x: {
        if (barVertical) {
            if (barAtLeft)
                return anchorItem.width + visualMargin + effectiveFrameOffset - shadowMargin;
            return -totalWidth + shadowMargin - visualMargin - effectiveFrameOffset;
        }
        return (anchorItem.width - totalWidth) / 2;
    }
    anchor.rect.y: {
        if (barVertical) {
            return (anchorItem.height - totalHeight) / 2;
        }
        if (barAtTop)
            return anchorItem.height + visualMargin + effectiveFrameOffset - shadowMargin;
        return -totalHeight + shadowMargin - visualMargin - effectiveFrameOffset;
    }
    anchor.rect.width: 0
    anchor.rect.height: 0

    color: "transparent"
    visible: false

    property bool focusActive: false

    FocusGrab {
        id: focusGrab
        active: root.visible && root.focusActive
        windows: [root]

        onCleared: {
            if (root.closeOnFocusLost && root.isOpen) {
                root.isOpen = false;
                root.closedExternally();
                root.close();
            }
        }
    }

    Behavior on popupOpacity {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Behavior on popupScale {
        enabled: Config.animDuration > 0
        NumberAnimation {
            duration: Config.animDuration
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: popupContainer
        anchors.fill: parent
        anchors.margins: root.shadowMargin
        opacity: root.popupOpacity
        scale: root.popupScale
        transformOrigin: {
            if (root.barAtTop)
                return Item.Top;
            if (root.barAtBottom)
                return Item.Bottom;
            if (root.barAtLeft)
                return Item.Left;
            if (root.barAtRight)
                return Item.Right;
            return Item.Center;
        }

        StyledRect {
            id: background
            anchors.fill: parent
            variant: root.variant
            enableShadow: true
            radius: Styling.radius(8)

            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: root.popupPadding
            }
        }
    }

    function open() {
        if (visible)
            return;

        console.log("BarPopup OPEN - position:", barPosition, "anchorItem:", anchorItem.width, "x", anchorItem.height, "rect.x:", anchor.rect.x, "rect.y:", anchor.rect.y);

        // Set logical state immediately
        isOpen = true;

        popupOpacity = 0;
        popupScale = 0.9;

        visible = true;

        Qt.callLater(() => {
            popupOpacity = 1;
            popupScale = 1;
            focusActive = true;
        });
    }

    function close() {
        if (!visible)
            return;

        // Set logical state immediately
        isOpen = false;
        focusActive = false;

        popupOpacity = 0;
        popupScale = 0.9;

        closeTimer.restart();
    }

    function toggle() {
        if (visible) {
            close();
        } else {
            open();
        }
    }

    Timer {
        id: closeTimer
        interval: Config.animDuration > 0 ? Config.animDuration + 50 : 50
        onTriggered: {
            root.visible = false;
        }
    }
}
