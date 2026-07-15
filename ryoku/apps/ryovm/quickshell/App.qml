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

    color: Theme.bgBot
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.bgTop }
        GradientStop { position: 1.0; color: Theme.bgBot }
    }

    property bool settingsOpen: false
    property bool importOpen: false
    property string mode: "library"     // library | catalog
    property string query: ""

    // only a hard hardware fault gates the whole window; a missing engine is an
    // annunciator banner instead, so the library (list/import need no engine)
    // stays a working room rather than a locked door.
    readonly property bool gated: Vm.capsLoaded && Vm.kvmOff
    readonly property bool engineMissing: Vm.capsLoaded && !Vm.kvmOff && !Vm.caps.quickemu
    readonly property int runningCount: {
        var n = 0;
        for (var i = 0; i < Vm.vms.length; i++)
            if (Vm.vms[i].running === true)
                n++;
        return n;
    }

    focus: true
    // keyboard grammar: Esc dismisses one layer and never quits (that muscle
    // memory kills downloads); arrows walk the library, Enter launches/stops,
    // / or Ctrl+F jumps to search, Ctrl+Q quits — with a handshake when a
    // download would die with the window.
    Keys.onEscapePressed: {
        if (app.importOpen) app.importOpen = false;
        else if (app.settingsOpen) app.settingsOpen = false;
        else if (input.activeFocus) { input.focus = false; app.forceActiveFocus(); }
        else if (app.query.length > 0) app.query = "";
        else if (app.mode === "catalog") app.mode = "library";
    }
    Keys.onUpPressed: app.moveSelection(-1)
    Keys.onDownPressed: app.moveSelection(1)
    Keys.onReturnPressed: app.launchSelected()
    Keys.onEnterPressed: app.launchSelected()
    Shortcut {
        sequences: ["/", "Ctrl+F"]
        onActivated: { if (!input.activeFocus) { input.forceActiveFocus(); input.selectAll(); } }
    }
    Shortcut { sequence: "Ctrl+Q"; onActivated: app.requestQuit() }

    function moveSelection(dir) {
        if (app.mode !== "library" || lib.shown.length === 0)
            return;
        var idx = -1;
        for (var i = 0; i < lib.shown.length; i++)
            if (lib.shown[i].name === Vm.selectedName) { idx = i; break; }
        idx = Math.max(0, Math.min(lib.shown.length - 1, idx + dir));
        Vm.select(lib.shown[idx].name);
    }
    function launchSelected() {
        if (app.mode !== "library" || Vm.busy || !Vm.selected)
            return;
        if (Vm.selected.running)
            Vm.stop(Vm.selected.name);
        else if (Vm.caps.quickemu === true)
            Vm.launch(Vm.selected.name, ({ "gtk": "window", "spice": "spice", "none": "headless" })[Vm.selected.display] || "window");
    }
    function requestQuit() {
        if (Vm.downloading && !quitArm.running) {
            Vm.info("A download is running — Cancel it, or quit again to abandon it");
            quitArm.restart();
            return;
        }
        Qt.quit();
    }
    Timer { id: quitArm; interval: 3000 }

    onModeChanged: if (mode === "catalog") Vm.loadCatalog(false)
    // deep-link start mode (the .desktop Browse action, tooling, tests), and an
    // optional OS to preselect once the catalogue lands.
    Component.onCompleted: { var m = Quickshell.env("RYOVM_START_MODE"); if (m === "catalog" || m === "instant") mode = m; }
    readonly property string startOs: Quickshell.env("RYOVM_START_OS") || ""
    Connections {
        target: Vm
        function onCreated(name) { app.mode = "library"; }
        function onOsListChanged() {
            if (app.startOs.length === 0 || Vm.selectedOs !== null)
                return;
            for (var i = 0; i < Vm.osList.length; i++)
                if (Vm.osList[i].os === app.startOs) { Vm.selectOs(Vm.osList[i]); break; }
        }
    }

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
                Text { text: "ryovm"; color: Theme.bright; font.family: Theme.display; font.pixelSize: 27; font.weight: Font.DemiBold; font.letterSpacing: 0.3 }
                Text { text: "Build, run and manage virtual machines."; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            // the departure board: the yard's headline, always live.
            FlapWord {
                anchors.verticalCenter: parent.verticalCenter
                visible: !app.gated
                text: String(Vm.vms.length).padStart(2, "0") + " MACHINES  "
                    + String(app.runningCount).padStart(2, "0") + " RUNNING"
                pad: 22
                cellW: 14
                cellH: 21
                fontPx: 12
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                IconBtn { name: "gear"; onClicked: app.settingsOpen = true }
                IconBtn { name: "close"; danger: true; onClicked: app.requestQuit() }
            }
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
            segW: 84
            model: [{ key: "library", label: "Library" }, { key: "catalog", label: "Catalog" }, { key: "instant", label: "Instant" }]
            current: app.mode
            onSelected: (k) => { app.mode = k; app.query = ""; }
        }

        Rectangle {
            id: searchBox
            anchors.left: modeToggle.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 280
            height: 38
            radius: Theme.radius
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
                    text: app.mode === "library" ? "Filter your machines" : app.mode === "instant" ? "Search instant images" : "Search 90+ operating systems"
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
        }
    }

    // ---- gate: virtualization off (the only whole-window fault) -------------
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

            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "cpu"; size: 40; tint: Theme.bad }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Virtualization is off"
                color: Theme.bright; font.family: Theme.font; font.pixelSize: 18; font.weight: Font.DemiBold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                text: "A virtual machine needs hardware virtualization. Turn on SVM / AMD-V (AMD) or VT-x (Intel) in your BIOS/firmware, then reboot."
                color: Theme.subtle; font.family: Theme.font; font.pixelSize: 13
            }
        }
    }

    // ---- engine banner: quickemu missing = a lit fault row, not a locked app --
    Rectangle {
        id: engineBanner
        anchors.top: toolbar.bottom
        anchors.topMargin: app.engineMissing ? 12 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 40
        anchors.rightMargin: 24
        height: app.engineMissing ? 44 : 0
        visible: app.engineMissing
        color: Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.08)
        border.width: 1
        border.color: Qt.alpha(Theme.ember, 0.45)
        antialiasing: false

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10; height: 10
                color: Theme.ember
                antialiasing: false
                SequentialAnimation on visible {
                    loops: Animation.Infinite
                    PropertyAction { value: true }
                    PauseAnimation { duration: 500 }
                    PropertyAction { value: false }
                    PauseAnimation { duration: 500 }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "ENGINE OFFLINE"
                color: Theme.ember
                font.family: Theme.mono; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 2
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "quickemu is not installed — machines can be imported and configured, not launched."
                color: Theme.subtle
                font.family: Theme.font; font.pixelSize: 12
            }
        }
        HubButton {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            label: "Install engine"
            icon: "download"
            primary: true
            onClicked: settings.installEngine()
        }
    }

    // ---- main: grid (left) + hero (right) -----------------------------------
    Item {
        id: main
        anchors.top: engineBanner.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: faultRow.top
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
            onBuildRequested: app.mode = "catalog"
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
            onInstallRequested: settings.installEngine()
            opacity: app.mode === "catalog" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        }
        CloudGrid {
            id: cloud
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.44
            filter: app.query
            selected: cloudPanel.os
            onPicked: (e) => cloudPanel.os = e
            opacity: app.mode === "instant" ? 1 : 0
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
        CloudPanel {
            id: cloudPanel
            anchors.left: gutter.right
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            opacity: app.mode === "instant" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        }
    }

    // ---- fault row: errors stay lit until dismissed or superseded -----------
    Rectangle {
        id: faultRow
        anchors.bottom: statusBar.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 40
        anchors.rightMargin: 24
        anchors.bottomMargin: Vm.fault.length > 0 ? 6 : 0
        height: Vm.fault.length > 0 ? faultCol.implicitHeight + 20 : 0
        visible: Vm.fault.length > 0
        color: Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.08)
        border.width: 1
        border.color: Qt.alpha(Theme.ember, 0.5)
        antialiasing: false
        property bool expanded: false

        Column {
            id: faultCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            Item {
                width: parent.width
                height: 22
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Annunciator { anchors.verticalCenter: parent.verticalCenter; label: "FAULT"; lit: true; warn: true; litColor: Theme.ember; tileW: 52 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: faultRow.width - 220
                        elide: Text.ElideRight
                        text: Vm.fault
                        color: Theme.bright
                        font.family: Theme.font; font.pixelSize: 12
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Text {
                        visible: Vm.faultDetail.indexOf("\n") >= 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: faultRow.expanded ? "LESS" : "DETAIL"
                        color: fdh.hovered ? Theme.bright : Theme.subtle
                        font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 1.5; font.weight: Font.DemiBold
                        HoverHandler { id: fdh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: faultRow.expanded = !faultRow.expanded }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DISMISS"
                        color: fxh.hovered ? Theme.ember : Theme.subtle
                        font.family: Theme.mono; font.pixelSize: 9; font.letterSpacing: 1.5; font.weight: Font.DemiBold
                        HoverHandler { id: fxh; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { faultRow.expanded = false; Vm.clearFault(); } }
                    }
                }
            }

            Flickable {
                visible: faultRow.expanded
                width: parent.width
                height: Math.min(faultDetailText.implicitHeight, 140)
                contentHeight: faultDetailText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: faultDetailText
                    width: parent.width
                    wrapMode: Text.WrapAnywhere
                    text: Vm.faultDetail
                    color: Theme.subtle
                    font.family: Theme.mono; font.pixelSize: 11
                }
            }
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
            color: Vm.status.length > 0 ? Theme.subtle : Theme.faint
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
            radius: Theme.radius
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
