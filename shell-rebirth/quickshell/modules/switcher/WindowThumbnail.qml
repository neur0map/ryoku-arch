import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import "../../colors" as ColorsModule

Item {
    id: thumbContainer

    property var hWin: null
    property var wHandle:null

    property string winKey: ''

    property real thumbW: -1
    property real thumbH: -1

    property var clientInfo: {}
    property bool hovered: false

    property real targetX: -1000
    property real targetY: -1000
    property real targetZ: 0
    property real targetRotation: 0

    property bool moveCursorToActiveWindow: false

    width: thumbW
    height: thumbH

    x: 0
    y: 0
    z: targetZ
    rotation: 0

    visible: !!wHandle

    NumberAnimation {
        id: animX
        target: thumbContainer
        property: "x"
        duration: root.animateWindows ? 100 : 0
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: animY
        target: thumbContainer
        property: "y"
        duration: root.animateWindows ? 100 : 0
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: animRotation
        target: thumbContainer
        property: "rotation"
        duration: 400
        easing.type: Easing.OutBack // Effetto rimbalzo/inerzia
        easing.overshoot: 1.2
    }

    function updateLastPos() {
        var lp = root.lastPositions || ({})
        var prev = lp[winKey] || ({})
        prev.x = x
        prev.y = y
        lp[winKey] = prev
        root.lastPositions = lp
    }

    onTargetXChanged: {
        if (!root.animateWindows) {
            x = targetX
            updateLastPos()
            return
        }

        var lp = root.lastPositions || ({})
        var prev = lp[winKey]
        var startX = (prev && prev.x !== undefined) ? prev.x : targetX

        if (startX === targetX) {
            x = targetX
            updateLastPos()
            return
        }

        animX.stop()
        animX.from = startX
        animX.to = targetX
        animX.start()
    }

    onTargetYChanged: {
        if (!root.animateWindows) {
            y = targetY
            updateLastPos()
            return
        }

        var lp = root.lastPositions || ({})
        var prev = lp[winKey]
        var startY = (prev && prev.y !== undefined) ? prev.y : targetY

        if (startY === targetY) {
            y = targetY
            updateLastPos()
            return
        }

        animY.stop()
        animY.from = startY
        animY.to = targetY
        animY.start()
    }

    onTargetRotationChanged: {
        rotation = targetRotation
        animRotation.stop()
        animRotation.from = 0
        animRotation.to = targetRotation
        animRotation.start()
    }

    onXChanged: updateLastPos()
    onYChanged: updateLastPos()

    Component.onCompleted: {
        rotation = targetRotation
        if (!root.animateWindows) {
            x = targetX
            y = targetY
            updateLastPos()
        }
    }

    function activateWindow() {
        if (!hWin) return

        var targetIsSpecial = (hWin?.workspace ?? 0) < 0 || (hWin?.workspace?.name ?? "").startsWith("special")

        if (root.specialActive && !targetIsSpecial) {
            Hyprland.dispatch("togglespecialworkspace")
        }

        if (hWin.workspace) {
            hWin.workspace.activate()
        }

        root.toggleExpose()
        Hyprland.dispatch("focuswindow address:0x" + hWin.address)
        Hyprland.dispatch("alterzorder top")
        if (thumbContainer.moveCursorToActiveWindow) {
          var cx = clientInfo.at[0] + (clientInfo.size[0]/2)
          var cy = clientInfo.at[1] + (clientInfo.size[1]/2)
        Hyprland.dispatch("movecursor " + cx + " " + cy)

        }
    }

    function closeWindow() {
        if (!hWin) return
        Hyprland.dispatch("closewindow address:0x" + hWin.address)
    }

    function refreshThumb() {
        if (thumbLoader.item) {
            thumbLoader.item.captureFrame()
        }
    }

    Item {
        id: card
        anchors.fill: parent

        scale: thumbContainer.hovered ? 1.05 : 0.95
        transformOrigin: Item.Center

        Behavior on scale {
            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton

            onEntered: {
                exposeArea.currentIndex = index
            }
            onClicked: event => {
                exposeArea.currentIndex = index

                if (event.button === Qt.LeftButton) {
                    thumbContainer.activateWindow()
                }
                if (event.button === Qt.MiddleButton) {
                    thumbContainer.closeWindow()
                }
            }
            onExited: {
                if (exposeArea.currentIndex === index) {
                    exposeArea.currentIndex = -1
                }
            }
        }

        RectangularShadow {
            anchors.fill: parent
            radius: 16
            blur: 24
            spread: 10
            color: "#55000000"
            cached: true
        }

        Loader {
            id: thumbLoader
            anchors.fill: parent
            active: root.isActive && !!thumbContainer.wHandle
            sourceComponent: ScreencopyView {
                id: thumb
                anchors.fill: parent
                captureSource: thumbContainer.wHandle
                live: root.liveCapture && root.isActive
                paintCursor: false
                visible: root.isActive && thumbContainer.wHandle && hasContent

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: thumb.width
                        height: thumb.height
                        radius: 16
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: thumbContainer.hovered
                        ? Qt.rgba(
                            Qt.color(ColorsModule.Colors.primary).r,
                            Qt.color(ColorsModule.Colors.primary).g,
                            Qt.color(ColorsModule.Colors.primary).b, 0.08)
                        : "transparent"
                    border.width: thumbContainer.hovered ? 2 : 1
                    border.color: thumbContainer.hovered
                        ? ColorsModule.Colors.primary
                        : Qt.rgba(1, 1, 1, 0.12)
                    radius: 16
                    Behavior on border.width { NumberAnimation { duration: 120 } }
                    Behavior on color        { ColorAnimation  { duration: 150 } }
                    Behavior on border.color { ColorAnimation  { duration: 150 } }
                }
            }
        }

        Rectangle {
            id: badge
            z: 100
            width: Math.min(titleText.implicitWidth + 24, thumbContainer.thumbW * 0.8)
            height: 26

            x: (card.width - width) / 2
            y: card.height - height - 10

            radius: 13
            color: Qt.rgba(0, 0, 0, thumbContainer.hovered ? 0.72 : 0.55)
            border.width: 1
            border.color: thumbContainer.hovered
                ? Qt.rgba(
                    Qt.color(ColorsModule.Colors.primary).r,
                    Qt.color(ColorsModule.Colors.primary).g,
                    Qt.color(ColorsModule.Colors.primary).b, 0.6)
                : Qt.rgba(1, 1, 1, 0.10)

            Behavior on color        { ColorAnimation  { duration: 150 } }
            Behavior on border.color { ColorAnimation  { duration: 150 } }

            Text {
                id: titleText
                anchors.centerIn: parent
                width: parent.width - 16
                text: hWin.title
                color: thumbContainer.hovered ? "white" : Qt.rgba(1, 1, 1, 0.75)
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
    }
}