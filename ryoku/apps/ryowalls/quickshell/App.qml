pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Dialogs
import Quickshell
import "Singletons"

// ryowalls: browse wallhaven on the left (or tune the look), live rice preview
// on the right. The left column swaps between Browse and Tune; the preview is
// always the visible hero.
Rectangle {
    id: app

    implicitWidth: 1180
    implicitHeight: 760

    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.bgTop }
        GradientStop { position: 1.0; color: Theme.bgBot }
    }

    property bool settingsOpen: false
    property bool sourceMenuOpen: false
    property string mode: "browse"          // browse | tune
    readonly property bool fitOn: Wallhaven.ratios.length > 0

    // re-check the upscaler tools when the window regains focus, e.g. after the
    // gpk install terminal closes, so Install clears to the toggle on its own.
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: if (windowActive) Wallhaven.refreshCaps()

    readonly property var builtins: [
        { key: "wallhaven", label: "Wallhaven" },
        { key: "live", label: "Live" },
        { key: "local", label: "Local" },
        { key: "moewalls", label: "MoeWalls" },
        { key: "motionbgs", label: "motionbgs" },
        { key: "ryoku", label: "Ryoku" }
    ]
    readonly property string sourceLabel: {
        if (Wallhaven.source === "lib")
            return Wallhaven.libraryName;
        for (var i = 0; i < builtins.length; i++)
            if (builtins[i].key === Wallhaven.source)
                return builtins[i].label;
        return "Wallhaven";
    }

    // nearest wallhaven aspect for the primary monitor, for the Fit toggle.
    readonly property string screenRatio: {
        var s = (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null;
        if (!s || !s.width || !s.height)
            return "16x9";
        var a = s.width / s.height;
        var t = [["9x16", 0.5625], ["10x16", 0.625], ["1x1", 1], ["5x4", 1.25], ["4x3", 1.333],
            ["3x2", 1.5], ["16x10", 1.6], ["16x9", 1.777], ["21x9", 2.333], ["32x9", 3.555]];
        var best = "16x9", bd = 1e9;
        for (var i = 0; i < t.length; i++) {
            var d = Math.abs(t[i][1] - a);
            if (d < bd) { bd = d; best = t[i][0]; }
        }
        return best;
    }

    focus: true
    Keys.onEscapePressed: { if (app.settingsOpen) app.settingsOpen = false; else Qt.quit(); }
    Component.onCompleted: if (Wallhaven.results.length === 0) Wallhaven.searchLatest("")

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
                Text { text: "ryowalls"; color: Theme.bright; font.family: Theme.font; font.pixelSize: 25; font.weight: Font.DemiBold; font.letterSpacing: 0.3 }
                Text { text: "Find a wallpaper, preview the rice, set it."; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
            }
        }

        Row {
            id: winBtns
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            IconBtn { name: "gear"; onClicked: app.settingsOpen = true }
            IconBtn { name: "close"; danger: true; onClicked: Qt.quit() }
        }

        // source picker: built-in libraries plus any repos the user added. A
        // dropdown (not a segmented row) so it scales to arbitrary libraries.
        Rectangle {
            id: sourceBtn
            anchors.right: winBtns.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            height: 34
            width: srcRow.implicitWidth + 26
            radius: Theme.radius
            color: srcHover.hovered || app.sourceMenuOpen ? Theme.keyTop : Theme.surfaceLo
            border.width: 1
            border.color: app.sourceMenuOpen ? Theme.ember : Theme.line
            Behavior on color { ColorAnimation { duration: Theme.quick } }
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }
            Row {
                id: srcRow
                anchors.centerIn: parent
                spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: app.sourceLabel; color: Theme.bright; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium }
                Icon { anchors.verticalCenter: parent.verticalCenter; name: "chevron-right"; size: 12; tint: Theme.dim; rotation: app.sourceMenuOpen ? 90 : 0; Behavior on rotation { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } } }
            }
            HoverHandler { id: srcHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: app.sourceMenuOpen = !app.sourceMenuOpen }
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

        Segmented {
            id: modeToggle
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            segW: 78
            model: [{ key: "browse", label: "Browse" }, { key: "tune", label: "Tune" }]
            current: app.mode
            onSelected: (k) => app.mode = k
        }

        // local live wallpapers have nothing to search; the box greys out there.
        Rectangle {
            id: searchBox
            anchors.left: modeToggle.right
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 270
            height: 36
            radius: Theme.radius
            color: Theme.surfaceLo
            opacity: Wallhaven.source === "live" ? 0.4 : 1
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
                enabled: Wallhaven.source !== "live"
                selectByMouse: true
                selectionColor: Theme.frameBg
                clip: true
                onAccepted: { app.mode = "browse"; Wallhaven.searchLatest(text); }
                Text {
                    anchors.fill: parent
                    visible: input.text.length === 0
                    verticalAlignment: Text.AlignVCenter
                    text: Wallhaven.source === "local" ? "Search saved wallpapers"
                        : (Wallhaven.source === "moewalls" ? "Search MoeWalls anime"
                        : (Wallhaven.source === "motionbgs" ? "Search motionbgs"
                        : (Wallhaven.source === "ryoku" ? "Search Ryoku wallpapers"
                        : (Wallhaven.source === "lib" ? "Search " + Wallhaven.libraryName : "Search wallhaven"))))
                    color: Theme.faint
                    font: input.font
                }
            }
        }

        // browse-only controls fade out in Tune mode.
        Item {
            id: browseTools
            anchors.left: searchBox.right
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            opacity: app.mode === "browse" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }

            Segmented {
                id: sorter
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                segW: 92
                visible: Wallhaven.source === "wallhaven"
                model: [{ key: "", label: "Latest" }, { key: "1w", label: "Top week" }, { key: "1M", label: "Top month" }]
                current: Wallhaven.topRange
                onSelected: (k) => Wallhaven.searchTop(k)
            }

            // a library can hold both images and video; filter by kind.
            Segmented {
                id: libType
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                segW: 74
                visible: Wallhaven.source === "lib" || Wallhaven.source === "local"
                model: [{ key: "all", label: "All" }, { key: "images", label: "Images" }, { key: "live", label: "Live" }]
                current: Wallhaven.libraryType
                onSelected: (k) => Wallhaven.setLibraryType(k)
            }

            // add your own mp4 to ~/Pictures/livewalls (Live source only).
            Rectangle {
                id: addChip
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                width: addRow.implicitWidth + 24
                radius: height / 2
                visible: Wallhaven.source === "live"
                color: Theme.surfaceLo
                border.width: 1
                border.color: addHover.hovered ? Qt.alpha(Theme.ember, 0.6) : Theme.line
                Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                Row {
                    id: addRow
                    anchors.centerIn: parent
                    spacing: 7
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "plus"; size: 14; tint: Theme.cream }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Add mp4"; color: Theme.cream; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                }
                HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: addDialog.open() }
            }

            Rectangle {
                id: fitChip
                anchors.left: sorter.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                width: fitRow.implicitWidth + 24
                radius: height / 2
                color: app.fitOn ? Theme.frameBg : Theme.surfaceLo
                border.width: 1
                border.color: app.fitOn ? Theme.ember : (fitHover.hovered ? Qt.alpha(Theme.ember, 0.6) : Theme.line)
                Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                Behavior on color { ColorAnimation { duration: Theme.quick } }
                Row {
                    id: fitRow
                    anchors.centerIn: parent
                    spacing: 7
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: "display"; size: 14; tint: app.fitOn ? Theme.ember : Theme.cream }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Fit screen"; color: app.fitOn ? Theme.ember : Theme.cream; font.family: Theme.font; font.pixelSize: 12; font.weight: Font.Medium }
                }
                HoverHandler { id: fitHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Wallhaven.setRatios(app.fitOn ? "" : app.screenRatio) }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: Wallhaven.source !== "live" && Wallhaven.source !== "ryoku" && Wallhaven.source !== "local"
                IconBtn { name: "chevron-left"; dim: Wallhaven.page <= 1 || Wallhaven.searching; onClicked: Wallhaven.prevPage() }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "" + Wallhaven.page
                    color: Wallhaven.searching ? Theme.ember : Theme.subtle
                    font.family: Theme.mono
                    font.pixelSize: 13
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }
                IconBtn { name: "chevron-right"; dim: Wallhaven.searching; onClicked: Wallhaven.nextPage() }
            }
            // Local source: bulk-select + delete controls.
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: Wallhaven.source === "local"
                HubButton {
                    label: Wallhaven.localSelection.length > 0 ? "Clear" : "Select all"
                    icon: Wallhaven.localSelection.length > 0 ? "close" : "check"
                    onClicked: Wallhaven.localSelection.length > 0 ? Wallhaven.clearLocalSelection() : Wallhaven.selectAllLocal()
                }
                HubButton {
                    visible: Wallhaven.localSelection.length > 0
                    primary: true
                    icon: "trash"
                    label: "Delete " + Wallhaven.localSelection.length
                    onClicked: confirmDelete.open = true
                }
            }
        }
    }

    // ---- main: browse | tune  on the left, preview on the right -------------
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

        WallGrid {
            id: grid
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.46
            opacity: app.mode === "browse" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        }

        TunePanel {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.46
            opacity: app.mode === "tune" ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        }

        Rectangle {
            id: gutter
            anchors.left: grid.right
            anchors.leftMargin: 20
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            width: 1
            color: Theme.line
        }

        PreviewPane {
            anchors.left: gutter.right
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
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
            text: Wallhaven.status.length > 0 ? Wallhaven.status
                : (Wallhaven.results.length > 0 ? Wallhaven.results.length + " wallpapers" : "")
            color: Wallhaven.status.length > 0 ? Theme.ember : Theme.faint
            font.family: Theme.mono
            font.pixelSize: 11
            font.letterSpacing: 0.5
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Wallhaven.source === "local" ? "~/Pictures"
                : (Wallhaven.source === "live" ? "~/Pictures/livewalls"
                : (Wallhaven.source === "moewalls" ? "moewalls.com"
                : (Wallhaven.source === "motionbgs" ? "motionbgs.com"
                : (Wallhaven.source === "ryoku" ? "ryoku-extras"
                : (Wallhaven.source === "lib" ? "github.com/" + Wallhaven.libraryRepo : "wallhaven.cc")))))
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    // source dropdown: built-ins, then user libraries, then an add field.
    Item {
        anchors.fill: parent
        visible: app.sourceMenuOpen
        z: 40
        MouseArea { anchors.fill: parent; onClicked: app.sourceMenuOpen = false }
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 64
            anchors.rightMargin: 22
            width: 244
            height: menuCol.implicitHeight + 16
            radius: Theme.radius
            color: Theme.cardTop
            border.width: 1
            border.color: Theme.line
            MouseArea { anchors.fill: parent }
            Column {
                id: menuCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                Repeater {
                    model: app.builtins
                    delegate: SrcRow {
                        required property var modelData
                        width: menuCol.width
                        label: modelData.label
                        active: Wallhaven.source === modelData.key
                        onPick: { app.mode = "browse"; Wallhaven.setSource(modelData.key); app.sourceMenuOpen = false; }
                    }
                }

                Rectangle { width: menuCol.width; height: 1; color: Theme.line; visible: Wallhaven.libraries.length > 0 }
                Repeater {
                    model: Wallhaven.libraries
                    delegate: SrcRow {
                        required property var modelData
                        width: menuCol.width
                        label: modelData.name
                        sub: modelData.repo
                        removable: true
                        active: Wallhaven.source === "lib" && Wallhaven.libraryRepo === modelData.repo
                        onPick: { app.mode = "browse"; Wallhaven.setLibrary(modelData); app.sourceMenuOpen = false; }
                        onRemove: Wallhaven.removeLibrary(modelData.repo)
                    }
                }

                Rectangle { width: menuCol.width; height: 1; color: Theme.line }
                Rectangle {
                    width: menuCol.width
                    height: 34
                    radius: Theme.radius
                    color: addInput.activeFocus ? Theme.surfaceLo : "transparent"
                    border.width: 1
                    border.color: addInput.activeFocus ? Theme.ember : "transparent"
                    Icon { id: pl; anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; name: "plus"; size: 13; tint: Theme.dim }
                    TextInput {
                        id: addInput
                        anchors.left: pl.right
                        anchors.leftMargin: 7
                        anchors.right: parent.right
                        anchors.rightMargin: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.bright
                        font.family: Theme.mono
                        font.pixelSize: 12
                        clip: true
                        selectByMouse: true
                        selectionColor: Theme.frameBg
                        onAccepted: { if (text.trim().length > 0) { Wallhaven.addLibrary(text); text = ""; app.sourceMenuOpen = false; } }
                        Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: addInput.text.length === 0; text: "add library:  owner/repo"; color: Theme.faint; font: addInput.font }
                    }
                }
            }
        }
    }

    SettingsPanel {
        anchors.fill: parent
        open: app.settingsOpen
        onClosed: app.settingsOpen = false
    }

    FileDialog {
        id: addDialog
        title: "Add a live wallpaper"
        nameFilters: ["Video (*.mp4 *.webm *.mkv *.mov)"]
        onAccepted: Wallhaven.importLive(selectedFile)
    }

    // confirm before deleting local wallpapers off disk.
    Item {
        id: confirmDelete
        anchors.fill: parent
        property bool open: false
        visible: opacity > 0
        opacity: open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            TapHandler { onTapped: if (!cCardHover.hovered) confirmDelete.open = false }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 380
            height: cCol.implicitHeight + 40
            radius: Theme.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }
            border.width: 1
            border.color: Theme.line
            HoverHandler { id: cCardHover }
            Column {
                id: cCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                spacing: 16
                Text { text: "Delete wallpapers"; color: Theme.bright; font.family: Theme.font; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { width: parent.width; wrapMode: Text.WordWrap; text: "Remove " + Wallhaven.localSelection.length + " wallpaper(s) from disk? This cannot be undone."; color: Theme.dim; font.family: Theme.font; font.pixelSize: 12 }
                Row {
                    anchors.right: parent.right
                    spacing: 10
                    HubButton { label: "Cancel"; onClicked: confirmDelete.open = false }
                    HubButton { primary: true; icon: "trash"; label: "Delete"; onClicked: { Wallhaven.removeLocalSelected(); confirmDelete.open = false; } }
                }
            }
        }
    }

    component SrcRow: Rectangle {
        id: sr
        property string label: ""
        property string sub: ""
        property bool active: false
        property bool removable: false
        signal pick()
        signal remove()
        height: sr.sub.length > 0 ? 40 : 32
        radius: Theme.radius
        color: rowHov.hovered ? Theme.keyTop : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Rectangle { anchors.left: parent.left; anchors.leftMargin: 3; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 14; radius: 1.5; color: Theme.ember; visible: sr.active }
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.right: xbtn.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text { width: parent.width; text: sr.label; color: sr.active ? Theme.ember : Theme.cream; font.family: Theme.font; font.pixelSize: 13; font.weight: Font.Medium; elide: Text.ElideRight }
            Text { width: parent.width; visible: sr.sub.length > 0; text: sr.sub; color: Theme.faint; font.family: Theme.mono; font.pixelSize: 9; elide: Text.ElideRight }
        }
        HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: sr.pick() }
        Rectangle {
            id: xbtn
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 20; radius: 10
            visible: sr.removable && rowHov.hovered
            color: xma.containsMouse ? Qt.alpha(Theme.ember, 0.2) : "transparent"
            Icon { anchors.centerIn: parent; name: "close"; size: 11; tint: xma.containsMouse ? Theme.ember : Theme.faint }
            MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sr.remove() }
        }
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
