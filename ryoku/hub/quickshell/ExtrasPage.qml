pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// Extras section = the ryoku-extras bundles as a bento grid of tiles. ryoku-hub
// fetches the catalogue; opening a tile shows its detail, where
// ryoku-extras-install installs or removes items in a floating terminal and
// publishes a per-bundle report the detail watches. this page owns the data and
// routes the buttons.
Item {
    id: page

    property var bundles: []
    property var statusMap: ({})
    property bool loading: true
    property bool loadFailed: false
    property string selectedId: ""
    property bool storeMode: false

    readonly property string reportDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-extras"


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


    Process {
        id: catalogProc
        command: ["ryoku-hub", "extras", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    var bs = o.bundles || [];
                    page.bundles = bs;
                    page.loadFailed = bs.length === 0;
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

    // loading / empty states.
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

    // refresh = re-pull the bundle catalogue so newly published extras appear
    // without leaving the page. spins while the fetch is in flight.
    Rectangle {
        id: extrasRefresh
        visible: !page.loading && !page.loadFailed && page.selectedId === "" && !page.storeMode
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 8
        width: 32; height: 32; radius: Theme.radius
        color: exHover.hovered ? Theme.surface : "transparent"
        border.width: 1
        border.color: exHover.hovered ? Theme.ember : "transparent"
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
        z: 3
        Icon {
            anchors.centerIn: parent
            name: "refresh"
            size: 15
            weight: 2
            tint: exHover.hovered ? Theme.bright : Theme.dim
            RotationAnimation on rotation { running: page.loading; loops: Animation.Infinite; from: 0; to: 360; duration: 800 }
        }
        HoverHandler { id: exHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: page.reload() }
    }

    // bento grid.
    Flickable {
        id: flick
        anchors.fill: parent
        visible: !page.loading && !page.loadFailed && page.selectedId === ""
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        contentHeight: grid.implicitHeight + 18
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: sb
            policy: ScrollBar.AsNeeded
            width: 7
            contentItem: Rectangle {
                implicitWidth: 4
                radius: Theme.radius
                color: Theme.line
                opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            }
        }

        Flow {
            id: grid
            width: flick.width - 10
            topPadding: 4
            spacing: 14

            Repeater {
                model: page.bundles

                delegate: ExtraBundleCard {
                    required property var modelData
                    width: Math.max(300, (grid.width - 14 * 2) / 3)
                    bundle: modelData
                    installedCount: page.installedCountFor(modelData.id)
                    onOpened: page.open(modelData.id)
                }
            }
        }
    }

    // bundle detail.
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
