pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "Singletons"

// ryovm: your machines on the left (Library) or the OS catalogue to build from
// (Catalog); the live machine stage or the create panel on the right. The hero
// is always the right pane, mirroring ryowalls' shape.
Rectangle {
    id: app

    implicitWidth: 1180
    implicitHeight: 760

    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.bgTop }
        GradientStop { position: 1.0; color: Theme.bgBot }
    }

    property bool settingsOpen: false
    property bool importOpen: false
    property string mode: "library"     // library | catalog
    property string query: ""

    readonly property bool gated: Vm.capsLoaded && (!Vm.caps.quickemu || Vm.kvmOff)

    focus: true
    Keys.onEscapePressed: { if (app.importOpen) app.importOpen = false; else if (app.settingsOpen) app.settingsOpen = false; else Qt.quit(); }
    onModeChanged: if (mode === "catalog") Vm.loadCatalog(false)

    // ---- header -------------------------------------------------------------
    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 40
        anchors.rightMargin: 22
        anchors.topMargin: 18
        height: 54

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 11
            Image {
                anchors.verticalCenter: parent.verticalCenter
                source: "logo.svg"
                sourceSize: Qt.size(30, 30)
                width: 30
                height: 30
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text { text: "ryovm"; color: Theme.bright; font.family: Theme.font; font.pixelSize: 25; font.weight: Font.DemiBold; font.letterSpacing: 0.3 }
                Text { text: "Build, run and manage virtual machines."; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            IconBtn { name: "gear"; onClicked: app.settingsOpen = true }
            IconBtn { name: "close"; danger: true; onClicked: Qt.quit() }
        }
    }

    // ---- toolbar ------------------------------------------------------------
    Item {
        id: toolbar
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 40
        anchors.rightMargin: 24
        anchors.topMargin: 10
        height: 40
        visible: !app.gated

        Segmented {
            id: modeToggle
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            segW: 86
            model: [{ key: "library", label: "Library" }, { key: "catalog", label: "Catalog" }]
            current: app.mode
            onSelected: (k) => { app.mode = k; app.query = ""; }
        }

        Rectangle {
            id: searchBox
            anchors.left: modeToggle.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 280
            height: 36
            radius: 9
            color: Theme.surfaceLo
            border.width: 1
            border.color: input.activeFocus ? Theme.ember : Theme.line
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

            Icon { id: si; anchors.left: parent.left; anchors.leftMargin: 11; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 15; tint: Theme.dim }
            TextInput {
                id: input
                anchors.left: si.right
                anchors.leftMargin: 9
                anchors.right: parent.right
                anchors.rightMargin: 11
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 13
                selectByMouse: true
                selectionColor: Theme.frameBg
                clip: true
                text: app.query
                onTextEdited: app.query = text
                Text {
                    anchors.fill: parent
                    visible: input.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                    text: app.mode === "library" ? "Filter your machines" : "Search 90+ operating systems"
                    color: Theme.faint
                    font: input.font
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            HubButton { anchors.verticalCenter: parent.verticalCenter; icon: "disk"; label: "Load ISO"; onClicked: app.importOpen = true }
            IconBtn { anchors.verticalCenter: parent.verticalCenter; visible: app.mode === "catalog"; name: "refresh"; dim: Vm.catalogLoading; onClicked: Vm.loadCatalog(true) }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: app.mode === "library"
                text: Vm.vms.length + (Vm.vms.length === 1 ? " machine" : " machines")
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 11
            }
        }
    }

    // ---- gate: engine missing / virtualization off --------------------------
    Item {
        anchors.top: toolbar.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: statusBar.top
        anchors.leftMargin: 40
        anchors.rightMargin: 24
        visible: app.gated

        Column {
            anchors.centerIn: parent
            width: Math.min(parent.width, 520)
            spacing: 16

            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Vm.kvmOff ? "cpu" : "download"; size: 40; tint: Vm.kvmOff ? Theme.bad : Theme.ember }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                text: Vm.kvmOff ? "Virtualization is off" : "Install QEMU to run virtual machines"
                color: Theme.bright; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                text: Vm.kvmOff
                    ? "A virtual machine needs hardware virtualization. Turn on SVM / AMD-V (AMD) or VT-x (Intel) in your BIOS/firmware, then reboot."
                    : "ryovm runs on quickemu, which downloads and tunes machines for you. This installs quickemu and the SPICE viewer."
                color: Theme.subtle; font.family: Theme.font; font.pixelSize: 13
            }
            HubButton {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !Vm.kvmOff
                label: "Install QEMU"
                icon: "download"
                primary: true
                onClicked: settings.installEngine()
            }
        }
    }

    // ---- main: grid (left) + hero (right) -----------------------------------
    Item {
        id: main
        anchors.top: toolbar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: statusBar.top
        anchors.leftMargin: 40
        anchors.rightMargin: 24
        anchors.topMargin: 12
        anchors.bottomMargin: 6
        visible: !app.gated

        VmGrid {
            id: lib
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.44
            filter: app.query
            opacity: app.mode === "library" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        }
        OsGrid {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.44
            filter: app.query
            opacity: app.mode === "catalog" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        }

        Rectangle {
            id: gutter
            anchors.left: lib.right
            anchors.leftMargin: 20
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            width: 1
            color: Theme.line
        }

        VmDetail {
            anchors.left: gutter.right
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            opacity: app.mode === "library" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        }
        CreatePanel {
            anchors.left: gutter.right
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            opacity: app.mode === "catalog" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        }
    }

    // ---- status bar ---------------------------------------------------------
    Item {
        id: statusBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 40
        anchors.rightMargin: 24
        height: 28

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Vm.status.length > 0 ? Vm.status : (Vm.busy ? "Working…" : "")
            color: Vm.status.length > 0 ? Theme.ember : Theme.faint
            font.family: Theme.mono
            font.pixelSize: 11
            font.letterSpacing: 0.5
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "quickemu"
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    SettingsPanel {
        id: settings
        anchors.fill: parent
        open: app.settingsOpen
        onClosed: app.settingsOpen = false
    }

    ImportDialog {
        anchors.fill: parent
        open: app.importOpen
        onClosed: app.importOpen = false
    }

    component IconBtn: Item {
        id: ib
        property string name: ""
        property bool danger: false
        property bool dim: false
        signal clicked()
        width: 30
        height: 30
        opacity: ib.dim ? 0.35 : 1
        Rectangle {
            anchors.fill: parent
            radius: 8
            color: ibHover.hovered && !ib.dim ? Theme.keyTop : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
        Icon {
            anchors.centerIn: parent
            name: ib.name
            size: 16
            tint: ib.danger ? (ibHover.hovered ? Theme.ember : Theme.faint)
                : (ibHover.hovered && !ib.dim ? Theme.bright : Theme.cream)
            Behavior on tint { ColorAnimation { duration: Theme.quick } }
        }
        HoverHandler { id: ibHover; enabled: !ib.dim; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: !ib.dim; onTapped: ib.clicked() }
    }
}
