import QtQuick
import "Singletons"

// one tool inside a bundle: status dot, name + summary, source tag, single
// action that fits the state (install when absent, remove when present).
// scripts aren't auto-removed and plugins live under Plugins, so those show a
// note instead of a remove button.
Item {
    id: row

    property string itemName: ""
    property string summary: ""
    property string itemType: "package"
    property string source: ""
    property string status: "absent"   // present|absent|installing|installed|removing|removed|failed|deferred|skipped
    property string reason: ""

    signal install()
    signal remove()

    readonly property bool busy: status === "installing" || status === "removing"
    readonly property bool here: status === "present" || status === "installed"
    readonly property bool failed: status === "failed"

    implicitHeight: 46
    width: parent ? parent.width : 0

    // status: spinner while busy, check when here, fault dot on fail.
    Item {
        id: ind
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18

        Spinner {
            anchors.centerIn: parent
            size: 15
            tint: Theme.ember
            visible: row.busy
        }
        Icon {
            anchors.centerIn: parent
            name: "check"
            size: 15
            weight: 2
            tint: Theme.ok
            visible: row.here
        }
        Rectangle {
            anchors.centerIn: parent
            visible: !row.busy && !row.here
            width: 6
            height: 6
            radius: 3
            color: row.failed ? Theme.bad : Theme.faint
        }
    }

    Column {
        anchors.left: ind.right
        anchors.leftMargin: 12
        anchors.right: actionArea.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Row {
            spacing: 8
            Text {
                text: row.itemName
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Text {
                visible: row.source !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: row.source
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }
        }

        Text {
            width: parent.width
            text: row.failed && row.reason !== "" ? row.reason : row.summary
            color: row.failed ? Theme.bad : Theme.dim
            font.family: Theme.font
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Item {
        id: actionArea
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 92
        height: 30

        // deferred (plugin) or skipped (script remove): quiet note, no button.
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: row.status === "deferred"
            text: row.itemType === "plugin" ? "Plugins" : "Manual"
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10
        }

        // install for anything not here.
        ActionPill {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !row.busy && !row.here && row.status !== "deferred"
            label: row.failed ? "Retry" : "Install"
            icon: "download"
            onClicked: row.install()
        }

        // remove for installed packages (scripts left alone).
        ActionPill {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: !row.busy && row.here && (row.itemType === "package" || row.itemType === "nautilus-pack")
            label: "Remove"
            icon: "trash"
            danger: true
            onClicked: row.remove()
        }
    }

    Rectangle {
        anchors.left: ind.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.lineSoft
    }
}
