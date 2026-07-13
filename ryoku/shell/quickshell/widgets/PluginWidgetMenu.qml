pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Io
import QtQuick.Dialogs
import Ryoku.PluginKit.Singletons

// right-click menu for a plugin desktop tile, carbon-dossier idiom (力
// masthead, corner ticks, hairline rules, mono uppercase rows). beyond
// Lock + Hide it renders the plugin's own settings inline straight from
// its declared schema (manifest.metadata.settings), so a desktop widget
// is tuned in place without opening Settings.
//
// controls are mouse-only (wallpaper layer = no keyboard):
//   choice -> chips, toggle -> switch, slider -> slider,
//   image  -> thumbnail strip scanned from ~/Pictures.
// text fields are left to the hub. each change emits
// settingChanged(id, key, value); host persists via ryoku-plugins-place
// and the shell retunes live.
Item {
    id: menu

    anchors.fill: parent
    visible: menu.open

    property bool open: false
    property string scope: ""
    property bool locked: false
    property real px: 0
    property real py: 0
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
        menu.px = x;
        menu.py = y;
        menu.manifest = manifest || ({});
        menu.placement = placement || ({});
        menu.vals = JSON.parse(JSON.stringify((placement && placement.settings) || {}));
        menu.open = true;
        if (menu.hasImage)
            picScan.running = true;
    }
    function close() { menu.open = false; }

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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: menu.close()
    }

    MultiEffect {
        source: panel
        anchors.fill: panel
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.6)
        shadowBlur: 1.0
        shadowVerticalOffset: 10
        blurMax: 48
        autoPaddingEnabled: true
    }

    Rectangle {
        id: panel
        x: Math.max(8, Math.min(menu.px, menu.width - width - 8))
        y: Math.max(8, Math.min(menu.py, menu.height - height - 8))
        width: menu.schema.length > 0 ? 300 : 234
        height: Math.min(col.implicitHeight + 28, menu.height - 16)
        radius: Theme.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.cardTop }
            GradientStop { position: 1.0; color: Theme.cardBot }
        }
        border.width: 1
        border.color: Theme.hair

        transformOrigin: Item.TopLeft
        scale: menu.open ? 1 : 0.95
        opacity: menu.open ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 130 } }

        Item {
            anchors.fill: parent
            anchors.margins: 7
            property color tint: Theme.hair
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 9; height: 1; color: parent.tint }
            Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1; height: 9; color: parent.tint }
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 9; height: 1; color: parent.tint }
            Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: 9; color: parent.tint }
            Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 9; height: 1; color: parent.tint }
            Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 1; height: 9; color: parent.tint }
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 9; height: 1; color: parent.tint }
            Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 1; height: 9; color: parent.tint }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 14
            contentHeight: col.implicitHeight
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col
                width: parent.width
                spacing: 0

                // masthead: 力 + scope (plugin id).
                Item {
                    width: parent.width
                    height: 26
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        BrandMark {
                            anchors.verticalCenter: parent.verticalCenter
                            size: 16
                            color: Theme.brand
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (menu.manifest && menu.manifest.name ? menu.manifest.name : menu.scope).toUpperCase()
                            color: Theme.subtle
                            font.family: Theme.mono
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2.4
                        }
                    }
                }

                Rule {}

                MenuRow {
                    k: "Lock"
                    v: menu.locked ? "On" : "Off"
                    on: menu.locked
                    closeOnTrigger: false
                    onTriggered: {
                        menu.lockToggled(menu.scope);
                        menu.locked = !menu.locked;
                    }
                }

                Rule {}

                MenuRow {
                    k: "Hide"
                    onTriggered: menu.hideRequested(menu.scope)
                }

                // -- settings, rendered from the plugin's schema --------------
                Item { width: parent.width; height: menu.schema.length > 0 ? 6 : 0 }

                Repeater {
                    model: menu.schema

                    delegate: Column {
                        id: fieldWrap
                        required property var modelData
                        required property int index
                        width: col.width
                        spacing: 8
                        readonly property var f: fieldWrap.modelData
                        readonly property string grp: fieldWrap.f.group || ""
                        readonly property bool startsGroup: fieldWrap.index === 0
                            || ((menu.schema[fieldWrap.index - 1].group || "") !== fieldWrap.grp)
                        // no keyboard on wallpaper layer -- text fields live in the hub.
                        readonly property bool shown: fieldWrap.f.type !== "text"

                        visible: fieldWrap.shown
                        topPadding: fieldWrap.startsGroup && fieldWrap.shown ? 6 : 0

                        // group eyebrow: vermilion dot + mono label.
                        Row {
                            visible: fieldWrap.startsGroup && fieldWrap.grp.length > 0 && fieldWrap.shown
                            spacing: 7
                            Rectangle { width: 5; height: 5; radius: Theme.radius; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: fieldWrap.grp
                                color: Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: 9
                                font.weight: Font.DemiBold
                                font.letterSpacing: 2
                                font.capitalization: Font.AllUppercase
                            }
                        }

                        // choice -> chips
                        Column {
                            visible: fieldWrap.f.type === "choice"
                            width: parent.width
                            spacing: 6
                            Text {
                                text: fieldWrap.f.label || fieldWrap.f.key
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            Flow {
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: fieldWrap.f.options || []
                                    delegate: Rectangle {
                                        id: chip
                                        required property var modelData
                                        readonly property bool sel: String(menu.val(fieldWrap.f)) === String(chip.modelData.value)
                                        width: chipT.implicitWidth + 18
                                        height: 24
                                        radius: Theme.radius
                                        color: chip.sel ? Theme.brand : Theme.tileBg
                                        border.width: 1
                                        border.color: chip.sel ? Theme.brand : Theme.border
                                        Behavior on color { ColorAnimation { duration: 90 } }
                                        Text {
                                            id: chipT
                                            anchors.centerIn: parent
                                            text: chip.modelData.label
                                            color: chip.sel ? Theme.cardBot : Theme.subtle
                                            font.family: Theme.font
                                            font.pixelSize: 11
                                            font.weight: chip.sel ? Font.DemiBold : Font.Medium
                                        }
                                        TapHandler { onTapped: menu.set(fieldWrap.f.key, chip.modelData.value) }
                                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }
                        }

                        // toggle -> switch
                        Item {
                            visible: fieldWrap.f.type === "toggle"
                            width: parent.width
                            height: 24
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: fieldWrap.f.label || fieldWrap.f.key
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            Rectangle {
                                id: sw
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property bool on: menu.val(fieldWrap.f) === true || menu.val(fieldWrap.f) === "true"
                                width: 38
                                height: 20
                                radius: Theme.radius
                                color: sw.on ? Theme.brand : Theme.tileBg
                                border.width: 1
                                border.color: sw.on ? Theme.brand : Theme.border
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Rectangle {
                                    width: 14
                                    height: 14
                                    radius: Theme.radius
                                    y: 3
                                    x: sw.on ? parent.width - width - 3 : 3
                                    color: sw.on ? Theme.cardBot : Theme.cream
                                    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
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
                            readonly property real frac: hi > lo ? Math.max(0, Math.min(1, (live - lo) / (hi - lo))) : 0
                            Text {
                                id: slLbl
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 70
                                elide: Text.ElideRight
                                text: fieldWrap.f.label || fieldWrap.f.key
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.weight: Font.Medium
                            }
                            Text {
                                id: slVal
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 38
                                horizontalAlignment: Text.AlignRight
                                text: slRow.live.toFixed(slRow.dec)
                                color: Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: 10
                            }
                            Item {
                                id: track
                                anchors.left: slLbl.right
                                anchors.leftMargin: 10
                                anchors.right: slVal.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 20
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 4
                                    radius: Theme.radius
                                    color: Theme.tileBg
                                    Rectangle {
                                        width: Math.round(parent.width * slRow.frac)
                                        height: parent.height
                                        radius: Theme.radius
                                        color: Theme.brand
                                    }
                                }
                                Rectangle {
                                    width: 13
                                    height: 13
                                    radius: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.round((track.width - width) * slRow.frac)
                                    color: Theme.cream
                                    border.width: 1
                                    border.color: Theme.brand
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

                        // image -> thumb strip (Default + ~/Pictures)
                        Column {
                            visible: fieldWrap.f.type === "image"
                            width: parent.width
                            spacing: 6
                            Text {
                                text: fieldWrap.f.label || fieldWrap.f.key
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 12
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
                                        radius: Theme.radius
                                        color: Theme.tileBg
                                        border.width: 1
                                        border.color: String(menu.val(fieldWrap.f)).length === 0 ? Theme.brand : Theme.border
                                        Text {
                                            anchors.centerIn: parent
                                            text: "Default"
                                            color: Theme.subtle
                                            font.family: Theme.mono
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                        }
                                        TapHandler { onTapped: menu.set(fieldWrap.f.key, "") }
                                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    }
                                    // "Browse" -> system file chooser (portal).
                                    Rectangle {
                                        width: 66
                                        height: 48
                                        radius: Theme.radius
                                        color: brHov.hovered ? Qt.rgba(Theme.brand.r, Theme.brand.g, Theme.brand.b, 0.12) : Theme.tileBg
                                        border.width: 1
                                        border.color: brHov.hovered ? Theme.brand : Theme.border
                                        Behavior on color { ColorAnimation { duration: 90 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "+ Browse"
                                            color: brHov.hovered ? Theme.cream : Theme.subtle
                                            font.family: Theme.mono
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
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
                                            radius: Theme.radius
                                            color: Theme.tileBg
                                            border.width: thumb.sel ? 2 : 1
                                            border.color: thumb.sel ? Theme.brand : Theme.border
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

    component Rule: Item {
        width: parent ? parent.width : 0
        height: 11
        Rectangle { anchors.centerIn: parent; width: parent.width; height: 1; color: Theme.hair }
    }

    component MenuRow: Item {
        id: mi
        property string k: ""
        property string v: ""
        property bool on: false
        property bool accent: false
        property bool closeOnTrigger: true
        signal triggered()

        width: parent ? parent.width : 0
        height: 30

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            radius: Theme.radius
            color: miMa.containsMouse ? Qt.rgba(Theme.brand.r, Theme.brand.g, Theme.brand.b, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: -6
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 14
            radius: Theme.radius
            color: Theme.brand
            opacity: miMa.containsMouse ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: mi.k
            color: mi.accent ? Theme.brand : (miMa.containsMouse ? Theme.cream : Theme.subtle)
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.6
            font.capitalization: Font.AllUppercase
            Behavior on color { ColorAnimation { duration: 90 } }
        }
        Text {
            visible: mi.v.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: mi.v
            color: mi.on ? Theme.brand : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        MouseArea {
            id: miMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                mi.triggered();
                if (mi.closeOnTrigger)
                    menu.close();
            }
        }
    }
}
