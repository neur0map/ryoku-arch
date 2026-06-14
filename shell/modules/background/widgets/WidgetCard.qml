pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Ryoku.Config
import qs.components
import qs.components.effects
import qs.services

// Shared desktop-widget surface. Replaces the old flat translucent-grey rect +
// hairline border with frosted glass: an optional blurred slice of the wallpaper
// behind the card (clipped to the rounded shape, same technique as DesktopClock),
// an accent wash pulled from the live palette so cards never read as dead grey, a
// soft inner top highlight (light catching the rim) and a real elevation shadow.
//
// `content` (default) is padded; `backdrop` is a full-bleed, rounded-clipped slot
// behind the glass tint for widget-specific backgrounds (album art, battery fill).
// A gentle spring entrance gives the desktop some life.
Item {
    id: root

    property bool showBackground: true
    property real sizeScale: 1
    property real padding: Tokens.padding.large * sizeScale
    property real radius: Tokens.rounding.large * sizeScale
    property color tintColour: Colours.palette.m3primary
    property real tintAmount: 0.1
    property int elevation: 2

    // Frosted wallpaper backdrop (see DesktopClock). Parent passes the background
    // wallpaper item + the card's screen-space top-left so the blur lines up.
    property Item wallpaper: null
    property real screenX: 0
    property real screenY: 0
    readonly property bool blurOn: root.showBackground && !!root.wallpaper && !GameMode.enabled
    readonly property real surfaceOpacity: {
        if (!root.blurOn)
            return 0.58;
        // Keep the card on the scheme's side (dark in dark schemes, light in light)
        // regardless of wallpaper brightness so text stays legible: lift opacity
        // when the wallpaper would push the frost the wrong way.
        const adverse = Colours.light ? 1 - Colours.wallLuminance : Colours.wallLuminance;
        return Math.max(0.4, Math.min(0.82, 0.42 + adverse * 0.45));
    }

    default property alias content: holder.data
    property alias backdrop: backdropHolder.data

    implicitWidth: holder.childrenRect.width + root.padding * 2
    implicitHeight: holder.childrenRect.height + root.padding * 2

    Elevation {
        anchors.fill: surface
        z: -1
        radius: root.radius
        level: root.showBackground ? root.elevation : 0
        opacity: root.showBackground ? 1 : 0

        Behavior on opacity {
            Anim {}
        }
    }

    // Blurred wallpaper slice, clipped to the rounded card shape. Gated by a
    // Loader so GameMode / no-wallpaper truly releases the FBO.
    StyledClippingRect {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: root.blurOn

        Loader {
            anchors.fill: parent
            active: root.blurOn
            asynchronous: true

            sourceComponent: MultiEffect {
                anchors.fill: parent
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 48
                saturation: -0.1
                source: ShaderEffectSource {
                    sourceItem: root.wallpaper
                    sourceRect: Qt.rect(root.screenX, root.screenY, root.width, root.height)
                }
            }
        }
    }

    // Widget-specific full-bleed backdrop (album art, battery fill, …).
    StyledClippingRect {
        id: backdropHolder

        anchors.fill: parent
        radius: root.radius
        color: "transparent"
    }

    StyledRect {
        id: surface

        anchors.fill: parent
        radius: root.radius
        visible: root.showBackground
        color: Qt.alpha(Qt.tint(Colours.palette.m3surfaceContainer, Qt.rgba(root.tintColour.r, root.tintColour.g, root.tintColour.b, root.tintAmount)), root.surfaceOpacity)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)

        // Inner top highlight: a soft vertical fade plus a 1px crisp bevel line,
        // both tonal (m3onSurface) so they read on light and dark schemes alike.
        StyledClippingRect {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.min(parent.height / 2, 18 * root.sizeScale)
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.12)
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Qt.alpha(Colours.palette.m3onSurface, 0.16)
            }
        }
    }

    Item {
        id: holder

        anchors.fill: parent
        anchors.margins: root.padding
    }

    // Spring entrance (runs once when the widget is created).
    opacity: 0
    scale: 0.96

    Component.onCompleted: enter.start()

    ParallelAnimation {
        id: enter

        Anim {
            target: root
            property: "opacity"
            to: 1
            duration: Tokens.anim.durations.large
        }
        Anim {
            target: root
            property: "scale"
            to: 1
            type: Anim.DefaultSpatial
        }
    }
}
