import QtQuick
import QtQuick.Effects

// Beautify: a real editor for turning a capture into a shareable image. Opened
// from the toolbar's 力 button. Left-to-right: a top bar (title + export), a
// centre canvas showing the live composition, and a right panel of grouped
// settings driven by sliders (background, frame, shadow, adjust, size). The
// capture sits on a Ryoku-brand background with padding, rounded corners and a
// drop shadow; the stage keeps its full logical size (a visual scale fits it to
// the canvas) so grabToImage exports at full resolution. Same wl-copy / save
// path as the annotator, so no new dependency and no separate app.
Item {
    id: beautify

    property string srcPath: ""

    signal copyRequested(string path)
    signal saveRequested(string path)
    signal closeRequested()

    readonly property string exportTmp: "/tmp/ryoshot-beautified.png"

    readonly property color backdrop: "#0e0d0b"
    readonly property color panelBg: Qt.rgba(20 / 255, 17 / 255, 12 / 255, 1.0)
    readonly property color barBg: Qt.rgba(24 / 255, 20 / 255, 14 / 255, 1.0)
    readonly property color vermilion: "#e2342a"
    readonly property color bright: "#f5efe4"
    readonly property color idle: "#c7bfae"
    readonly property color dim: "#8f8378"
    readonly property color sep: Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.10)

    // --- look state (continuous) ---
    property int bgIndex: 0
    property real bgOpacity: 100
    property real padding: 72
    property real roundness: 14
    property real imgScale: 100
    property real borderW: 0
    property real shadowBlur: 55
    property real shadowDist: 22
    property real shadowOpacity: 45
    property real adjBright: 0
    property real adjContrast: 0
    property real adjSat: 0
    property int ratioIndex: 0

    readonly property var backgrounds: [
        { "name": "Ember", "a": "#e2342a", "b": "#14120f" },
        { "name": "Dusk", "a": "#4b607f", "b": "#12161f" },
        { "name": "Teal", "a": "#3e6868", "b": "#0f1514" },
        { "name": "Sand", "a": "#cda47b", "b": "#7c5f42" },
        { "name": "Slate", "a": "#2b2f38", "b": "#0e0d0b" },
        { "name": "Carbon", "a": "#241d15", "b": "#0e0d0b" },
        { "name": "Ash", "a": "#efe6d8", "b": "#c9bdad" },
        { "name": "Ink", "a": "#101318", "b": "#05060a" }
    ]
    readonly property var ratios: [
        { "name": "Auto", "v": 0 },
        { "name": "16:9", "v": 1.7778 },
        { "name": "1:1", "v": 1 },
        { "name": "4:3", "v": 1.3333 },
        { "name": "3:2", "v": 1.5 }
    ]

    // --- computed stage geometry (full resolution) ---
    readonly property real natW: img.sourceSize.width > 0 ? img.sourceSize.width : 800
    readonly property real natH: img.sourceSize.height > 0 ? img.sourceSize.height : 500
    readonly property real imgW: natW * (imgScale / 100)
    readonly property real imgH: natH * (imgScale / 100)
    readonly property real minW: imgW + 2 * padding
    readonly property real minH: imgH + 2 * padding
    readonly property real ratioV: ratios[ratioIndex].v
    readonly property real fullW: ratioV <= 0 ? minW : (ratioV >= minW / minH ? minH * ratioV : minW)
    readonly property real fullH: ratioV <= 0 ? minH : (ratioV >= minW / minH ? minH : minW / ratioV)

    function exportStage(path, cb) {
        var scheduled = stage.grabToImage(function (r) {
            var ok = false;
            try { ok = r ? r.saveToFile(path) : false; }
            catch (e) { console.log("ryoshot: beautify grab failed: " + e); }
            if (cb) cb(ok);
        }, Qt.size(Math.round(beautify.fullW), Math.round(beautify.fullH)));
        if (!scheduled && cb) cb(false);
    }

    // editor backdrop
    Rectangle { anchors.fill: parent; color: beautify.backdrop }

    // ============================ TOP BAR ============================
    Rectangle {
        id: topbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 54
        color: beautify.barBg

        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: beautify.sep }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u529b"
                color: beautify.vermilion
                font.family: "Noto Sans CJK JP"
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Beautify"
                color: beautify.bright
                font.family: "Space Grotesk"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                font.letterSpacing: 0.3
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            TopBtn { label: "Back"; onTapped: beautify.closeRequested() }
            TopBtn {
                label: "Copy"
                onTapped: beautify.exportStage(beautify.exportTmp, function (ok) { if (ok) beautify.copyRequested(beautify.exportTmp); })
            }
            TopBtn {
                label: "Save image"
                accent: true
                onTapped: beautify.exportStage(beautify.exportTmp, function (ok) { if (ok) beautify.saveRequested(beautify.exportTmp); })
            }
        }
    }

    // ============================ RIGHT PANEL ============================
    Rectangle {
        id: panel
        anchors.right: parent.right
        anchors.top: topbar.bottom
        anchors.bottom: parent.bottom
        width: 348
        color: beautify.panelBg

        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: beautify.sep }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 20
            anchors.topMargin: 22
            anchors.bottomMargin: 22
            contentHeight: pcol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: pcol
                width: flick.width
                spacing: 26

                Group {
                    title: "BACKGROUND"
                    Flow {
                        width: parent.width
                        spacing: 8
                        Repeater {
                            model: beautify.backgrounds
                            Rectangle {
                                id: sw
                                required property int index
                                required property var modelData
                                width: 44
                                height: 30
                                radius: 7
                                readonly property bool sel: beautify.bgIndex === sw.index
                                border.color: sw.sel ? "#ffffff" : Qt.rgba(1, 1, 1, 0.16)
                                border.width: sw.sel ? 2 : 1
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: sw.modelData.a }
                                    GradientStop { position: 1.0; color: sw.modelData.b }
                                }
                                scale: swMa.containsMouse ? 1.07 : 1.0
                                Behavior on scale { NumberAnimation { duration: 90 } }
                                MouseArea { id: swMa; anchors.fill: parent; hoverEnabled: true; onClicked: beautify.bgIndex = sw.index }
                            }
                        }
                    }
                    Slider { width: parent.width; label: "Opacity"; from: 0; to: 100; suffix: "%"; value: beautify.bgOpacity; onMoved: (v) => beautify.bgOpacity = v }
                }

                Group {
                    title: "FRAME"
                    Slider { width: parent.width; label: "Padding"; from: 0; to: 200; value: beautify.padding; onMoved: (v) => beautify.padding = v }
                    Slider { width: parent.width; label: "Roundness"; from: 0; to: 64; value: beautify.roundness; onMoved: (v) => beautify.roundness = v }
                    Slider { width: parent.width; label: "Image scale"; from: 40; to: 100; suffix: "%"; value: beautify.imgScale; onMoved: (v) => beautify.imgScale = v }
                    Slider { width: parent.width; label: "Border"; from: 0; to: 8; value: beautify.borderW; onMoved: (v) => beautify.borderW = v }
                }

                Group {
                    title: "SHADOW"
                    Slider { width: parent.width; label: "Blur"; from: 0; to: 100; value: beautify.shadowBlur; onMoved: (v) => beautify.shadowBlur = v }
                    Slider { width: parent.width; label: "Distance"; from: 0; to: 80; value: beautify.shadowDist; onMoved: (v) => beautify.shadowDist = v }
                    Slider { width: parent.width; label: "Opacity"; from: 0; to: 100; suffix: "%"; value: beautify.shadowOpacity; onMoved: (v) => beautify.shadowOpacity = v }
                }

                Group {
                    title: "ADJUST"
                    Slider { width: parent.width; label: "Brightness"; bipolar: true; from: -100; to: 100; value: beautify.adjBright; onMoved: (v) => beautify.adjBright = v }
                    Slider { width: parent.width; label: "Contrast"; bipolar: true; from: -100; to: 100; value: beautify.adjContrast; onMoved: (v) => beautify.adjContrast = v }
                    Slider { width: parent.width; label: "Saturation"; bipolar: true; from: -100; to: 100; value: beautify.adjSat; onMoved: (v) => beautify.adjSat = v }
                }

                Group {
                    title: "SIZE"
                    RatioSeg { width: parent.width }
                }
            }
        }
    }

    // ============================ CANVAS ============================
    Item {
        id: canvasArea
        anchors.left: parent.left
        anchors.right: panel.left
        anchors.top: topbar.bottom
        anchors.bottom: parent.bottom

        Item {
            id: stage
            width: beautify.fullW
            height: beautify.fullH
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -12
            scale: Math.min((canvasArea.width - 96) / beautify.fullW, (canvasArea.height - 120) / beautify.fullH, 1)
            transformOrigin: Item.Center

            Rectangle {
                anchors.fill: parent
                opacity: beautify.bgOpacity / 100
                gradient: Gradient {
                    GradientStop { position: 0.0; color: beautify.backgrounds[beautify.bgIndex].a }
                    GradientStop { position: 1.0; color: beautify.backgrounds[beautify.bgIndex].b }
                }
            }

            Item {
                id: shotHolder
                anchors.centerIn: parent
                width: beautify.imgW
                height: beautify.imgH

                Image {
                    id: img
                    anchors.fill: parent
                    source: beautify.srcPath ? ("file://" + beautify.srcPath) : ""
                    cache: false
                    fillMode: Image.Stretch
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: beautify.roundness > 0
                        maskSource: rounded
                        shadowEnabled: beautify.shadowOpacity > 0
                        shadowColor: Qt.rgba(0, 0, 0, beautify.shadowOpacity / 100)
                        shadowBlur: beautify.shadowBlur / 100
                        shadowVerticalOffset: beautify.shadowDist
                        brightness: beautify.adjBright / 100
                        contrast: beautify.adjContrast / 100
                        saturation: beautify.adjSat / 100
                        autoPaddingEnabled: true
                    }
                }
                Rectangle {
                    id: rounded
                    anchors.fill: parent
                    radius: beautify.roundness
                    visible: false
                    layer.enabled: true
                }
                Rectangle {
                    anchors.fill: parent
                    visible: beautify.borderW > 0
                    color: "transparent"
                    radius: beautify.roundness
                    border.width: beautify.borderW
                    border.color: Qt.rgba(1, 1, 1, 0.5)
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            text: Math.round(beautify.fullW) + " \u00d7 " + Math.round(beautify.fullH) + "  \u00b7  " + Math.round(stage.scale * 100) + "%"
            color: beautify.dim
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
        }
    }

    // ============================ inline widgets ============================
    component Group: Column {
        id: grp
        width: parent ? parent.width : 0
        property string title: ""
        default property alias content: body.data
        spacing: 16

        Item {
            width: grp.width
            height: 14
            Text {
                id: gh
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: grp.title
                color: beautify.dim
                font.family: "Space Grotesk"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                font.letterSpacing: 2
            }
            Rectangle {
                anchors.left: gh.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: beautify.sep
            }
        }
        Column { id: body; width: grp.width; spacing: 16 }
    }

    component TopBtn: Rectangle {
        id: tbn
        property string label: ""
        property bool accent: false
        signal tapped()
        implicitWidth: tl.implicitWidth + 32
        implicitHeight: 34
        radius: 8
        color: tbn.accent ? (tbnMa.containsMouse ? Qt.lighter(beautify.vermilion, 1.12) : beautify.vermilion) : (tbnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        border.width: tbn.accent ? 0 : 1
        border.color: beautify.sep
        Text {
            id: tl
            anchors.centerIn: parent
            text: tbn.label
            color: tbn.accent ? "#ffffff" : beautify.idle
            font.family: "Space Grotesk"
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        MouseArea { id: tbnMa; anchors.fill: parent; hoverEnabled: true; onClicked: tbn.tapped() }
    }

    component RatioSeg: Rectangle {
        id: rs
        height: 34
        radius: 9
        color: Qt.rgba(1, 1, 1, 0.05)
        Row {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 3
            Repeater {
                model: beautify.ratios
                Rectangle {
                    required property int index
                    required property var modelData
                    width: (rs.width - 6 - (beautify.ratios.length - 1) * 3) / beautify.ratios.length
                    height: parent.height
                    radius: 7
                    readonly property bool sel: beautify.ratioIndex === index
                    color: sel ? beautify.vermilion : (rma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        color: parent.sel ? "#ffffff" : beautify.idle
                        font.family: "Space Grotesk"
                        font.pixelSize: 12
                        font.weight: parent.sel ? Font.DemiBold : Font.Medium
                    }
                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: beautify.ratioIndex = index }
                }
            }
        }
    }
}
