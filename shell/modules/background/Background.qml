pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.services
import Quickshell.Services.UPower
import "../dashboard/dash" as Dash

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: contentItem.Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom
        color: contentItem.Config.background.wallpaperEnabled ? "black" : "transparent"
        surfaceFormat.opaque: false

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        Item {
            id: behindClock

            anchors.fill: parent

            Loader {
                id: wallpaper

                asynchronous: true

                anchors.fill: parent
                active: Config.background.wallpaperEnabled

                sourceComponent: Wallpaper {}
            }

            Visualiser {
                anchors.fill: parent
                screen: win.modelData
                wallpaper: wallpaper
            }
        }

        // Desktop widget host: draggable widgets on the background layer.
        Item {
            id: widgetHost

            anchors.fill: parent
            visible: Config.background.widgets.enabled

            readonly property real leftInset: Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.smaller, Config.border.thickness)

            // Snap-grid overlay, shown only while editing widgets.
            Canvas {
                id: gridOverlay

                anchors.fill: parent
                visible: Visibilities.widgetEditMode && GlobalConfig.background.widgets.snap
                opacity: 0.16
                z: -1

                readonly property int gridSize: Math.max(4, GlobalConfig.background.widgets.gridSize)

                onVisibleChanged: if (visible) requestPaint()
                onGridSizeChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = Colours.palette.m3onSurface;
                    ctx.lineWidth = 1;
                    const g = gridOverlay.gridSize;
                    ctx.beginPath();
                    for (let x = 0; x <= width; x += g) {
                        ctx.moveTo(x, 0);
                        ctx.lineTo(x, height);
                    }
                    for (let y = 0; y <= height; y += g) {
                        ctx.moveTo(0, y);
                        ctx.lineTo(width, y);
                    }
                    ctx.stroke();
                }
            }

            DesktopWidget {
                id: clockWidget

                cfg: GlobalConfig.background.desktopClock
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: "Clock"
                selfScales: true
                visible: Config.background.desktopClock.enabled

                DesktopClock {
                    wallpaper: behindClock
                    absX: clockWidget.x
                    absY: clockWidget.y
                }
            }

            DesktopWidget {
                cfg: GlobalConfig.background.widgets.resources
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: "Resources"
                visible: GlobalConfig.background.widgets.resources.enabled

                StyledRect {
                    // dash/Resources is a vertical bar chart that fills its
                    // parent height, so the backing sets a fixed height.
                    implicitWidth: resContent.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: 132
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.6)

                    Dash.Resources {
                        id: resContent

                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            DesktopWidget {
                cfg: GlobalConfig.background.widgets.weather
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: "Weather"
                visible: GlobalConfig.background.widgets.weather.enabled

                StyledRect {
                    implicitWidth: weatherContent.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: weatherContent.implicitHeight + Tokens.padding.large * 2
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.6)

                    Dash.SmallWeather {
                        id: weatherContent

                        anchors.centerIn: parent
                    }
                }
            }

            DesktopWidget {
                cfg: GlobalConfig.background.widgets.media
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: "Media"
                visible: GlobalConfig.background.widgets.media.enabled

                StyledRect {
                    implicitWidth: mediaContent.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: mediaContent.implicitHeight + Tokens.padding.large * 2
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.6)

                    Dash.Media {
                        id: mediaContent

                        anchors.centerIn: parent
                    }
                }
            }

            DesktopWidget {
                cfg: GlobalConfig.background.widgets.battery
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: "Battery"
                visible: GlobalConfig.background.widgets.battery.enabled && UPower.displayDevice.isLaptopBattery

                StyledRect {
                    implicitWidth: batteryRow.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: batteryRow.implicitHeight + Tokens.padding.large * 2
                    radius: Tokens.rounding.normal
                    color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.6)

                    Row {
                        id: batteryRow

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: UPower.displayDevice.state === UPowerDeviceState.Charging ? "battery_charging_full" : "battery_horiz_075"
                            color: UPower.displayDevice.percentage <= 0.2 ? Colours.palette.m3error : Colours.palette.m3primary
                            font.pointSize: Tokens.font.size.extraLarge
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                            color: Colours.palette.m3onSurface
                            font.pointSize: Tokens.font.size.extraLarge
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }
}
