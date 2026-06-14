pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.effects
import qs.services
import "widgets"

Variants {
    model: Screens.screens.filter(s => GlobalConfig.forScreen(s.name).background.enabled)

    StyledWindow {
        id: win

        required property ShellScreen modelData

        screen: modelData
        name: "background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: contentItem.Config.background.wallpaperEnabled ? WlrLayer.Background : WlrLayer.Bottom
        // Allow on-demand keyboard focus only while sticky notes exist, so they can
        // be typed into; clicking elsewhere doesn't steal focus.
        WlrLayershell.keyboardFocus: Notes.list.length > 0 ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        // Use transparent clear color for live backends so their surface shows through.
        color: contentItem.Config.background.wallpaperEnabled && Wallpapers.currentType === "image" ? "black" : "transparent"
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
            readonly property bool editing: Visibilities.widgetEditMode

            // Right-click anywhere on the desktop opens the context menu. Sits
            // below the widgets (z 0); right-clicks on a widget's empty area
            // fall through to here.
            MouseArea {
                anchors.fill: parent
                z: 0
                acceptedButtons: Qt.RightButton
                onClicked: mouse => {
                    desktopMenu.px = mouse.x;
                    desktopMenu.py = mouse.y;
                    desktopMenu.open = true;
                }
            }

            // Snap-grid overlay, shown only while editing widgets.
            Canvas {
                id: gridOverlay

                z: 1
                anchors.fill: parent
                visible: widgetHost.editing && GlobalConfig.background.widgets.snap
                opacity: 0.16

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

                z: 2
                cfg: GlobalConfig.background.desktopClock
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: qsTr("Clock")
                selfScales: true
                visible: Config.background.desktopClock.enabled

                DesktopClock {
                    wallpaper: behindClock
                    absX: clockWidget.x
                    absY: clockWidget.y
                }
            }

            DesktopWidget {
                id: resourcesWidget

                z: 2
                cfg: GlobalConfig.background.widgets.resources
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: qsTr("Resources")
                selfScales: true
                visible: GlobalConfig.background.widgets.resources.enabled

                ResourcesWidget {
                    showBackground: GlobalConfig.background.widgets.resources.background
                    sizeScale: GlobalConfig.background.widgets.resources.scale
                    wallpaper: behindClock
                    screenX: resourcesWidget.x
                    screenY: resourcesWidget.y
                }
            }

            DesktopWidget {
                id: weatherWidget

                z: 2
                cfg: GlobalConfig.background.widgets.weather
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: qsTr("Weather")
                selfScales: true
                visible: GlobalConfig.background.widgets.weather.enabled

                WeatherWidget {
                    showBackground: GlobalConfig.background.widgets.weather.background
                    sizeScale: GlobalConfig.background.widgets.weather.scale
                    wallpaper: behindClock
                    screenX: weatherWidget.x
                    screenY: weatherWidget.y
                }
            }

            DesktopWidget {
                id: mediaWidget

                z: 2
                cfg: GlobalConfig.background.widgets.media
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: qsTr("Media")
                selfScales: true
                visible: GlobalConfig.background.widgets.media.enabled

                MediaWidget {
                    showBackground: GlobalConfig.background.widgets.media.background
                    sizeScale: GlobalConfig.background.widgets.media.scale
                    wallpaper: behindClock
                    screenX: mediaWidget.x
                    screenY: mediaWidget.y
                }
            }

            DesktopWidget {
                id: batteryWidget

                z: 2
                cfg: GlobalConfig.background.widgets.battery
                canvas: widgetHost
                leftInset: widgetHost.leftInset
                label: qsTr("Battery")
                selfScales: true
                visible: GlobalConfig.background.widgets.battery.enabled && UPower.displayDevice.isLaptopBattery

                BatteryWidget {
                    showBackground: GlobalConfig.background.widgets.battery.background
                    sizeScale: GlobalConfig.background.widgets.battery.scale
                    wallpaper: behindClock
                    screenX: batteryWidget.x
                    screenY: batteryWidget.y
                }
            }

            // ── User-defined custom widgets (CustomWidgets service) ────────
            Repeater {
                model: CustomWidgets.list

                DesktopWidget {
                    id: customWidget

                    required property var modelData

                    z: 2
                    cfg: modelData
                    saveFn: modelData.save
                    canvas: widgetHost
                    leftInset: widgetHost.leftInset
                    label: modelData.cwName
                    visible: modelData.enabled

                    Loader {
                        asynchronous: true
                        source: customWidget.modelData.widgetUrl
                        onStatusChanged: if (status === Loader.Error)
                            console.warn("CustomWidget failed to load:", customWidget.modelData.cwId)
                    }
                }
            }

            // ── Sticky notes (Notes service) ──────────────────────────────
            Repeater {
                model: Notes.list

                DesktopWidget {
                    id: noteWidget

                    required property var modelData

                    z: 3
                    cfg: modelData
                    saveFn: modelData.save
                    canvas: widgetHost
                    leftInset: widgetHost.leftInset
                    label: qsTr("Note")

                    NoteWidget {
                        cfg: noteWidget.modelData
                    }
                }
            }

            // ── Edit-mode controls bar (Done + grid options) ───────────────
            StyledRect {
                id: editBar

                z: 90
                // Raised clear of the compositor's bottom-edge hover strip,
                // which otherwise intercepts clicks on this background-layer bar.
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 140
                visible: widgetHost.editing
                opacity: widgetHost.editing ? 1 : 0
                implicitWidth: editRow.implicitWidth + Tokens.padding.normal * 2
                implicitHeight: 52
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHigh
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.7)

                Behavior on opacity {
                    Anim {}
                }

                Row {
                    id: editRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    EditBarButton {
                        icon: GlobalConfig.background.widgets.snap ? "grid_on" : "grid_off"
                        text: qsTr("Snap")
                        toggled: GlobalConfig.background.widgets.snap
                        onActivated: {
                            GlobalConfig.background.widgets.snap = !GlobalConfig.background.widgets.snap;
                            GlobalConfig.save();
                        }
                    }

                    EditBarButton {
                        icon: "grid_4x4"
                        text: GlobalConfig.background.widgets.gridSize + qsTr("px")
                        onActivated: {
                            const steps = [8, 16, 24, 32, 48];
                            const cur = GlobalConfig.background.widgets.gridSize;
                            const idx = steps.indexOf(cur);
                            GlobalConfig.background.widgets.gridSize = steps[(idx + 1) % steps.length];
                            GlobalConfig.save();
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 24
                        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.8)
                    }

                    // Done — exit edit mode without the settings round-trip.
                    StyledRect {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: doneRow.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: 38
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        StateLayer {
                            color: Colours.palette.m3onPrimary
                            radius: parent.radius
                            onClicked: Visibilities.widgetEditMode = false
                        }

                        Row {
                            id: doneRow

                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "check"
                                color: Colours.palette.m3onPrimary
                                font.pointSize: Tokens.font.size.normal
                            }

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Done")
                                color: Colours.palette.m3onPrimary
                                font.pointSize: Tokens.font.size.normal
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            // ── Desktop context menu ───────────────────────────────────────
            MouseArea {
                id: menuScrim

                anchors.fill: parent
                z: 99
                enabled: desktopMenu.open
                acceptedButtons: Qt.AllButtons
                onPressed: desktopMenu.open = false
            }

            Item {
                id: desktopMenu

                z: 100
                anchors.fill: parent
                visible: open

                property bool open: false
                property real px: 0
                property real py: 0

                Elevation {
                    id: menuCard

                    x: Math.max(8, Math.min(desktopMenu.px, widgetHost.width - width - 8))
                    y: Math.max(8, Math.min(desktopMenu.py, widgetHost.height - height - 8))
                    implicitWidth: 214
                    implicitHeight: menuCol.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.normal
                    level: 2

                    transform: Scale {
                        origin.x: 0
                        origin.y: 0
                        xScale: desktopMenu.open ? 1 : 0.85
                        yScale: desktopMenu.open ? 1 : 0.85

                        Behavior on xScale {
                            Anim {}
                        }
                        Behavior on yScale {
                            Anim {}
                        }
                    }

                    StyledRect {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Colours.palette.m3surfaceContainerLow

                        Column {
                            id: menuCol

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Tokens.padding.small
                            spacing: 0

                            CtxItem {
                                icon: "sticky_note_2"
                                text: qsTr("Add sticky note")
                                onActivated: {
                                    Notes.create();
                                    desktopMenu.open = false;
                                }
                            }

                            CtxItem {
                                icon: "edit"
                                text: widgetHost.editing ? qsTr("Stop editing widgets") : qsTr("Edit widgets")
                                onActivated: {
                                    Visibilities.widgetEditMode = !Visibilities.widgetEditMode;
                                    desktopMenu.open = false;
                                }
                            }

                            CtxItem {
                                icon: "settings"
                                text: qsTr("Settings")
                                onActivated: {
                                    desktopMenu.open = false;
                                    const v = Visibilities.getForActive();
                                    if (v)
                                        v.settings = true;
                                }
                            }

                            CtxItem {
                                icon: "refresh"
                                text: qsTr("Reload shell")
                                onActivated: {
                                    desktopMenu.open = false;
                                    Quickshell.execDetached(["systemctl", "--user", "restart", "ryoku-shell.service"]);
                                }
                            }
                        }
                    }
                }
            }

            component CtxItem: StyledRect {
                id: ctx

                required property string icon
                required property string text
                signal activated

                width: menuCol.width
                implicitHeight: 38
                radius: Tokens.rounding.small
                color: "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3onSurface
                    onClicked: ctx.activated()
                }

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.padding.normal
                    spacing: Tokens.spacing.normal

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ctx.icon
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.normal
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ctx.text
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.small
                    }
                }
            }

            component EditBarButton: StyledRect {
                id: ebb

                required property string icon
                required property string text
                property bool toggled: false
                signal activated

                anchors.verticalCenter: parent?.verticalCenter
                implicitWidth: ebbRow.implicitWidth + Tokens.padding.normal * 2
                implicitHeight: 38
                radius: Tokens.rounding.full
                color: toggled ? Qt.alpha(Colours.palette.m3primary, 0.16) : "transparent"

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3onSurface
                    onClicked: ebb.activated()
                }

                Row {
                    id: ebbRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.smaller

                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ebb.icon
                        color: ebb.toggled ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.normal
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ebb.text
                        color: ebb.toggled ? Colours.palette.m3primary : Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.small
                    }
                }
            }
        }
    }
}
