pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The NEW lane's CATALOG right pane: the chosen OS on a flat framed hero, a
// release and edition picker as wrapping chips, then Create. Create downloads
// in-app, so the pane switches to the shared progress spec until the machine
// lands in the Library.
Item {
    id: pane

    readonly property var os: Vm.selectedOs
    property string release: ""
    property string edition: ""

    readonly property var editions: {
        if (!pane.os || !pane.release)
            return [];
        return pane.os.editions[pane.release] || [];
    }

    onOsChanged: {
        // quickget lists releases oldest-first, but the tail is often a dev
        // channel. Default to the newest STABLE: scan from the end, skip dev.
        var r = pane.os ? pane.os.releases : [];
        var dev = /(^|[-_])(daily|weekly|nightly|unstable|testing|preview|beta|canary|sid)([-_]|$)|^rc/i;
        var pick = "";
        for (var i = r.length - 1; i >= 0; i--)
            if (!dev.test(r[i])) { pick = r[i]; break; }
        pane.release = pick.length > 0 ? pick : (r.length > 0 ? r[r.length - 1] : "");
        pane._resetEdition();
    }
    onReleaseChanged: pane._resetEdition()
    function _resetEdition() {
        var e = pane.editions || [];
        var ranked = ["standard", "default", "gnome", "plasma", "kde"];
        for (var i = 0; i < ranked.length; i++)
            if (e.indexOf(ranked[i]) >= 0) { pane.edition = ranked[i]; return; }
        pane.edition = e.length > 0 ? e[0] : "";
    }

    // empty state.
    Column {
        anchors.centerIn: parent
        spacing: Tokens.s3
        visible: pane.os === null
        Mark { anchors.horizontalCenter: parent.horizontalCenter; size: 96 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            text: Vm.dlCount > 0 ? "Pick another OS to build alongside" : "Pick an OS to build a new machine"
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: 12
        }
    }

    // active downloads: a compact stack (see DownloadStack), so several builds
    // run at once while the picker below stays ready for the next.
    DownloadStack {
        id: dlStack
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    Item {
        anchors.top: dlStack.visible ? dlStack.bottom : parent.top
        anchors.topMargin: dlStack.visible ? Tokens.s4 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: pane.os !== null

        // the OS hero: brand mark and name on a flat framed plate.
        Rectangle {
            id: hero
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(150, parent.height * 0.26)
            color: "transparent"
            radius: Tokens.radius
            border.width: Tokens.border
            border.color: Tokens.line
            antialiasing: false

            RegMark { x: parent.width - width - 16; y: 15; size: 12; tint: Tokens.inkFaint }

            Column {
                anchors.centerIn: parent
                spacing: Tokens.s3
                OsIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 72; height: 72; size: 72
                    slug: pane.os ? pane.os.os : ""
                    label: pane.os ? pane.os.name : ""
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pane.os ? pane.os.name : ""
                    color: Tokens.ink
                    font.family: Tokens.display
                    font.pixelSize: 22
                }
            }
        }

        Flickable {
            anchors.top: hero.bottom
            anchors.topMargin: Tokens.s4
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: createRow.top
            anchors.bottomMargin: Tokens.s4
            contentWidth: width
            contentHeight: form.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            ScrollBar.vertical: ScrollRail {}

            Column {
                id: form
                width: parent.width - 8
                spacing: Tokens.s4

                Column {
                    width: parent.width
                    spacing: Tokens.s2
                    Text {
                        text: "RELEASE"
                        color: Tokens.inkMuted
                        font.family: Tokens.ui; font.pixelSize: 10; font.weight: Font.Medium
                        font.letterSpacing: Tokens.trackLabel; font.capitalization: Font.AllUppercase
                    }
                    Chips {
                        width: parent.width
                        options: pane.os ? pane.os.releases : []
                        current: pane.release
                        onChose: (k) => pane.release = k
                    }
                }

                Column {
                    width: parent.width
                    spacing: Tokens.s2
                    visible: pane.editions.length > 0
                    Text {
                        text: "EDITION"
                        color: Tokens.inkMuted
                        font.family: Tokens.ui; font.pixelSize: 10; font.weight: Font.Medium
                        font.letterSpacing: Tokens.trackLabel; font.capitalization: Font.AllUppercase
                    }
                    Chips {
                        width: parent.width
                        options: pane.editions
                        current: pane.edition
                        onChose: (k) => pane.edition = k
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "quickemu downloads the official image and tunes the machine to your hardware. You can change cores, memory and the display mode after it lands in your Library."
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: 12
                }
            }
        }

        Row {
            id: createRow
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 32
            spacing: Tokens.s3
            Btn {
                primary: true
                text: "CREATE MACHINE"
                armed: pane.release.length > 0
                onAct: { Vm.createVm(pane.os.os, pane.release, pane.edition); Vm.selectedOs = null; }
            }
        }
    }
}
