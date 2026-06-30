import QtQuick
import QtQuick.Controls
import "Singletons"

// The library: a scrollable column of VM cards bound to Vm.vms. Picking a card
// selects it for the detail hero on the right. An empty library invites a build.
Item {
    id: g

    property string filter: ""

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
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
            required property var modelData
            width: list.width
            height: 64
            VmCard {
                width: parent.width - 4
                item: parent.modelData
                active: Vm.selectedName === parent.modelData.name
                onPicked: Vm.select(parent.modelData.name)
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
                : "No machines yet.\nSwitch to Catalog to build one.")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
        }
    }
}
