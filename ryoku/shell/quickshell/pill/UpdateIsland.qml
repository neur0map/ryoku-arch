pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

/**
 * The update island: a compact chip on the top-right of the frame. It has three
 * faces, driven by the shared update state:
 *   available  a newer build is ready -> click opens the Hub's Updates section.
 *   running    an update is in progress -> a Ryoku wave fills with its progress.
 *   success    the update finished -> a Refresh shell affordance; click reloads.
 * It folds to nothing when there is no update and none is running.
 */
Item {
    id: root

    property real s: 1
    // The shell context allows showing it (no open surface/toast/osd over the pill).
    property bool active: true

    property bool hovered: false

    readonly property string mode: Updates.runPhase === "running" ? "running"
        : Updates.runPhase === "success" ? "success"
        : (Updates.available ? "available" : "none")
    readonly property bool present: mode !== "none" && active

    readonly property real contentW: mode === "running" ? runRow.implicitWidth
        : mode === "success" ? doneRow.implicitWidth
        : availRow.implicitWidth

    signal activated()

    implicitWidth: present ? (contentW + 26 * s) : 0
    implicitHeight: 30 * s
    width: implicitWidth
    height: implicitHeight
    opacity: present ? 1 : 0
    visible: opacity > 0.01
    scale: present ? 1 : 0.85

    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
    Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

    transform: Translate {
        y: root.hovered ? -1.5 * root.s : 0
        Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
    }

    Rectangle {
        id: body
        anchors.verticalCenter: parent.verticalCenter
        width: root.contentW + 26 * root.s
        height: parent.height
        radius: height / 2
        color: root.hovered ? Theme.frameBg : Theme.tileBg
        border.width: 1
        border.color: Qt.alpha(Theme.brand, root.hovered ? 0.6 : 0.32)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
            height: parent.height * 0.5
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.sheen }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
    }

    // --- available: "Update  |  2026.06.20  +6" ----------------------------
    Row {
        id: availRow
        anchors.centerIn: body
        visible: root.mode === "available"
        spacing: 7 * root.s

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 15 * root.s
            height: 15 * root.s

            Rectangle {
                anchors.centerIn: parent
                width: 22 * root.s
                height: 22 * root.s
                radius: width / 2
                color: Theme.brand
                opacity: 0
                SequentialAnimation on opacity {
                    running: root.mode === "available"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.20; duration: 1300; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.05; duration: 1300; easing.type: Easing.InOutSine }
                }
            }

            GlyphIcon {
                anchors.fill: parent
                name: "download"
                color: Theme.brand
                stroke: 1.9
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Update"
            color: root.hovered ? Theme.bright : Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 11 * root.s
            color: Theme.hair
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Updates.latestVersion
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: badgeText.implicitWidth + 11 * root.s
            height: 16 * root.s
            radius: height / 2
            color: Theme.brand

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: "+" + Updates.behind
                color: "#fdeee6"
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
        }
    }

    // --- running: "Updating  ~~~~~~" (Ryoku wave fills with progress) -------
    Row {
        id: runRow
        anchors.centerIn: body
        visible: root.mode === "running"
        spacing: 8 * root.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 14 * root.s
            height: 14 * root.s
            name: "download"
            color: Theme.brand
            stroke: 1.9
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Updating"
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
        }

        WaveMeter {
            anchors.verticalCenter: parent.verticalCenter
            width: 56 * root.s
            s: root.s
            frac: Updates.runProgress
        }
    }

    // --- success: "Refresh shell" ------------------------------------------
    Row {
        id: doneRow
        anchors.centerIn: body
        visible: root.mode === "success"
        spacing: 7 * root.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 14 * root.s
            height: 14 * root.s
            name: "reboot"
            color: Theme.brand
            stroke: 1.9
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Refresh shell"
            color: root.hovered ? Theme.bright : Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
    }

    HoverHandler {
        enabled: root.present
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: root.hovered = hovered
    }

    TapHandler {
        enabled: root.present
        onTapped: {
            if (root.mode === "success")
                Updates.refresh();
            else
                root.activated();
        }
    }
}
