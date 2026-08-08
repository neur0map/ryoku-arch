import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The catalogue: OS tiles bound to Vm.osList, split into Popular (systems that
// ship real brand art) above All systems (the rest, drawn as monograms). The
// split survives; the section headers are the dot-and-leader. Picking a tile
// selects it for the create sheet.
Item {
    id: g

    property string filter: ""
    signal installRequested()

    readonly property real gap: 10
    readonly property int cols: Math.max(2, Math.floor(width / 150))
    readonly property real tileW: Math.floor(g.width / g.cols)

    function _match(o) {
        if (g.filter.length === 0)
            return true;
        var f = g.filter.toLowerCase();
        return o.name.toLowerCase().indexOf(f) >= 0 || o.os.toLowerCase().indexOf(f) >= 0;
    }
    readonly property var popularSlugs: ["ubuntu", "debian", "archlinux", "linuxmint", "opensuse",
        "nixos", "alpine", "kali", "freebsd", "windows", "macos", "cachyos"]
    readonly property var popular: Vm.osList.filter(o => g._match(o) && g.popularSlugs.indexOf(o.os) >= 0)
    readonly property var rest: Vm.osList.filter(o => g._match(o) && g.popularSlugs.indexOf(o.os) < 0)
    readonly property int total: popular.length + rest.length

    Flickable {
        id: flick
        anchors.fill: parent
        visible: g.total > 0
        contentWidth: width
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        opacity: Vm.catalogLoading ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
        ScrollBar.vertical: ScrollRail {}

        Column {
            id: col
            width: flick.width
            spacing: Tokens.s3

            Group { title: "Popular"; entries: g.popular; visible: g.popular.length > 0 }
            Group { title: g.popular.length > 0 ? "All systems" : ""; entries: g.rest; visible: g.rest.length > 0 }
        }
    }

    // empty / loading / error, anchored on the app mark.
    Column {
        anchors.centerIn: parent
        spacing: Tokens.s4
        width: parent.width - 40
        visible: g.total === 0
        Mark { anchors.horizontalCenter: parent.horizontalCenter; size: 96 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            text: Vm.catalogLoading ? "Fetching the OS catalogue"
                : (Vm.caps.quickget !== true ? "The catalogue needs the engine (quickget): install it and the 90+ systems appear here."
                : (Vm.catalogError.length > 0 ? Vm.catalogError
                : (g.filter.length > 0 ? "No systems match" : "No catalogue")))
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: 12
        }
        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Vm.catalogLoading && Vm.caps.quickget !== true
            primary: true
            text: "INSTALL ENGINE"
            onAct: g.installRequested()
        }
        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Vm.catalogLoading && Vm.caps.quickget === true && Vm.catalogError.length > 0
            text: "RETRY"
            onAct: Vm.loadCatalog(true)
        }
    }

    // a catalogue section: dot + caps title + lineSoft leader, then a tile grid.
    component Group: Column {
        id: sec
        property string title: ""
        property var entries: []
        width: g.width - 8
        spacing: Tokens.s2

        Row {
            visible: sec.title.length > 0
            spacing: Tokens.s2
            width: parent.width
            Rectangle { width: 4; height: 4; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sec.title
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: Tokens.trackMark
                font.capitalization: Font.AllUppercase
            }
            Rectangle {
                width: Math.max(0, parent.width - 200)
                height: 1
                color: Tokens.lineSoft
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Grid {
            columns: g.cols
            Repeater {
                model: sec.entries
                delegate: Item {
                    required property var modelData
                    width: g.tileW
                    height: g.tileW * 0.92
                    OsCard {
                        anchors.fill: parent
                        anchors.margins: g.gap / 2
                        entry: parent.modelData
                        active: Vm.selectedOs && Vm.selectedOs.os === parent.modelData.os
                        onPicked: Vm.selectOs(parent.modelData)
                    }
                }
            }
        }
    }
}
