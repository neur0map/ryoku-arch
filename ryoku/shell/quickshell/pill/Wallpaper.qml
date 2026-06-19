pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "Singletons"

/**
 * Wallpaper surface: a filmstrip over the wallpaper directory, rendered as one
 * of the pill's surfaces. Thumbs come from the Walls singleton snapshot, newest
 * first. The focused thumb is large and fully lit; neighbours shrink, dim and
 * desaturate as they slide under it, so the strip reads as depth. Arrow keys
 * and wheel move focus, clicking a neighbour glides to it, Enter or a tap on
 * the focused thumb applies it via ryoku-shell wallpaper (strip stays open so you can
 * keep trying picks). Hold the focused thumb for the heat duration to trash the
 * file (press-and-hold confirm, same as the clipboard wipe); progress sweeps
 * along the thumb's lower edge and drains on early release.
 */
PillSurface {
    id: root

    property int focusIndex: 0

    /**
     * Continuous view position chasing focusIndex. The strip renders from this
     * single value, so any input rate (40Hz key autorepeat, wheel bursts) stays
     * coherent: lag is bounded by the chase time constant, not piled up across
     * per-tile retargeting animations.
     */
    property real pos: 0

    clip: true

    readonly property var slotW:      [196, 126, 104, 88, 74]
    readonly property var slotH:      [110, 71, 59, 50, 42]
    readonly property var slotCX:     [0, 143, 244, 326, 393]
    readonly property var slotBright: [1, 0.56, 0.42, 0.30, 0.22]
    readonly property var slotSat:    [1, 0.65, 0.55, 0.45, 0.40]

    function slotLerp(arr, ao) {
        if (ao >= 4)
            return arr[4];
        var i = Math.floor(ao);
        var f = ao - i;
        return arr[i] + (arr[i + 1] - arr[i]) * f;
    }

    function offsetX(off) {
        var ao = Math.abs(off);
        var cx = ao <= 4 ? slotLerp(slotCX, ao) : slotCX[4] + (ao - 4) * 60;
        return (off < 0 ? -cx : cx) * s;
    }

    function move(delta) {
        if (Walls.count === 0)
            return;
        focusIndex = Math.max(0, Math.min(Walls.count - 1, focusIndex + delta));
    }

    FrameAnimation {
        running: root.active && root.pos !== root.focusIndex
        onTriggered: {
            var k = 1 - Math.exp(-frameTime / 0.07);
            var next = root.pos + (root.focusIndex - root.pos) * k;
            root.pos = Math.abs(next - root.focusIndex) < 0.001 ? root.focusIndex : next;
        }
    }

    function activate() {
        if (focusIndex < 0 || focusIndex >= Walls.count)
            return;
        Walls.apply(Walls.entries[focusIndex].path);
    }

    function centerOnCurrent() {
        var idx = 0;
        for (var i = 0; i < Walls.entries.length; i++)
            if (Walls.entries[i].path === Walls.current) {
                idx = i;
                break;
            }
        focusIndex = idx;
        pos = idx;
    }

    onActiveChanged: if (active) {
        Walls.refresh();
        centerOnCurrent();
    }

    Connections {
        target: Walls
        function onEntriesChanged() {
            if (root.focusIndex >= Walls.count)
                root.focusIndex = Math.max(0, Walls.count - 1);
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 20 * root.s
        anchors.verticalCenter: parent.verticalCenter
        z: 0
        text: "力"
        color: Theme.brand
        opacity: 0.55
        font.family: Theme.fontJp
        font.weight: Font.Medium
        font.pixelSize: 30 * root.s
    }

    Repeater {
        model: Walls.entries

        delegate: Item {
            id: tile

            required property int index
            required property var modelData

            readonly property real off: index - root.pos
            readonly property real ao: Math.abs(off)
            readonly property bool focused: index === root.focusIndex
            readonly property real bright: root.slotLerp(root.slotBright, ao)
            readonly property real sat: root.slotLerp(root.slotSat, ao)
            readonly property real corner: (8 + 2 * Math.max(0, 1 - ao)) * root.s

            readonly property real hold: trashHeat.hold
            readonly property bool holding: trashHeat.holding

            /**
             * Fade a tile out as its outer edge nears the clipped strip
             * boundary, so the strip ends soften instead of getting hard-cut by
             * the pill's clip.
             */
            readonly property real edgeFade: {
                var soft = 70 * root.s;
                var gap = Math.min(x, root.width - (x + width));
                return Math.max(0, Math.min(1, gap / soft));
            }

            width: root.slotLerp(root.slotW, ao) * root.s
            height: root.slotLerp(root.slotH, ao) * root.s
            x: root.width / 2 + root.offsetX(off) - width / 2
            y: (root.height - height) / 2
            z: 10 - ao
            visible: ao <= 5
            opacity: edgeFade * (ao <= 4 ? 1 : Math.max(0, 5 - ao))

            onFocusedChanged: if (!focused) trashHeat.cancel()

            ClippingRectangle {
                id: card
                anchors.fill: parent
                radius: tile.corner
                color: Theme.tileBg

                layer.enabled: true
                layer.effect: MultiEffect {
                    saturation: tile.sat - 1
                    shadowEnabled: tile.focused
                    shadowColor: Qt.rgba(0, 0, 0, Theme.shadowOpacity)
                    shadowBlur: 0.7
                    shadowVerticalOffset: 4 * root.s
                }

                Image {
                    anchors.fill: parent
                    source: tile.ao <= 6 ? "file://" + tile.modelData.thumb : ""
                    sourceSize.width: 512
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 1)
                    opacity: 1 - tile.bright
                }

                Rectangle {
                    id: consume
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: card.height * tile.hold
                    visible: tile.holding
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.alpha(Theme.vermBurn, 0.66) }
                        GradientStop { position: 0.74; color: Qt.alpha(Theme.vermLit, 0.30) }
                        GradientStop { position: 1.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 2 * root.s
                        opacity: Math.min(1, tile.hold * 3)
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                            GradientStop { position: 0.5; color: Theme.flameGlow }
                            GradientStop { position: 1.0; color: Qt.alpha(Theme.flameGlow, 0.0) }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: tile.corner
                color: "transparent"
                border.width: 1
                border.color: tile.holding ? Theme.vermLit : Theme.border
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }
            }

            HeatHold {
                id: trashHeat
                tapThreshold: 0.5
                onConfirmed: Walls.trash(tile.modelData.path)
                onTapped: root.activate()
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: if (tile.focused) trashHeat.press()
                onReleased: if (tile.focused) trashHeat.release()
                onExited: trashHeat.cancel()
                onClicked: if (!tile.focused) root.focusIndex = tile.index
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: Walls.count === 0
        text: "No wallpapers in ~/Pictures/Wallpapers"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 10.5 * root.s
    }

    MouseArea {
        id: wheelArea
        anchors.fill: parent
        z: 20
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: (event) => {
            acc += event.angleDelta.y / 120;
            const notches = Math.trunc(acc);
            if (notches !== 0) {
                root.move(-notches);
                acc -= notches;
            }
            event.accepted = true;
        }
    }
}
