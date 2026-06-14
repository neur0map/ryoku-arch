pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

// Self-contained desktop weather card. Style switches the presentation: "default"
// hero icon+temp+description, "minimal" icon+temp, "detailed" adds tonal
// feels-like/humidity/wind chips. The condition glyph gently breathes for life.
WidgetCard {
    id: root

    readonly property string style: GlobalConfig.background.widgets.weather.style

    Component.onCompleted: Weather.reload()

    Loader {
        id: content

        sourceComponent: {
            switch (root.style) {
            case "minimal":
                return minimalStyle;
            case "detailed":
                return detailedStyle;
            default:
                return cardStyle;
            }
        }
    }

    // A condition glyph that slowly breathes — cheap ambient motion.
    component WeatherGlyph: MaterialIcon {
        animate: true
        text: Weather.icon
        color: Colours.palette.m3secondary
        fill: 1

        SequentialAnimation on scale {
            running: !GameMode.enabled
            loops: Animation.Infinite
            NumberAnimation {
                from: 1
                to: 1.06
                duration: 2600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 1.06
                to: 1
                duration: 2600
                easing.type: Easing.InOutSine
            }
        }
    }

    // ── default: hero icon + temp + description ──────────────────────────────
    Component {
        id: cardStyle

        RowLayout {
            spacing: Tokens.spacing.large * root.sizeScale

            WeatherGlyph {
                Layout.alignment: Qt.AlignVCenter
                font.pointSize: Tokens.font.size.extraLarge * 2.1 * root.sizeScale
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                StyledText {
                    animate: true
                    text: Weather.temp
                    color: Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.extraLarge * 1.15 * root.sizeScale
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.maximumWidth: 180 * root.sizeScale
                    animate: true
                    text: Weather.description
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small * root.sizeScale
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ── minimal: icon + temp ─────────────────────────────────────────────────
    Component {
        id: minimalStyle

        RowLayout {
            spacing: Tokens.spacing.normal * root.sizeScale

            WeatherGlyph {
                Layout.alignment: Qt.AlignVCenter
                font.pointSize: Tokens.font.size.extraLarge * 1.4 * root.sizeScale
            }
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                animate: true
                text: Weather.temp
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.extraLarge * root.sizeScale
                font.weight: Font.DemiBold
            }
        }
    }

    // ── detailed: header + feels-like / humidity / wind ──────────────────────
    Component {
        id: detailedStyle

        ColumnLayout {
            spacing: Tokens.spacing.normal * root.sizeScale

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.large * root.sizeScale

                WeatherGlyph {
                    Layout.alignment: Qt.AlignVCenter
                    font.pointSize: Tokens.font.size.extraLarge * 2.1 * root.sizeScale
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    StyledText {
                        animate: true
                        text: Weather.temp
                        color: Colours.palette.m3primary
                        font.pointSize: Tokens.font.size.extraLarge * 1.15 * root.sizeScale
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.maximumWidth: 200 * root.sizeScale
                        animate: true
                        text: Weather.description
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small * root.sizeScale
                        elide: Text.ElideRight
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small * root.sizeScale

                DetailChip {
                    icon: "thermostat"
                    text: Weather.feelsLike
                }
                DetailChip {
                    icon: "humidity_percentage"
                    text: Weather.humidity + "%"
                }
                DetailChip {
                    icon: "air"
                    text: Math.round(Weather.windSpeed) + ""
                }
            }
        }
    }

    component DetailChip: StyledRect {
        id: chip

        required property string icon
        required property string text

        Layout.fillWidth: true
        implicitHeight: chipRow.implicitHeight + Tokens.padding.small * 2 * root.sizeScale
        radius: Tokens.rounding.normal * root.sizeScale
        color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.55)

        RowLayout {
            id: chipRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.smaller * root.sizeScale

            MaterialIcon {
                text: chip.icon
                color: Colours.palette.m3tertiary
                fill: 1
                font.pointSize: Tokens.font.size.normal * root.sizeScale
            }
            StyledText {
                text: chip.text
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small * root.sizeScale
                font.weight: Font.Medium
            }
        }
    }
}
