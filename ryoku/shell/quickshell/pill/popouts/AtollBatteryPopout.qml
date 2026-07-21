pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import ".."
import "../Singletons"

// atoll battery popout content, ported from ilyamiro's BatteryPopup: a hero
// battery RING (percent + charge state) over brightness / volume faders, a
// session-action row (lock / sleep / restart / power), and a Perform / Balance
// / Saver power-profile toggle. transparent Item, the frame blob behind it IS
// the surface, so the outer window fill is dropped and only the inner content
// is drawn (ilyamiro's cards flattened to Ryoku's bone-on-black). the arc is
// bone; vermilion is spent only on a genuine low-battery alert and the heat
// fill of the two destructive holds. live probes (brightnessctl, powerprofilesctl)
// are gated on `open` so a closed panel costs nothing.
Item {
    id: root

    property real s: 1
    property bool open: false

    anchors.fill: parent

    implicitWidth: 300 * s
    implicitHeight: body.implicitHeight + 36 * s

    // ── battery readout (from the Battery singleton) ───────────────────────
    readonly property bool low: Battery.low
    // arc counts up with the number: a shadow of Battery.frac eased so a jump
    // in reading sweeps the ring instead of snapping.
    property real animFrac: Battery.frac
    Behavior on animFrac { NumberAnimation { duration: Motion.spatial; easing.type: Easing.OutCubic } }
    onAnimFracChanged: ring.requestPaint()
    onLowChanged: ring.requestPaint()

    // charge state as an uppercase eyebrow: the CHARGING / NOT CHARGING line
    // ilyamiro shows under the percent, honestly widened for AC-full and drain.
    readonly property string stateText: Battery.charging ? "CHARGING"
        : (Battery.full ? "FULLY CHARGED"
        : (Battery.discharging ? "DISCHARGING" : "NOT CHARGING"))

    // ── brightness (brightnessctl via Process; no laptop-brightness singleton
    // exists, Devices.qml owns external ddcutil monitors only) ──────────────
    property real briFrac: 0
    property bool briAvailable: true
    readonly property bool briDragging: briSlider.dragging

    Process {
        id: briRead
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{print substr($4,1,length($4)-1)}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = parseInt(this.text.trim());
                if (!isNaN(v) && !root.briDragging)
                    root.briFrac = Math.max(0, Math.min(1, v / 100));
            }
        }
        onExited: (code) => { if (code !== 0) root.briAvailable = false; }
    }

    // throttle the writes so a drag never floods brightnessctl (ilyamiro idiom).
    Timer {
        id: briWrite
        interval: 40
        property int pct: -1
        onTriggered: {
            if (briWrite.pct >= 0) {
                Quickshell.execDetached(["brightnessctl", "set", briWrite.pct + "%"]);
                briWrite.pct = -1;
            }
        }
    }

    // catch keyboard brightness keys while the panel is open; re-read on open.
    Timer {
        interval: 1500
        running: root.open && root.briAvailable
        repeat: true
        triggeredOnStart: true
        onTriggered: briRead.running = true
    }

    // ── power profiles (powerprofilesctl; hidden until a get succeeds) ──────
    property string profile: ""
    property bool profilesAvailable: false
    readonly property int profIndex: root.profile === "performance" ? 0
        : (root.profile === "balanced" ? 1
        : (root.profile === "power-saver" ? 2 : -1))

    readonly property var profiles: [
        { name: "performance", glyph: "speed",   label: "Perform" },
        { name: "balanced",    glyph: "balance", label: "Balance" },
        { name: "power-saver", glyph: "eco",     label: "Saver" }
    ]

    Process {
        id: profRead
        command: ["bash", "-c", "powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim();
                if (t.length) {
                    root.profile = t;
                    root.profilesAvailable = true;
                }
            }
        }
    }

    function setProfile(name) {
        Quickshell.execDetached(["powerprofilesctl", "set", name]);
        root.profile = name;
        profRead.running = true;
    }

    // ── session actions, dispatched exactly like Ryoku's PowerSurface ──────
    readonly property var sessions: [
        { key: "lock",    glyph: "lock",                label: "Lock",    danger: false, argv: ["ryoku-shell", "lock"] },
        { key: "sleep",   glyph: "bedtime",             label: "Sleep",   danger: false, argv: ["systemctl", "suspend"] },
        { key: "restart", glyph: "restart_alt",         label: "Restart", danger: true,  argv: ["systemctl", "reboot"] },
        { key: "power",   glyph: "power_settings_new",  label: "Power",   danger: true,  argv: ["systemctl", "poweroff"] }
    ]

    function dispatch(a) { Quickshell.execDetached(a.argv); }

    // profiles have no poll (they change only on a set), so read them on open;
    // brightness reads via its own poll timer's triggeredOnStart.
    onOpenChanged: if (open) profRead.running = true

    // one horizontal fader: bone fill over a tile track, drag to set. `active`
    // greys it out (brightness with no backend). reports the 0..1 target up.
    component Fader: Item {
        id: fader
        property real value: 0
        property bool active: true
        property alias dragging: dragMa.dragging
        signal moved(real v)

        height: 20 * root.s

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.tileBg
            border.width: 1
            border.color: Theme.hair
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(parent.width * Math.max(0, Math.min(1, fader.value)))
                height: parent.height
                radius: parent.radius
                color: fader.active ? Theme.bright : Theme.dim
                Behavior on width { enabled: !fader.dragging; NumberAnimation { duration: Motion.effects; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }

        MouseArea {
            id: dragMa
            anchors.fill: parent
            property bool dragging: false
            enabled: fader.active
            hoverEnabled: true
            cursorShape: fader.active ? Qt.PointingHandCursor : Qt.ArrowCursor
            preventStealing: true
            function frac(x) { return Math.max(0, Math.min(1, x / width)); }
            onPressed: (m) => { dragMa.dragging = true; fader.moved(dragMa.frac(m.x)); }
            onPositionChanged: (m) => { if (dragMa.dragging) fader.moved(dragMa.frac(m.x)); }
            onReleased: dragMa.dragging = false
            onCanceled: dragMa.dragging = false
        }
    }

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 18 * root.s
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        spacing: 16 * root.s

        // ── hero ring ──────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 186 * root.s

            Canvas {
                id: ring
                width: 186 * root.s
                height: width
                anchors.horizontalCenter: parent.horizontalCenter

                onWidthChanged: requestPaint()
                Component.onCompleted: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var cx = width / 2;
                    var cy = height / 2;
                    var r = (width / 2) - 14 * root.s;
                    var lw = 12 * root.s;
                    ctx.lineCap = "round";

                    // faint bone track for the full circle.
                    ctx.lineWidth = lw;
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.strokeStyle = Qt.alpha(Theme.bright, 0.10);
                    ctx.stroke();

                    // charge arc from 12 o'clock, bone (vermilion only on a low alert).
                    if (root.animFrac > 0.001) {
                        var start = -Math.PI / 2;
                        var end = start + root.animFrac * 2 * Math.PI;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, start, end);
                        ctx.strokeStyle = root.low ? Theme.vermLit : Theme.bright;
                        ctx.lineWidth = lw;
                        ctx.stroke();
                    }
                }
            }

            // ring centre: state glyph, animated percent, charge-state eyebrow.
            Column {
                anchors.centerIn: ring
                spacing: 2 * root.s

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.low ? "battery_alert"
                        : (Battery.charging ? "battery_charging_full" : "battery_full")
                    fill: 1
                    color: root.low ? Theme.vermLit : Theme.bright
                    font.pixelSize: 24 * root.s
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(root.animFrac * 100) + "%"
                    color: root.low ? Theme.vermLit : Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 46 * root.s
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    id: stateLbl
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.stateText
                    color: root.low ? Theme.vermLit : (Battery.charging ? Theme.cream : Theme.subtle)
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6 * root.s
                    // charging is the one live state, so its label breathes.
                    SequentialAnimation on opacity {
                        running: root.open && Battery.charging
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 0.4; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.4; to: 1; duration: 900; easing.type: Easing.InOutSine }
                        onStopped: stateLbl.opacity = 1
                    }
                }
            }
        }

        // ── brightness fader ───────────────────────────────────────────────
        Row {
            width: parent.width
            visible: root.briAvailable
            spacing: 12 * root.s

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 28 * root.s
                text: root.briFrac > 0.66 ? "brightness_high"
                    : (root.briFrac > 0.33 ? "brightness_medium" : "brightness_low")
                fill: 1
                color: Theme.cream
                font.pixelSize: 20 * root.s
            }
            Fader {
                id: briSlider
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 * root.s - 12 * root.s
                value: root.briFrac
                onMoved: (v) => {
                    root.briFrac = v;
                    briWrite.pct = Math.round(v * 100);
                    if (!briWrite.running) briWrite.start();
                }
            }
        }

        // ── volume fader (straight to the default sink) ────────────────────
        Row {
            width: parent.width
            spacing: 12 * root.s

            readonly property real vol: Audio.sink ? Audio.sink.audio.volume : 0
            readonly property bool muted: Audio.sink ? Audio.sink.audio.muted : false

            MaterialIcon {
                id: volIcon
                anchors.verticalCenter: parent.verticalCenter
                width: 28 * root.s
                text: (parent.muted || parent.vol <= 0.001) ? "volume_off"
                    : (parent.vol > 0.5 ? "volume_up" : "volume_down")
                fill: 1
                color: parent.muted ? Theme.faint : Theme.cream
                font.pixelSize: 20 * root.s

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (Audio.sink) Audio.sink.audio.muted = !Audio.sink.audio.muted
                }
            }
            Fader {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28 * root.s - 12 * root.s
                value: parent.muted ? 0 : parent.vol
                onMoved: (v) => {
                    if (!Audio.sink) return;
                    if (Audio.sink.audio.muted && v > 0) Audio.sink.audio.muted = false;
                    Audio.sink.audio.volume = v;
                }
            }
        }

        // ── session actions: safe taps (lock/sleep), hold-to-confirm holds
        // (restart/power) with a vermilion heat fill, mirroring PowerSurface ──
        Row {
            id: sessionRow
            width: parent.width
            spacing: 10 * root.s

            Repeater {
                model: root.sessions

                delegate: Item {
                    id: tile
                    required property var modelData
                    readonly property bool danger: modelData.danger
                    readonly property bool lit: ma.containsMouse || heat.holding

                    width: (sessionRow.width - sessionRow.spacing * 3) / 4
                    height: 54 * root.s

                    Rectangle {
                        anchors.fill: parent
                        radius: Motion.rTile * root.s
                        color: tile.lit ? Theme.frameBg : "transparent"
                        border.width: 1
                        border.color: tile.danger
                            ? (tile.lit ? Theme.vermLit : Theme.border)
                            : (tile.lit ? Theme.frameBorder : Theme.border)
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                    }

                    // bottom-up heat fill for the destructive holds. ClippingRectangle
                    // carries the tile radius so the fill never pokes past the corner.
                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: (Motion.rTile - 1) * root.s
                        color: "transparent"
                        visible: tile.danger

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height * heat.hold
                            visible: heat.holding
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.alpha(Theme.verm, 0.7) }
                                GradientStop { position: 1.0; color: Qt.alpha(Theme.vermLit, 0.15) }
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 3 * root.s

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.glyph
                            fill: tile.lit ? 1 : 0
                            color: heat.holding ? Theme.flameCore
                                : (tile.danger ? (tile.lit ? Theme.vermLit : Theme.iconDim)
                                : (tile.lit ? Theme.bright : Theme.iconDim))
                            font.pixelSize: 20 * root.s
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.label
                            color: tile.lit ? Theme.cream : Theme.faint
                            font.family: Theme.mono
                            font.pixelSize: 8.5 * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.6 * root.s
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }
                    }
                    HeatHold {
                        id: heat
                        onConfirmed: root.dispatch(tile.modelData)
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onExited: if (tile.danger) heat.cancel()
                        onPressed: if (tile.danger) heat.press()
                        onReleased: if (tile.danger) heat.release()
                        onClicked: if (!tile.danger) root.dispatch(tile.modelData)
                    }
                }
            }
        }

        // ── power-profile toggle: a bone pill slides under the active chip ──
        Rectangle {
            width: parent.width
            height: 48 * root.s
            radius: Motion.rTile * root.s
            color: Theme.cardTop
            border.width: 1
            border.color: Theme.hair
            visible: root.profilesAvailable

            readonly property real chipW: (width - 2) / 3

            // bone selector with dark ink chips on top (Ryoku's only emphasis).
            Rectangle {
                id: pill
                width: parent.chipW
                height: parent.height - 2
                y: 1
                radius: (Motion.rTile - 1) * root.s
                color: Theme.bright
                visible: root.profIndex >= 0
                x: Math.max(0, root.profIndex) * parent.chipW + 1
                Behavior on x { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutCubic } }
            }

            Row {
                anchors.fill: parent
                Repeater {
                    model: root.profiles

                    delegate: Item {
                        id: chip
                        required property var modelData
                        readonly property bool sel: root.profile === modelData.name

                        width: (parent.width) / 3
                        height: parent.height

                        Row {
                            anchors.centerIn: parent
                            spacing: 6 * root.s

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.glyph
                                fill: chip.sel ? 1 : 0
                                color: chip.sel ? Theme.cardBot
                                    : (chipHov.hovered ? Theme.cream : Theme.subtle)
                                font.pixelSize: 16 * root.s
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData.label
                                color: chip.sel ? Theme.cardBot
                                    : (chipHov.hovered ? Theme.cream : Theme.subtle)
                                font.family: Theme.mono
                                font.pixelSize: 10 * root.s
                                font.weight: Font.DemiBold
                                Behavior on color { ColorAnimation { duration: Motion.fast } }
                            }
                        }

                        HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.setProfile(chip.modelData.name) }
                    }
                }
            }
        }
    }
}
