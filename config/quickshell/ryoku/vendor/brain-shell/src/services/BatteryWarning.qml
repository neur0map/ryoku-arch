import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

// Low battery warning. Small top-right toast, auto-dismisses after
// `timeout` ms. Click anywhere on the toast to dismiss early.

PanelWindow {
    id: root

    property int warnLevel: 30
    property int timeout:   8000

    anchors.top: true
    anchors.right: true

    margins.top: Theme.notchHeight + Theme.borderWidth + 10
    margins.right: Theme.borderWidth + 12

    implicitWidth: 260
    implicitHeight: 64

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"
    
    // Auto-dismiss timer
    Timer {
        id: autoClose
        interval: root.timeout
        running:  root.visible
        onTriggered: root.visible = false
    }

    onVisibleChanged: if (visible) autoClose.restart()

    // ── Severity helpers ─────────────────────────────────────────────────────
    readonly property color accentColor: warnLevel <= 5  ? "#ff4444" :
                                         warnLevel <= 10 ? "#ff6b00" : "#ffcc00"
    readonly property string title:      "Battery " + warnLevel + "%"
    readonly property string message:    warnLevel <= 5  ? "Plug in now" :
                                         warnLevel <= 10 ? "Find power soon" :
                                                          "Consider charging"

    // ── Visuals ───────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius:       12
        color:        Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.96)
        border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.35)
        border.width: 1
        clip: true

        // Left accent bar
        Rectangle {
            width:                  3
            height:                 parent.height - 18
            radius:                 1.5
            anchors.left:           parent.left
            anchors.leftMargin:     9
            anchors.verticalCenter: parent.verticalCenter
            color:                  root.accentColor
        }

        Row {
            anchors {
                left:           parent.left
                leftMargin:     20
                right:          parent.right
                rightMargin:    12
                verticalCenter: parent.verticalCenter
            }
            spacing: 10

            Text {
                text:           "!"
                color:          root.accentColor
                font.pixelSize: 18
                font.bold:      true
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                width: Math.max(0, parent.width - 28)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text:           root.title
                    color:          root.accentColor
                    font.pixelSize: 12
                    font.bold:      true
                    width:          parent.width
                    elide:          Text.ElideRight
                }

                Text {
                    text:           root.message
                    color:          Theme.text
                    font.pixelSize: 11
                    width:          parent.width
                    elide:          Text.ElideRight
                }
            }
        }

        // Countdown progress bar
        Rectangle {
            anchors.bottom:      parent.bottom
            anchors.left:        parent.left
            anchors.right:       parent.right
            height:              3
            radius:              2
            color:               Qt.rgba(1, 1, 1, 0.08)

            Rectangle {
                id:       countdown
                height:   parent.height
                radius:   parent.radius
                color:    root.accentColor
                width:    parent.width

                NumberAnimation on width {
                    running:  root.visible
                    from:     countdown.parent.width
                    to:       0
                    duration: root.timeout
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape:  Qt.PointingHandCursor
            onClicked:    root.visible = false
        }
        Item {
            anchors.fill: parent
            Keys.onEscapePressed: root.visible = false
        }
    }
}
