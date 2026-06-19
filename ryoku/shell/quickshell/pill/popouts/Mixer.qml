pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Services.Pipewire
import ".."
import "../Singletons"

/**
 * Mixer popout content: a header (力 MIXER + DND / Keep-Awake chips) over a row
 * of vertical ink-faders wired to real hardware (per-monitor brightness via
 * ddcutil, vibrance via nvibrant, volume and mic via Pipewire). A plain
 * transparent Item; the frame blob behind it is the surface, and Popout sizes
 * and reveals it. Ported from the pill's Mixer, decoupled from PillSurface and
 * the pill's Ame bead. The fader under the pointer lights and the wheel nudges
 * it; the popout is pointer-driven, with no keyboard focus.
 */
Item {
    id: root

    property real s: 1

    anchors.fill: parent

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    property int focusIndex: -1
    readonly property int faderCount: faders.length
    readonly property var faders: {
        void brRep.count;
        var out = [];
        for (var i = 0; i < brRep.count; i++) {
            var f = brRep.itemAt(i);
            if (f)
                out.push(f);
        }
        out.push(vibFader, volFader, micFader);
        return out;
    }
    readonly property bool surfaceHovered: hoverTracker.hovered
    onSurfaceHoveredChanged: if (!surfaceHovered) focusIndex = -1

    // Pointer column under the cursor drives which fader lights. Coordinates are
    // body-local (the HoverHandler lives in `body`), matching faderRow's frame.
    readonly property int hoverIndex: surfaceHovered && body.width > 0
        && hoverTracker.point.position.y >= faderRow.y
        ? Math.max(0, Math.min(faders.length - 1, Math.floor(hoverTracker.point.position.x / (body.width / faders.length))))
        : -1
    onHoverIndexChanged: if (hoverIndex >= 0) focusIndex = hoverIndex

    /** Nudge the focused fader by `deltaPct` percent; true when one handled it. */
    function stepFocused(deltaPct) {
        if (focusIndex < 0)
            return false;
        faders[focusIndex].step(deltaPct);
        return true;
    }

    Component.onCompleted: Devices.detect()

    property real pendingVibrance: -1

    Timer {
        id: vibDebounce
        interval: 160
        onTriggered: if (root.pendingVibrance >= 0) {
            Devices.setVibrance(root.pendingVibrance);
            root.pendingVibrance = -1;
        }
    }

    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
    }

    component IconChip: Rectangle {
        id: chip
        property string glyph: ""
        property bool on: false
        signal toggled()

        width: 26 * root.s
        height: 26 * root.s
        radius: 8 * root.s
        color: chip.on ? Theme.frameBg : "transparent"
        border.width: 1
        border.color: chip.on ? Theme.frameBorder : Theme.border

        GlyphIcon {
            anchors.centerIn: parent
            width: 15 * root.s
            height: 15 * root.s
            name: chip.glyph
            color: chip.on ? Theme.vermLit : Theme.iconDim
            stroke: 1.7
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.toggled()
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.topMargin: 13 * root.s
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        anchors.bottomMargin: 14 * root.s

        HoverHandler {
            id: hoverTracker
        }

        Item {
            id: header
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 24 * root.s

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "力"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MIXER"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * root.s
                IconChip {
                    glyph: "dnd"
                    on: Flags.dnd
                    onToggled: Flags.dnd = !Flags.dnd
                }
                IconChip {
                    glyph: "awake"
                    on: Flags.keepAwake
                    onToggled: Flags.keepAwake = !Flags.keepAwake
                }
            }
        }

        Rectangle {
            id: divider
            anchors.top: header.bottom
            anchors.topMargin: 9 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hair
        }

        Row {
            id: faderRow
            anchors.top: divider.bottom
            anchors.topMargin: 10 * root.s
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            spacing: 0

            readonly property real colW: width / Math.max(1, root.faderCount)

            Repeater {
                id: brRep
                model: Devices.ddcMonitors

                VFader {
                    id: brFader

                    required property var modelData
                    required property int index

                    property int pct: 75
                    property real pendingPct: -1

                    width: faderRow.colW
                    s: root.s
                    icon: "sun"
                    subLabel: modelData.label
                    focused: root.focusIndex === index
                    value: pct / 100
                    valueLabel: pct + "%"
                    onMoved: (v) => pct = Math.max(5, Math.min(100, Math.round(v * 100)))
                    onCommitted: (v) => {
                        pendingPct = Math.max(5, Math.min(100, Math.round(v * 100)));
                        brCommit.restart();
                    }

                    Timer {
                        id: brCommit
                        interval: 160
                        onTriggered: if (brFader.pendingPct >= 0) {
                            Devices.setBrightness(brFader.modelData.bus, brFader.pendingPct);
                            brFader.pendingPct = -1;
                        }
                    }

                    Process {
                        id: brRead
                        command: ["timeout", "3", "ddcutil", "getvcp", "10", "--bus", brFader.modelData.bus, "--brief"]
                        running: true
                        stdout: StdioCollector {
                            onStreamFinished: {
                                var v = Devices.parseBrightness(this.text);
                                if (v >= 0)
                                    brFader.pct = v;
                            }
                        }
                    }
                }
            }

            VFader {
                id: vibFader
                width: faderRow.colW
                s: root.s
                icon: "monitor"
                focused: root.focusIndex === root.faderCount - 3
                value: Devices.vibrance / 100
                valueLabel: Devices.vibrance + "%"
                onMoved: (v) => Devices.vibrance = Math.round(v * 100)
                onCommitted: (v) => { root.pendingVibrance = v * 100; vibDebounce.restart(); }
            }
            VFader {
                id: volFader
                width: faderRow.colW
                s: root.s
                icon: "speaker"
                focused: root.focusIndex === root.faderCount - 2
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                valueLabel: Math.round((root.sink && root.sink.audio ? root.sink.audio.volume : 0) * 100) + "%"
                onMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
            }
            VFader {
                id: micFader
                width: faderRow.colW
                s: root.s
                icon: (root.source && root.source.audio && root.source.audio.muted) ? "mic-off" : "mic"
                focused: root.focusIndex === root.faderCount - 1
                value: root.source && root.source.audio ? root.source.audio.volume : 0
                valueLabel: (root.source && root.source.audio && root.source.audio.muted)
                    ? "off"
                    : (Math.round((root.source && root.source.audio ? root.source.audio.volume : 0) * 100) + "%")
                onMoved: (v) => { if (root.source && root.source.audio) root.source.audio.volume = v; }

                MouseArea {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 24 * root.s
                    height: 22 * root.s
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted; }
                }
            }
        }
    }

    // Wheel over a fader nudges it without a click.
    MouseArea {
        id: wheelArea
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        property real acc: 0
        onWheel: (event) => {
            acc += event.angleDelta.y / 120;
            const notches = Math.trunc(acc);
            if (notches !== 0 && root.stepFocused(notches * 5))
                acc -= notches;
            event.accepted = true;
        }
    }
}
