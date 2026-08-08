import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: calPopup
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-calendar"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property real reveal: root.calendarVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.calendarVisible ? 160 : 120
            easing.type: root.calendarVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.calendarVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.calendarVisible = false
    }

    Rectangle {
        id: card
        width: 280
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: calPopup.root
            ownerActive: calPopup.root.calendarVisible
            targetX: calPopup.root.calendarBarX
            reveal: calPopup.reveal
        }

        x: Math.round((parent.width - width) / 2)
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - calPopup.reveal)
            : (barBottom + gap) - 2 * (1 - calPopup.reveal)
        opacity: calPopup.reveal
        focus: root.calendarVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.calendarVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            // ── header: month name + navigation chevrons ──
            Item {
                width: parent.width
                height: 24

                // ‹ previous month
                Rectangle {
                    id: prevBtn
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: root.panelButtonRadius
                    color: "transparent"
                    UiText {
                        anchors.centerIn: parent
                        text: "‹"   // ‹
                        color: prevMa.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 16
                    }
                    MouseArea {
                        id: prevMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calendarMonthOffset--
                    }
                }

                // month + year — click to jump back to today
                UiText {
                    anchors.centerIn: parent
                    text: root.calendarMonthName + "  " + root.calendarYear
                    color: monthMa.containsMouse && root.calendarMonthOffset !== 0 ? root.seal : root.ink
                    font.family: root.mono
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                    MouseArea {
                        id: monthMa
                        anchors.fill: parent; anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: root.calendarMonthOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.calendarMonthOffset = 0
                    }
                }

                // › next month
                Rectangle {
                    id: nextBtn
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: root.panelButtonRadius
                    color: "transparent"
                    UiText {
                        anchors.centerIn: parent
                        text: "›"   // ›
                        color: nextMa.containsMouse ? root.seal : root.sumi
                        font.family: root.mono; font.pixelSize: 16
                    }
                    MouseArea {
                        id: nextMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calendarMonthOffset++
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── weekday headers ──
            Row {
                width: parent.width
                Repeater {
                    model: ["MO","TU","WE","TH","FR","SA","SU"]
                    delegate: Item {
                        required property string modelData
                        required property int index
                        width: parent.width / 7
                        height: 20
                        UiText {
                            anchors.centerIn: parent
                            text: modelData
                            color: index >= 5 ? root.seal : root.inkDeep
                            opacity: index >= 5 ? 0.85 : 0.7
                            font.family: root.mono
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }
                    }
                }
            }

            // ── day grid ──
            Grid {
                columns: 7
                rowSpacing: 2
                columnSpacing: 0
                width: parent.width
                Repeater {
                    model: root.calendarCells
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: parent.width / 7
                        height: 28

                        readonly property int dayOfWeek: index % 7
                        readonly property bool isCurrentMonth: modelData.day !== 0
                        readonly property bool isToday: modelData.today
                        readonly property bool isSelected: isCurrentMonth && root.selectedDay === modelData.day && root.calendarMonthOffset === 0

                        readonly property color textColor: {
                            if (isToday) return root.seal.hsvValue < 0.5 ? root.ink : root.paper;
                            if (!isCurrentMonth) return root.inkDeep;
                            return dayOfWeek >= 5 ? root.seal : root.ink;
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: root.seal
                            visible: isToday
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            border.color: root.seal; border.width: 1
                            color: "transparent"
                            visible: isSelected && !isToday
                        }

                        UiText {
                            anchors.centerIn: parent
                            text: modelData.day === 0 ? "" : modelData.day
                            color: textColor
                            opacity: isCurrentMonth ? 1.0 : 0.35
                            font.family: root.mono
                            font.pixelSize: 12
                            font.weight: isToday ? Font.Medium : Font.Light
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: isCurrentMonth
                            enabled: isCurrentMonth
                            cursorShape: isCurrentMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.selectedDay = modelData.day
                        }
                    }
                }
            }
        }
    }
}
