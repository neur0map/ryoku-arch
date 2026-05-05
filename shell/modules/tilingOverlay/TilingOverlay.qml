import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import "root:"
import "root:services"

Scope {
    id: root

    property bool showPicker: false
    property bool showOsd: false

    readonly property string currentLayout: NiriService.currentLayout
    readonly property int windowCount: NiriService.tilingWindowCount
    readonly property var layouts: [
        { id: "off", name: "Off" },
        { id: "master-left", name: "Master Left" },
        { id: "master-right", name: "Master Right" },
        { id: "columns", name: "Columns" },
        { id: "monocle", name: "Monocle" }
    ]

    function layoutIndex(id): int {
        for (let i = 0; i < layouts.length; i++)
            if (layouts[i].id === id) return i
        return 0
    }

    Timer {
        id: osdTimer
        interval: 1500
        onTriggered: root.showOsd = false
    }

    Timer {
        id: pickerTimer
        interval: 2500
        onTriggered: root.showPicker = false
    }

    Connections {
        target: NiriService
        function onLayoutApplied(layout, count) {
            root.showOsd = true
            osdTimer.restart()
        }
    }

    function applyLayout(id): void {
        NiriService.applyLayout(id)
        pickerTimer.restart()
    }

    function cycle(): void {
        NiriService.cycleLayout()
    }

    // Panel
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData

            visible: root.showPicker || root.showOsd
            color: "transparent"
            exclusiveZone: 0

            anchors { top: true; left: true; right: true; bottom: true }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:tilingOverlay"
            WlrLayershell.keyboardFocus: root.showPicker ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            // Scrim
            Rectangle {
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: root.showPicker ? 0.3 : 0
                visible: opacity > 0
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.showPicker = false
                }
            }

            // OSD
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 16

                width: osdRow.width + 32
                height: 72
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                visible: root.showOsd

                layer.enabled: visible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#40000000"
                    shadowBlur: 0.8
                    shadowVerticalOffset: 8
                }

                RowLayout {
                    id: osdRow
                    anchors.centerIn: parent
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colPrimaryContainer

                        LayoutPreview {
                            anchors.fill: parent
                            anchors.margins: 6
                            layout: root.currentLayout
                            windowCount: root.windowCount
                            accentColor: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    Column {
                        spacing: 2
                        StyledText {
                            text: root.layouts[root.layoutIndex(root.currentLayout)]?.name ?? "Off"
                            font.pixelSize: Appearance.font.pixelSize.large
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }
                        StyledText {
                            text: root.windowCount + " window" + (root.windowCount !== 1 ? "s" : "")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            // Picker
            Rectangle {
                id: pickerCard
                anchors.centerIn: parent
                width: 520
                height: 360
                radius: Appearance.rounding.large
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                visible: root.showPicker

                layer.enabled: visible
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#50000000"
                    shadowBlur: 1.0
                    shadowVerticalOffset: 12
                }

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        MaterialSymbol {
                            text: "grid_view"
                            iconSize: 26
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: "Snap Layouts"
                            font.pixelSize: Appearance.font.pixelSize.larger
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnLayer0
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            height: 24
                            width: statusText.width + 14
                            radius: Appearance.rounding.small
                            color: Appearance.colors.colPrimaryContainer
                            StyledText {
                                id: statusText
                                anchors.centerIn: parent
                                text: root.windowCount + " win"
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 4
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: root.layouts

                            Rectangle {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: Appearance.rounding.small

                                readonly property bool isCurrent: modelData.id === root.currentLayout

                                color: isCurrent ? Appearance.colors.colPrimaryContainer
                                     : ma.containsMouse ? Appearance.colors.colLayer1Hover
                                     : Appearance.colors.colLayer1

                                border.width: isCurrent ? 2 : 1
                                border.color: isCurrent ? Appearance.colors.colPrimary
                                            : Appearance.colors.colLayer0Border

                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        LayoutPreview {
                                            anchors.fill: parent
                                            layout: modelData.id
                                            windowCount: Math.max(root.windowCount, 3)
                                            accentColor: isCurrent
                                                ? Appearance.colors.colOnPrimaryContainer
                                                : Appearance.colors.colOnLayer1Inactive
                                        }
                                    }

                                    StyledText {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.name
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.weight: isCurrent ? Font.Medium : Font.Normal
                                        color: isCurrent ? Appearance.colors.colOnPrimaryContainer
                                             : Appearance.colors.colOnLayer1
                                    }
                                }

                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.applyLayout(modelData.id)
                                }
                            }
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Mod+X cycle • Click to apply • Esc close"
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colSubtext
                    }
                }

                Keys.onEscapePressed: root.showPicker = false
                Keys.onPressed: (e) => {
                    const idx = root.layoutIndex(root.currentLayout)
                    if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) {
                        root.applyLayout(root.layouts[(idx + 1) % root.layouts.length].id)
                        e.accepted = true
                    } else if (e.key === Qt.Key_Left) {
                        root.applyLayout(root.layouts[(idx - 1 + root.layouts.length) % root.layouts.length].id)
                        e.accepted = true
                    }
                }

                Component.onCompleted: forceActiveFocus()
            }

            Connections {
                target: root
                function onShowPickerChanged() {
                    if (root.showPicker) pickerCard.forceActiveFocus()
                }
            }
        }
    }

    IpcHandler {
        target: "tiling"

        function toggle(): void {
            root.showPicker = !root.showPicker
            if (root.showPicker) pickerTimer.stop()
        }

        function open(): void {
            root.showPicker = true
            pickerTimer.stop()
        }

        function hide(): void {
            root.showPicker = false
            root.showOsd = false
        }

        function cycle(): void {
            root.cycle()
            root.showOsd = true
            root.showPicker = false
            osdTimer.restart()
        }

        function showOsd(): void {
            root.showOsd = true
            root.showPicker = false
            osdTimer.restart()
        }

        function promote(): void {
            NiriService.promoteToMaster()
        }
    }
}
