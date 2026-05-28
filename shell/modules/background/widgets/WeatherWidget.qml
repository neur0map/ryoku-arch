pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

// Self-contained desktop weather card. Style switches the presentation: "default"
// icon+temp+description, "minimal" icon+temp, "detailed" adds feels-like/humidity/wind.
StyledRect {
    id: root

    property bool showBackground: true
    property real sizeScale: 1
    readonly property string style: GlobalConfig.background.widgets.weather.style

    readonly property real pad: Tokens.padding.large * sizeScale

    implicitWidth: content.implicitWidth + pad * 2
    implicitHeight: content.implicitHeight + pad * 2
    radius: Tokens.rounding.large * sizeScale
    color: showBackground ? Qt.alpha(Colours.palette.m3surfaceContainer, 0.78) : "transparent"
    border.width: showBackground ? 1 : 0
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

    Component.onCompleted: Weather.reload()

    Loader {
        id: content
        anchors.centerIn: parent
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

    // ── default: icon + temp + description ───────────────────────────────────
    Component {
        id: cardStyle

        RowLayout {
            spacing: Tokens.spacing.normal * root.sizeScale

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                animate: true
                text: Weather.icon
                color: Colours.palette.m3secondary
                font.pointSize: Tokens.font.size.extraLarge * 1.9 * root.sizeScale
                fill: 1
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                StyledText {
                    animate: true
                    text: Weather.temp
                    color: Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.extraLarge * root.sizeScale
                    font.weight: Font.Medium
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
            spacing: Tokens.spacing.small * root.sizeScale

            MaterialIcon {
                Layout.alignment: Qt.AlignVCenter
                animate: true
                text: Weather.icon
                color: Colours.palette.m3secondary
                font.pointSize: Tokens.font.size.extraLarge * 1.3 * root.sizeScale
                fill: 1
            }
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                animate: true
                text: Weather.temp
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.extraLarge * root.sizeScale
                font.weight: Font.Medium
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
                spacing: Tokens.spacing.normal * root.sizeScale

                MaterialIcon {
                    Layout.alignment: Qt.AlignVCenter
                    animate: true
                    text: Weather.icon
                    color: Colours.palette.m3secondary
                    font.pointSize: Tokens.font.size.extraLarge * 2.1 * root.sizeScale
                    fill: 1
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    StyledText {
                        animate: true
                        text: Weather.temp
                        color: Colours.palette.m3primary
                        font.pointSize: Tokens.font.size.extraLarge * root.sizeScale
                        font.weight: Font.Medium
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

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Qt.alpha(Colours.palette.m3outlineVariant, 0.5)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.larger * root.sizeScale

                DetailStat {
                    icon: "thermostat"
                    text: Weather.feelsLike
                }
                DetailStat {
                    icon: "humidity_percentage"
                    text: Weather.humidity + "%"
                }
                DetailStat {
                    icon: "air"
                    text: Math.round(Weather.windSpeed) + ""
                }
            }
        }
    }

    component DetailStat: RowLayout {
        id: ds
        required property string icon
        required property string text
        spacing: Tokens.spacing.smaller * root.sizeScale

        MaterialIcon {
            text: ds.icon
            color: Colours.palette.m3tertiary
            font.pointSize: Tokens.font.size.normal * root.sizeScale
        }
        StyledText {
            text: ds.text
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.small * root.sizeScale
        }
    }
}
