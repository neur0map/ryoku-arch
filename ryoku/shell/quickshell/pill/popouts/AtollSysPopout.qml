pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."
import "../Singletons"

// system usage popout content: a port of ilyamiro's SystemUsage, five liquid
// fill cards laid 3 over 2 (CPU / RAM / TEMP on top, DISK / NET below). each
// card is a rounded tile whose bone water rises to the value fraction with a
// slow wave; the readout inverts to dark ink where the water covers it. a bare
// transparent Item, the frame blob behind it IS the surface. cpu/mem/temp come
// from the kernel-native SysStats singleton; disk (df) and net (/proc/net/dev
// deltas) are polled locally, only while open so a closed panel costs nothing.
Item {
    id: root

    property real s: 1
    // popout open: gates every poller and the wave animation.
    property bool open: false

    anchors.fill: parent

    implicitWidth: 300 * s
    implicitHeight: 210 * s

    // one shared wave clock: all five canvases read this phase so the water
    // ripples in unison. only runs while open (no offscreen repaint churn).
    property real wavePhase: 0
    NumberAnimation on wavePhase {
        from: 0
        to: Math.PI * 2
        duration: 1800
        loops: Animation.Infinite
        running: root.open
    }

    // ---- disk (df on the root filesystem), refreshed once a minute ----
    property real diskFrac: 0
    property string diskUsed: ""
    property string diskSize: ""

    Process {
        id: diskProc
        command: ["sh", "-c", "df -h / | awk 'NR==2{print $5\" \"$3\" \"$2}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = (this.text || "").trim();
                if (!t)
                    return;
                var p = t.split(/\s+/);
                if (p.length >= 3) {
                    root.diskFrac = Math.max(0, Math.min(1, (parseFloat(p[0].replace("%", "")) || 0) / 100));
                    root.diskUsed = p[1];
                    root.diskSize = p[2];
                }
            }
        }
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.open
        triggeredOnStart: true
        onTriggered: diskProc.running = true
    }

    // ---- net throughput from /proc/net/dev byte deltas (kernel-native) ----
    property real rxRate: 0
    property real txRate: 0
    property real _prevRx: 0
    property real _prevTx: 0
    property real _prevTime: 0

    function fmtRate(b) {
        if (!(b > 0))
            return "0 B/s";
        var k = 1024;
        var u = ["B/s", "KB/s", "MB/s", "GB/s"];
        var i = Math.floor(Math.log(b) / Math.log(k));
        i = Math.max(0, Math.min(u.length - 1, i));
        return parseFloat((b / Math.pow(k, i)).toFixed(1)) + " " + u[i];
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var lines = (netFile.text() || "").split("\n");
            var rx = 0;
            var tx = 0;
            // rows 0-1 are the two header lines; sum every real interface but lo.
            for (var i = 2; i < lines.length; i++) {
                var ln = lines[i].trim();
                if (!ln)
                    continue;
                var c = ln.indexOf(":");
                if (c < 0)
                    continue;
                if (ln.substring(0, c).trim() === "lo")
                    continue;
                var f = ln.substring(c + 1).trim().split(/\s+/);
                rx += Number(f[0]) || 0;
                tx += Number(f[8]) || 0;
            }
            var now = Date.now();
            var dt = (now - root._prevTime) / 1000;
            // real elapsed, not the timer interval, so a late tick never inflates.
            if (root._prevTime > 0 && dt > 0) {
                root.rxRate = Math.max(0, (rx - root._prevRx) / dt);
                root.txRate = Math.max(0, (tx - root._prevTx) / dt);
            }
            root._prevRx = rx;
            root._prevTx = tx;
            root._prevTime = now;
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.open
        triggeredOnStart: true
        onTriggered: netFile.reload()
    }

    // both readout copies of a card share this layout: dim ink above the water,
    // dark ink below (revealed through the clip box) so the value stays legible
    // on the bone fill. `mono` numerals; the eyebrow is the small caps label.
    component CardFace: Item {
        id: face
        property color ink: Theme.dim
        property color valueInk: Theme.cream
        property string glyph: ""
        property string eyebrow: ""
        property string valueText: ""
        property string subText: ""

        Item {
            anchors.fill: parent
            anchors.margins: 12 * root.s

            MaterialIcon {
                id: faceIcon
                anchors.top: parent.top
                anchors.left: parent.left
                text: face.glyph
                fill: 1
                color: face.ink
                font.pixelSize: 15 * root.s
            }
            Text {
                anchors.verticalCenter: faceIcon.verticalCenter
                anchors.right: parent.right
                text: face.eyebrow
                color: face.ink
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.2 * root.s
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.bottomMargin: 3 * root.s
                visible: text.length > 0
                text: face.subText
                color: face.ink
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.weight: Font.Medium
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                text: face.valueText
                color: face.valueInk
                font.family: Theme.mono
                font.pixelSize: 22 * root.s
                font.weight: Font.Black
                font.features: ({ "tnum": 1 })
            }
        }
    }

    // one liquid card: dark tile, a bone (or verm when critical) water column
    // clipped to a rounded rect with a slow surface wave, two stacked readout
    // faces, and a free slot (NET fills it with its up/down rows).
    component Card: Item {
        id: card
        property real value: 0
        property string glyph: ""
        property string eyebrow: ""
        property string valueText: ""
        property string subText: ""
        property bool critical: false
        default property alias content: overlay.data

        readonly property real cardRadius: 10 * root.s
        readonly property color fillColor: critical ? Theme.verm : Theme.bright
        readonly property real fillRatio: Math.max(0, Math.min(1, value))
        readonly property real fillY: height * (1 - fillRatio)
        // wave amplitude fades to zero at empty/full so a static level sits flat.
        readonly property real waveAmp: (fillRatio > 0.01 && fillRatio < 0.99) ? 5 * root.s * Math.sin(fillRatio * Math.PI) : 0
        // nudge the reveal line to ride the drawn wave crest, keeping the dark
        // ink and the water surface in step.
        readonly property real waveCenterOffset: 0.375 * waveAmp * (Math.sin(root.wavePhase) - Math.cos(root.wavePhase))

        Behavior on value {
            NumberAnimation {
                duration: 800
                easing.type: Easing.OutQuint
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: card.cardRadius
            color: Theme.cardTop
            border.color: Theme.hair
            border.width: 1
        }

        Canvas {
            id: fluid
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (card.value <= 0)
                    return;

                var r = card.cardRadius;
                ctx.save();
                // clip to the tile's rounded rect so the water keeps the corners.
                ctx.beginPath();
                ctx.moveTo(r, 0);
                ctx.lineTo(width - r, 0);
                ctx.quadraticCurveTo(width, 0, width, r);
                ctx.lineTo(width, height - r);
                ctx.quadraticCurveTo(width, height, width - r, height);
                ctx.lineTo(r, height);
                ctx.quadraticCurveTo(0, height, 0, height - r);
                ctx.lineTo(0, r);
                ctx.quadraticCurveTo(0, 0, r, 0);
                ctx.closePath();
                ctx.clip();

                var fy = card.fillY;
                ctx.beginPath();
                ctx.moveTo(0, fy);
                if (card.waveAmp > 0) {
                    var cp1y = fy + Math.sin(root.wavePhase) * card.waveAmp;
                    var cp2y = fy + Math.cos(root.wavePhase + Math.PI) * card.waveAmp;
                    ctx.bezierCurveTo(width * 0.33, cp2y, width * 0.66, cp1y, width, fy);
                } else {
                    ctx.lineTo(width, fy);
                }
                ctx.lineTo(width, height);
                ctx.lineTo(0, height);
                ctx.closePath();

                var grad = ctx.createLinearGradient(0, 0, 0, height);
                grad.addColorStop(0, Qt.lighter(card.fillColor, 1.18).toString());
                grad.addColorStop(1, card.fillColor.toString());
                ctx.fillStyle = grad;
                ctx.globalAlpha = 0.95;
                ctx.fill();
                ctx.restore();
            }

            Connections {
                target: root
                enabled: root.open && card.waveAmp > 0
                function onWavePhaseChanged() { fluid.requestPaint(); }
            }
            Connections {
                target: card
                function onFillRatioChanged() { fluid.requestPaint(); }
                function onFillColorChanged() { fluid.requestPaint(); }
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // above the water: dim readout on the dark tile.
        CardFace {
            anchors.fill: parent
            ink: Theme.dim
            valueInk: card.critical ? Theme.vermLit : Theme.cream
            glyph: card.glyph
            eyebrow: card.eyebrow
            valueText: card.valueText
            subText: card.subText
        }

        // below the water: the same readout in dark ink, revealed only where the
        // clip box (height = water level) uncovers it.
        Item {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.max(0, Math.min(parent.height, parent.height * card.fillRatio - card.waveCenterOffset))
            clip: true
            visible: card.value > 0

            CardFace {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: card.height
                ink: Theme.cardBot
                valueInk: Theme.paper
                glyph: card.glyph
                eyebrow: card.eyebrow
                valueText: card.valueText
                subText: card.subText
            }
        }

        // free slot for custom content (NET), always on top.
        Item {
            id: overlay
            anchors.fill: parent
            anchors.margins: 12 * root.s
            z: 10
        }
    }

    GridLayout {
        anchors.fill: parent
        anchors.margins: 14 * root.s
        columns: 6
        columnSpacing: 8 * root.s
        rowSpacing: 8 * root.s

        // ---- top row: three thirds ----
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 2
            glyph: "developer_board"
            eyebrow: "CPU"
            value: SysStats.cpu / 100
            valueText: SysStats.cpu + "%"
            critical: SysStats.cpu > 95
        }
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 2
            glyph: "memory"
            eyebrow: "RAM"
            value: SysStats.mem / 100
            valueText: SysStats.mem + "%"
            critical: SysStats.mem > 95
        }
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 2
            glyph: "device_thermostat"
            eyebrow: "TEMP"
            value: SysStats.tempAvailable ? Math.min(1, SysStats.temp / 100) : 0
            valueText: SysStats.tempAvailable ? SysStats.temp + "\u00b0" : "--"
            critical: SysStats.tempAvailable && SysStats.temp >= 85
        }

        // ---- bottom row: two halves ----
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 3
            glyph: "hard_drive"
            eyebrow: "DISK"
            value: root.diskFrac
            valueText: Math.round(root.diskFrac * 100) + "%"
            subText: root.diskUsed.length > 0 ? root.diskUsed + " / " + root.diskSize : ""
            critical: root.diskFrac > 0.9
        }
        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.columnSpan: 3
            glyph: "swap_vert"
            eyebrow: "NET"
            // low resting fill that swells with traffic (8 MB/s reads as full).
            value: Math.max(0.08, Math.min(1, (root.rxRate + root.txRate) / (8 * 1024 * 1024)))

            Column {
                anchors.centerIn: parent
                spacing: 6 * root.s

                Row {
                    spacing: 8 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "arrow_downward"
                        fill: 1
                        color: Theme.subtle
                        font.pixelSize: 14 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.fmtRate(root.rxRate)
                        color: Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 13 * root.s
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }
                Row {
                    spacing: 8 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "arrow_upward"
                        fill: 1
                        color: Theme.subtle
                        font.pixelSize: 14 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.fmtRate(root.txRate)
                        color: Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 13 * root.s
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }
    }
}
