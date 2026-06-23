pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// The Lockscreen section: the full qylock theme catalogue as a bento grid, fetched
// live from upstream (ryoku-hub lock catalog) so new and fixed skins appear without
// a Ryoku release. Each tile previews the real lockscreen; the two vendored skins
// (clockwork) are the offline baseline and the rest stream their preview gif from
// the repo. Selecting a skin makes it both the in-session lock (ryoku-hub lock set,
// writing ~/.config/qylock/theme) and the SDDM greeter; the greeter lives on a
// system path so that step asks for the password via pkexec. Selecting one not yet
// installed downloads it first (ryoku-hub lock install) then activates both. The
// login/auth flow itself is untouched. Styled to match the Appearance themes and
// Extras catalogues.
Item {
    id: page

    property var skins: []
    property string active: ""
    property bool online: true
    property bool loading: true
    property bool loadFailed: false
    property string pendingSlug: ""
    property bool pendingInstall: false
    property string error: ""

    readonly property string lockSh: Quickshell.env("HOME") + "/.local/share/quickshell-lockscreen/lock.sh"
    readonly property int cols: width >= 1320 ? 4 : (width >= 980 ? 3 : (width >= 640 ? 2 : 1))

    Component.onCompleted: page.reload()

    function reload() {
        page.loading = true;
        page.loadFailed = false;
        catalogProc.running = true;
    }
    function select(skin) {
        if (skin.slug === page.active || page.pendingSlug !== "")
            return;
        page.error = "";
        page.pendingSlug = skin.slug;
        page.pendingInstall = !skin.installed;
        actProc.command = skin.installed
            ? ["ryoku-hub", "lock", "set", skin.slug]
            : ["ryoku-hub", "lock", "install", skin.slug];
        actProc.running = true;
    }
    function preview(slug) {
        Quickshell.execDetached([page.lockSh, slug]);
    }

    // Greedy masonry like the Extras grid: each tile into the shortest column,
    // estimated from the gif hero plus the blurb length so columns stay balanced.
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
        id: catalogProc
        command: ["ryoku-hub", "lock", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    var ss = o.skins || [];
                    for (var i = 0; i < ss.length; i++)
                        ss[i].ordinal = i + 1;
                    page.skins = ss;
                    page.active = o.active || "";
                    page.online = !!o.online;
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
        id: actProc
        stderr: StdioCollector { id: actErr }
        onExited: (code) => {
            if (code !== 0)
                page.error = (page.pendingInstall ? "Install failed: " : "Couldn't switch skin: ")
                    + (actErr.text.trim() || ("exit " + code));
            page.pendingSlug = "";
            page.pendingInstall = false;
            catalogProc.running = true;
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

        Column {
            anchors.left: parent.left
            anchors.right: refresh.left
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: "Browse every qylock skin. Selecting one installs it if needed, then applies it to both your lock screen and the sign-in screen; you'll be asked for your password."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.Medium
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: !page.online || page.error !== ""
                text: page.error !== "" ? page.error : "Offline: showing installed skins only."
                color: page.error !== "" ? Theme.bad : Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.Medium
            }
        }
        HubButton {
            id: refresh
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: "Refresh"
            icon: "refresh"
            enabled: page.pendingSlug === ""
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
                            viewport: flick
                            skin: modelData
                            ordinal: modelData.ordinal || 0
                            active: !!modelData.active
                            installed: !!modelData.installed
                            busy: page.pendingSlug === modelData.slug
                            installing: page.pendingInstall && page.pendingSlug === modelData.slug
                            onApplied: page.select(modelData)
                            onPreviewed: page.preview(modelData.slug)
                        }
                    }
                }
            }
        }
    }
}
