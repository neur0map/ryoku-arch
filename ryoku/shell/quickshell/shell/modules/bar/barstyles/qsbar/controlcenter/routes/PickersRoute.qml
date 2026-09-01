import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../kit"
import "../../modules"
import Ryoku.Ui
import Ryoku.Ui.Singletons
import shell.services as Services

// Pickers route on the house Ryoku.Ui kit: choose the media/image browser layout
// the next wallpaper/screenshot picker opens in. The style writes straight to
// root.pickerStyle. Three selectable cards, each a small schematic of its layout:
//   tanzaku     = two columns
//   hearthstone = single wide column
//   carousel    = a centered row of thumbs
Item {
    id: page
    property var root: null
    property var cc: null
    readonly property var tk: page.cc ? page.cc.tokens : null

    readonly property real colW: Math.min(page.width, page.tk ? page.tk.contentW : 640)
    implicitHeight: col.implicitHeight

    readonly property var pickers: [
        { key: "tanzaku", label: "Tanzaku", sub: "Two columns" },
        { key: "hearthstone", label: "Hearthstone", sub: "Single column" },
        { key: "carousel", label: "Carousel", sub: "Thumb row" }
    ]

    // Aim the wallpaper switcher at a screen ("*" = all, else a connector) then
    // open it, mirroring SystemRoute. ShellState reads and clears the target on open.
    function openSwitcher(target) {
        Services.ShellState.wallpaperSwitcherTarget = target;
        const st = Services.ShellState.forActive();
        if (st)
            st.wallpaperSwitcherOpen = true;
        if (page.cc)
            page.cc.close();
    }

    // ── wallpaper reveal preference ──────────────────────────────────────────
    // The animation the desktop plays on a wallpaper switch. The daemon owns 22
    // named reveals plus the "random" sentinel (a fresh no-repeat pick per
    // switch, the default), keyed as wallpaper.transition_preset in shell.json.
    // Read and written over the same settings.patch seam MenuTheme uses, because
    // this key lives in the daemon's schema, not the qsbar Theme store the rest
    // of this route writes. The list is the daemon's table (transitions.go).
    readonly property var revealOptions: [
        "random",
        "silk_fade", "diagonal_silk", "dream_curtain", "liquid_ribbon",
        "iris_open", "corner_bloom", "spotlight_rise", "wander_iris", "vignette_close",
        "celeste_veil", "comet_streak", "aurora_ripple", "starfall_bloom",
        "mosaic_swell", "ember_burn", "pond_wake", "glass_scatter", "signal_tear",
        "cathode_wink", "shutter_sweep", "wax_descent", "page_turn"
    ]
    property string reveal: "random"
    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"
    function setReveal(k) {
        if (!k)
            return;
        page.reveal = k;   // optimistic, so the mark tracks the tap before the frame returns
        ctl.queued += "call settings.patch " + JSON.stringify({ path: "wallpaper.transition_preset", value: k }) + "\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
    }

    // Read the applied preset from the daemon (one-way) so the mark reflects real
    // state; parse defensively so an unexpected frame leaves the optimistic value.
    Socket {
        id: sub
        path: page.sockPath
        parser: SplitParser {
            onRead: line => {
                try {
                    const frame = JSON.parse(line);
                    if (frame && frame.wallpaper && typeof frame.wallpaper.transition_preset === "string" && frame.wallpaper.transition_preset !== "")
                        page.reveal = frame.wallpaper.transition_preset;
                } catch (e) {
                }
            }
        }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe settings\n");
                flush();
            } else {
                retry.restart();
            }
        }
    }
    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected) sub.connected = true
    }
    Socket {
        id: ctl
        path: page.sockPath
        property string queued: ""
        function flushQueued() {
            if (queued.length === 0)
                return;
            write(queued);
            flush();
            queued = "";
        }
        onConnectionStateChanged: if (connected) flushQueued()
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: page.colW
            spacing: page.tk ? page.tk.sectionGap : 16

            // ── STYLE ──
            Entrance {
                width: page.colW
                index: 0
                SettingCard {
                    width: page.colW
                    title: I18n.tr("STYLE")
                    kana: "\u9078"

                    // The cards fill the content column evenly: thirds of the inset
                    // width, not a fixed width stranded in an empty row. Bespoke
                    // schematic content, so it stays on page.tk; only the container is
                    // the house kit, and the body keeps a row's own inset.
                    Item {
                    width: parent.width
                        height: styleRow.height + (page.tk ? page.tk.gap * 2 : 24)

                        Row {
                            id: styleRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: page.tk ? page.tk.gap : 12
                            anchors.rightMargin: page.tk ? page.tk.gap : 12
                            spacing: page.tk ? page.tk.colGap : 16

                            Repeater {
                                model: page.pickers
                                delegate: PickerCard {
                                    required property var modelData
                                width: (styleRow.width - (page.tk ? page.tk.colGap * 2 : 32)) / 3
                                    item: modelData
                                }
                            }
                        }
                    }
                }
            }

            // ── REVEAL ──
            // How the desktop switches wallpapers. 23 options (the "random"
            // sentinel plus 22 named reveals) is a catalogue, so the control is
            // the house Picker inset into the card, not a segmented bar. It writes
            // wallpaper.transition_preset and takes effect on the next switch.
            Entrance {
                width: page.colW
                index: 1
                SettingCard {
                    width: page.colW
                    title: I18n.tr("REVEAL")
                    kana: "\u5e55"

                    Item {
                        width: parent.width
                        height: revealPicker.height + (page.tk ? page.tk.gap * 2 : 24)

                        Picker {
                            id: revealPicker
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: page.tk ? page.tk.gap : 12
                            anchors.rightMargin: page.tk ? page.tk.gap : 12
                            anchors.verticalCenter: parent.verticalCenter
                            height: 300
                            title: I18n.tr("WALLPAPER REVEAL")
                            options: page.revealOptions
                            current: page.reveal
                            onChose: (k) => page.setReveal(k)
                        }
                    }
                }
            }

            // ── DISPLAYS ──
            // Per-monitor wallpaper: each row aims the switcher at one screen, All
            // at every one. Hidden on a single-head machine where the choice is moot.
            Entrance {
                width: page.colW
                index: 2
                visible: Hyprland.monitors.values.length > 1
                SettingCard {
                    width: page.colW
                    title: I18n.tr("DISPLAYS")
                    kana: "\u753b"

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        controlWidth: 90
                        label: I18n.tr("All screens")
                        desc: I18n.tr("Set every display at once.")
                        Btn {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            compact: true
                            text: I18n.tr("SET")
                            onAct: page.openSwitcher("*")
                        }
                    }
                    Repeater {
                        model: Hyprland.monitors
                        delegate: SettingRow {
                            id: monRow
                            required property var modelData
                            anchors.left: parent.left
                            anchors.right: parent.right
                            divider: true
                            controlWidth: 90
                            label: monRow.modelData.name
                            desc: monRow.modelData.width + "\u00d7" + monRow.modelData.height
                            Btn {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                compact: true
                                text: I18n.tr("SET")
                                onAct: page.openSwitcher(monRow.modelData.name)
                            }
                        }
                    }
                }
            }
        }
    }

    // ── a selectable style card with a schematic layout preview ──
    component PickerCard: Rectangle {
        id: cardRoot
        property var item: ({})
        readonly property string key: item.key || ""
        readonly property bool sel: page.root ? page.root.pickerStyle === cardRoot.key : false
        readonly property bool hovered: ma.containsMouse

        // The schematic stays a neutral ink diagram; selection is inversion, a
        // bone frame + corner tag, never a tint. Diagram colours are held here so
        // the panels keep contrast when the card fills on hover.
        readonly property color panelFill: page.tk ? Tokens.tint10 : "#1e1e1e"
        readonly property color panelLine: page.tk ? Tokens.line : "#333333"
        readonly property color slat: page.tk ? Tokens.inkMuted : "#958f87"

        readonly property int schematicH: page.tk ? page.tk.rowH + page.tk.eyebrowH : 64

        height: cardRoot.schematicH + (page.tk ? page.tk.rowH + page.tk.gap : 52)
        radius: page.tk ? Tokens.radius : 6
        color: cardRoot.hovered ? (page.tk ? Tokens.tint5 : "#141414") : "transparent"
        border.width: cardRoot.sel ? 2 : 1
        border.color: cardRoot.sel ? (page.tk ? Tokens.bone : "#cdc4ba")
                                   : (page.tk ? Tokens.line : "#333333")
        Behavior on color { ColorAnimation { duration: page.tk ? Tokens.snap : 90 } }
        Behavior on border.color { ColorAnimation { duration: page.tk ? Tokens.snap : 90 } }

        // ── schematic preview ──
        Item {
            id: schematic
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: page.tk ? page.tk.gap : 12 }
            height: cardRoot.schematicH

            // tanzaku: two columns of stacked slats
            Row {
                visible: cardRoot.key === "tanzaku"
                anchors.fill: parent
                spacing: 8
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        width: (schematic.width - 8) / 2
                        height: schematic.height
                        radius: 4
                        color: cardRoot.panelFill
                        border.width: 1
                        border.color: cardRoot.panelLine
                        Column {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 5
                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    width: parent.width; height: 4; radius: 2
                                    color: cardRoot.slat
                                }
                            }
                        }
                    }
                }
            }

            // hearthstone: one wide centered column, header + rows
            Rectangle {
                visible: cardRoot.key === "hearthstone"
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: schematic.width * 0.62
                height: schematic.height
                radius: 4
                color: cardRoot.panelFill
                border.width: 1
                border.color: cardRoot.panelLine
                Column {
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 6
                    Rectangle {                       // header
                        width: parent.width; height: 12; radius: 2
                        color: cardRoot.slat
                    }
                    Repeater {
                        model: 3
                        delegate: Rectangle {
                            width: parent.width; height: 6; radius: 2
                            color: cardRoot.panelLine
                        }
                    }
                }
            }

            // carousel: a centered row of thumbs, middle one emphasized
            Row {
                visible: cardRoot.key === "carousel"
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: 5
                    delegate: Rectangle {
                        required property int index
                        readonly property bool mid: index === 2
                        width: mid ? 30 : 18
                        height: mid ? 46 : 34
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: mid ? cardRoot.panelFill : (page.tk ? Tokens.tint5 : "#141414")
                        border.width: 1
                        border.color: mid ? cardRoot.panelLine : (page.tk ? Tokens.lineSoft : "#222222")
                    }
                }
            }
        }

        // ── label + sub ──
        Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: page.tk ? page.tk.gap : 12 }
            spacing: 1
            UiText {
                text: cardRoot.item.label || ""
                color: page.tk ? Tokens.ink : "#cdc4ba"
                font.family: page.tk ? Tokens.mono : "monospace"
                font.pixelSize: page.tk ? Tokens.fSmall : 13
            }
            UiText {
                text: cardRoot.item.sub || ""
                color: page.tk ? Tokens.inkFaint : "#7a756e"
                font.family: page.tk ? Tokens.mono : "monospace"
                font.pixelSize: page.tk ? Tokens.fTiny : 9
            }
        }

        // ── selected: a bone corner tag ──
        Rectangle {
            visible: cardRoot.sel
            anchors.right: parent.right
            anchors.top: parent.top
            width: page.tk ? Tokens.ctlH : 26
            height: page.tk ? page.tk.eyebrowH : 24
            topRightRadius: page.tk ? Tokens.radius : 6
            bottomLeftRadius: page.tk ? Tokens.radius : 6
            color: page.tk ? Tokens.bone : "#cdc4ba"
            IconText {
                anchors.centerIn: parent
                text: "check"
                color: page.tk ? Tokens.inkOnBone : "#000000"
                font.pixelSize: page.tk ? Tokens.fSmall : 13
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (page.root) page.root.pickerStyle = cardRoot.key
        }
    }

    CcScrollRail { root: page.root; tk: page.tk; flick: flick; z: 5 }
}
