pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.modules.common
import qs.modules.common.widgets
import qs.services

Loader {
    id: root
    
    property Item anchorItem: parent
    
    function toggle() {
        active = !active
    }
    
    function close() {
        active = false
    }

    active: false
    visible: active

    sourceComponent: PopupWindow {
        id: popupWindow
        visible: true
        
        anchor.item: root.anchorItem
        anchor.gravity: Edges.Bottom
        anchor.edges: Edges.Top
        anchor.adjustment: PopupAdjustment.SlideY | PopupAdjustment.SlideX

        // Close on escape
        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    root.close()
                    event.accepted = true
                }
            }
            Component.onCompleted: forceActiveFocus()
        }

        // Close on click outside (Backdrop)
        PanelWindow {
            visible: true
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:widgetSettings"
            
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: (event) => {
                    root.close()
                    event.accepted = true
                }
            }
        }

        // Animation logic
        property real sourceEdgeMargin: -implicitHeight
        
        SequentialAnimation {
            id: openAnim
            running: true
            PropertyAnimation {
                target: popupWindow
                property: "sourceEdgeMargin"
                to: 8 // margin
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        GlassBackground {
            id: background
            anchors.top: parent.top
            anchors.topMargin: popupWindow.sourceEdgeMargin
            anchors.right: parent.right // Align right with the button usually
            
            implicitWidth: 220
            implicitHeight: contentCol.implicitHeight + 24

            fallbackColor: Appearance.colors.colSurfaceContainer
            inirColor: Appearance.inir.colLayer2
            auroraTransparency: Appearance.aurora.popupTransparentize
            radius: Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
            border.width: 1
            border.color: Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colOutlineVariant

            StyledRectangularShadow {
                anchors.fill: parent
                color: "black"
                opacity: 0.3
                radius: background.radius
                blur: 16
            }

            ColumnLayout {
                id: contentCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                StyledText {
                    text: Translation.tr("Widget Visibility")
                    font.weight: Font.Bold
                    color: Appearance.colors.colPrimary
                    Layout.bottomMargin: 4
                }

                // Helper component for uniform switches
                component WidgetSwitch : ConfigSwitch {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    font.pixelSize: Appearance.font.pixelSize.small
                }

                WidgetSwitch {
                    text: Translation.tr("Media Player")
                    buttonIcon: "music_note"
                    checked: Config.options?.sidebar?.widgets?.media ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.media", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Week Calendar")
                    buttonIcon: "calendar_view_week"
                    checked: Config.options?.sidebar?.widgets?.week ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.week", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Context Info")
                    buttonIcon: "info"
                    checked: Config.options?.sidebar?.widgets?.context ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.context", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Quick Note")
                    buttonIcon: "edit_note"
                    checked: Config.options?.sidebar?.widgets?.note ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.note", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Launcher")
                    buttonIcon: "rocket_launch"
                    checked: Config.options?.sidebar?.widgets?.launch ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.launch", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("System Controls")
                    buttonIcon: "toggle_on"
                    checked: Config.options?.sidebar?.widgets?.controls ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.controls", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Status Rings")
                    buttonIcon: "data_usage"
                    checked: Config.options?.sidebar?.widgets?.status ?? true
                    onClicked: Config.setNestedValue("sidebar.widgets.status", checked)
                }

                WidgetSwitch {
                    text: Translation.tr("Crypto Ticker")
                    buttonIcon: "currency_bitcoin"
                    checked: Config.options?.sidebar?.widgets?.crypto ?? false
                    onClicked: Config.setNestedValue("sidebar.widgets.crypto", checked)
                }
                
                WidgetSwitch {
                    text: Translation.tr("Wallpaper")
                    buttonIcon: "wallpaper"
                    checked: Config.options?.sidebar?.widgets?.wallpaper ?? false
                    onClicked: Config.setNestedValue("sidebar.widgets.wallpaper", checked)
                }
            }
        }
    }
}
