import QtQuick
import "../modules"
import "kit/Routes.js" as Routes

// The breadcrumb chrome: 力 / CONTROL CENTER / <ROUTE>, a state dot, and close.
Item {
    id: hdr
    property var root
    property string mode: "quick"
    property string route: ""
    signal closed()

    implicitHeight: 22

    readonly property string crumb: mode === "quick" ? "QUICK"
        : (route === "" ? "CONFIGURE" : Routes.labelFor(route).toUpperCase())

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: "力"; color: hdr.root.seal
            font.family: "Noto Sans CJK JP"; font.pixelSize: 13
        }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: "RYOKU"; color: hdr.root.ink; font.family: hdr.root.mono; font.pixelSize: 11; font.letterSpacing: 2; font.weight: Font.Medium }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: "/"; color: hdr.root.sumi; font.family: hdr.root.mono; font.pixelSize: 11 }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: "CONTROL CENTER"; color: hdr.root.ink; font.family: hdr.root.mono; font.pixelSize: 11; font.letterSpacing: 2 }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: "/"; color: hdr.root.sumi; font.family: hdr.root.mono; font.pixelSize: 11 }
        UiText { anchors.verticalCenter: parent.verticalCenter; text: hdr.crumb; color: hdr.root.sumiHi; font.family: hdr.root.mono; font.pixelSize: 11; font.letterSpacing: 2 }
    }

    Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: hdr.root.seal }
            UiText { anchors.verticalCenter: parent.verticalCenter; text: "STATE SYNCED"; color: hdr.root.sumi; font.family: hdr.root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
        }
        UiText {
            anchors.verticalCenter: parent.verticalCenter
            text: "✕"; color: closeMa.containsMouse ? hdr.root.seal : hdr.root.sumi; font.pixelSize: 13
            Behavior on color { ColorAnimation { duration: 120 } }
            MouseArea { id: closeMa; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: hdr.closed() }
        }
    }
}
