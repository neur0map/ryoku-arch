pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// GPU specimen card: a hub trading-card of the machine's graphics, a sibling of
// ProfileCard. carbon gradient, holographic wash, a cursor foil sheen and a
// parallax tilt on hover, closed by the Ryoku wave. the render GPU is the hero
// with a VRAM badge; both GPUs sit in the dossier box with a DISPLAY/FREE role
// marker; the machine is the type line. read-only, fed by `caps` from
// `ryoku-hub gpu caps`.
Item {
    id: root

    property var caps: ({})
    property bool failed: false       // caps probe failed: show "Unavailable", not a spinner
    property real cardWidth: 360
    readonly property real s: cardWidth / 360
    width: cardWidth
    implicitWidth: cardWidth
    implicitHeight: card.height

    readonly property real pad: 18 * root.s
    readonly property real cardRadius: 16 * root.s

    // the GPU wired to the display: what the desktop and a windowed VM draw on.
    readonly property var renderGpu: {
        var p = root.caps.passthrough, h = root.caps.host;
        if (p && p.drivesDisplay)
            return p;
        if (h && h.drivesDisplay)
            return h;
        return h || p || null;
    }

    // parallax tilt + foil + intro state (the ProfileCard idiom).
    property real tiltX: 0
    property real tiltY: 0
    property real shimNX: 0.5
    property real shimNY: 0.5
    property real hoverPct: 0
    property real showAnim: 0
    Behavior on tiltX { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    Behavior on tiltY { NumberAnimation { duration: 220; easing.type: Easing.OutQuad } }
    Behavior on shimNX { NumberAnimation { duration: 80 } }
    Behavior on shimNY { NumberAnimation { duration: 80 } }
    Behavior on hoverPct { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    Component.onCompleted: introShow.start()
    NumberAnimation { id: introShow; target: root; property: "showAnim"; from: 0; to: 1; duration: 320; easing.type: Easing.OutQuart }

    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
    }
    readonly property string holoTop: root.rgba(Theme.cream, 0.07)
    readonly property string holoLeft: root.rgba(Theme.dim, 0.08)
    readonly property string holoRight: root.rgba(Theme.brand, 0.05)
    readonly property string foilRgb: Math.round(Theme.bright.r * 255) + "," + Math.round(Theme.bright.g * 255) + "," + Math.round(Theme.bright.b * 255)

    // one inventory line: tag chip, model + spec, and a role marker.
    component GpuRow: Item {
        id: gr
        property var gpu: null
        property string tag: ""
        width: parent ? parent.width : 0
        height: 38 * root.s
        visible: gr.gpu !== null && gr.gpu !== undefined
        readonly property bool active: gr.gpu !== null && gr.gpu !== undefined && gr.gpu.drivesDisplay === true

        Rectangle {
            id: chip
            width: 46 * root.s
            height: 20 * root.s
            radius: 5 * root.s
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.width: 1
            border.color: gr.active ? Theme.ember : Theme.line
            Text {
                anchors.centerIn: parent
                text: gr.tag
                color: gr.active ? Theme.ember : Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1 * root.s
            }
        }
        Column {
            anchors.left: chip.right
            anchors.leftMargin: 11 * root.s
            anchors.right: role.left
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * root.s
            Text {
                width: parent.width
                text: gr.gpu ? gr.gpu.model : ""
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                text: gr.gpu ? (gr.gpu.vramMb + " MB · " + gr.gpu.driver) : ""
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 9.5 * root.s
            }
        }
        Row {
            id: role
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: gr.active ? "DISPLAY" : "FREE"
                color: gr.active ? Theme.ember : Theme.faint
                font.family: Theme.mono
                font.pixelSize: 8 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4 * root.s
            }
            Rectangle {
                width: 6 * root.s
                height: 6 * root.s
                radius: 3 * root.s
                anchors.verticalCenter: parent.verticalCenter
                color: gr.active ? Theme.ember : Theme.faint
            }
        }
    }

    Item {
        id: card
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: cardBody.height
        opacity: root.showAnim
        scale: 0.96 + 0.04 * root.showAnim + 0.02 * root.hoverPct
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
            border.width: 1
            border.color: Theme.line
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }

            // holographic wash: three soft radial tints, screen blend.
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
                    radial(width * 0.5, 0, width * 0.7, h0);
                    radial(0, height, width * 0.7, h1);
                    radial(width, height, width * 0.7, h2);
                }
            }

            // foil sheen: follows the cursor while hovering.
            Canvas {
                anchors.fill: parent
                property real nx: root.shimNX
                property real ny: root.shimNY
                property real op: root.hoverPct
                property string rgb: root.foilRgb
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
                    let g = ctx.createRadialGradient(nx * width, ny * height, 0, nx * width, ny * height, width * 0.85);
                    g.addColorStop(0, "rgba(" + rgb + "," + (0.14 * op) + ")");
                    g.addColorStop(0.45, "rgba(" + rgb + "," + (0.04 * op) + ")");
                    g.addColorStop(1, "rgba(" + rgb + ",0)");
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, width, height);
                }
            }

            Column {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: root.pad
                spacing: 0

                Text {
                    text: "力  GRAPHICS"
                    color: Theme.cream
                    font.family: Theme.mono
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.4 * root.s
                }

                Item { width: 1; height: 14 * root.s }

                // hero: the GPU that draws the desktop + a windowed VM, with a
                // circular VRAM badge.
                Row {
                    width: parent.width
                    spacing: 12 * root.s

                    Column {
                        width: parent.width - vramBadge.width - parent.spacing
                        spacing: 3 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: "RENDERS ON"
                            color: Theme.dim
                            font.family: Theme.mono
                            font.pixelSize: 8.5 * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 2 * root.s
                        }
                        Text {
                            width: parent.width
                            text: root.renderGpu ? root.renderGpu.model : (root.failed ? "Unavailable" : "Detecting…")
                            color: Theme.bright
                            font.family: Theme.font
                            font.pixelSize: 21 * root.s
                            font.weight: Font.Black
                            font.letterSpacing: -0.3 * root.s
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "the desktop and a windowed VM draw here"
                            color: Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                        }
                    }

                    Rectangle {
                        id: vramBadge
                        width: 46 * root.s
                        height: 46 * root.s
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.renderGpu !== null
                        border.color: Theme.brand
                        border.width: 1.5 * root.s
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.frameBg }
                            GradientStop { position: 1.0; color: Theme.cardBot }
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 0
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.renderGpu ? (Math.round(root.renderGpu.vramMb / 1024) + "G") : ""
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 15 * root.s
                                font.weight: Font.Black
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "VRAM"
                                color: Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 7 * root.s
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1 * root.s
                            }
                        }
                    }
                }

                Item { width: 1; height: 16 * root.s }

                // type line: INVENTORY badge + hairline + chassis · cpu.
                Row {
                    width: parent.width
                    spacing: 8 * root.s
                    height: 20 * root.s

                    Rectangle {
                        id: invBadge
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18 * root.s
                        width: invText.implicitWidth + 14 * root.s
                        radius: 3 * root.s
                        color: "transparent"
                        border.color: Theme.brand
                        border.width: 1
                        Text {
                            id: invText
                            anchors.centerIn: parent
                            text: "INVENTORY"
                            color: Theme.cream
                            font.family: Theme.font
                            font.pixelSize: 8.5 * root.s
                            font.weight: Font.Bold
                            font.letterSpacing: 1.8 * root.s
                        }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(1, parent.width - invBadge.width - machineLabel.implicitWidth - 2 * parent.spacing)
                        height: 1
                        color: Theme.line
                    }
                    Text {
                        id: machineLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.caps.chassis === "laptop" ? "LAPTOP" : "DESKTOP") + (root.caps.cpu ? " · " + root.caps.cpu : "")
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.4 * root.s
                    }
                }

                Item { width: 1; height: 12 * root.s }

                // dossier box: the two GPUs behind a thin accent rail.
                Rectangle {
                    width: parent.width
                    height: invCol.implicitHeight + 20 * root.s
                    color: Theme.lineSoft
                    radius: 3 * root.s

                    Rectangle {
                        width: 2 * root.s
                        height: parent.height
                        color: Theme.cream
                        opacity: 0.4
                    }

                    Column {
                        id: invCol
                        anchors.fill: parent
                        anchors.leftMargin: 12 * root.s
                        anchors.rightMargin: 12 * root.s
                        anchors.topMargin: 10 * root.s
                        anchors.bottomMargin: 10 * root.s
                        spacing: 8 * root.s

                        GpuRow { tag: "iGPU"; gpu: root.caps.host }
                        Rectangle {
                            visible: (root.caps.host !== undefined) && (root.caps.passthrough !== undefined)
                            width: parent.width
                            height: 1
                            color: Theme.line
                        }
                        GpuRow { tag: "dGPU"; gpu: root.caps.passthrough }
                    }
                }

                Item { width: 1; height: 14 * root.s }

                // edition: MUX line + the Ryoku wave signature.
                Text {
                    visible: root.caps.mux !== undefined && root.caps.mux !== "none"
                    text: "MUX " + (root.caps.mux ? root.caps.mux.replace("present-", "").toUpperCase() : "")
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 8.5 * root.s
                    font.letterSpacing: 1.5 * root.s
                }
                Item {
                    width: 1
                    height: 8 * root.s
                    visible: root.caps.mux !== undefined && root.caps.mux !== "none"
                }

                WaveMeter {
                    width: parent.width
                    s: root.s
                    frac: 1
                    tint: Theme.ember
                }
            }
        }
    }

    MouseArea {
        anchors.fill: card
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: (mouse) => {
            let cw = card.width, ch = card.height;
            if (cw <= 0 || ch <= 0)
                return;
            let dx = mouse.x / cw - 0.5, dy = mouse.y / ch - 0.5;
            root.tiltY = dx * 6;
            root.tiltX = -dy * 6;
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
