pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Strips: the focused wallpaper opens to a large preview at centre — the whole
// image, in its own aspect — while the rest flank it as thin portrait strips, a
// hero plus a shelf. A wheel or arrow steps the focus; the preview and strips
// glide and morph on an OutCubic slide. A pointer-move gate stops a strip that
// slides under a still cursor from stealing the keyboard focus. Cells reuse
// WallCell / ThemeCell, so live previews, the on-air dot and hover come free.
Item {
    id: strip

    required property real s
    required property var model
    required property string kind            // "wall" | "theme"
    required property color bg
    property int selIndex: 0
    property bool active: true
    property string activeKey: ""
    property bool interactive: true
    signal focusIndex(int i)
    signal chosen(int i)

    readonly property int count: model ? model.length : 0
    readonly property int gap: Math.round(10 * s)

    readonly property real previewH: Math.round(height * (strip.kind === "theme" ? 0.5 : 0.46))
    readonly property real previewW: strip.kind === "theme"
        ? Math.round(previewH * 0.74)
        : Math.round(previewH * 16 / 9)
    readonly property real stripW: Math.round(height * 0.05)
    readonly property real stripH: Math.round(previewH * 0.8)
    readonly property int maxSide: Math.ceil((width / 2) / (stripW + gap)) + 1

    function wFor(rel) { return rel === 0 ? strip.previewW : strip.stripW }
    function hFor(rel) { return rel === 0 ? strip.previewH : strip.stripH }
    function leftEdge(rel) {
        var cx = strip.width / 2;
        if (rel === 0)
            return cx - strip.previewW / 2;
        if (rel > 0) {
            var x = cx + strip.previewW / 2 + strip.gap;
            for (var d = 1; d < rel; d++)
                x += strip.stripW + strip.gap;
            return x;
        }
        var right = cx - strip.previewW / 2 - strip.gap;
        for (var e = 1; e <= -rel; e++) {
            if (e === -rel)
                return right - strip.stripW;
            right -= (strip.stripW + strip.gap);
        }
        return right;
    }

    // gate live video off while the shelf is travelling.
    property bool moving: false
    onSelIndexChanged: { strip.moving = true; movingCool.restart(); }
    Timer { id: movingCool; interval: 320; onTriggered: strip.moving = false }

    // pointer-move gate: only a real cursor move focuses a strip, so strips
    // sliding under a still cursor never fight the arrow keys.
    property bool pointerLive: false
    property point hoverPt: areaHover.point.position
    onHoverPtChanged: { strip.pointerLive = true; pointerCool.restart(); }
    HoverHandler { id: areaHover }
    Timer { id: pointerCool; interval: 130; onTriggered: strip.pointerLive = false }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            if (strip.count <= 1) return;
            var step = e.angleDelta.y < 0 ? 1 : -1;
            var ni = Math.max(0, Math.min(strip.count - 1, strip.selIndex + step));
            if (ni !== strip.selIndex)
                strip.focusIndex(ni);
        }
    }

    Repeater {
        model: strip.model
        delegate: Item {
            id: slot
            required property int index
            required property var modelData
            readonly property int rel: index - strip.selIndex
            readonly property bool near: Math.abs(rel) <= strip.maxSide
            readonly property bool foc: rel === 0

            visible: slot.near
            width: strip.wFor(rel)
            height: strip.hFor(rel)
            x: strip.leftEdge(rel)
            y: (strip.height - height) / 2
            z: slot.foc ? 100 : 60 - Math.abs(rel)
            opacity: slot.near ? 1 : 0

            Behavior on x { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Loader {
                anchors.fill: parent
                sourceComponent: strip.kind === "theme" ? themeC : wallC
            }
            Component {
                id: wallC
                WallCell {
                    s: strip.s; item: slot.modelData; bg: strip.bg
                    selected: slot.foc
                    live: slot.visible
                    beltMoving: strip.moving
                    onEntered: if (strip.pointerLive) strip.focusIndex(slot.index)
                    onChosen: strip.chosen(slot.index)
                }
            }
            Component {
                id: themeC
                ThemeCell {
                    s: strip.s; item: slot.modelData; bg: strip.bg
                    selected: slot.foc
                    active: !!slot.modelData && slot.modelData.id === strip.activeKey
                    interactive: strip.interactive
                    onEntered: if (strip.pointerLive) strip.focusIndex(slot.index)
                    onChosen: strip.chosen(slot.index)
                }
            }

            // recede the flanking strips into the dark.
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusWidget
                color: "black"
                opacity: slot.foc ? 0 : Math.min(0.4, 0.14 + Math.abs(slot.rel) * 0.05)
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // name caption on the focused preview (a photo placard).
            Rectangle {
                visible: slot.foc && slot.modelData
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Math.round(12 * strip.s)
                height: Math.round(22 * strip.s)
                width: capRow.implicitWidth + Math.round(16 * strip.s)
                radius: Math.round(4 * strip.s)
                color: Qt.rgba(0, 0, 0, 0.5)
                Row {
                    id: capRow
                    anchors.centerIn: parent
                    spacing: Math.round(8 * strip.s)
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: strip.kind === "theme"
                            ? (slot.modelData ? slot.modelData.label : "")
                            : (slot.modelData ? slot.modelData.name : "")
                        color: "white"
                        font.family: Theme.mono
                        font.pixelSize: Math.round(11 * strip.s)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: strip.kind !== "theme" && slot.modelData
                        text: slot.modelData ? Colors.names[slot.modelData.group].toUpperCase() : ""
                        color: Qt.rgba(1, 1, 1, 0.6)
                        font.family: Theme.mono
                        font.pixelSize: Math.round(8.5 * strip.s)
                        font.letterSpacing: 1.4 * strip.s
                    }
                }
            }
        }
    }

    // red seal brushed beneath the focused preview.
    Rectangle {
        visible: strip.count > 0
        width: strip.previewW * 0.5
        height: Math.max(2, Math.round(3 * strip.s))
        x: (strip.width - width) / 2
        y: (strip.height + strip.previewH) / 2 + Math.round(9 * strip.s)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(Theme.seal, 0) }
            GradientStop { position: 0.5; color: Theme.seal }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.seal, 0) }
        }
    }
}
