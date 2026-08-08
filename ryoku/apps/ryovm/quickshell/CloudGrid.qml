import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The INSTANT lane's left column: the curated cloud-image OSes as tiles. Picking
// one selects it for the CloudPanel. Prebuilt images only: a short curated
// list, so no Popular/rest split.
Item {
    id: g

    property string filter: ""
    property var selected: null
    signal picked(var entry)

    readonly property real gap: 10
    readonly property int cols: Math.max(2, Math.floor(width / 150))
    readonly property real tileW: Math.floor(g.width / g.cols)

    readonly property var shown: {
        if (g.filter.length === 0) return Vm.cloudList;
        var f = g.filter.toLowerCase();
        return Vm.cloudList.filter(o => o.name.toLowerCase().indexOf(f) >= 0 || o.os.toLowerCase().indexOf(f) >= 0);
    }

    Component.onCompleted: Vm.loadCloud()

    Flickable {
        anchors.fill: parent
        visible: g.shown.length > 0
        contentWidth: width
        contentHeight: grid.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail {}

        Grid {
            id: grid
            width: parent.width
            columns: g.cols
            Repeater {
                model: g.shown
                delegate: Item {
                    required property var modelData
                    width: g.tileW
                    height: g.tileW * 0.92
                    OsCard {
                        anchors.fill: parent
                        anchors.margins: g.gap / 2
                        entry: parent.modelData
                        active: g.selected && g.selected.os === parent.modelData.os
                        onPicked: g.picked(parent.modelData)
                    }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Tokens.s4
        width: parent.width - 40
        visible: g.shown.length === 0
        Mark { anchors.horizontalCenter: parent.horizontalCenter; size: 96 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            text: Vm.cloudLoading ? "Loading the image list" : (g.filter.length > 0 ? "No images match" : "No cloud images")
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: 12
        }
    }
}
