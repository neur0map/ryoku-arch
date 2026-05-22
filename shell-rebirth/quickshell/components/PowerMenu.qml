import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../colors" as ColorsModule

Item {
    id: root
    anchors.fill: parent
    visible: false
    focus: true

    // ── Inline orb component ─────────────────────────────────────────────────

    component PowerOrb: Item {
        id: orb

        required property string icon
        required property string label
        required property color glowColor
        signal activated()

        width: 124
        height: 168
        opacity: 0

        property bool hovered: false
        property bool isPressed: false

        function enter(delayMs) {
            enterDelay.interval = delayMs
            enterDelay.start()
        }

        Timer {
            id: enterDelay
            onTriggered: {
                orb.y = 24
                slideIn.restart()
            }
        }

        ParallelAnimation {
            id: slideIn
            NumberAnimation {
                target: orb; property: "opacity"
                to: 1; duration: 380; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: orb; property: "y"
                to: 0; duration: 420; easing.type: Easing.OutCubic
            }
        }

        // Outer glow ring (visible on hover)
        Rectangle {
            anchors.centerIn: circle
            width: circle.width + 24
            height: circle.height + 24
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(
                orb.glowColor.r, orb.glowColor.g, orb.glowColor.b,
                orb.hovered ? 0.28 : 0
            )
            scale: orb.hovered ? 1 : 0.8

            Behavior on border.color { ColorAnimation { duration: 200 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }

        // Main circle
        Rectangle {
            id: circle
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96
            height: 96
            radius: 48

            color: Qt.rgba(
                orb.glowColor.r, orb.glowColor.g, orb.glowColor.b,
                orb.isPressed ? 0.35 : orb.hovered ? 0.22 : 0.1
            )
            border.width: 1.5
            border.color: Qt.rgba(
                orb.glowColor.r, orb.glowColor.g, orb.glowColor.b,
                orb.hovered ? 0.8 : 0.3
            )
            scale: orb.isPressed ? 0.86 : orb.hovered ? 1.1 : 1.0

            // inner top shine
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.5
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Text {
                anchors.centerIn: parent
                text: orb.icon
                font.family: "Material Design Icons"
                font.pixelSize: 38
                color: orb.glowColor
                opacity: orb.hovered ? 1.0 : 0.75
                Behavior on opacity { NumberAnimation { duration: 160 } }
            }

            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }
        }

        // Label
        Text {
            anchors.top: circle.bottom
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            text: orb.label.toUpperCase()
            font.pixelSize: 10
            font.weight: Font.Medium
            font.letterSpacing: 2.5
            color: Qt.rgba(1, 1, 1, orb.hovered ? 0.88 : 0.38)
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: orb.hovered = true
            onExited: { orb.hovered = false; orb.isPressed = false }
            onPressed: orb.isPressed = true
            onReleased: orb.isPressed = false
            onClicked: orb.activated()
        }
    }

    // ── Process ───────────────────────────────────────────────────────────────

    Process { id: proc }

    // ── Backdrop ─────────────────────────────────────────────────────────────

    Rectangle {
        id: backdrop
        anchors.fill: parent
        opacity: 0

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.88) }
            GradientStop { position: 0.42; color: Qt.rgba(0, 0, 0, 0.74) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.88) }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    // ── Header label ─────────────────────────────────────────────────────────

    Column {
        id: header
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: orbRow.top
        anchors.bottomMargin: 52
        spacing: 8
        opacity: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰐥"
            font.family: "Material Design Icons"
            font.pixelSize: 20
            color: Qt.rgba(1, 1, 1, 0.22)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "POWER MENU"
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 4.0
            color: Qt.rgba(1, 1, 1, 0.25)
        }

        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    }

    // ── Orb row ───────────────────────────────────────────────────────────────

    Row {
        id: orbRow
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -20
        spacing: 44

        PowerOrb {
            id: lockOrb
            icon: "󰌾"
            label: "Lock"
            glowColor: ColorsModule.Colors.secondary
            onActivated: {
                root.close()
                proc.exec(["quickshell", "-p",
                    Quickshell.env("RYOKU_REBIRTH_SHELL_DIR") + "/Lock.qml"])
            }
        }

        PowerOrb {
            id: logoutOrb
            icon: "󰍃"
            label: "Logout"
            glowColor: ColorsModule.Colors.tertiary
            onActivated: {
                root.close()
                proc.exec(["bash", "-c", "sleep 0.35 && loginctl terminate-user $USER"])
            }
        }

        PowerOrb {
            id: rebootOrb
            icon: "󰜉"
            label: "Reboot"
            glowColor: ColorsModule.Colors.primary
            onActivated: {
                root.close()
                proc.exec(["bash", "-c", "sleep 0.35 && systemctl reboot"])
            }
        }

        PowerOrb {
            id: powerOrb
            icon: "󰐥"
            label: "Power Off"
            glowColor: ColorsModule.Colors.error
            onActivated: {
                root.close()
                proc.exec(["bash", "-c", "sleep 0.35 && systemctl poweroff"])
            }
        }
    }

    // ── Hint ─────────────────────────────────────────────────────────────────

    Text {
        id: hintText
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 52
        text: "ESC TO CANCEL"
        font.pixelSize: 10
        font.letterSpacing: 2.5
        font.weight: Font.Light
        color: Qt.rgba(1, 1, 1, 0.2)
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
    }

    // ── Hint timer ────────────────────────────────────────────────────────────

    Timer {
        id: hintDelay
        interval: 420
        onTriggered: hintText.opacity = 1
    }

    // ── Close timer ───────────────────────────────────────────────────────────

    Timer {
        id: closeTimer
        interval: 280
        onTriggered: root.visible = false
    }

    // ── Open / Close ─────────────────────────────────────────────────────────

    function open() {
        visible = true
        forceActiveFocus()

        // reset
        lockOrb.opacity   = 0
        logoutOrb.opacity = 0
        rebootOrb.opacity = 0
        powerOrb.opacity  = 0
        hintText.opacity  = 0
        header.opacity    = 0
        backdrop.opacity  = 1

        // staggered entrance
        lockOrb.enter(60)
        logoutOrb.enter(140)
        rebootOrb.enter(220)
        powerOrb.enter(300)

        header.opacity = 1
        hintDelay.restart()
    }

    function close() {
        backdrop.opacity = 0
        lockOrb.opacity   = 0
        logoutOrb.opacity = 0
        rebootOrb.opacity = 0
        powerOrb.opacity  = 0
        header.opacity    = 0
        hintText.opacity  = 0
        closeTimer.restart()
    }

    // ── Keyboard ──────────────────────────────────────────────────────────────

    Keys.onEscapePressed: close()
}
