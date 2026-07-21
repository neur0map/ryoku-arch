pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"

// volume popout content, a port of ilyamiro's VolumePopup hero orb. a circular
// orb whose wave fill height tracks the default sink volume (drag vertically to
// set, click the chip to mute) over a mono percent readout, then the list of
// output devices (the default collapses its slider since the orb owns it, the
// rest carry a fader and promote to default on tap) and per-app playback
// streams. plain transparent Item, the frame blob behind it IS the surface, so
// ilyamiro's window/panel fill is dropped and only the content is drawn. bone
// is the fill and emphasis, verm is held back for the genuine alerts: a muted
// sink and a boosted over-100 level. pointer-driven, no keyboard focus.
Item {
    id: root

    property real s: 1
    // popout open: gates the wave animation and the per-fader VU peaks so a
    // closed panel never spins a timer or a monitor.
    property bool open: false

    anchors.fill: parent

    implicitWidth: 340 * s
    implicitHeight: body.implicitHeight + 27 * s

    readonly property var sink: Audio.sink
    readonly property var au: (sink && sink.audio) ? sink.audio : null
    // Pipewire volume is 0..1 but can boost past 1 (over-100), so keep the raw
    // value for the readout and clamp a separate ratio for the fill geometry.
    readonly property real vol: au ? au.volume : 0
    readonly property bool muted: au ? au.muted : false
    readonly property int pct: Math.round(root.vol * 100)
    readonly property bool over100: root.pct > 100
    readonly property real fillRatio: Math.max(0, Math.min(1, root.vol))
    readonly property bool alert: root.muted || root.over100

    function isDefaultNode(n) {
        return !!(n && root.sink && n.id === root.sink.id);
    }

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: Theme.hair
    }

    // one output endpoint in the device list. the default collapses its fader
    // (the orb owns its level) and wears a bone DEFAULT chip; the rest carry a
    // fader plus a header tap that promotes them to the default sink.
    component DeviceRow: Item {
        id: dev

        property real s: 1
        property var node: null
        property bool isDefault: false
        property bool peakEnabled: false
        property bool input: false

        width: parent ? parent.width : 0
        implicitHeight: dcol.implicitHeight

        readonly property var dau: (dev.node && dev.node.audio) ? dev.node.audio : null

        HoverHandler { id: devHover }

        Column {
            id: dcol
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6 * dev.s

            Item {
                width: parent.width
                height: 20 * dev.s

                Row {
                    anchors.left: parent.left
                    anchors.right: tag.left
                    anchors.rightMargin: 8 * dev.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * dev.s

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 15 * dev.s
                        height: 15 * dev.s
                        name: Audio.nodeIcon(dev.node)
                        color: dev.isDefault ? Theme.bright
                             : (devHover.hovered ? Theme.cream : Theme.iconDim)
                        stroke: 1.7
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, dev.width - 90 * dev.s)
                        text: Audio.nodeLabel(dev.node) || "Output"
                        color: dev.isDefault ? Theme.bright
                             : (devHover.hovered ? Theme.cream : Theme.subtle)
                        font.family: Theme.font
                        font.pixelSize: 11.5 * dev.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }

                // DEFAULT chip marks the active device (bone-inverted, the shell's
                // one emphasis idiom); the rest show a bone-outline USE chip on
                // hover, so tapping the row to switch the default is discoverable.
                Rectangle {
                    id: tag
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: dev.isDefault || devHover.hovered
                    height: 15 * dev.s
                    width: tagText.implicitWidth + 12 * dev.s
                    radius: 999
                    color: dev.isDefault ? Theme.bright : "transparent"
                    border.width: dev.isDefault ? 0 : 1
                    border.color: Theme.bright
                    Text {
                        id: tagText
                        anchors.centerIn: parent
                        text: dev.isDefault ? "DEFAULT" : "USE"
                        color: dev.isDefault ? Theme.cardBot : Theme.bright
                        font.family: Theme.mono
                        font.pixelSize: 8 * dev.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8 * dev.s
                    }
                }

                // header tap promotes a non-default output to the default sink.
                MouseArea {
                    anchors.fill: parent
                    enabled: !dev.isDefault
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dev.input ? Audio.setInput(dev.node) : Audio.setOutput(dev.node)
                }
            }

            HFader {
                width: parent.width
                s: dev.s
                visible: dev.input || !dev.isDefault
                icon: dev.input ? "mic" : "speaker"
                lit: devHover.hovered
                peakEnabled: dev.peakEnabled
                peakNode: dev.node
                muted: dev.dau ? dev.dau.muted : false
                value: dev.dau ? dev.dau.volume : 0
                valueLabel: !dev.dau ? ""
                    : (dev.dau.muted ? "off" : (Math.round(dev.dau.volume * 100) + "%"))
                onMoved: (v) => { if (dev.dau) dev.dau.volume = v; }
                onIconTapped: { if (dev.dau) dev.dau.muted = !dev.dau.muted; }
            }
        }
    }

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 13 * root.s
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        spacing: 12 * root.s

        // ---- header ----
        Row {
            spacing: 8 * root.s
            BrandMark {
                anchors.verticalCenter: parent.verticalCenter
                size: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "VOLUME"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        // ---- hero: orb + name ----
        Row {
            width: parent.width
            spacing: 18 * root.s

            // the orb: a clipped disc with a bezier wave fill rising to the
            // level. drag vertically to set the level, tap the mute chip below
            // to silence it.
            Item {
                id: orb
                width: 108 * root.s
                height: 108 * root.s
                anchors.verticalCenter: parent.verticalCenter

                scale: orbDrag.pressed ? 0.97 : (orbHover.hovered ? 1.03 : 1.0)
                Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Easing.OutBack } }

                HoverHandler { id: orbHover }

                Rectangle {
                    id: orbDisc
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 2 * root.s
                    border.color: root.alert ? Theme.vermLit : Theme.lineStrong
                    clip: true
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    // the wave fill. clipped to the disc, a bezier crest rides
                    // the level line while the sink is audible and mid-level.
                    Canvas {
                        id: orbCanvas
                        anchors.fill: parent

                        property real wavePhase: 0
                        NumberAnimation on wavePhase {
                            running: root.open && !root.muted && root.fillRatio > 0 && root.fillRatio < 0.99
                            loops: Animation.Infinite
                            from: 0
                            to: Math.PI * 2
                            duration: 1200
                        }
                        onWavePhaseChanged: requestPaint()

                        Connections {
                            target: root
                            function onFillRatioChanged() { orbCanvas.requestPaint(); }
                            function onMutedChanged() { orbCanvas.requestPaint(); }
                            function onOver100Changed() { orbCanvas.requestPaint(); }
                        }
                        Component.onCompleted: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            if (root.fillRatio <= 0)
                                return;

                            var r = width / 2;
                            var fillY = height * (1.0 - root.fillRatio);

                            ctx.save();
                            ctx.beginPath();
                            ctx.arc(r, r, r, 0, 2 * Math.PI);
                            ctx.clip();

                            ctx.beginPath();
                            ctx.moveTo(0, fillY);
                            if (root.fillRatio < 0.99) {
                                var amp = (8 * root.s) * Math.sin(root.fillRatio * Math.PI);
                                var cp1y = fillY + Math.sin(orbCanvas.wavePhase) * amp;
                                var cp2y = fillY + Math.cos(orbCanvas.wavePhase + Math.PI) * amp;
                                ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fillY);
                                ctx.lineTo(width, height);
                                ctx.lineTo(0, height);
                            } else {
                                ctx.lineTo(width, fillY);
                                ctx.lineTo(width, height);
                                ctx.lineTo(0, height);
                            }
                            ctx.closePath();

                            // bone by default, verm only for the alerts: faint
                            // ghost fill when muted, vermilion when boosted.
                            var grad = ctx.createLinearGradient(0, 0, 0, height);
                            if (root.muted) {
                                grad.addColorStop(0, Theme.faint.toString());
                                grad.addColorStop(1, Theme.ghost.toString());
                            } else if (root.over100) {
                                grad.addColorStop(0, Theme.vermLit.toString());
                                grad.addColorStop(1, Theme.verm.toString());
                            } else {
                                grad.addColorStop(0, Theme.bright.toString());
                                grad.addColorStop(1, Theme.cream.toString());
                            }
                            ctx.fillStyle = grad;
                            ctx.fill();
                            ctx.restore();
                        }
                    }

                    // base readout, visible over the dark unfilled region.
                    Text {
                        anchors.centerIn: parent
                        text: root.muted ? "MUTE" : (root.pct + "%")
                        color: root.alert ? Theme.vermLit : Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: (root.muted ? 20 : 24) * root.s
                        font.weight: Font.Bold
                        Behavior on color { ColorAnimation { duration: Motion.fast } }
                    }

                    // dark ink revealed only over the bone fill, the ilyamiro
                    // dual-layer contrast trick; hidden while muted (ghost fill).
                    Item {
                        id: waveClip
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        visible: !root.muted && root.fillRatio > 0
                        clip: true

                        property real amp: root.fillRatio < 0.99 ? (8 * root.s) * Math.sin(root.fillRatio * Math.PI) : 0
                        property real centerOffset: 0.375 * amp * (Math.sin(orbCanvas.wavePhase) - Math.cos(orbCanvas.wavePhase))
                        property real baseClip: parent.height * root.fillRatio
                        height: Math.min(parent.height, Math.max(0, baseClip - centerOffset))

                        Text {
                            x: waveClip.width / 2 - width / 2
                            y: (orbDisc.height / 2) - (height / 2) - (orbDisc.height - waveClip.height)
                            text: root.pct + "%"
                            color: root.over100 ? Theme.paper : Theme.cardBot
                            font.family: Theme.mono
                            font.pixelSize: 24 * root.s
                            font.weight: Font.Bold
                        }
                    }
                }

                // vertical drag sets the level, top is 100, bottom is 0; a level
                // above zero lifts a mute so dragging up always makes sound.
                MouseArea {
                    id: orbDrag
                    anchors.fill: parent
                    cursorShape: Qt.SizeVerCursor
                    preventStealing: true
                    function setFromY(my) {
                        if (!root.au)
                            return;
                        var v = Math.max(0, Math.min(1, 1 - my / height));
                        if (v > 0 && root.au.muted)
                            root.au.muted = false;
                        root.au.volume = v;
                    }
                    onPressed: (e) => setFromY(e.y)
                    onPositionChanged: (e) => { if (pressed) setFromY(e.y); }
                }
            }

            // ---- name + mute chip ----
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - orb.width - 18 * root.s
                spacing: 5 * root.s

                Text {
                    width: parent.width
                    text: Audio.nodeLabel(root.sink) || "No output"
                    color: Theme.cream
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 15 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    text: root.over100 ? ("Boosted " + root.pct + "%") : "Default output"
                    color: root.over100 ? Theme.vermLit : Theme.dim
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                }

                // mute toggle. a bone-inverted pill when muted (the emphasis
                // idiom), a hairline chip otherwise.
                Rectangle {
                    height: 26 * root.s
                    width: muteRow.implicitWidth + 20 * root.s
                    radius: 999
                    color: root.muted ? Theme.bright : (muteHover.hovered ? Theme.frameBg : "transparent")
                    border.width: 1
                    border.color: root.muted ? Theme.bright : Theme.border
                    Behavior on color { ColorAnimation { duration: Motion.fast } }

                    Row {
                        id: muteRow
                        anchors.centerIn: parent
                        spacing: 6 * root.s
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.muted ? "volume_off" : "volume_up"
                            fill: 1
                            color: root.muted ? Theme.cardBot : (muteHover.hovered ? Theme.bright : Theme.cream)
                            font.pixelSize: 16 * root.s
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.muted ? "Muted" : "Mute"
                            color: root.muted ? Theme.cardBot : (muteHover.hovered ? Theme.bright : Theme.subtle)
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                            font.weight: Font.DemiBold
                        }
                    }

                    HoverHandler { id: muteHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !!root.au
                        onClicked: { if (root.au) root.au.muted = !root.au.muted; }
                    }
                }
            }
        }

        Divider {}

        // ---- output devices ----
        Column {
            width: parent.width
            spacing: 7 * root.s

            Row {
                spacing: 7 * root.s
                MicroLabel { label: "Output"; s: root.s }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Audio.outputs.length > 1
                    text: Audio.outputs.length + ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: parent.width
                spacing: 10 * root.s
                Repeater {
                    model: Audio.outputs
                    DeviceRow {
                        required property var modelData
                        width: parent.width
                        s: root.s
                        node: modelData
                        isDefault: root.isDefaultNode(modelData)
                        peakEnabled: root.open
                    }
                }
            }
        }

        Divider {}

        // ---- input devices (microphones): tap to make default, fader sets level ----
        Column {
            width: parent.width
            spacing: 7 * root.s
            visible: Audio.inputs.length > 0

            Row {
                spacing: 7 * root.s
                MicroLabel { label: "Input"; s: root.s }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Audio.inputs.length > 1
                    text: Audio.inputs.length + ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Column {
                width: parent.width
                spacing: 10 * root.s
                Repeater {
                    model: Audio.inputs
                    DeviceRow {
                        required property var modelData
                        width: parent.width
                        s: root.s
                        node: modelData
                        input: true
                        isDefault: !!(Audio.source && modelData.id === Audio.source.id)
                        peakEnabled: root.open
                    }
                }
            }
        }

        Divider {}

        // ---- per-app streams ----
        Column {
            width: parent.width
            spacing: 7 * root.s

            Row {
                spacing: 7 * root.s
                MicroLabel { label: "Apps"; s: root.s }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Audio.streams.length > 0
                    text: Audio.streams.length + ""
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                }
            }

            Text {
                width: parent.width
                visible: Audio.streams.length === 0
                text: "Nothing playing"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.Medium
            }

            Column {
                width: parent.width
                spacing: 9 * root.s
                Repeater {
                    model: Audio.streams
                    MixerAppRow {
                        required property var modelData
                        width: parent.width
                        s: root.s
                        node: modelData
                        peakEnabled: root.open
                    }
                }
            }
        }
    }
}
