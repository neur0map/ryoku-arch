import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "Singletons"

Rectangle {
    id: root
    property real s: 1
    property bool opened: false
    property string greet: greeting()
    property string uptime: ""
    property bool notif: false
    property int unread: 0

    function greeting() {
        var h = new Date().getHours();
        return h < 5 ? "Good Night" : h < 12 ? "Good Morning" : h < 18 ? "Good Afternoon" : "Good Evening";
    }

    onOpenedChanged: if (opened) { greet = greeting(); upProc.running = true; }

    Process {
        id: upProc
        command: ["uptime", "-p"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.uptime = this.text.trim() }
    }

    Timer {
        interval: 60000
        running: root.opened
        repeat: true
        triggeredOnStart: true
        onTriggered: upProc.running = true
    }

    radius: 16 * s
    color: "transparent"
    border.width: 1
    border.color: Theme.border
    implicitHeight: 38 * s + 26 * s
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.panelTop }
        GradientStop { position: 1.0; color: Theme.panelBot }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 13 * root.s
        spacing: 12 * root.s

        Rectangle {
            id: mark
            width: 38 * root.s; height: 38 * root.s; radius: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            border.width: 1
            border.color: Theme.vermLit
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.verm }
                GradientStop { position: 1.0; color: Theme.vermDeep }
            }
            Image {
                id: markGlyph
                anchors.centerIn: parent
                width: 20 * root.s; height: 20 * root.s
                source: Qt.resolvedUrl("assets/icons/ryoku.svg")
                sourceSize.width: 64; sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true; visible: false
            }
            MultiEffect {
                anchors.fill: markGlyph
                source: markGlyph
                colorization: 1.0
                colorizationColor: "#f3e7df"
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * root.s
            Text {
                text: root.notif ? "Notifications" : root.greet
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 15 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                text: "ryoku · ryoku"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
            }
        }
    }

    Rectangle {
        id: uppill
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 13 * root.s
        radius: 999
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.border
        implicitHeight: 24 * root.s
        width: pillRow.implicitWidth + 22 * root.s
        height: implicitHeight

        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6 * root.s

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * root.s
                visible: !root.notif
                Text {
                    text: "up"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.Medium
                }
                Text {
                    text: root.uptime.replace(/^up\s+/, "")
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4 * root.s
                visible: root.notif
                Text {
                    text: String(root.unread)
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "unread"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.Medium
                }
            }
        }
    }
}
