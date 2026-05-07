import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Amber pill with countdown ring + remaining time. Click opens the existing
// Timer popup (sidebar, bottom group, tab 3).
Item {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colAmber: "#ffa500"

    readonly property int secondsLeft: {
        if (TimerService.pomodoroRunning)  return TimerService.pomodoroSecondsLeft;
        if (TimerService.countdownRunning) return TimerService.countdownSecondsLeft;
        if (TimerService.stopwatchRunning) return TimerService.stopwatchSecondsLeft ?? 0;
        return 0;
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        color: Qt.rgba(1, 0.65, 0, 0.14)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 18
            implicitHeight: 18
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                border.width: 2
                border.color: root.colAmber
                color: "transparent"
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: {
                const s = root.secondsLeft;
                const mm = String(Math.floor(s / 60)).padStart(2, "0")
                const ss = String(s % 60).padStart(2, "0")
                return mm + ":" + ss
            }
            font.pixelSize: Appearance.font.pixelSize.small
            font.family: "monospace"
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            GlobalStates.sidebarRightOpen = true
            Persistent.states.sidebar.bottomGroup.collapsed = false
            Persistent.states.sidebar.bottomGroup.tab = 3
        }
        StyledToolTip { text: Translation.tr("Timer running - click for controls") }
    }
}
