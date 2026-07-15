import QtQuick
import QtQuick.Controls
import "Singletons"

// The catalogue: OS tiles bound to Vm.osList, split into Popular (systems that
// ship real brand art) above All systems (the rest, drawn as monograms). The
// split re-evaluates when the prefetch fills Vm.iconSet, so logos float up once
// they're known. Picking a tile selects it for the create panel.
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
    // curated headliners; everything else files under All systems.
    readonly property var popularSlugs: ["ubuntu", "debian", "archlinux", "linuxmint", "opensuse",
        "nixos", "alpine", "kali", "freebsd", "windows", "macos", "cachyos"]
    readonly property var popular: { void Vm.iconRev; return Vm.osList.filter(o => g._match(o) && g.popularSlugs.indexOf(o.os) >= 0); }
    readonly property var rest: { void Vm.iconRev; return Vm.osList.filter(o => g._match(o) && g.popularSlugs.indexOf(o.os) < 0); }
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
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        ScrollBar.vertical: BoardScrollBar {}

        Column {
            id: col
            width: flick.width
            spacing: 10

            Section {
                title: "Popular"
                entries: g.popular
                visible: g.popular.length > 0
            }
            Section {
                // only label the second band when the first is present.
                title: g.popular.length > 0 ? "All systems" : ""
                entries: g.rest
                visible: g.rest.length > 0
            }
        }
    }

    // empty / loading / error state.
    Column {
        anchors.centerIn: parent
        spacing: 12
        width: parent.width - 40
        visible: g.total === 0
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: Vm.catalogLoading ? "refresh" : (Vm.catalogError.length > 0 ? "close" : (g.filter.length > 0 ? "search" : "download"))
            size: 32
            tint: Theme.faint
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            width: parent.width
            wrapMode: Text.WordWrap
            text: Vm.catalogLoading ? "Fetching the OS catalogue"
                : (Vm.caps.quickget !== true ? "The catalogue needs the engine (quickget) — install it and the 90+ systems appear here."
                : (Vm.catalogError.length > 0 ? Vm.catalogError
                : (g.filter.length > 0 ? "No systems match" : "No catalogue")))
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
        }
        HubButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Vm.catalogLoading && Vm.caps.quickget !== true
            primary: true
            icon: "download"
            label: "Install engine"
            onClicked: g.installRequested()
        }
        HubButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !Vm.catalogLoading && Vm.caps.quickget === true && Vm.catalogError.length > 0
            icon: "refresh"
            label: "Retry"
            onClicked: Vm.loadCatalog(true)
        }
    }

    component Section: Column {
        id: sec
        property string title: ""
        property var entries: []
        width: g.width - 8
        spacing: 6

        Row {
            visible: sec.title.length > 0
            spacing: 7
            Rectangle { width: 5; height: 5; radius: Theme.radius; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: sec.title
                color: Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 10
                font.letterSpacing: 2
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
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
