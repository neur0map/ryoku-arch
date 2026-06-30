pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

// Load ISO: build a machine from any local ISO, off-catalogue. The full QEMU
// reach for an OS quickget doesn't carry, or a custom spin. The guest type
// doubles as the brand-logo slug (Windows/macOS get real marks).
Item {
    id: dlg
    property bool open: false
    signal closed()

    property string vmName: ""
    property string isoPath: ""
    property string guest: "linux"

    readonly property bool valid: dlg.vmName.trim().length > 0 && dlg.isoPath.trim().length > 0

    function reset() { dlg.vmName = ""; dlg.isoPath = ""; dlg.guest = "linux"; }

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        TapHandler { onTapped: dlg.closed() }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 480
        height: col.implicitHeight + 44
        radius: 16
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.line
        scale: dlg.open ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        TapHandler {}

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            spacing: 16

            Item {
                width: parent.width
                height: 28
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "disk"; size: 18; tint: Theme.ember }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Load ISO"; color: Theme.bright; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold }
                }
                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    Icon { anchors.centerIn: parent; name: "close"; size: 15; tint: ch.hovered ? Theme.ember : Theme.faint; Behavior on tint { ColorAnimation { duration: Theme.quick } } }
                    HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: dlg.closed() }
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Build a machine from an ISO on disk. quickemu picks tuned defaults; set cores, memory and the display after it's created."
                color: Theme.dim; font.family: Theme.font; font.pixelSize: 12
            }

            // name.
            Column {
                width: parent.width
                spacing: 7
                Text { text: "Name"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                Rectangle {
                    width: parent.width
                    height: 38
                    radius: 9
                    color: Theme.surfaceLo
                    border.width: 1
                    border.color: nameIn.activeFocus ? Theme.ember : Theme.line
                    Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                    TextInput {
                        id: nameIn
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.bright
                        font.family: Theme.font
                        font.pixelSize: 13
                        clip: true
                        selectByMouse: true
                        text: dlg.vmName
                        // a conf filename: no spaces or slashes.
                        onTextEdited: dlg.vmName = text.replace(/[\/\s]+/g, "-")
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: nameIn.text.length === 0; text: "my-machine"; color: Theme.faint; font: nameIn.font }
                    }
                }
            }

            // ISO path + browse.
            Column {
                width: parent.width
                spacing: 7
                Text { text: "ISO file"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                Row {
                    width: parent.width
                    spacing: 10
                    Rectangle {
                        width: parent.width - browse.width - 10
                        height: 38
                        radius: 9
                        color: Theme.surfaceLo
                        border.width: 1
                        border.color: isoIn.activeFocus ? Theme.ember : Theme.line
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                        TextInput {
                            id: isoIn
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.bright
                            font.family: Theme.mono
                            font.pixelSize: 12
                            clip: true
                            selectByMouse: true
                            text: dlg.isoPath
                            onTextEdited: dlg.isoPath = text
                            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: isoIn.text.length === 0; text: "/path/to/os.iso"; color: Theme.faint; font: isoIn.font }
                        }
                    }
                    HubButton {
                        id: browse
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Browse"
                        icon: "folder"
                        onClicked: pickProc.running = true
                    }
                }
            }

            // guest type (doubles as logo slug).
            Column {
                width: parent.width
                spacing: 7
                Text { text: "Guest type"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                Segmented {
                    width: parent.width
                    segW: (width - 8) / model.length
                    model: [{ key: "linux", label: "Linux" }, { key: "windows", label: "Windows" }, { key: "macos", label: "macOS" }]
                    current: dlg.guest
                    onSelected: (k) => dlg.guest = k
                }
            }

            Row {
                spacing: 10
                HubButton {
                    primary: true
                    icon: "check"
                    label: "Create"
                    enabled: dlg.valid && !Vm.busy
                    onClicked: {
                        Vm.importVm(dlg.vmName.trim(), dlg.isoPath.trim(), dlg.guest, dlg.guest);
                        dlg.reset();
                        dlg.closed();
                    }
                }
                HubButton {
                    label: "Cancel"
                    onClicked: dlg.closed()
                }
            }
        }
    }

    Process {
        id: pickProc
        command: ["sh", "-c", "zenity --file-selection --title='Select an ISO' --file-filter='ISO images | *.iso *.ISO *.img' --file-filter='All files | *' 2>/dev/null || kdialog --getopenfilename \"$HOME\" '*.iso *.ISO *.img|ISO images' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim();
                if (p.length > 0) {
                    dlg.isoPath = p;
                    if (dlg.vmName.length === 0) {
                        var base = p.split("/").pop().replace(/\.(iso|img|ISO|IMG)$/, "");
                        dlg.vmName = base.replace(/[\/\s]+/g, "-");
                    }
                }
            }
        }
    }
}
