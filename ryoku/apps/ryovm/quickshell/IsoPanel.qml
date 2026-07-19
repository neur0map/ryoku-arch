pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The NEW lane's ISO right pane. The old modal ImportDialog dissolves into this
// sheet in the hero: build a machine from any local ISO, off-catalogue, the full
// QEMU reach. Fields: name, path (mono, with BROWSE via the zenity/kdialog
// fallback), guest type (which doubles as the brand-logo slug), CREATE.
Item {
    id: pane

    property string vmName: ""
    property string isoPath: ""
    property string guest: "linux"

    readonly property bool valid: pane.vmName.trim().length > 0 && pane.isoPath.trim().length > 0
    function reset() { pane.vmName = ""; pane.isoPath = ""; pane.guest = "linux"; }

    // hero: the guest mark and the prospective name in the window's serif.
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
                width: 64; height: 64; size: 64
                slug: pane.guest
                label: pane.guest
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: hero.width - 2 * Tokens.s6
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: pane.vmName.trim().length > 0 ? pane.vmName : "New machine from ISO"
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

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Build a machine from an ISO on disk. quickemu picks tuned defaults; set cores, memory and the display after it's created."
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: 12
            }

            Column {
                width: parent.width
                spacing: Tokens.s2
                FieldLabel { text: "Name" }
                Field {
                    width: parent.width
                    text: pane.vmName
                    placeholder: "my-machine"
                    // a conf filename: no spaces or slashes.
                    onEdited: (v) => pane.vmName = v.replace(/[\/\s]+/g, "-")
                }
            }

            Column {
                width: parent.width
                spacing: Tokens.s2
                FieldLabel { text: "ISO file" }
                Row {
                    width: parent.width
                    spacing: Tokens.s3
                    Field {
                        id: pathField
                        width: parent.width - browse.width - Tokens.s3
                        tabular: true
                        text: pane.isoPath
                        placeholder: "/path/to/os.iso"
                        onEdited: (v) => pane.isoPath = v
                    }
                    Btn {
                        id: browse
                        anchors.verticalCenter: parent.verticalCenter
                        text: "BROWSE"
                        onAct: pickProc.running = true
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Tokens.s2
                FieldLabel { text: "Guest type" }
                Seg {
                    options: ["LINUX", "WINDOWS", "MACOS"]
                    current: pane.guest.toUpperCase()
                    onChose: (k) => pane.guest = k.toLowerCase()
                }
                Text {
                    width: parent.width
                    visible: pane.guest === "windows"
                    wrapMode: Text.WordWrap
                    text: "Windows enables a TPM and fetches the VirtIO driver CD, attached so setup sees the disk. Secure Boot stays off (Arch ships no MS-key firmware). Grab the ISO from microsoft.com/software-download."
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: 11
                }
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
            text: "CREATE"
            armed: pane.valid && !Vm.busy
            onAct: {
                Vm.importVm(pane.vmName.trim(), pane.isoPath.trim(), pane.guest, pane.guest);
                pane.reset();
            }
        }
    }

    component FieldLabel: Text {
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: Tokens.trackLabel
        font.capitalization: Font.AllUppercase
    }

    // the zenity/kdialog file picker survives verbatim.
    Process {
        id: pickProc
        command: ["sh", "-c", "zenity --file-selection --title='Select an ISO' --file-filter='ISO images | *.iso *.ISO *.img' --file-filter='All files | *' 2>/dev/null || kdialog --getopenfilename \"$HOME\" '*.iso *.ISO *.img|ISO images' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim();
                if (p.length > 0) {
                    pane.isoPath = p;
                    if (pane.vmName.length === 0) {
                        var base = p.split("/").pop().replace(/\.(iso|img|ISO|IMG)$/, "");
                        pane.vmName = base.replace(/[\/\s]+/g, "-");
                    }
                }
            }
        }
    }
}
