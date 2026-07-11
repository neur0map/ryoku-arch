import QtQuick
import QtQuick.Effects

// Beautify: a sharing-first image editor for a capture. Frosted, textured chrome
// (the launcher's grainy look: a warm translucent surface over a square-grid
// weave), a live canvas, and a right panel of the right control per job -- a
// background thumbnail grid (preset gradients, solid, custom gradient, image,
// transparent), colour swatches, ratio + social-format pills, a shadow-direction
// dial -- with sliders only for the continuous frame values. The card layers are
// kept separate (a blurred directional shadow, a mask-rounded image, a coloured
// border) so rounding, border colour and shadow direction each work on their own.
// Exports at full resolution through the same wl-copy / save path as the shot.
Item {
    id: beautify

    property string srcPath: ""
    property string bgImagePath: ""

    signal copyRequested(string path)
    signal saveRequested(string path)
    signal pickImageRequested()
    signal closeRequested()

    readonly property string exportTmp: "/tmp/ryoshot-beautified.png"

    readonly property color vermilion: "#e2342a"
    readonly property color bright: "#f5efe4"
    readonly property color idle: "#c7bfae"
    readonly property color dim: "#8f8378"
    readonly property color panelBg: Qt.rgba(30 / 255, 25 / 255, 18 / 255, 0.86)
    readonly property color fieldBg: Qt.rgba(1, 1, 1, 0.05)
    readonly property color hair: Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.12)

    // ---- state ----
    property string bgKind: "preset"     // preset | solid | gradient | image | none
    property int bgPreset: 6
    property color bgSolid: "#2b3350"
    property color bgGradA: "#4facfe"
    property color bgGradB: "#00c6a7"
    property real bgGradAngle: 135
    property real padding: 90
    property real roundness: 24
    property real borderW: 0
    property color borderColor: "#ffffff"
    property real shadowStrength: 45
    property real shadowBlur: 55
    property real shadowDist: 20
    property real shadowAngle: 90
    property real adjBright: 0
    property real adjContrast: 0
    property real adjSat: 0
    property string ratioKey: "auto"
    property bool watermark: false

    readonly property var presets: [
        { "a": "#4facfe", "b": "#00c6a7", "ang": 135 },
        { "a": "#f6543e", "b": "#f7b733", "ang": 135 },
        { "a": "#7b4397", "b": "#dc2430", "ang": 135 },
        { "a": "#11998e", "b": "#38ef7d", "ang": 135 },
        { "a": "#ee9ca7", "b": "#ffdde1", "ang": 135 },
        { "a": "#334155", "b": "#0f172a", "ang": 135 },
        { "a": "#e2342a", "b": "#14120f", "ang": 135 },
        { "a": "#00c3ff", "b": "#ffff1c", "ang": 135 },
        { "a": "#ffecd2", "b": "#fcb69f", "ang": 135 },
        { "a": "#3e6868", "b": "#0f1514", "ang": 135 },
        { "a": "#ff6a88", "b": "#ff99ac", "ang": 135 },
        { "a": "#141e30", "b": "#243b55", "ang": 135 }
    ]
    readonly property var palette: [
        "#ffffff", "#0e0d0b", "#e2342a", "#f3701e", "#f7b733", "#38ef7d",
        "#4facfe", "#2b6cb0", "#7b4397", "#ee9ca7", "#3e6868", "#c7bfae"
    ]
    readonly property var ratioRow: [
        { "k": "auto", "l": "Auto" }, { "k": "1:1", "l": "1:1" }, { "k": "4:3", "l": "4:3" },
        { "k": "3:2", "l": "3:2" }, { "k": "16:9", "l": "16:9" }, { "k": "9:16", "l": "9:16" }
    ]
    readonly property var socialRow: [
        { "k": "x", "l": "X" }, { "k": "instagram", "l": "Instagram" }, { "k": "story", "l": "Story" },
        { "k": "linkedin", "l": "LinkedIn" }, { "k": "youtube", "l": "YouTube" }, { "k": "pinterest", "l": "Pinterest" }
    ]
    readonly property var ratioMap: ({ "auto": 0, "1:1": 1, "4:3": 1.3333, "3:2": 1.5, "16:9": 1.7778, "9:16": 0.5625, "x": 1.7778, "instagram": 1, "story": 0.5625, "linkedin": 1.91, "youtube": 1.7778, "pinterest": 0.6667 })

    // ---- resolved background ----
    readonly property bool bgIsGradient: bgKind === "preset" || bgKind === "gradient"
    readonly property color bgA: bgKind === "preset" ? presets[bgPreset].a : bgGradA
    readonly property color bgB: bgKind === "preset" ? presets[bgPreset].b : bgGradB
    readonly property real bgAngle: bgKind === "preset" ? presets[bgPreset].ang : bgGradAngle

    // ---- geometry (full resolution) ----
    readonly property real natW: img.sourceSize.width > 0 ? img.sourceSize.width : 800
    readonly property real natH: img.sourceSize.height > 0 ? img.sourceSize.height : 500
    readonly property real minW: natW + 2 * padding
    readonly property real minH: natH + 2 * padding
    readonly property real ratioV: ratioMap[ratioKey] !== undefined ? ratioMap[ratioKey] : 0
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

    // ============================ frosted backdrop ============================
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1b1610" }
            GradientStop { position: 1.0; color: "#100d09" }
        }
    }
    Canvas {
        anchors.fill: parent
        opacity: 0.5
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = "rgba(245, 239, 228, 0.04)";
            ctx.lineWidth = 1;
            var step = 34;
            for (var x = 0; x <= width; x += step) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke(); }
            for (var y = 0; y <= height; y += step) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke(); }
        }
        Component.onCompleted: requestPaint()
    }

    // ============================ top bar ============================
    Rectangle {
        id: topbar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 56
        color: beautify.panelBg
        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 1; color: beautify.hair }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 11
            Text { anchors.verticalCenter: parent.verticalCenter; text: "\u529b"; color: beautify.vermilion; font.family: "Noto Sans CJK JP"; font.pixelSize: 21; font.weight: Font.DemiBold }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Beautify"; color: beautify.bright; font.family: "Space Grotesk"; font.pixelSize: 16; font.weight: Font.DemiBold }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "ready to share"; color: beautify.dim; font.family: "Space Grotesk"; font.pixelSize: 12 }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            TopBtn { label: "Back"; onTapped: beautify.closeRequested() }
            TopBtn { label: "Copy"; onTapped: beautify.exportStage(beautify.exportTmp, function (ok) { if (ok) beautify.copyRequested(beautify.exportTmp); }) }
            TopBtn { label: "Save image"; accent: true; onTapped: beautify.exportStage(beautify.exportTmp, function (ok) { if (ok) beautify.saveRequested(beautify.exportTmp); }) }
        }
    }

    // ============================ right panel ============================
    Rectangle {
        id: panel
        anchors.right: parent.right
        anchors.top: topbar.bottom
        anchors.bottom: parent.bottom
        width: 360
        color: beautify.panelBg
        Rectangle { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 1; color: beautify.hair }

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.leftMargin: 22
            anchors.rightMargin: 18
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            contentHeight: pcol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: pcol
                width: flick.width
                spacing: 24

                // ---------- BACKGROUND ----------
                Group {
                    title: "BACKGROUND"
                    Grid {
                        width: parent.width
                        columns: 6
                        columnSpacing: 8
                        rowSpacing: 8
                        Repeater {
                            model: beautify.presets
                            Rectangle {
                                id: cell
                                required property int index
                                required property var modelData
                                width: (parent.width - 5 * 8) / 6
                                height: 34
                                radius: 8
                                readonly property bool sel: beautify.bgKind === "preset" && beautify.bgPreset === cell.index
                                border.color: cell.sel ? "#ffffff" : beautify.hair
                                border.width: cell.sel ? 2 : 1
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: cell.modelData.a }
                                    GradientStop { position: 1.0; color: cell.modelData.b }
                                }
                                MouseArea { anchors.fill: parent; onClicked: { beautify.bgKind = "preset"; beautify.bgPreset = cell.index; } }
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 8
                        BgType { label: "Solid"; on: beautify.bgKind === "solid"; onTapped: beautify.bgKind = "solid" }
                        BgType { label: "Gradient"; on: beautify.bgKind === "gradient"; onTapped: beautify.bgKind = "gradient" }
                        BgType { label: "Image"; on: beautify.bgKind === "image"; onTapped: { beautify.bgKind = "image"; beautify.pickImageRequested(); } }
                        BgType { label: "None"; on: beautify.bgKind === "none"; onTapped: beautify.bgKind = "none" }
                    }
                    ColorRow { visible: beautify.bgKind === "solid"; width: parent.width; current: beautify.bgSolid; onPicked: (c) => beautify.bgSolid = c }
                    Column {
                        visible: beautify.bgKind === "gradient"
                        width: parent.width
                        spacing: 10
                        ColorRow { width: parent.width; current: beautify.bgGradA; onPicked: (c) => beautify.bgGradA = c }
                        ColorRow { width: parent.width; current: beautify.bgGradB; onPicked: (c) => beautify.bgGradB = c }
                        Slider { width: parent.width; label: "Angle"; from: 0; to: 360; suffix: "\u00b0"; value: beautify.bgGradAngle; onMoved: (v) => beautify.bgGradAngle = v }
                    }
                    Text {
                        visible: beautify.bgKind === "image"
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: beautify.bgImagePath ? beautify.bgImagePath : "Click Image again to choose a file\u2026"
                        color: beautify.dim
                        font.family: "Space Grotesk"
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                    }
                }

                // ---------- FRAME ----------
                Group {
                    title: "FRAME"
                    Slider { width: parent.width; label: "Padding"; from: 0; to: 240; value: beautify.padding; onMoved: (v) => beautify.padding = v }
                    Slider { width: parent.width; label: "Roundness"; from: 0; to: 80; value: beautify.roundness; onMoved: (v) => beautify.roundness = v }
                    Slider { width: parent.width; label: "Border"; from: 0; to: 16; value: beautify.borderW; onMoved: (v) => beautify.borderW = v }
                    ColorRow { visible: beautify.borderW > 0; width: parent.width; current: beautify.borderColor; onPicked: (c) => beautify.borderColor = c }
                }

                // ---------- SHADOW ----------
                Group {
                    title: "SHADOW"
                    Row {
                        width: parent.width
                        spacing: 16
                        Column {
                            width: parent.width - 56 - 16
                            spacing: 16
                            Slider { width: parent.width; label: "Strength"; from: 0; to: 100; suffix: "%"; value: beautify.shadowStrength; onMoved: (v) => beautify.shadowStrength = v }
                            Slider { width: parent.width; label: "Blur"; from: 0; to: 100; value: beautify.shadowBlur; onMoved: (v) => beautify.shadowBlur = v }
                            Slider { width: parent.width; label: "Distance"; from: 0; to: 80; value: beautify.shadowDist; onMoved: (v) => beautify.shadowDist = v }
                        }
                        Dial {
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Angle"
                            angle: beautify.shadowAngle
                            onMoved: (a) => beautify.shadowAngle = a
                        }
                    }
                }

                // ---------- ADJUST ----------
                Group {
                    title: "ADJUST"
                    Slider { width: parent.width; label: "Brightness"; bipolar: true; from: -100; to: 100; value: beautify.adjBright; onMoved: (v) => beautify.adjBright = v }
                    Slider { width: parent.width; label: "Contrast"; bipolar: true; from: -100; to: 100; value: beautify.adjContrast; onMoved: (v) => beautify.adjContrast = v }
                    Slider { width: parent.width; label: "Saturation"; bipolar: true; from: -100; to: 100; value: beautify.adjSat; onMoved: (v) => beautify.adjSat = v }
                }

                // ---------- RATIO / SIZE ----------
                Group {
                    title: "RATIO / SIZE"
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: beautify.ratioRow
                            Pill { label: modelData.l; on: beautify.ratioKey === modelData.k; onTapped: beautify.ratioKey = modelData.k }
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 6
                        Repeater {
                            model: beautify.socialRow
                            Pill { label: modelData.l; on: beautify.ratioKey === modelData.k; onTapped: beautify.ratioKey = modelData.k }
                        }
                    }
                }

                // ---------- SHARE ----------
                Group {
                    title: "SHARE"
                    ToggleRow { width: parent.width; label: "Watermark (力 Ryoku)"; on: beautify.watermark; onToggled: (v) => beautify.watermark = v }
                }
            }
        }
    }

    // ============================ canvas ============================
    Item {
        id: canvasArea
        anchors.left: parent.left
        anchors.right: panel.left
        anchors.top: topbar.bottom
        anchors.bottom: parent.bottom

        // transparency checker, shown behind the stage only when bg is None
        Rectangle {
            visible: beautify.bgKind === "none"
            width: stage.width * stage.scale
            height: stage.height * stage.scale
            anchors.centerIn: stage
            color: "#ffffff"
            Canvas {
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d");
                    var s = 12;
                    ctx.fillStyle = "#c8c8c8";
                    for (var y = 0; y < height; y += s)
                        for (var x = 0; x < width; x += s)
                            if (((x / s) + (y / s)) % 2 === 0) ctx.fillRect(x, y, s, s);
                }
                Component.onCompleted: requestPaint()
            }
        }

        Item {
            id: stage
            width: beautify.fullW
            height: beautify.fullH
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -12
            scale: Math.min((canvasArea.width - 96) / beautify.fullW, (canvasArea.height - 120) / beautify.fullH, 1)
            transformOrigin: Item.Center

            // background
            Item {
                anchors.fill: parent
                visible: beautify.bgKind !== "none"
                clip: true
                Rectangle {
                    visible: beautify.bgIsGradient
                    anchors.centerIn: parent
                    width: Math.max(parent.width, parent.height) * 1.5
                    height: width
                    rotation: beautify.bgAngle - 90
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: beautify.bgA }
                        GradientStop { position: 1.0; color: beautify.bgB }
                    }
                }
                Rectangle { visible: beautify.bgKind === "solid"; anchors.fill: parent; color: beautify.bgSolid }
                Image { visible: beautify.bgKind === "image" && beautify.bgImagePath !== ""; anchors.fill: parent; source: beautify.bgImagePath ? ("file://" + beautify.bgImagePath) : ""; fillMode: Image.PreserveAspectCrop; cache: false }
            }

            // the framed capture
            Item {
                id: card
                anchors.centerIn: parent
                width: beautify.natW
                height: beautify.natH

                // directional blurred shadow, cast from the rounded card shape
                Rectangle {
                    anchors.fill: parent
                    x: Math.cos(beautify.shadowAngle * Math.PI / 180) * beautify.shadowDist
                    y: Math.sin(beautify.shadowAngle * Math.PI / 180) * beautify.shadowDist
                    radius: beautify.roundness
                    color: "#000000"
                    visible: beautify.shadowStrength > 0
                    opacity: beautify.shadowStrength / 100
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 1.0
                        blurMax: Math.round(beautify.shadowBlur * 0.64)
                        autoPaddingEnabled: true
                    }
                }

                // the screenshot, rounded via a mask (no shadow/padding here, so
                // the mask stays aligned), plus the colour adjust
                Image {
                    id: img
                    anchors.fill: parent
                    source: beautify.srcPath ? ("file://" + beautify.srcPath) : ""
                    cache: false
                    fillMode: Image.Stretch
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: beautify.roundness > 0
                        maskSource: maskRect
                        brightness: beautify.adjBright / 100
                        contrast: beautify.adjContrast / 100
                        saturation: beautify.adjSat / 100
                    }
                }
                Rectangle {
                    id: maskRect
                    anchors.fill: parent
                    radius: beautify.roundness
                    visible: false
                    layer.enabled: true
                }
                // coloured border, tracing the same rounded shape
                Rectangle {
                    anchors.fill: parent
                    visible: beautify.borderW > 0
                    color: "transparent"
                    radius: beautify.roundness
                    border.width: beautify.borderW
                    border.color: beautify.borderColor
                }
            }

            // watermark
            Text {
                visible: beautify.watermark
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Math.max(14, beautify.padding * 0.28)
                text: "\u529b Ryoku"
                color: Qt.rgba(1, 1, 1, 0.85)
                font.family: "Noto Sans CJK JP"
                font.pixelSize: Math.max(16, beautify.fullW * 0.018)
                font.weight: Font.DemiBold
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.35)
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
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
        spacing: 14
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
            Rectangle { anchors.left: gh.right; anchors.leftMargin: 12; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 1; color: beautify.hair }
        }
        Column { id: body; width: grp.width; spacing: 14 }
    }

    component TopBtn: Rectangle {
        id: tbn
        property string label: ""
        property bool accent: false
        signal tapped()
        implicitWidth: tl.implicitWidth + 32
        implicitHeight: 36
        radius: 9
        color: tbn.accent ? (tbnMa.containsMouse ? Qt.lighter(beautify.vermilion, 1.12) : beautify.vermilion) : (tbnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        border.width: tbn.accent ? 0 : 1
        border.color: beautify.hair
        Text { id: tl; anchors.centerIn: parent; text: tbn.label; color: tbn.accent ? "#ffffff" : beautify.idle; font.family: "Space Grotesk"; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { id: tbnMa; anchors.fill: parent; hoverEnabled: true; onClicked: tbn.tapped() }
    }

    component BgType: Rectangle {
        id: bgt
        property string label: ""
        property bool on: false
        signal tapped()
        width: (parent.width - 3 * 8) / 4
        height: 30
        radius: 8
        color: bgt.on ? beautify.vermilion : (btMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : beautify.fieldBg)
        Text { anchors.centerIn: parent; text: bgt.label; color: bgt.on ? "#ffffff" : beautify.idle; font.family: "Space Grotesk"; font.pixelSize: 12; font.weight: bgt.on ? Font.DemiBold : Font.Medium }
        MouseArea { id: btMa; anchors.fill: parent; hoverEnabled: true; onClicked: bgt.tapped() }
    }

    component Pill: Rectangle {
        id: pill
        property string label: ""
        property bool on: false
        signal tapped()
        implicitWidth: pl.implicitWidth + 22
        height: 28
        radius: 8
        color: pill.on ? beautify.vermilion : (plMa.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : beautify.fieldBg)
        Text { id: pl; anchors.centerIn: parent; text: pill.label; color: pill.on ? "#ffffff" : beautify.idle; font.family: "Space Grotesk"; font.pixelSize: 12; font.weight: pill.on ? Font.DemiBold : Font.Medium }
        MouseArea { id: plMa; anchors.fill: parent; hoverEnabled: true; onClicked: pill.tapped() }
    }

    component ColorRow: Flow {
        id: cr
        property color current: "#ffffff"
        signal picked(color c)
        spacing: 7
        Repeater {
            model: beautify.palette
            Rectangle {
                id: sw
                required property var modelData
                width: 22
                height: 22
                radius: 6
                color: sw.modelData
                readonly property bool sel: Qt.colorEqual(cr.current, sw.modelData)
                border.color: sw.sel ? "#ffffff" : beautify.hair
                border.width: sw.sel ? 2 : 1
                scale: crMa.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 80 } }
                MouseArea { id: crMa; anchors.fill: parent; hoverEnabled: true; onClicked: cr.picked(sw.modelData) }
            }
        }
    }

    component ToggleRow: Item {
        id: tr
        property string label: ""
        property bool on: false
        signal toggled(bool v)
        width: parent.width
        height: 28
        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: tr.label; color: beautify.idle; font.family: "Space Grotesk"; font.pixelSize: 13; font.weight: Font.Medium }
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 24
            radius: 12
            color: tr.on ? beautify.vermilion : beautify.fieldBg
            border.width: 1
            border.color: tr.on ? beautify.vermilion : beautify.hair
            Rectangle {
                width: 18
                height: 18
                radius: 9
                y: 3
                x: tr.on ? parent.width - width - 3 : 3
                color: "#ffffff"
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; onClicked: tr.toggled(!tr.on) }
        }
    }
}
