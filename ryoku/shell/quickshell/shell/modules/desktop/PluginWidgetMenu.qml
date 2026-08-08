pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import QtQuick.Dialogs
import "Singletons"

// The right-click menu for a plugin desktop tile, built on the shared
// DesktopMenu chrome in the quick-settings sidebar idiom. Beyond Lock + Hide it
// renders the plugin's own settings inline straight from its declared schema
// (manifest.metadata.settings), so a desktop widget is tuned in place without
// opening Settings.
//
// Controls are mouse-only (wallpaper layer = no keyboard):
//   choice -> chips, toggle -> switch, slider -> slider,
//   image  -> thumbnail strip scanned from ~/Pictures + a file chooser.
// Text fields are left to the hub. Each change emits
// settingChanged(id, key, value); the host persists via ryoku-plugins-place
// and the shell retunes live.
Item {
    id: menu

    anchors.fill: parent

    property string scope: ""
    property bool locked: false
    property var manifest: ({})
    property var placement: ({})
    property var vals: ({})         // live settings copy, optimistically updated
    property var pics: []           // scanned ~/Pictures paths for the image picker

    readonly property var schema: (manifest && manifest.metadata && manifest.metadata.settings) || []
    readonly property bool hasImage: schema.some(function (f) { return f.type === "image"; })

    signal hideRequested(string id)
    signal lockToggled(string id)
    signal settingChanged(string id, string key, var value)

    function openFor(id, locked, x, y, manifest, placement) {
        menu.scope = id;
        menu.locked = locked;
        shell.px = x;
        shell.py = y;
        menu.manifest = manifest || ({});
        menu.placement = placement || ({});
        menu.vals = JSON.parse(JSON.stringify((placement && placement.settings) || {}));
        shell.open = true;
        if (menu.hasImage)
            picScan.running = true;
    }
    function close() { shell.open = false; }

    function val(field) {
        return (menu.vals && menu.vals[field.key] !== undefined) ? menu.vals[field.key] : field.default;
    }
    function set(key, value) {
        var n = JSON.parse(JSON.stringify(menu.vals || {}));
        n[key] = value;
        menu.vals = n;
        menu.settingChanged(menu.scope, key, value);
    }

    // scan ~/Pictures (one level deep) for picker thumbnails.
    Process {
        id: picScan
        command: ["bash", "-c",
            "find \"${XDG_PICTURES_DIR:-$HOME/Pictures}\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \\) 2>/dev/null | head -24"]
        stdout: StdioCollector {
            onStreamFinished: menu.pics = text.split("\n").filter(function (l) { return l.trim().length > 0; })
        }
    }

    DesktopMenu {
        id: shell
        title: (menu.manifest && menu.manifest.name) ? menu.manifest.name : menu.scope
        cardWidth: menu.schema.length > 0 ? 300 : 248

        MenuRow {
            label: "Lock"
            value: menu.locked ? "On" : "Off"
            on: menu.locked
            closeOnTrigger: false
            onTriggered: {
                menu.lockToggled(menu.scope);
                menu.locked = !menu.locked;
            }
        }
        MenuRow {
            label: "Hide"
            onTriggered: menu.hideRequested(menu.scope)
        }

        // ── settings, rendered from the plugin's schema ────────────────
        Column {
            visible: menu.schema.length > 0
            width: parent.width
            spacing: 12

            MenuSection {}

            Repeater {
                model: menu.schema

                delegate: Column {
                    id: fieldWrap
                    required property var modelData
                    required property int index
                    width: parent.width
                    spacing: 8

                    readonly property var f: fieldWrap.modelData
                    readonly property string grp: fieldWrap.f.group || ""
                    readonly property bool startsGroup: fieldWrap.index === 0
                        || ((menu.schema[fieldWrap.index - 1].group || "") !== fieldWrap.grp)
                    // no keyboard on the wallpaper layer -- text fields live in the hub.
                    readonly property bool shown: fieldWrap.f.type !== "text"

                    visible: fieldWrap.shown

                    // group eyebrow when this field opens a named group.
                    MenuSection {
                        visible: fieldWrap.startsGroup && fieldWrap.grp.length > 0
                        label: fieldWrap.grp
                    }

                    // choice -> chips
                    Column {
                        visible: fieldWrap.f.type === "choice"
                        width: parent.width
                        spacing: 6
                        Text {
                            text: fieldWrap.f.label || fieldWrap.f.key
                            color: Theme.inkSoft
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        Flow {
                            width: parent.width
                            spacing: 6
                            Repeater {
                                model: fieldWrap.f.options || []
                                delegate: MenuChip {
                                    id: opt
                                    required property var modelData
                                    selected: String(menu.val(fieldWrap.f)) === String(opt.modelData.value)
                                    label: opt.modelData.label
                                    onClicked: menu.set(fieldWrap.f.key, opt.modelData.value)
                                }
                            }
                        }
                    }

                    // toggle -> switch
                    Item {
                        visible: fieldWrap.f.type === "toggle"
                        width: parent.width
                        height: 26
                        Text {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: fieldWrap.f.label || fieldWrap.f.key
                            color: Theme.inkSoft
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        Rectangle {
                            id: sw
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            readonly property bool on: menu.val(fieldWrap.f) === true || menu.val(fieldWrap.f) === "true"
                            width: 42
                            height: 22
                            radius: Theme.radiusTile
                            color: sw.on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) : Theme.tile
                            border.width: 1
                            border.color: sw.on ? Theme.accent : Theme.line
                            Behavior on color { ColorAnimation { duration: Theme.quick } }
                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                y: 3
                                x: sw.on ? parent.width - width - 3 : 3
                                color: sw.on ? Theme.accent : Theme.inkDim
                                Behavior on x { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
                            }
                            TapHandler { onTapped: menu.set(fieldWrap.f.key, !sw.on) }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    // slider -> track + knob, commits on release.
                    Item {
                        id: slRow
                        visible: fieldWrap.f.type === "slider"
                        width: parent.width
                        height: 34
                        readonly property real lo: fieldWrap.f.min !== undefined ? fieldWrap.f.min : 0
                        readonly property real hi: fieldWrap.f.max !== undefined ? fieldWrap.f.max : 1
                        readonly property int dec: fieldWrap.f.decimals !== undefined ? fieldWrap.f.decimals : 2
                        property real live: Number(menu.val(fieldWrap.f))
                        readonly property real frac: slRow.hi > slRow.lo ? Math.max(0, Math.min(1, (slRow.live - slRow.lo) / (slRow.hi - slRow.lo))) : 0
                        Text {
                            id: slLbl
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 70
                            elide: Text.ElideRight
                            text: fieldWrap.f.label || fieldWrap.f.key
                            color: Theme.inkSoft
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        Text {
                            id: slVal
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 40
                            horizontalAlignment: Text.AlignRight
                            text: slRow.live.toFixed(slRow.dec)
                            color: Theme.inkDim
                            font.family: Theme.mono
                            font.pixelSize: 11
                        }
                        Item {
                            id: track
                            anchors { left: slLbl.right; leftMargin: 10; right: slVal.left; rightMargin: 10; verticalCenter: parent.verticalCenter }
                            height: 20
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: Theme.radiusTile
                                color: Theme.tile
                                Rectangle {
                                    width: Math.round(parent.width * slRow.frac)
                                    height: parent.height
                                    radius: Theme.radiusTile
                                    color: Theme.accent
                                }
                            }
                            Rectangle {
                                width: 14
                                height: 14
                                radius: 7
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.round((track.width - width) * slRow.frac)
                                color: Theme.surface
                                border.width: 1
                                border.color: Theme.accent
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                function at(mx) {
                                    var fr = Math.max(0, Math.min(1, mx / track.width));
                                    var v = slRow.lo + fr * (slRow.hi - slRow.lo);
                                    var st = fieldWrap.f.step || 0.01;
                                    return Math.round(v / st) * st;
                                }
                                onPositionChanged: (m) => { if (pressed) slRow.live = at(m.x); }
                                onPressed: (m) => slRow.live = at(m.x)
                                onReleased: menu.set(fieldWrap.f.key, slRow.dec === 0 ? Math.round(slRow.live) : slRow.live)
                            }
                        }
                    }

                    // image -> thumb strip (Default + Browse + ~/Pictures)
                    Column {
                        visible: fieldWrap.f.type === "image"
                        width: parent.width
                        spacing: 6
                        Text {
                            text: fieldWrap.f.label || fieldWrap.f.key
                            color: Theme.inkSoft
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }
                        Flickable {
                            width: parent.width
                            height: 50
                            contentWidth: strip.implicitWidth
                            clip: true
                            interactive: contentWidth > width
                            boundsBehavior: Flickable.StopAtBounds
                            Row {
                                id: strip
                                spacing: 6
                                // "Default" clears the path -> bundled sample.
                                Rectangle {
                                    width: 66
                                    height: 48
                                    radius: Theme.radiusTile
                                    color: Theme.tile
                                    border.width: 1
                                    border.color: String(menu.val(fieldWrap.f)).length === 0 ? Theme.accent : Theme.line
                                    Text {
                                        anchors.centerIn: parent
                                        text: "Default"
                                        color: Theme.inkDim
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                    TapHandler { onTapped: menu.set(fieldWrap.f.key, "") }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                }
                                // "Browse" -> system file chooser (portal).
                                Rectangle {
                                    width: 66
                                    height: 48
                                    radius: Theme.radiusTile
                                    color: brHov.hovered ? Theme.tileHover : Theme.tile
                                    border.width: 1
                                    border.color: brHov.hovered ? Theme.line : Theme.line
                                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "+ Browse"
                                        color: brHov.hovered ? Theme.ink : Theme.inkDim
                                        font.family: Theme.font
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                    }
                                    HoverHandler { id: brHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: imgFileDlg.open() }
                                }
                                Repeater {
                                    model: menu.pics
                                    delegate: Rectangle {
                                        id: thumb
                                        required property var modelData
                                        readonly property bool sel: String(menu.val(fieldWrap.f)) === ("file://" + thumb.modelData)
                                        width: 66
                                        height: 48
                                        radius: Theme.radiusTile
                                        color: Theme.tile
                                        border.width: thumb.sel ? 2 : 1
                                        border.color: thumb.sel ? Theme.accent : Theme.line
                                        clip: true
                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            source: "file://" + thumb.modelData
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            cache: true
                                            sourceSize.width: 132
                                        }
                                        TapHandler { onTapped: menu.set(fieldWrap.f.key, "file://" + thumb.modelData) }
                                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }
                        }
                        FileDialog {
                            id: imgFileDlg
                            title: "Choose an image"
                            nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp)", "All files (*)"]
                            onAccepted: menu.set(fieldWrap.f.key, "" + imgFileDlg.selectedFile)
                        }
                    }
                }
            }
        }
    }
}
