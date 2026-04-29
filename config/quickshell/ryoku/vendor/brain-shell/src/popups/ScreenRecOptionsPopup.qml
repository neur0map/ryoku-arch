import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../"

// ScreenRecOptionsPopup — minimal dropdown under the center notch.
//
// No checkboxes, no radio dots. Selection shown by background highlight only.
// Window sized exactly to content — no mask, no dead space.

PopupWindow {
    id: root

    required property var anchorWindow

    readonly property int _padH: 5
    readonly property int _padV: 5

    implicitWidth:  optCol.implicitWidth + _padH * 2
    implicitHeight: optCol.implicitHeight + _padV * 2

    anchor.window:     root.anchorWindow
    anchor.gravity:    Edges.Bottom
    anchor.adjustment: PopupAdjustment.None
    anchor.rect: Qt.rect(
       ScreenRecService.popupTargetX + (ScreenRecService.popupTargetWidth / 2),
        25,
        root.implicitWidth,
        Theme.notchHeight
    )

    color:   "transparent"
    visible: ScreenRecService.openStrip !== ""

    HoverHandler {
        onHoveredChanged: {
            if (hovered) ScreenRecService.keepStripOpen()
            else         ScreenRecService.scheduleStripClose()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius:       Theme.cornerRadius - 6
        color:        Theme.background
        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15)
        border.width: 1
    }

    Column {
        id: optCol
        x:       _padH
        y:       _padV
        spacing: 2

        // Capture — radio (one active at a time)
        Repeater {
            model: ScreenRecService.openStrip === "capture"
                   ? ["screen", "window", "region"] : []
            delegate: OptionRow {
                required property string modelData
                required property int    index
                _icon:     ScreenRecService._captureIcons[modelData]  ?? ""
                _label:    ScreenRecService._captureLabels[modelData] ?? ""
                _selected: ScreenRecService.captureTarget === modelData
                onClicked: ScreenRecService.captureTarget = modelData
            }
        }

        // Audio — checkboxes (independent)
        Repeater {
            model: ScreenRecService.openStrip === "audio"
                   ? ["mic", "system", "none"] : []
            delegate: OptionRow {
                required property string modelData
                required property int    index

                readonly property var _icons:  ({ mic: "󰍬", system: "󰕾", none: "󰖁" })
                readonly property var _labels: ({ mic: "Mic", system: "System", none: "No Audio" })

                _icon:    _icons[modelData]  ?? ""
                _label:   _labels[modelData] ?? ""
                _selected: {
                    if (modelData === "none")   return !ScreenRecService.audioMic && !ScreenRecService.audioSystem
                    if (modelData === "mic")    return ScreenRecService.audioMic
                    return ScreenRecService.audioSystem
                }

                onClicked: {
                    if (modelData === "none") {
                        ScreenRecService.audioMic    = false
                        ScreenRecService.audioSystem = false
                    } else if (modelData === "mic") {
                        ScreenRecService.audioMic = !ScreenRecService.audioMic
                    } else {
                        ScreenRecService.audioSystem = !ScreenRecService.audioSystem
                    }
                }
            }
        }
    }

    // ── Option row — highlight only, no dots or checkboxes ────────────────────
    component OptionRow: Item {
        id: row

        property string _icon:     ""
        property string _label:    ""
        property bool   _selected: false

        signal clicked()

        implicitWidth:  8 + 14 + 6 + _lbl.implicitWidth + 12
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius:       5
            color: row._selected
                   ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                   : rH.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }

        Row {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            spacing: 6

            Text {
                text:           row._icon
                font.pixelSize: 13
                color:          row._selected ? Theme.active : Qt.rgba(1, 1, 1, 0.45)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 100 } }
            }
            Text {
                id:             _lbl
                text:           row._label
                font.pixelSize: 12
                color:          row._selected ? Theme.active : Qt.rgba(1, 1, 1, 0.70)
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }

        HoverHandler { id: rH; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; onClicked: row.clicked() }
    }
}
