pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import "Singletons"

// A live, plain-QML mock of the shell so edits show instantly without pulling in
// the SDF blob plugin: a desktop behind the rounded screen frame, with the top
// island swelling out of the upper border. Faithful to the knobs that matter
// (rounding, border, colour, opacity, the inward contact shadow, island
// geometry), not a pixel copy of the metaball renderer. Drawn at a virtual
// 1920x1080 and scaled to fit, so every value reads in real shell pixels.
Item {
    id: preview

    property real frameRadius: 16
    property real frameBorder: 66
    property real frameOpacity: 1
    property real shadowStrength: 0.5
    property real shadowSize: 26
    property color surfaceColor: "#1a1b26"
    property real islandWidth: 108
    property real islandHeight: 38
    property real islandRestCorner: 18
    property real islandGap: 8
    property real islandOpacity: 1

    readonly property real vw: 1920
    readonly property real vh: 1080

    clip: true

    Item {
        id: stage
        width: preview.vw
        height: preview.vh
        anchors.centerIn: parent
        scale: Math.min(preview.width / preview.vw, preview.height / preview.vh)

        // Desktop behind the frame, so the hole reads as a window onto something.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2c2118" }
                GradientStop { position: 0.55; color: "#1c140e" }
                GradientStop { position: 1.0; color: "#241a2e" }
            }

            Rectangle {
                id: hole
                x: preview.frameBorder
                y: preview.frameBorder
                width: parent.width - 2 * preview.frameBorder
                height: parent.height - 2 * preview.frameBorder
                radius: preview.frameRadius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3b2d20" }
                    GradientStop { position: 1.0; color: "#1f1726" }
                }
            }
        }

        // The frame: a full surface sheet with the window hole punched out, plus
        // the soft contact shadow it throws inward onto the window.
        Item {
            id: frameSheet
            anchors.fill: parent
            opacity: preview.frameOpacity
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: holeMask
                maskInverted: true
                shadowEnabled: preview.shadowStrength > 0 && preview.shadowSize > 0
                shadowColor: "#000000"
                shadowOpacity: preview.shadowStrength
                shadowBlur: Math.max(0, Math.min(1, preview.shadowSize / 80))
                blurMax: 80
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
            Rectangle { anchors.fill: parent; color: preview.surfaceColor }
        }

        Item {
            id: holeMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle {
                x: hole.x
                y: hole.y
                width: hole.width
                height: hole.height
                radius: hole.radius
                color: "white"
            }
        }

        // The top island: fused flat to the upper border, swelling downward with
        // the rest-corner radius, in the same surface colour as the frame.
        Rectangle {
            id: islandPill
            width: preview.islandWidth
            height: preview.islandHeight
            x: (parent.width - width) / 2
            y: preview.islandGap
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: preview.islandRestCorner
            bottomRightRadius: preview.islandRestCorner
            color: preview.surfaceColor
            opacity: preview.islandOpacity

            Text {
                anchors.centerIn: parent
                text: Qt.formatTime(clk.date, "HH:mm")
                color: "#e0e6ff"
                font.family: Theme.mono
                font.pixelSize: preview.islandHeight * 0.44
                font.weight: Font.DemiBold
            }
        }

        SystemClock { id: clk; precision: SystemClock.Minutes }
    }
}
