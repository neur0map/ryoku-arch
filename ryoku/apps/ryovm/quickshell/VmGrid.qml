import QtQuick
import QtQuick.Controls
import "Singletons"

// The library: a scrollable column of VM cards bound to Vm.vms. Picking a card
// selects it for the detail hero on the right. An empty library invites a build.
Item {
    id: g

    property string filter: ""
    signal buildRequested()

    readonly property var shown: {
        if (g.filter.length === 0)
            return Vm.vms;
        var f = g.filter.toLowerCase();
        return Vm.vms.filter(v => v.name.toLowerCase().indexOf(f) >= 0 || (v.guest || "").toLowerCase().indexOf(f) >= 0);
    }

    ListView {
        id: list
        anchors.fill: parent
        visible: g.shown.length > 0
        clip: true
        spacing: 10
        model: g.shown
        cacheBuffer: 800
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: BoardScrollBar {}

        delegate: Item {
            id: slot
            required property var modelData
            required property int index
            width: list.width
            height: 68
            VmCard {
                id: plate
                width: parent.width - 6
                item: slot.modelData
                active: Vm.selectedName === slot.modelData.name
                onPicked: Vm.select(slot.modelData.name)
                // yard roll-call: plates drop in one after another on first paint.
                opacity: 0
                y: 14
                Component.onCompleted: entrance.restart()
                SequentialAnimation {
                    id: entrance
                    PauseAnimation { duration: 50 * Math.min(slot.index, 8) }
                    ParallelAnimation {
                        NumberAnimation { target: plate; property: "opacity"; to: 1; duration: Theme.medium; easing.type: Theme.ease }
                        NumberAnimation { target: plate; property: "y"; to: 0; duration: Theme.medium; easing.type: Theme.ease }
                    }
                }
            }
        }
    }

    // empty state.
    Column {
        anchors.centerIn: parent
        spacing: 12
        width: parent.width - 40
        visible: g.shown.length === 0
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: Vm.vmsLoading ? "refresh" : (g.filter.length > 0 ? "search" : "server")
            size: 32
            tint: Theme.faint
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            text: Vm.vmsLoading ? "Loading your machines"
                : (g.filter.length > 0 ? "No machines match"
                : "No machines yet.")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
        }
        HubButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Vm.vmsLoading && g.filter.length === 0
            primary: true
            icon: "download"
            label: "Open Catalog"
            onClicked: g.buildRequested()
        }
    }
}
