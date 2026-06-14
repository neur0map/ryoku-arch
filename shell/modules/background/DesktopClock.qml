pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

Item {
    id: root

    required property Item wallpaper
    required property real absX
    required property real absY

    property real clockScale: GlobalConfig.background.desktopClock.scale
    readonly property string style: GlobalConfig.background.desktopClock.style
    readonly property bool bgEnabled: GlobalConfig.background.desktopClock.background.enabled
    readonly property bool blurEnabled: bgEnabled && GlobalConfig.background.desktopClock.background.blur && !GameMode.enabled
    readonly property bool invertColors: GlobalConfig.background.desktopClock.invertColors
    readonly property bool useLightSet: root.bgEnabled ? false : (Colours.light ? !root.invertColors : root.invertColors)
    readonly property color safePrimary: useLightSet ? Colours.palette.m3primaryContainer : Colours.palette.m3primary
    readonly property color safeSecondary: useLightSet ? Colours.palette.m3secondaryContainer : Colours.palette.m3secondary
    readonly property color safeTertiary: useLightSet ? Colours.palette.m3tertiaryContainer : Colours.palette.m3tertiary
    // On the frosted plate, digits contrast the PLATE: crisp onSurface text with an
    // accent colon/divider, not the muted wallpaper-contrast accent set.
    readonly property color clockText: root.bgEnabled ? Colours.palette.m3onSurface : root.safePrimary
    readonly property color clockTextDim: root.bgEnabled ? Colours.palette.m3onSurfaceVariant : root.safeSecondary
    readonly property color clockAccent: root.bgEnabled ? Colours.palette.m3primary : root.safeTertiary
    readonly property real frostAlpha: {
        const adverse = Colours.light ? 1 - Colours.wallLuminance : Colours.wallLuminance;
        return Math.max(0.4, Math.min(0.82, 0.42 + adverse * 0.45));
    }

    implicitWidth: content.implicitWidth + (Tokens.padding.large * 4 * root.clockScale)
    implicitHeight: content.implicitHeight + (Tokens.padding.large * 2 * root.clockScale)

    Item {
        id: clockContainer

        anchors.fill: parent

        layer.enabled: GlobalConfig.background.desktopClock.shadow.enabled
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3shadow
            shadowOpacity: GlobalConfig.background.desktopClock.shadow.opacity
            shadowBlur: GlobalConfig.background.desktopClock.shadow.blur
        }

        // Blurred wallpaper slice, clipped to the rounded shape (matches the
        // frosted WidgetCard family).
        StyledClippingRect {
            anchors.fill: parent
            radius: Tokens.rounding.large * root.clockScale
            color: "transparent"
            visible: root.blurEnabled

            Loader {
                anchors.fill: parent
                active: root.blurEnabled
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
                        sourceRect: Qt.rect(root.absX, root.absY, root.width, root.height)
                    }
                }
            }
        }

        StyledRect {
            id: backgroundPlate

            visible: root.bgEnabled
            anchors.fill: parent
            radius: Tokens.rounding.large * root.clockScale
            color: Qt.alpha(Qt.tint(Colours.palette.m3surfaceContainer, Qt.rgba(Colours.palette.m3primary.r, Colours.palette.m3primary.g, Colours.palette.m3primary.b, 0.1)), root.blurEnabled ? root.frostAlpha : GlobalConfig.background.desktopClock.background.opacity)
            border.width: 1
            border.color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
        }

        // Inner top highlight to match the frosted widget family.
        StyledClippingRect {
            anchors.fill: backgroundPlate
            radius: backgroundPlate.radius
            color: "transparent"
            visible: root.bgEnabled

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.min(parent.height / 2, 16 * root.clockScale)
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Qt.alpha(Colours.palette.m3onSurface, 0.1)
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
                color: Qt.alpha(Colours.palette.m3onSurface, 0.14)
            }
        }

        Loader {
            id: content

            anchors.centerIn: parent
            sourceComponent: {
                switch (root.style) {
                case "minimal":
                    return minimalStyle;
                case "stacked":
                    return stackedStyle;
                case "compact":
                    return compactStyle;
                default:
                    return modernStyle;
                }
            }
        }
    }

    // ── modern: time | divider | date column (default) ──────────────────────
    Component {
        id: modernStyle

        RowLayout {
            spacing: Tokens.spacing.larger * root.clockScale

            RowLayout {
                spacing: Tokens.spacing.small

                StyledText {
                    text: Time.hourStr
                    font.pointSize: Tokens.font.size.extraLarge * 3 * root.clockScale
                    font.weight: Font.Bold
                    color: root.clockText
                }
                StyledText {
                    text: ":"
                    font.pointSize: Tokens.font.size.extraLarge * 3 * root.clockScale
                    color: root.clockAccent
                    opacity: 0.8
                    Layout.topMargin: -Tokens.padding.large * 1.5 * root.clockScale

                    SequentialAnimation on opacity {
                        running: !GameMode.enabled
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 0.85
                            to: 0.35
                            duration: 1100
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 0.35
                            to: 0.85
                            duration: 1100
                            easing.type: Easing.InOutSine
                        }
                    }
                }
                StyledText {
                    text: Time.minuteStr
                    font.pointSize: Tokens.font.size.extraLarge * 3 * root.clockScale
                    font.weight: Font.Bold
                    color: root.clockText
                }
                Loader {
                    asynchronous: true
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: Tokens.padding.large * 1.4 * root.clockScale
                    active: GlobalConfig.services.useTwelveHourClock
                    visible: active
                    sourceComponent: StyledText {
                        text: Time.amPmStr
                        font.pointSize: Tokens.font.size.large * root.clockScale
                        color: root.clockTextDim
                    }
                }
            }

            StyledRect {
                Layout.fillHeight: true
                Layout.preferredWidth: 4 * root.clockScale
                Layout.topMargin: Tokens.spacing.larger * root.clockScale
                Layout.bottomMargin: Tokens.spacing.larger * root.clockScale
                radius: Tokens.rounding.full
                color: root.clockAccent
                opacity: 0.8
            }

            ColumnLayout {
                spacing: 0
                StyledText {
                    text: Time.format("MMMM").toUpperCase()
                    font.pointSize: Tokens.font.size.large * root.clockScale
                    font.letterSpacing: 4
                    font.weight: Font.Bold
                    color: root.clockTextDim
                }
                StyledText {
                    text: Time.format("dd")
                    font.pointSize: Tokens.font.size.extraLarge * root.clockScale
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                    color: root.clockText
                }
                StyledText {
                    text: Time.format("dddd")
                    font.pointSize: Tokens.font.size.larger * root.clockScale
                    font.letterSpacing: 2
                    color: root.clockTextDim
                }
            }
        }
    }

    // ── minimal: just the time ──────────────────────────────────────────────
    Component {
        id: minimalStyle

        RowLayout {
            spacing: Tokens.spacing.small

            StyledText {
                text: Time.hourStr + ":" + Time.minuteStr
                font.pointSize: Tokens.font.size.extraLarge * 3.2 * root.clockScale
                font.weight: Font.Bold
                color: root.safePrimary
            }
            Loader {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: Tokens.padding.large * 1.4 * root.clockScale
                active: GlobalConfig.services.useTwelveHourClock
                visible: active
                sourceComponent: StyledText {
                    text: Time.amPmStr
                    font.pointSize: Tokens.font.size.large * root.clockScale
                    color: root.safeSecondary
                }
            }
        }
    }

    // ── stacked: time over a single date line, centered ──────────────────────
    Component {
        id: stackedStyle

        ColumnLayout {
            spacing: Tokens.spacing.small * root.clockScale

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr + ":" + Time.minuteStr + (GlobalConfig.services.useTwelveHourClock ? " " + Time.amPmStr : "")
                font.pointSize: Tokens.font.size.extraLarge * 2.8 * root.clockScale
                font.weight: Font.Bold
                color: root.safePrimary
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.format("dddd, MMMM d").toUpperCase()
                font.pointSize: Tokens.font.size.normal * root.clockScale
                font.letterSpacing: 3
                font.weight: Font.Medium
                color: root.safeSecondary
            }
        }
    }

    // ── compact: time · short date on one line ────────────────────────────────
    Component {
        id: compactStyle

        RowLayout {
            spacing: Tokens.spacing.normal * root.clockScale

            StyledText {
                text: Time.hourStr + ":" + Time.minuteStr
                font.pointSize: Tokens.font.size.extraLarge * 1.4 * root.clockScale
                font.weight: Font.Bold
                color: root.safePrimary
            }
            StyledRect {
                Layout.preferredWidth: 3 * root.clockScale
                Layout.preferredHeight: parent.height * 0.6
                Layout.alignment: Qt.AlignVCenter
                radius: Tokens.rounding.full
                color: root.safeTertiary
                opacity: 0.7
            }
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: Time.format("ddd, MMM d")
                font.pointSize: Tokens.font.size.larger * root.clockScale
                font.weight: Font.Medium
                color: root.safeSecondary
            }
        }
    }

    Behavior on clockScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
