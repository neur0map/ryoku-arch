import QtQuick
import Quickshell

Item {
    id: row

    required property var entry
    property bool selected: false

    signal activated()
    signal entered()

    implicitHeight: 50

    readonly property color cream: "#e6d6cb"
    readonly property color white: "#fff6f0"
    readonly property color dim2: "#565e6a"

    readonly property string secondary: {
        if (entry.genericName && entry.genericName.length > 0) return entry.genericName;
        if (entry.categories && entry.categories.length > 0) {
            var first = String(entry.categories).split(";")[0].trim();
            if (first.length > 0) return first;
        }
        return "";
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#c0442b" }
            GradientStop { position: 1.0; color: "#a3371f" }
        }
        visible: row.selected
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: row.entered()
        onClicked: row.activated()
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15

        Rectangle {
            id: iconBox
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26
            radius: 6
            color: Qt.rgba(1, 1, 1, 0.05)
            visible: !(icon.status === Image.Ready && icon.source !== "")
        }

        Image {
            id: icon
            anchors.fill: iconBox
            sourceSize.width: 52
            sourceSize.height: 52
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: status === Image.Ready && source !== ""
            source: row.entry.icon ? Quickshell.iconPath(row.entry.icon, true) : ""
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: icon.right
            anchors.leftMargin: 12
            text: row.entry.name
            color: row.selected ? row.white : row.cream
            font.family: "Inter"
            font.pixelSize: 15
            font.weight: row.selected ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            width: Math.min(implicitWidth, parent.width - icon.width - 12 - secondary.width - enter.width - 18)
        }

        Text {
            id: enter
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            text: "↵"
            color: row.white
            font.family: "Inter"
            font.pixelSize: 13
            visible: row.selected
            width: visible ? implicitWidth + 7 : 0
            horizontalAlignment: Text.AlignRight
        }

        Text {
            id: secondary
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: enter.left
            text: row.secondary
            color: row.selected ? Qt.rgba(1, 0.965, 0.941, 0.72) : row.dim2
            font.family: "Inter"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignRight
        }
    }
}
