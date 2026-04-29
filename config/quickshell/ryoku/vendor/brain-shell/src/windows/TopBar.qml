import Quickshell
import QtQuick
import "../components"
import "../modules/Center/"
import "../modules/Right/"
import "../modules/Left/"
import "../"
import "../shapes/"

PanelWindow {
    id: root

    property string screenName: screen ? screen.name : ""

    color: "transparent"

    anchors {
        top:   true
        left:  true
        right: true
    }

    Binding { target: ShellState; property: "topBarLWidth"; value: root.lWidth }
    Binding { target: ShellState; property: "topBarCWidth"; value: root.cWidth }
    Binding { target: ShellState; property: "topBarRWidth"; value: root.rWidth }

    // ── Height shrinks to a border strip in focus mode ───────────────────────
    // Safe to animate on PanelWindow (anchored, no position jank).
    // PopupWindow is the one that must never have animated implicitHeight.
    implicitHeight: ShellState.focusMode ? Theme.borderWidth : Theme.notchHeight
    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    exclusiveZone: ShellState.focusMode ? 0 : Theme.exclusionGap
    Behavior on exclusiveZone {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    readonly property int lWidth: Math.max(
        Theme.lNotchMinWidth,
        Math.min(Theme.lNotchMaxWidth,
                 leftContent.implicitWidth + Theme.notchPadding * 2)
    )

    // cWidth uses Popups.dashboardPageWidth when the dashboard is open,
    // so the center notch tracks the active tab's declared width.
    property int cWidth: Popups.dashboardOpen
        ? Popups.dashboardPageWidth
        : Math.max(
            Theme.cNotchMinWidth,
            Math.min(Theme.cNotchMaxWidth,
                     centerContent.implicitWidth + Theme.notchPadding * 2)
          )
    Behavior on cWidth {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    // Width matches sizer open width: popupWidth + notchRadius (fw) in both popups
    property int rWidth: Popups.notificationsOpen
        ? Theme.notificationsWidth + Theme.notchRadius
        : Popups.networkOpen
            ? Theme.networkPopupWidth + Theme.notchRadius
            : Math.max(
                Theme.rNotchMinWidth,
                Math.min(Theme.rNotchMaxWidth,
                         rightContent.implicitWidth + Theme.notchPadding * 2)
              )
    Behavior on rWidth {
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    // ── Border strip (focus mode) ────────────────────────────────────────────
    // Painted behind the notch content layer. Visible only when focus mode
    // fades the notches out. Uses the same bar color so it reads as a thin
    // edge strip matching the side border strips.
    Rectangle {
        anchors.fill: parent
        color: Theme.background
        opacity: ShellState.focusMode ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }
    }

    // ── Notch content (fades out in focus mode) ──────────────────────────────
    Item {
        anchors.fill: parent
        opacity: ShellState.focusMode ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }

        SeamlessBarShape {
            id: barShape
            anchors.fill: parent
            leftWidth:   root.lWidth
            centerWidth: root.cWidth
            rightWidth:  root.rWidth
        }

        Item {
            id:           leftNotch
            width:        root.lWidth
            height:       Theme.notchHeight
            anchors.left: parent.left

            LeftContent {
                id: leftContent
                anchors.centerIn: parent
            }
        }

        Item {
            id:               centerNotch
            width:            root.cWidth
            height:           Theme.notchHeight
            anchors.centerIn: parent

            CenterContent {
                id: centerContent
                anchors.centerIn: parent
            }
        }

        Item {
            id:            rightNotch
            width:         root.rWidth
            height:        Theme.notchHeight
            anchors.right: parent.right

            RightContent {
                id: rightContent
                anchors.centerIn: parent
            }
        }
    }
}