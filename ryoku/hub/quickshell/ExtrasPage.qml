pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// The Extras section: the ryoku-extras bundles as a bento grid of tiles. ryoku-hub
// fetches the catalogue; opening a tile shows its detail, where ryoku-extras-install
// installs or removes items in a floating terminal and publishes a per-bundle
// report the detail watches. This page owns the data and routes the buttons.
Item {
    id: page

    property var bundles: []
    property var statusMap: ({})
    property bool loading: true
    property bool loadFailed: false
    property string selectedId: ""

    readonly property string reportDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-extras"

    readonly property int cols: width >= 1180 ? 4 : (width >= 820 ? 3 : (width >= 520 ? 2 : 1))

    readonly property var selectedBundle: {
        for (var i = 0; i < bundles.length; i++)
            if (bundles[i].id === selectedId)
                return bundles[i];
        return null;
    }

    Component.onCompleted: page.reload()

    function reload() {
        page.loading = true;
        page.loadFailed = false;
        catalogProc.running = true;
    }

    function installedCountFor(id) {
        var m = page.statusMap[id];
        if (!m)
            return 0;
        var n = 0;
        for (var k in m)
            if (m[k] === "present" || m[k] === "installed") n++;
        return n;
    }

    // Greedy masonry: place each tile in the currently shortest column, using an
    // estimated height from the blurb length so the columns end up balanced.
    function buildColumns(list, n) {
        var cols = [], heights = [], i;
        for (i = 0; i < n; i++) { cols.push([]); heights.push(0); }
        for (i = 0; i < list.length; i++) {
            var b = list[i];
            var est = 150 + Math.ceil(((b.description || "").length) / 32) * 17;
            var min = 0;
            for (var j = 1; j < n; j++)
                if (heights[j] < heights[min]) min = j;
            cols[min].push(b);
            heights[min] += est + 14;
        }
        return cols;
    }

    readonly property var grouped: buildColumns(page.bundles, page.cols)

    Process {
        id: catalogProc
        command: ["ryoku-hub", "extras", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    page.bundles = o.bundles || [];
                    page.loadFailed = page.bundles.length === 0;
                } catch (e) {
                    page.bundles = [];
                    page.loadFailed = true;
                }
                page.loading = false;
                statusProc.running = true;
            }
        }
    }

    Process {
        id: statusProc
        command: ["ryoku-extras-install", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    var m = ({});
                    var bs = o.bundles || [];
                    for (var i = 0; i < bs.length; i++) {
                        var im = ({});
                        var its = bs[i].items || [];
                        for (var j = 0; j < its.length; j++)
                            im[its[j].name] = its[j].status;
                        m[bs[i].id] = im;
                    }
                    page.statusMap = m;
                } catch (e) {
                    page.statusMap = ({});
                }
            }
        }
    }

    function runTerminal(args) {
        Quickshell.execDetached(["kitty", "--class", "ryoku-extras", "-e"].concat(args));
    }

    function open(id) { page.selectedId = id; }
    function closeDetail() { page.selectedId = ""; statusProc.running = true; }

    // --- loading / empty states --------------------------------------------
    Column {
        anchors.centerIn: parent
        visible: page.loading || page.loadFailed
        spacing: 16
        width: Math.min(page.width - 96, 420)

        Spinner {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.loading
            size: 26
        }
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.loadFailed
            name: "sparkles"
            size: 44
            tint: Theme.faint
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.loadFailed
            text: "Couldn't load the extras catalogue."
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
        }
        HubButton {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.loadFailed
            label: "Try again"
            icon: "refresh"
            onClicked: page.reload()
        }
    }

    // --- bento grid ---------------------------------------------------------
    Flickable {
        id: flick
        anchors.fill: parent
        visible: !page.loading && !page.loadFailed && page.selectedId === ""
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        contentHeight: masonry.implicitHeight + 18
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: sb
            policy: ScrollBar.AsNeeded
            width: 7
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.line
                opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            }
        }

        Row {
            id: masonry
            width: flick.width - 10
            topPadding: 4
            spacing: 14

            Repeater {
                model: page.cols

                delegate: Column {
                    id: column
                    required property int index
                    width: (masonry.width - (page.cols - 1) * 14) / page.cols
                    spacing: 14

                    Repeater {
                        model: page.grouped[column.index] || []

                        delegate: ExtraBundleCard {
                            required property var modelData
                            width: column.width
                            bundle: modelData
                            installedCount: page.installedCountFor(modelData.id)
                            onOpened: page.open(modelData.id)
                        }
                    }
                }
            }
        }
    }

    // --- bundle detail ------------------------------------------------------
    Loader {
        anchors.fill: parent
        active: page.selectedId !== "" && page.selectedBundle !== null
        visible: active
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        sourceComponent: ExtraBundleDetail {
            bundle: page.selectedBundle
            statuses: page.statusMap[page.selectedId] || ({})
            reportDir: page.reportDir
            onBack: page.closeDetail()
            onInstallAll: page.runTerminal(["ryoku-extras-install", "install", "bundle", page.selectedId])
            onRemoveAll: page.runTerminal(["ryoku-extras-install", "remove", "bundle", page.selectedId])
            onInstallItem: (name) => page.runTerminal(["ryoku-extras-install", "install", "item", page.selectedId, name])
            onRemoveItem: (name) => page.runTerminal(["ryoku-extras-install", "remove", "item", page.selectedId, name])
            onRefreshRequested: statusProc.running = true
        }
    }
}
