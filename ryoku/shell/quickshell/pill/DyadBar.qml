pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Ryoku.Ui
import "Singletons"

// Dyad: a dual-edge floating-island bar, ported from Jules3182's Waybar dual-bar
// (github.com/Jules3182/dotfiles). Some modules ride the TOP edge and some the
// BOTTOM edge, both at once, forming one bar style; islands float over the
// wallpaper with no continuous band.
//
// Two surfaces, chosen by `ryoku`:
//   faithful (false) -- dark translucent capsules, hairline border (the reference).
//   ryoku    (true)  -- paper-black square chips, bone ink (our language).
//
// Layout (both edges, left / centre / right clusters):
//   top    : [wallpaper][window title]  |  [day][ time ][date]  |  [tools][vpn][bt][vol][power]
//   bottom : [stats][mem][cpu][gpu][net] | [ workspaces (occupied) ] | [media][tray][notif]
//
// Data comes from our own singletons and taps emit popoutRequested so they open
// OUR popouts -- native behaviour, not the source's external scripts. The shell
// mounts this as a full-area overlay and sets `ryoku`; it is otherwise
// self-contained.
Item {
    id: bar

    property real s: 1
    property bool ryoku: false
    property real edgeM: 10 * s
    property real gap: 6 * s
    readonly property real islandH: 30 * s

    // startup cascade: islands fade + pop in once the bar mounts.
    property bool booted: false
    Timer { interval: 10; running: true; onTriggered: bar.booted = true }

    // a module asks the shell to open a popout, growing from the module centre.
    signal popoutRequested(string name, point centre)

    readonly property var loc: Qt.locale("en_US")
    SystemClock { id: clk; precision: SystemClock.Seconds }

    // occupied + active workspaces only (unused stay hidden). Hyprland's live
    // model omits empty non-active workspaces, so they never appear; the active
    // one is always present, and we force it in as a guard.
    readonly property var wsIds: {
        var ids = [];
        var ws = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < ws.length; i++)
            if (ws[i] && ws[i].id > 0) ids.push(ws[i].id);
        var f = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
        if (f > 0 && ids.indexOf(f) < 0) ids.push(f);
        ids.sort(function(a, b) { return a - b; });
        return ids;
    }

    function askPopout(item, name) {
        var c = item.mapToItem(bar, item.width / 2, item.height / 2);
        bar.popoutRequested(name, Qt.point(c.x, c.y));
    }

    // some modules open a hover popout (media transport) rather than pinning one.
    signal hoverPopoutRequested(string name, point centre, bool hovered)
    function askHoverPopout(item, name, hovered) {
        var c = item.mapToItem(bar, item.width / 2, item.height / 2);
        bar.hoverPopoutRequested(name, Qt.point(c.x, c.y), hovered);
    }

    // keep the vitals poller running only while dyad is the shown bar.
    Binding { target: SysStats; property: "active"; value: true; when: bar.visible }

    // bytes/sec -> compact rate (B/K/M/G) for the net island.
    function fmtRate(bps) {
        if (bps < 1024) return Math.round(bps) + "B";
        if (bps < 1048576) return (bps / 1024).toFixed(bps < 10240 ? 1 : 0) + "K";
        if (bps < 1073741824) return (bps / 1048576).toFixed(bps < 10485760 ? 1 : 0) + "M";
        return (bps / 1073741824).toFixed(1) + "G";
    }

    // ---- floating island surface (variant-aware) ------------------------------
    component Island: Item {
        id: isl
        default property alias content: inner.data
        property real padH: 12 * bar.s
        property bool reveal: false
        readonly property alias hovered: islHov.hovered
        implicitWidth: inner.implicitWidth + 2 * padH
        implicitHeight: bar.islandH
        opacity: reveal ? 1 : 0
        scale: reveal ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Motion.emphasized; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Motion.emphasized; easing.type: Easing.OutExpo } }
        Timer { interval: 60; running: bar.booted; onTriggered: isl.reveal = true }
        Rectangle {
            anchors.fill: parent
            radius: bar.ryoku ? 6 * bar.s : height / 2
            color: bar.ryoku ? Theme.paper : Qt.rgba(0.08, 0.08, 0.08, 0.62)
            border.width: 1
            border.color: bar.ryoku ? Theme.border : Qt.rgba(1, 1, 1, 0.08)
            clip: bar.ryoku
            Grain { anchors.fill: parent; anchors.margins: 1; visible: bar.ryoku }
        }
        Row { id: inner; anchors.centerIn: parent; spacing: 6 * bar.s }
        HoverHandler { id: islHov }
    }

    // ---- circular / square icon chip (a tap target) ---------------------------
    component Chip: Item {
        id: chip
        property string sym: ""
        property real px: 15 * bar.s
        property color tint: Theme.cream
        property string glyph: ""
        signal tapped()
        implicitWidth: bar.islandH
        implicitHeight: bar.islandH
        property bool reveal: false
        opacity: reveal ? 1 : 0
        scale: reveal ? 1 : 0.9
        Behavior on opacity { NumberAnimation { duration: Motion.emphasized; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Motion.emphasized; easing.type: Easing.OutExpo } }
        Timer { interval: 60; running: bar.booted; onTriggered: chip.reveal = true }
        Rectangle {
            anchors.fill: parent
            radius: bar.ryoku ? 6 * bar.s : height / 2
            color: chipHov.hovered ? (bar.ryoku ? Theme.cardBot : Qt.rgba(0.10, 0.10, 0.10, 0.78))
                                   : (bar.ryoku ? Theme.paper : Qt.rgba(0.08, 0.08, 0.08, 0.62))
            border.width: 1
            border.color: bar.ryoku ? Theme.border : Qt.rgba(1, 1, 1, 0.08)
            clip: bar.ryoku
            Grain { anchors.fill: parent; anchors.margins: 1; visible: bar.ryoku }
            Behavior on color { ColorAnimation { duration: Motion.hover } }
        }
        MaterialIcon {
            visible: chip.glyph === ""
            anchors.centerIn: parent
            text: chip.sym
            color: chip.tint
            font.pixelSize: chip.px
            scale: chipHov.hovered ? 1.12 : 1.0
            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutExpo } }
        }
        Text {
            visible: chip.glyph !== ""
            anchors.centerIn: parent
            text: chip.glyph
            color: chip.tint
            font.family: Theme.fontJp
            font.pixelSize: chip.px
            scale: chipHov.hovered ? 1.12 : 1.0
            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutExpo } }
        }
        HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.tapped() }
    }

    // shared mono/proportional data text.
    component DataText: Text {
        color: Theme.cream
        font.family: bar.ryoku ? Theme.font : Theme.mono
        font.pixelSize: 12 * bar.s
        font.features: ({ "tnum": 1 })
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    }

    // ============================ TOP EDGE =====================================
    Row {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: bar.edgeM
        anchors.leftMargin: bar.edgeM
        spacing: bar.gap
        Chip { glyph: "力"; tint: Theme.brand; px: 16 * bar.s; onTapped: Quickshell.execDetached(["ryoku-shell", "launcher"]) }
        Island {
            DataText {
                text: (Hyprland.activeToplevel && Hyprland.activeToplevel.lastIpcObject
                       && Hyprland.activeToplevel.lastIpcObject.title) || "Desktop"
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 320 * bar.s)
            }
        }
    }

    Row {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: bar.edgeM
        spacing: bar.gap
        Island { DataText { text: bar.loc.toString(clk.date, "ddd") } }
        Island {
            padH: 14 * bar.s
            DataText {
                text: Qt.formatTime(clk.date, "HH:mm:ss")
                color: Theme.bright
                font.weight: Font.DemiBold
            }
        }
        Island { DataText { text: bar.loc.toString(clk.date, "d/M") } }
    }

    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: bar.edgeM
        anchors.rightMargin: bar.edgeM
        spacing: bar.gap
        Island {
            padH: 5 * bar.s
            Chip { sym: "calendar_month"; implicitWidth: bar.islandH - 8 * bar.s; px: 13 * bar.s; onTapped: bar.askPopout(this, "calendar") }
            Chip { sym: "content_paste"; implicitWidth: bar.islandH - 8 * bar.s; px: 13 * bar.s; onTapped: bar.askPopout(this, "clipboard") }
            Chip { sym: "partly_cloudy_day"; implicitWidth: bar.islandH - 8 * bar.s; px: 13 * bar.s; onTapped: bar.askPopout(this, "weather") }
        }
        Chip { sym: "vpn_key_off"; tint: Theme.dim; onTapped: bar.askPopout(this, "network") }
        Chip { sym: "bluetooth"; onTapped: bar.askPopout(this, "bluetooth") }
        Island {
            id: volIsl
            padH: 10 * bar.s
            MaterialIcon { anchors.verticalCenter: parent.verticalCenter; text: "volume_up"; color: Theme.cream; font.pixelSize: 14 * bar.s }
            DataText { text: Audio.sink ? Math.round(Audio.sink.audio.volume * 100) + "%" : "--" }
            TapHandler { onTapped: bar.askPopout(volIsl, "mixer") }
        }
        Chip { sym: "power_settings_new"; px: 18 * bar.s; onTapped: Quickshell.execDetached(["ryoku-shell", "power"]) }
    }

    // ============================ BOTTOM EDGE ==================================
    Row {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: bar.edgeM
        anchors.leftMargin: bar.edgeM
        spacing: bar.gap
        Chip { sym: "monitoring"; onTapped: bar.askPopout(this, "resources") }
        Island { DataText { text: "MEM " + SysStats.mem + "%" } }
        Island { DataText { text: "CPU " + SysStats.cpu + "%" } }
        Island { visible: SysStats.gpuAvailable; DataText { text: "GPU " + SysStats.gpu + "%" } }
        Island { DataText { text: "\u2193" + bar.fmtRate(SysStats.netDown) + "  \u2191" + bar.fmtRate(SysStats.netUp) } }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: bar.edgeM
        Island {
            padH: 8 * bar.s
            Row {
                spacing: 2 * bar.s
                Repeater {
                    model: bar.wsIds
                    delegate: Item {
                        id: wsSlot
                        required property var modelData
                        readonly property int wsId: wsSlot.modelData
                        readonly property bool onWs: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsSlot.wsId
                        width: (wsSlot.onWs ? 40 : 22) * bar.s
                        height: bar.islandH - 10 * bar.s
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on width { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutExpo } }
                        Rectangle {
                            anchors.fill: parent
                            radius: bar.ryoku ? 4 * bar.s : height / 2
                            color: wsSlot.onWs ? Theme.bright : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: wsSlot.wsId
                            color: wsSlot.onWs ? Theme.paper : Theme.dim
                            font.family: bar.ryoku ? Theme.font : Theme.mono
                            font.pixelSize: 11 * bar.s
                            font.features: ({ "tnum": 1 })
                        }
                        TapHandler { onTapped: Hyprland.dispatch("workspace " + wsSlot.wsId) }
                    }
                }
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.bottomMargin: bar.edgeM
        anchors.rightMargin: bar.edgeM
        spacing: bar.gap
        Island {
            id: mediaIsl
            onHoveredChanged: bar.askHoverPopout(mediaIsl, "media", hovered)
            DataText {
                text: Media.player ? (Media.player.trackTitle || "Nothing playing") : "No media"
                color: Media.playing ? Theme.cream : Theme.dim
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 220 * bar.s)
            }
        }
        Chip { sym: "notifications"; onTapped: bar.askPopout(this, "inbox") }
    }
}
