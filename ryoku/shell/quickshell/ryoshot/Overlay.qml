import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import "lib/coords.js" as Coords

Item {
    id: overlay
    anchors.fill: parent

    required property var screenData
    property var globalSel: null
    property bool capturing: false
    property bool ready: false

    property var model: null
    property var draft: null
    property int annRevision: 0
    property bool textEditing: false
    property var selectedIndex: null
    property var moveOffset: null
    property var hoverWindow: null

    signal pressedAt(real gx, real gy)
    signal movedTo(real gx, real gy)
    signal hovered(real gx, real gy)
    signal released()
    signal frozen()
    signal textChanged(string t)
    signal textCommitted()

    readonly property int sx: screenData.x
    readonly property int sy: screenData.y

    readonly property var localSel: globalSel
        ? Coords.intersectRect(globalSel, { x: sx, y: sy, width: width, height: height })
        : null

    readonly property color dimColor: Qt.rgba(15 / 255, 12 / 255, 7 / 255, 0.62)
    readonly property color vermilion: "#e2342a"

    function selectionBox() {
        if (selectedIndex === null || !model
            || selectedIndex < 0 || selectedIndex >= model.items.length) return null;
        var a = model.items[selectedIndex];
        var off = moveOffset || { x: 0, y: 0 };
        var xs = a.points.map(function (p) { return p.x; });
        var ys = a.points.map(function (p) { return p.y; });
        var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs);
        var y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
        var pad = Math.max((a.width || 4), 6);
        if (a.type === "text") {
            var size = a.size || 16;
            x1 = x0 + Math.max((a.text ? a.text.length : 1) * size * 0.6, size);
            y1 = y0 + size * 1.4;
            pad = 4;
        }
        return {
            x: x0 - sx + off.x - pad,
            y: y0 - sy + off.y - pad,
            w: (x1 - x0) + pad * 2,
            h: (y1 - y0) + pad * 2
        };
    }

    readonly property var selBox: { annRevision; return selectionBox(); }

    Item {
        id: scene
        anchors.fill: parent

        ScreencopyView {
            id: frozen
            anchors.fill: parent
            captureSource: overlay.screenData
            live: false
            paintCursor: false
        }

        function effectItems() {
            var src = overlay.model ? overlay.model.items : [];
            var out = [];
            for (var i = 0; i < src.length; i++)
                if (src[i] && (src[i].type === "blur" || src[i].type === "pixelate" || src[i].type === "magnify")) out.push(src[i]);
            if (overlay.draft && (overlay.draft.type === "blur" || overlay.draft.type === "pixelate" || overlay.draft.type === "magnify")) out.push(overlay.draft);
            return out;
        }

        Repeater {
            model: { overlay.annRevision; return scene.effectItems(); }

            Item {
                required property var modelData
                readonly property var a: modelData
                readonly property bool valid: a !== undefined && a !== null && a.points !== undefined && a.points.length >= 2
                readonly property real rx: valid ? Math.min(a.points[0].x, a.points[1].x) - overlay.sx : 0
                readonly property real ry: valid ? Math.min(a.points[0].y, a.points[1].y) - overlay.sy : 0
                readonly property real rw: valid ? Math.abs(a.points[1].x - a.points[0].x) : 0
                readonly property real rh: valid ? Math.abs(a.points[1].y - a.points[0].y) : 0
                readonly property bool isPix: valid && a.type === "pixelate"
                readonly property real block: valid ? ((a.width || 4) * 2 + 8) : 12
                readonly property bool isMag: valid && a.type === "magnify"
                readonly property real magD: Math.min(rw, rh)
                readonly property real magZoom: 2.0
                x: rx
                y: ry
                width: rw
                height: rh
                visible: valid && rw > 0 && rh > 0
                clip: true

                ShaderEffectSource {
                    id: blurSrc
                    sourceItem: frozen
                    anchors.fill: parent
                    live: false
                    recursive: false
                    sourceRect: Qt.rect(parent.rx, parent.ry, parent.rw, parent.rh)
                    visible: false
                }

                FastBlur {
                    anchors.fill: parent
                    source: blurSrc
                    radius: 64
                    visible: parent.valid && parent.a.type === "blur"
                }

                ShaderEffectSource {
                    anchors.fill: parent
                    visible: parent.isPix
                    sourceItem: frozen
                    live: false
                    recursive: false
                    sourceRect: Qt.rect(parent.rx, parent.ry, parent.rw, parent.rh)
                    textureSize: Qt.size(Math.max(1, Math.round(parent.rw / parent.block)),
                                         Math.max(1, Math.round(parent.rh / parent.block)))
                    smooth: false
                }

                ShaderEffectSource {
                    id: magSrc
                    width: parent.magD
                    height: parent.magD
                    anchors.centerIn: parent
                    sourceItem: frozen
                    live: false
                    recursive: false
                    sourceRect: Qt.rect(parent.rx + parent.rw / 2 - parent.magD / (2 * parent.magZoom),
                                         parent.ry + parent.rh / 2 - parent.magD / (2 * parent.magZoom),
                                         parent.magD / parent.magZoom, parent.magD / parent.magZoom)
                    visible: false
                }
                Rectangle {
                    id: magMask
                    width: parent.magD
                    height: parent.magD
                    anchors.centerIn: parent
                    radius: parent.magD / 2
                    visible: false
                    layer.enabled: true
                }
                OpacityMask {
                    width: parent.magD
                    height: parent.magD
                    anchors.centerIn: parent
                    source: magSrc
                    maskSource: magMask
                    visible: parent.isMag
                }
                Rectangle {
                    width: parent.magD
                    height: parent.magD
                    anchors.centerIn: parent
                    radius: parent.magD / 2
                    color: "transparent"
                    border.color: "#ffffff"
                    border.width: Math.max(2, parent.magD * 0.03)
                    visible: parent.isMag
                }
            }
        }

        AnnLayer {
            id: annCanvas
            anchors.fill: parent
            sx: overlay.sx
            sy: overlay.sy
            model: overlay.model
            draft: overlay.draft
            revision: overlay.annRevision
            selectedIndex: overlay.selectedIndex
            moveOffset: overlay.moveOffset
        }
    }

    Timer {
        id: capTimer
        interval: 50
        repeat: true
        running: true
        property int tries: 0
        onTriggered: {
            tries += 1;
            if (frozen.hasContent) {
                running = false;
                overlay.ready = true;
                overlay.frozen();
            } else if (tries > 60) {
                running = false;
            } else {
                frozen.captureFrame();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: overlay.dimColor
        visible: overlay.ready && overlay.localSel === null
    }

    Item {
        anchors.fill: parent
        visible: overlay.ready && overlay.localSel !== null
        Rectangle {
            color: overlay.dimColor
            x: 0; y: 0; width: parent.width
            height: overlay.localSel ? overlay.localSel.y : 0
        }
        Rectangle {
            color: overlay.dimColor
            x: 0; width: parent.width
            y: overlay.localSel ? overlay.localSel.y + overlay.localSel.h : 0
            height: overlay.localSel ? parent.height - (overlay.localSel.y + overlay.localSel.h) : 0
        }
        Rectangle {
            color: overlay.dimColor
            x: 0
            y: overlay.localSel ? overlay.localSel.y : 0
            width: overlay.localSel ? overlay.localSel.x : 0
            height: overlay.localSel ? overlay.localSel.h : 0
        }
        Rectangle {
            color: overlay.dimColor
            x: overlay.localSel ? overlay.localSel.x + overlay.localSel.w : 0
            y: overlay.localSel ? overlay.localSel.y : 0
            width: overlay.localSel ? parent.width - (overlay.localSel.x + overlay.localSel.w) : 0
            height: overlay.localSel ? overlay.localSel.h : 0
        }
    }

    Item {
        id: chrome
        visible: overlay.ready && overlay.localSel !== null
        x: overlay.localSel ? overlay.localSel.x : 0
        y: overlay.localSel ? overlay.localSel.y : 0
        width: overlay.localSel ? overlay.localSel.w : 0
        height: overlay.localSel ? overlay.localSel.h : 0

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: overlay.vermilion
            border.width: 1.5
        }

        Repeater {
            model: [
                { hx: 0, hy: 0 },
                { hx: 1, hy: 0 },
                { hx: 0, hy: 1 },
                { hx: 1, hy: 1 }
            ]
            Rectangle {
                required property var modelData
                width: 8; height: 8
                color: overlay.vermilion
                x: modelData.hx * (chrome.width - width)
                y: modelData.hy * (chrome.height - height)
            }
        }

        Text {
            text: overlay.globalSel
                ? "ryoshot · " + Math.round(overlay.globalSel.w) + "×" + Math.round(overlay.globalSel.h)
                : ""
            color: overlay.vermilion
            font.family: "JetBrains Mono"
            font.pixelSize: 13
            x: 0
            y: -height - 4
        }
    }

    Item {
        id: winHighlight
        readonly property var hw: overlay.hoverWindow
            ? Coords.intersectRect(overlay.hoverWindow, { x: overlay.sx, y: overlay.sy, width: overlay.width, height: overlay.height })
            : null
        visible: overlay.ready && overlay.globalSel === null && hw !== null
        x: hw ? hw.x : 0
        y: hw ? hw.y : 0
        width: hw ? hw.w : 0
        height: hw ? hw.h : 0

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.88, 0.34, 0.23, 0.16)
            border.color: overlay.vermilion
            border.width: 2.5
            antialiasing: true
        }
    }

    Item {
        id: annSelection
        visible: overlay.ready && overlay.selBox !== null
        x: overlay.selBox ? overlay.selBox.x : 0
        y: overlay.selBox ? overlay.selBox.y : 0
        width: overlay.selBox ? overlay.selBox.w : 0
        height: overlay.selBox ? overlay.selBox.h : 0

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: overlay.vermilion
            border.width: 1
            antialiasing: true
        }

        Repeater {
            model: [
                { hx: 0, hy: 0 },
                { hx: 1, hy: 0 },
                { hx: 0, hy: 1 },
                { hx: 1, hy: 1 }
            ]
            Rectangle {
                required property var modelData
                width: 7; height: 7
                radius: 1
                color: overlay.vermilion
                x: modelData.hx * (annSelection.width - width)
                y: modelData.hy * (annSelection.height - height)
            }
        }
    }

    Item {
        id: exportClip
        clip: true
        visible: false
        width: overlay.localSel ? overlay.localSel.w : 0
        height: overlay.localSel ? overlay.localSel.h : 0

        ShaderEffectSource {
            sourceItem: scene
            width: scene.width
            height: scene.height
            x: overlay.localSel ? -overlay.localSel.x : 0
            y: overlay.localSel ? -overlay.localSel.y : 0
            live: true
            recursive: false
        }
    }

    function grabExport(path, cb) {
        if (!overlay.localSel) { cb(false); return; }
        var scheduled = exportClip.grabToImage(function (result) {
            var ok = false;
            try { ok = result ? result.saveToFile(path) : false; }
            catch (e) { console.log("ryoshot: saveToFile failed: " + e); }
            if (cb) cb(ok);
        });
        if (!scheduled && cb) cb(false);
    }

    MouseArea {
        anchors.fill: parent
        enabled: overlay.ready
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.CrossCursor
        onPressed: (m) => overlay.pressedAt(m.x + overlay.sx, m.y + overlay.sy)
        onPositionChanged: (m) => {
            if (overlay.capturing) overlay.movedTo(m.x + overlay.sx, m.y + overlay.sy);
            else overlay.hovered(m.x + overlay.sx, m.y + overlay.sy);
        }
        onReleased: overlay.released()
    }

    TextInput {
        id: textEdit
        readonly property bool mine: overlay.textEditing && overlay.draft
            && overlay.draft.type === "text" && overlay.localSel !== null
            && (overlay.draft.points[0].x >= overlay.sx) && (overlay.draft.points[0].x < overlay.sx + overlay.width)
            && (overlay.draft.points[0].y >= overlay.sy) && (overlay.draft.points[0].y < overlay.sy + overlay.height)
        visible: mine
        enabled: mine
        x: mine ? overlay.draft.points[0].x - overlay.sx : 0
        y: mine ? overlay.draft.points[0].y - overlay.sy : 0
        color: mine ? overlay.draft.color : "transparent"
        font.family: "Space Grotesk"
        font.pixelSize: mine ? overlay.draft.size : 16
        renderType: Text.NativeRendering
        cursorVisible: mine
        autoScroll: false
        onTextEdited: overlay.textChanged(text)
        onMineChanged: if (mine) { text = overlay.draft.text || ""; forceActiveFocus(); }
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { overlay.textCommitted(); e.accepted = true; }
            else if (e.key === Qt.Key_Escape) { e.accepted = false; }
        }
    }
}
