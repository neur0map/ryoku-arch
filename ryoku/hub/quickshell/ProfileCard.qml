pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "Singletons"

/**
 * 機 The SYSTEM specimen card, the hub-side twin of the shell pill's SysInfoSurface:
 * a carbon trading-card of this machine, sized to share. Parallax tilt on hover, a
 * holographic radial wash, a foil sheen, and an intro reveal. Top to bottom: the
 * operator name + CODENAME · HOST subline + a circular MEM% badge; a portrait
 * window framing the 力 mark over a grid texture, central glow and corner ornaments;
 * a SYSTEM type line; a flavor box (WM/SH · RES/PKG); RAM and disk wave meters;
 * dual CPU | GPU columns and a wave accent; an edition footer. All values come from
 * SysInfo; every face is a hub Theme token. Drives its width from `cardWidth`; the
 * height follows the content and is reported through implicitHeight.
 */
Item {
    id: root

    // The card's outer width; everything inside scales from it (360 is the
    // shell card's design width, so s == 1 reproduces it 1:1).
    property real cardWidth: 420
    readonly property real s: cardWidth / 360

    width: cardWidth
    implicitWidth: cardWidth
    implicitHeight: card.height

    // Inner card padding and corner radius, on the card's scale.
    readonly property real pad: 18 * root.s
    readonly property real cardRadius: 16 * root.s

    // ── Parallax tilt + foil shimmer state ──────────────────────────────────
    property real tiltX: 0
    property real tiltY: 0
    property real shimNX: 0.5
    property real shimNY: 0.5
    property real hoverPct: 0

    readonly property real tiltStrengthX: 6
    readonly property real tiltStrengthY: 7
    readonly property real foilCenter: 0.16
    readonly property real foilEdge: 0.04

    Behavior on tiltX { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    Behavior on tiltY { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    Behavior on shimNX { NumberAnimation { duration: 80 } }
    Behavior on shimNY { NumberAnimation { duration: 80 } }
    Behavior on hoverPct { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

    // ── Intro reveal, replays each time the section opens ───────────────────
    property real showAnim: 0
    property real rowsAnim: 0

    Component.onCompleted: {
        introShow.start();
        introRows.start();
    }

    NumberAnimation {
        id: introShow
        target: root
        property: "showAnim"
        from: 0
        to: 1
        duration: 300
        easing.type: Easing.OutQuart
    }
    SequentialAnimation {
        id: introRows
        PauseAnimation { duration: 160 }
        NumberAnimation {
            target: root
            property: "rowsAnim"
            from: 0
            to: 1
            duration: 420
            easing.type: Easing.OutExpo
        }
    }

    /** Build a Canvas-safe "rgba(...)" string from a Theme colour + alpha. */
    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
    }

    // Holographic wash + glow tints, derived from Theme tokens.
    readonly property string holoTop: rgba(Theme.cream, 0.07)
    readonly property string holoLeft: rgba(Theme.dim, 0.08)
    readonly property string holoRight: rgba(Theme.brand, 0.05)
    readonly property string logoGlow: rgba(Theme.cream, 0.16)
    readonly property string gridTint: rgba(Theme.cream, 0.04)
    readonly property string foilRgb: Math.round(Theme.bright.r * 255) + "," + Math.round(Theme.bright.g * 255) + "," + Math.round(Theme.bright.b * 255)

    // ── Card ────────────────────────────────────────────────────────────────
    Item {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: cardBody.height

        opacity: root.showAnim
        scale: 0.95 + 0.05 * root.showAnim + 0.02 * root.hoverPct
        transformOrigin: Item.Center
        layer.enabled: true

        transform: [
            Rotation {
                origin.x: card.width / 2
                origin.y: card.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: root.tiltX
            },
            Rotation {
                origin.x: card.width / 2
                origin.y: card.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: root.tiltY
            }
        ]

        Rectangle {
            id: cardBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: content.implicitHeight + 2 * root.pad
            radius: root.cardRadius
            clip: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }

            // Holo wash: three soft radial tints in screen blend.
            Canvas {
                anchors.fill: parent
                property string h0: root.holoTop
                property string h1: root.holoLeft
                property string h2: root.holoRight
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    function radial(cx, cy, r, color) {
                        let g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
                        g.addColorStop(0, color);
                        g.addColorStop(1, "rgba(0,0,0,0)");
                        ctx.fillStyle = g;
                        ctx.fillRect(0, 0, width, height);
                    }
                    ctx.globalCompositeOperation = "screen";
                    radial(width * 0.5, height * 0.0, width * 0.7, h0);
                    radial(width * 0.0, height * 1.0, width * 0.7, h1);
                    radial(width * 1.0, height * 1.0, width * 0.7, h2);
                }
            }

            // Foil sheen: follows the cursor while hovering.
            Canvas {
                anchors.fill: parent
                property real nx: root.shimNX
                property real ny: root.shimNY
                property real op: root.hoverPct
                property string rgb: root.foilRgb
                property real cAlpha: root.foilCenter
                property real eAlpha: root.foilEdge
                onNxChanged: requestPaint()
                onNyChanged: requestPaint()
                onOpChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    let ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (op <= 0.001)
                        return;
                    let cx = nx * width;
                    let cy = ny * height;
                    let g = ctx.createRadialGradient(cx, cy, 0, cx, cy, width * 0.85);
                    g.addColorStop(0, "rgba(" + rgb + "," + (cAlpha * op) + ")");
                    g.addColorStop(0.45, "rgba(" + rgb + "," + (eAlpha * op) + ")");
                    g.addColorStop(1, "rgba(" + rgb + ",0)");
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, width, height);
                }
            }

            // ── Content column ─────────────────────────────────────────────
            Column {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: root.pad
                spacing: 0

                // Header: operator name + subline + MEM% badge.
                Row {
                    width: parent.width
                    spacing: 10 * root.s

                    Column {
                        width: parent.width - memBadge.width - parent.spacing
                        spacing: 5 * root.s
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: nameText
                            width: parent.width
                            text: SysInfo.sysUser
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 24 * root.s
                            font.weight: Font.Black
                            font.letterSpacing: -0.5 * root.s
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: SysInfo.codename + "  ·  " + SysInfo.sysHost.toUpperCase()
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2 * root.s
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        id: memBadge
                        width: 44 * root.s
                        height: 44 * root.s
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        border.color: Theme.brand
                        border.width: 1.5 * root.s
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: Theme.frameBg }
                            GradientStop { position: 1.0; color: Theme.cardBot }
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 1 * root.s
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: SysInfo.sysRamPct
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 14 * root.s
                                font.weight: Font.Black
                                font.features: { "tnum": 1 }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "MEM%"
                                color: Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 7 * root.s
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1 * root.s
                            }
                        }
                    }
                }

                Item { width: 1; height: 14 * root.s }

                // Portrait window: framed 力 mark over grid + glow + corners.
                Rectangle {
                    width: parent.width
                    height: 180 * root.s
                    radius: 8 * root.s
                    color: "transparent"
                    border.color: Theme.line
                    border.width: 1 * root.s

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2 * root.s
                        radius: 6 * root.s
                        clip: true
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.frameBg }
                            GradientStop { position: 1.0; color: Theme.cardBot }
                        }

                        // Grid texture.
                        Canvas {
                            anchors.fill: parent
                            property string tint: root.gridTint
                            property real step: 16 * root.s
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                let ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                ctx.strokeStyle = tint;
                                ctx.lineWidth = 1;
                                for (let x = 0; x <= width; x += step) {
                                    ctx.beginPath();
                                    ctx.moveTo(x, 0);
                                    ctx.lineTo(x, height);
                                    ctx.stroke();
                                }
                                for (let y = 0; y <= height; y += step) {
                                    ctx.beginPath();
                                    ctx.moveTo(0, y);
                                    ctx.lineTo(width, y);
                                    ctx.stroke();
                                }
                            }
                        }

                        // Central glow behind the mark.
                        Canvas {
                            anchors.fill: parent
                            property string glow: root.logoGlow
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                let ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                let g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width * 0.45);
                                g.addColorStop(0, glow);
                                g.addColorStop(1, "rgba(0,0,0,0)");
                                ctx.fillStyle = g;
                                ctx.fillRect(0, 0, width, height);
                            }
                        }

                        // The 力 mark as the card's emblem.
                        Text {
                            anchors.centerIn: parent
                            text: "力"
                            color: Theme.brand
                            font.family: Theme.fontJp
                            font.weight: Font.Medium
                            font.pixelSize: 104 * root.s
                        }

                        // Corner ornaments.
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                width: 8 * root.s
                                height: 8 * root.s
                                radius: 1 * root.s
                                color: "transparent"
                                border.color: Qt.alpha(Theme.cream, 0.5)
                                border.width: 1 * root.s
                                anchors.top: index < 2 ? parent.top : undefined
                                anchors.bottom: index >= 2 ? parent.bottom : undefined
                                anchors.left: index % 2 === 0 ? parent.left : undefined
                                anchors.right: index % 2 === 1 ? parent.right : undefined
                                anchors.margins: 6 * root.s
                            }
                        }
                    }
                }

                Item { width: 1; height: 12 * root.s }

                // Type line: SYSTEM badge + hairline + distro · kernel.
                Row {
                    width: parent.width
                    spacing: 8 * root.s
                    height: 22 * root.s

                    Rectangle {
                        id: typeBadge
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20 * root.s
                        width: typeBadgeText.implicitWidth + 16 * root.s
                        radius: 3 * root.s
                        color: "transparent"
                        border.color: Theme.brand
                        border.width: 1 * root.s
                        Text {
                            id: typeBadgeText
                            anchors.centerIn: parent
                            text: "SYSTEM"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.weight: Font.Bold
                            font.letterSpacing: 2 * root.s
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1 * root.s, parent.width - typeBadge.width - distroLabel.implicitWidth - 2 * parent.spacing)
                        height: 1 * root.s
                        color: Theme.line
                    }

                    Text {
                        id: distroLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: SysInfo.sysDistro + " · " + SysInfo.sysKernel.split("-")[0]
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.6 * root.s
                    }
                }

                Item { width: 1; height: 10 * root.s }

                // Flavor box: thin left accent bar + WM/SH · RES/PKG rows.
                Rectangle {
                    width: parent.width
                    height: flavorCol.implicitHeight + 20 * root.s
                    color: Theme.lineSoft
                    radius: 2 * root.s
                    opacity: root.rowsAnim

                    Rectangle {
                        width: 2 * root.s
                        height: parent.height
                        color: Theme.cream
                    }

                    Column {
                        id: flavorCol
                        anchors.fill: parent
                        anchors.leftMargin: 12 * root.s
                        anchors.rightMargin: 12 * root.s
                        anchors.topMargin: 10 * root.s
                        anchors.bottomMargin: 10 * root.s
                        spacing: 5 * root.s

                        component FlavorRow: Row {
                            id: fr
                            property string k1: ""
                            property string v1: ""
                            property string k2: ""
                            property string v2: ""
                            width: parent ? parent.width : 0
                            spacing: 8 * root.s

                            Text {
                                width: 26 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: fr.k1
                                color: Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 8 * root.s
                                font.letterSpacing: 1.6 * root.s
                            }
                            Text {
                                width: (fr.width - 2 * 26 * root.s - 3 * 8 * root.s) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: fr.v1
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 11 * root.s
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                            Text {
                                width: 26 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                text: fr.k2
                                color: Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 8 * root.s
                                font.letterSpacing: 1.6 * root.s
                            }
                            Text {
                                width: (fr.width - 2 * 26 * root.s - 3 * 8 * root.s) / 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: fr.v2
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 11 * root.s
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        FlavorRow {
                            k1: "WM"
                            v1: SysInfo.sysWM
                            k2: "SH"
                            v2: SysInfo.sysShell
                        }
                        FlavorRow {
                            k1: "RES"
                            v1: SysInfo.sysResolution + (SysInfo.sysRefresh.length ? "@" + SysInfo.sysRefresh : "")
                            k2: "PKG"
                            v2: SysInfo.sysPackages
                        }
                    }
                }

                Item { width: 1; height: 12 * root.s }

                // Memory + disk read-outs as Ryoku wave lines: label + value
                // above, a dim wave with a bright crest filled to the percentage.
                component WaveStat: Column {
                    id: ws
                    property string label: ""
                    property string value: ""
                    property real frac: 0
                    width: parent ? parent.width : 0
                    spacing: 6 * root.s

                    Item {
                        width: parent.width
                        height: wsVal.implicitHeight

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: ws.label
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 8 * root.s
                            font.letterSpacing: 1.8 * root.s
                        }
                        Text {
                            id: wsVal
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: ws.value
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                        }
                    }

                    WaveMeter {
                        s: root.s
                        frac: ws.frac
                        width: parent.width
                    }
                }

                WaveStat {
                    label: "MEMORY"
                    value: SysInfo.sysRam
                    frac: SysInfo.sysRamPct / 100
                }

                Item { width: 1; height: 12 * root.s }

                WaveStat {
                    label: "DISK"
                    value: SysInfo.sysDisk
                    frac: SysInfo.sysDiskPct / 100
                }

                Item { width: 1; height: 10 * root.s }

                Rectangle {
                    width: parent.width
                    height: 1 * root.s
                    color: Theme.line
                }

                Item { width: 1; height: 10 * root.s }

                // Bottom stats: CPU | divider | GPU (with uptime).
                Row {
                    width: parent.width
                    spacing: 12 * root.s
                    opacity: root.rowsAnim

                    Column {
                        width: (parent.width - 2 * parent.spacing - 1 * root.s) / 2
                        spacing: 2 * root.s

                        Text {
                            text: "CPU"
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 8 * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.8 * root.s
                        }
                        Text {
                            width: parent.width
                            text: SysInfo.sysCpu
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            text: SysInfo.sysCpuCores
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.features: { "tnum": 1 }
                        }
                    }

                    Rectangle {
                        width: 1 * root.s
                        height: 38 * root.s
                        color: Theme.hair
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        width: (parent.width - 2 * parent.spacing - 1 * root.s) / 2
                        spacing: 2 * root.s

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignRight
                            text: "GPU"
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 8 * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.8 * root.s
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignRight
                            text: SysInfo.sysGpu
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: SysInfo.sysGpu2.length > 0
                            width: parent.width
                            horizontalAlignment: Text.AlignRight
                            text: "GPU 2"
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: 8 * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.8 * root.s
                        }
                        Text {
                            visible: SysInfo.sysGpu2.length > 0
                            width: parent.width
                            horizontalAlignment: Text.AlignRight
                            text: SysInfo.sysGpu2
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 12 * root.s
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignRight
                            text: "UP · " + SysInfo.sysUptime
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9 * root.s
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                Item { width: 1; height: 12 * root.s }

                // Ryoku wave accent: a soft house signature closing the card.
                WaveMeter {
                    width: parent.width
                    s: root.s
                    frac: 1
                    opacity: 0.35
                }

                Item { width: 1; height: 12 * root.s }

                // Edition footer: edition string + accent dots + node.
                RowLayout {
                    width: parent.width
                    spacing: 6 * root.s

                    Text {
                        text: "RYOKU FOUNDRY · 力"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 7.5 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.6 * root.s
                    }

                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: 2 * root.s
                        Repeater {
                            model: 3
                            Rectangle {
                                width: 4 * root.s
                                height: 4 * root.s
                                radius: width / 2
                                color: Theme.brand
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "  NODE · " + SysInfo.sysHost.toUpperCase()
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 8 * root.s
                            font.weight: Font.Bold
                            font.letterSpacing: 1.8 * root.s
                        }
                    }
                }
            }
        }

        // Nested border overlays for the card edge.
        Rectangle {
            anchors.fill: parent
            radius: root.cardRadius
            color: "transparent"
            border.width: 1 * root.s
            border.color: Theme.line
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 5 * root.s
            radius: root.cardRadius - 4 * root.s
            color: "transparent"
            border.width: 1 * root.s
            border.color: Theme.hair
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 9 * root.s
            radius: root.cardRadius - 7 * root.s
            color: "transparent"
            border.width: 1 * root.s
            border.color: Theme.lineSoft
        }
    }

    // Hover tracker for tilt + foil. Sits above the card, untransformed, so the
    // tilt never feeds back into the reading. Tracks only, no clicks.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: (mouse) => {
            let cw = card.width;
            let ch = card.height;
            if (cw <= 0 || ch <= 0)
                return;
            let dx = (mouse.x - cw / 2) / (cw / 2);
            let dy = (mouse.y - ch / 2) / (ch / 2);
            root.tiltY = dx * root.tiltStrengthY;
            root.tiltX = -dy * root.tiltStrengthX;
            root.shimNX = mouse.x / cw;
            root.shimNY = mouse.y / ch;
            root.hoverPct = 1;
        }
        onExited: {
            root.tiltX = 0;
            root.tiltY = 0;
            root.shimNX = 0.5;
            root.shimNY = 0.5;
            root.hoverPct = 0;
        }
    }
}
