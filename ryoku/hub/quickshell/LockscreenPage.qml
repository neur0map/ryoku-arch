pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// The Lockscreen section: the installed qylock lock skins as a bento grid, each
// tile a looping preview of the real lockscreen. Ryoku ships the "clockwork"
// theme; selecting a skin only swaps which one the lock wears (ryoku-hub lock
// set, writing ~/.config/qylock/theme) and never touches the login or auth flow.
// Preview launches the lock live with that skin without changing the selection.
// Styled to match the Appearance themes and Extras catalogues.
Item {
    id: page

    property var skins: []
    property string active: ""
    property bool loading: true
    property bool loadFailed: false
    property string applying: ""

    readonly property string lockSh: Quickshell.env("HOME") + "/.local/share/quickshell-lockscreen/lock.sh"
    readonly property int cols: width >= 1180 ? 3 : (width >= 720 ? 2 : 1)

    Component.onCompleted: page.reload()

    function reload() {
        page.loading = true;
        page.loadFailed = false;
        listProc.running = true;
    }
    function apply(slug) {
        if (slug === page.active)
            return;
        page.applying = slug;
        applyProc.command = ["ryoku-hub", "lock", "set", slug];
        applyProc.running = true;
    }
    function preview(slug) {
        Quickshell.execDetached([page.lockSh, slug]);
    }

    // Greedy masonry like the Extras grid: each tile into the currently shortest
    // column, estimated from the blurb length so the columns stay balanced.
    function buildColumns(list, n) {
        var c = [], h = [], i;
        for (i = 0; i < n; i++) { c.push([]); h.push(0); }
        for (i = 0; i < list.length; i++) {
            var est = 300 + Math.ceil(((list[i].blurb || "").length) / 30) * 16;
            var min = 0;
            for (var j = 1; j < n; j++)
                if (h[j] < h[min]) min = j;
            c[min].push(list[i]);
            h[min] += est + 14;
        }
        return c;
    }
    readonly property var grouped: buildColumns(page.skins, page.cols)

    Process {
        id: listProc
        command: ["ryoku-hub", "lock", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    var ss = o.skins || [];
                    for (var i = 0; i < ss.length; i++)
                        ss[i].ordinal = i + 1;
                    page.skins = ss;
                    page.active = o.active || "";
                    page.loadFailed = ss.length === 0;
                } catch (e) {
                    page.skins = [];
                    page.loadFailed = true;
                }
                page.loading = false;
            }
        }
    }
    Process {
        id: applyProc
        stdout: StdioCollector {
            onStreamFinished: { page.applying = ""; listProc.running = true; }
        }
    }

    // --- loading / empty states ---
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
            name: "lock"
            size: 44
            tint: Theme.faint
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: page.loadFailed
            text: "No lock skins found. Install qylock to add some."
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

    // --- header: explainer + refresh ---
    Item {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 40
        visible: !page.loading && !page.loadFailed

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - refresh.width - 24
            elide: Text.ElideRight
            text: "Pick the skin your lock screen wears. Your login stays exactly the same."
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        HubButton {
            id: refresh
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: "Refresh"
            icon: "refresh"
            onClicked: page.reload()
        }
    }

    // --- bento grid ---
    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: bar.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 14
        visible: !page.loading && !page.loadFailed
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
                        delegate: LockscreenTile {
                            required property var modelData
                            width: column.width
                            skin: modelData
                            ordinal: modelData.ordinal || 0
                            active: !!modelData.active
                            busy: page.applying === modelData.slug
                            onApplied: page.apply(modelData.slug)
                            onPreviewed: page.preview(modelData.slug)
                        }
                    }
                }
            }
        }
    }
}
