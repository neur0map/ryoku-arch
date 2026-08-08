import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The yard: a scrollable column of 64-tall machine rows bound to Vm.vms. Picking
// a row selects it for the stage on the right. The populate cascade survives:
// it is the roll-call, and the flaps are already doing it; an empty yard invites
// a build.
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
        spacing: Tokens.s2
        model: g.shown
        cacheBuffer: 800
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail {}

        // roll-call on first population only (never on scroll-back or refresh).
        populate: Transition {
            id: popT
            SequentialAnimation {
                PropertyAction { property: "opacity"; value: 0 }
                PauseAnimation { duration: 40 * Math.min(popT.ViewTransition.index, 8) }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tokens.swap; easing.type: Tokens.ease }
            }
        }
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Tokens.swap; easing.type: Tokens.ease }
        }

        delegate: Item {
            id: slot
            required property var modelData
            required property int index
            width: list.width
            height: 64
            VmCard {
                width: parent.width - 6
                item: slot.modelData
                active: Vm.selectedName === slot.modelData.name
                onPicked: Vm.select(slot.modelData.name)
            }
        }
    }

    // empty / loading state, anchored on the app mark.
    Column {
        anchors.centerIn: parent
        spacing: Tokens.s4
        width: parent.width - 40
        visible: g.shown.length === 0
        Mark {
            anchors.horizontalCenter: parent.horizontalCenter
            size: 96
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            text: Vm.vmsLoading ? "Loading your machines"
                : (g.filter.length > 0 ? "No machines match"
                : "No machines yet.")
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: 12
        }
        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Vm.vmsLoading && g.filter.length === 0
            primary: true
            text: "OPEN CATALOG"
            onAct: g.buildRequested()
        }
    }
}
