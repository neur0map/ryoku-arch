pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Singletons"

// In-app settings: where VMs live, the engine status, and a one-click install
// when quickemu is missing.
Item {
    id: sp
    property bool open: false
    signal closed()

    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        TapHandler { onTapped: sp.closed() }
    }

    // the modal is a raised plate: same hard offset shadow as the board.
    Rectangle {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: 8
        anchors.verticalCenterOffset: 8
        width: 480
        height: panelFace.height
        color: Theme.shadow
        antialiasing: false
        visible: panelFace.visible
    }
    Rectangle {
        id: panelFace
        anchors.centerIn: parent
        width: 480
        height: col.implicitHeight + 44
        radius: Theme.radius
        color: Theme.surface
        border.width: 1
        border.color: Theme.lineStrong
        scale: sp.open ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        TapHandler {}

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 22
            spacing: 18

            Item {
                width: parent.width
                height: 28
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Settings"; color: Theme.bright; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold }
                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    Icon { anchors.centerIn: parent; name: "close"; size: 15; tint: ch.hovered ? Theme.ember : Theme.faint; Behavior on tint { ColorAnimation { duration: Theme.quick } } }
                    HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: sp.closed() }
                }
            }

            // engine status row.
            Item {
                width: parent.width
                height: 40
                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "Engine"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                    Text {
                        text: Vm.caps.quickemu ? ("quickemu " + (Vm.caps.version || "")) : "quickemu not installed"
                        color: Vm.caps.quickemu ? Theme.ok : Theme.bad
                        font.family: Theme.mono; font.pixelSize: 11
                    }
                }
                HubButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !Vm.caps.quickemu
                    label: "Install"
                    icon: "download"
                    primary: true
                    onClicked: sp.installEngine()
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.line }

            // defaults.
            Text { text: "New machine defaults"; color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
            NumberField {
                width: parent.width
                label: "CPU cores"
                from: 1; to: 32; step: 1
                value: Vm.settings.defaultCores
                onModified: (v) => { Vm.settings.defaultCores = Math.round(v); Vm.saveSettings(); }
            }
            NumberField {
                width: parent.width
                label: "Memory"
                unit: "GB"
                from: 1; to: 128; step: 1
                value: Vm.settings.defaultRam
                onModified: (v) => { Vm.settings.defaultRam = Math.round(v); Vm.saveSettings(); }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.line }

            Item {
                width: parent.width
                height: 38
                Column {
                    anchors.left: parent.left
                    anchors.right: openBtn.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "Machines"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                    Text { width: parent.width; elide: Text.ElideMiddle; text: Vm.paths.vms || "~/.local/share/ryoku/vms"; color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11 }
                }
                HubButton {
                    id: openBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "folder"
                    label: "Open"
                    onClicked: Vm.openFolder("")
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.line }

            // where the catalogue + brand logos come from, and where they cache.
            Column {
                width: parent.width
                spacing: 9
                Text { text: "Catalogue"; color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 2; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
                ProvRow { k: "Source"; v: (Vm.paths.provider || "quickemu + quickget") + " · " + (Vm.paths.source || "github.com/quickemu-project") }
                ProvRow { k: "Logos"; v: Vm.paths.icons_provider || "simple-icons + quickemu-icons" }
                ProvRow { k: "Cached"; v: Vm.paths.icons || "~/.cache/ryoku/ryovm-icons" }
            }
        }
    }

    component ProvRow: Item {
        property string k: ""
        property string v: ""
        width: parent ? parent.width : 0
        height: 18
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 64; text: parent.k; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
        Text { anchors.left: parent.left; anchors.leftMargin: 70; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideMiddle; text: parent.v; color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 11 }
        }

    function installEngine() {
        Quickshell.execDetached(["sh", "-c",
            "exec \"${TERMINAL:-kitty}\" --class ryovm -e sh -c \"ryovm setup; echo; read -n1 -rsp 'Press any key to close…'; echo\""]);
    }
}
