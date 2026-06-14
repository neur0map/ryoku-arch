import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.dashboard.modules.theme
import qs.dashboard.modules.components
import qs.dashboard.modules.globals
import qs.dashboard.modules.services
import qs.dashboard.config
import "calendar"

Rectangle {
    color: "transparent"
    implicitWidth: 600
    implicitHeight: 750

    property int leftPanelWidth: 0

    RowLayout {
        anchors.fill: parent
        spacing: 8

        FullPlayer {
            Layout.preferredWidth: 216
            Layout.fillHeight: true
        }

        ClippingRectangle {
            id: widgetsContainer
            Layout.preferredWidth: controlButtonsContainer.implicitWidth
            Layout.fillHeight: true
            radius: Styling.radius(4)
            color: "transparent"

            property bool circularControlDragging: false

            Flickable {
                id: widgetsFlickable
                anchors.fill: parent
                contentWidth: width
                contentHeight: columnLayout.implicitHeight
                clip: true
                interactive: !widgetsContainer.circularControlDragging

                ColumnLayout {
                    id: columnLayout
                    width: parent.width
                    spacing: 8

                    QuickControls {
                        id: controlButtonsContainer
                    }

                    Calendar {
                        Layout.fillWidth: true
                        Layout.preferredHeight: width
                    }

                    StyledRect {
                        variant: "pane"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                    }
                }
            }
        }

        // RYOKU PORT: weather card — replaces the notification card (ryoku has its own
        // notification center). The dashboard's animated weather scene + the 5-day forecast strip
        // (same as the dashboard's clock popout), fed by ryoku's Weather (Open-Meteo) via
        // WeatherService. Fills the slot the notification card used to occupy.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            ClippingRectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Styling.radius(4)
                color: "transparent"

                WeatherWidget {
                    anchors.fill: parent
                    showDebugControls: false
                    animationsEnabled: GlobalStates.dashboardOpen
                }
            }

            StyledRect {
                id: forecastStrip
                variant: "pane"
                Layout.fillWidth: true
                Layout.preferredHeight: forecastRow.implicitHeight + 16
                visible: WeatherService.dataAvailable && WeatherService.forecast.length > 0

                Row {
                    id: forecastRow
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: WeatherService.forecast.slice(0, 5)

                        Row {
                            id: fDayRow
                            required property var modelData
                            required property int index
                            spacing: 4

                            Column {
                                id: fDay
                                spacing: 2
                                width: (forecastStrip.width - 16 - (4 * 4) - (4 * 6)) / 5

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: fDayRow.modelData.dayName
                                    color: Colors.overBackground
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Medium
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: fDayRow.modelData.emoji
                                    font.pixelSize: Styling.fontSize(4)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (Math.round(fDayRow.modelData.maxTemp) >= 0 ? "+" : "") + Math.round(fDayRow.modelData.maxTemp) + "°"
                                    color: Colors.overBackground
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Bold
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: (Math.round(fDayRow.modelData.minTemp) >= 0 ? "+" : "") + Math.round(fDayRow.modelData.minTemp) + "°"
                                    color: Colors.outline
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Normal
                                }
                            }

                            Separator {
                                vert: true
                                visible: fDayRow.index < 4
                                anchors.verticalCenter: parent.verticalCenter
                                height: fDay.height - 16
                            }
                        }
                    }
                }
            }
        }

    }
}
