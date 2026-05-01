import Quickshell
import Quickshell.Wayland
import QtQuick
import "../components"
import "../modules/Center/"
import "../modules/Right/"
import "../modules/Left/"
import "../modules/Gap/"
import "../services/home"
import "../"
import "../shapes/"

PanelWindow {
    id: root

    property string screenName: screen ? screen.name : ""

    color: "transparent"

    // Layer is dynamic. Default Top so the bar yields to fullscreen
    // apps (screensaver, video) the way every other layer-shell bar
    // does. Promoted to Overlay while attached center/topbar surfaces
    // are visually present so they keep painting and receiving input
    // as one continuous surface during open and close.
    WlrLayershell.layer: Popups.toolboxOpen || Popups.dashboardVisible || Popups.launcherVisible || Popups.systemMenuVisible || Popups.legacySettingsMenuVisible
                         ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: Popups.toolboxOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top:   true
        left:  true
        right: true
    }

    Binding { target: ShellState; property: "topBarLWidth"; value: root.lWidth }
    Binding { target: ShellState; property: "topBarCWidth"; value: root.cWidth }
    Binding { target: ShellState; property: "topBarRWidth"; value: root.rWidth }

    // Height shrinks to a border strip in focus mode. The dashboard popup
    // is its own window now — bar height stays constant when it opens.
    implicitHeight: ShellState.focusMode ? Theme.borderWidth : Theme.notchHeight
    Behavior on implicitHeight {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    exclusiveZone: ShellState.focusMode ? 0 : Theme.exclusionGap
    Behavior on exclusiveZone {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
    }

    Connections {
        target: ShellState
        function onFocusModeChanged() {
            if (ShellState.focusMode) Popups.dashboardOpen = false
        }
    }

    Connections {
        target: Popups
        function onToolboxOpenChanged() {
            if (Popups.toolboxOpen) {
                Qt.callLater(function() { toolboxKeyScope.forceActiveFocus() })
                toolboxFocusTimer.restart()
            } else {
                toolboxFocusTimer.stop()
            }
        }
    }

    Timer {
        id: toolboxFocusTimer
        interval: 35
        repeat: false
        onTriggered: {
            if (Popups.toolboxOpen) toolboxKeyScope.forceActiveFocus()
        }
    }

    readonly property int lWidth: Math.max(
        Theme.lNotchMinWidth,
        Math.min(Theme.lNotchMaxWidth,
                 leftContent.implicitWidth + Theme.notchPadding * 2)
    )

    // Keep the center notch at its natural pill width except for the
    // toolbox, which is hosted inside the notch so the pill itself
    // warps into the toolkit strip and back.
    property int cWidth: Popups.toolboxOpen
        ? Math.max(Theme.cNotchMinWidth,
                   toolboxContent.implicitWidth + Theme.notchPadding * 2)
        : Math.max(
            Theme.cNotchMinWidth,
            Math.min(Theme.cNotchMaxWidth,
                     centerContent.implicitWidth + Theme.notchPadding * 2)
          )
    Behavior on cWidth {
        enabled: !Theme.staticMode
        NumberAnimation {
            duration: root.toolboxMorphActive ? Theme.motionExpandDuration + 80 : Theme.animDuration
            easing.type: root.toolboxMorphActive
                ? Popups.toolboxOpen ? Easing.OutBack : Easing.OutQuart
                : Easing.InOutCubic
            easing.overshoot: 1.05
        }
    }
    readonly property bool toolboxMorphActive: Popups.toolboxOpen || toolboxContent.opacity > 0

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
        enabled: !Theme.staticMode
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
            enabled: !Theme.staticMode
            NumberAnimation { duration: Theme.animDuration; easing.type: Easing.InOutCubic }
        }
    }

    // ── Notch content (fades out in focus mode) ──────────────────────────────
    Item {
        anchors.fill: parent
        opacity: ShellState.focusMode ? 0 : 1
        Behavior on opacity {
            enabled: !Theme.staticMode
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
            id: leftGap
            anchors {
                left: leftNotch.right
                right: centerNotch.left
                top: parent.top
            }
            height: Theme.notchHeight
            clip: true

            DayWidget {
                id: dayWidget
                anchors.centerIn: parent
                active: parent.width >= implicitWidth + 20
                        && !Popups.toolboxOpen
                        && !Popups.dashboardOpen
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
                opacity: Popups.toolboxOpen ? 0 : Popups.dashboardOpen ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    enabled: !Theme.staticMode
                    NumberAnimation {
                        duration: Theme.motionExpandDuration
                        easing.type: Easing.OutQuart
                    }
                }
            }

            ToolboxContent {
                id: toolboxContent
                screen: root.screen
                anchors.centerIn: parent
            }

            DashboardTopControls {
                anchors {
                    centerIn: parent
                    // The dashboard clock column sits 12px left of screen
                    // center because the telemetry rail is wider than the
                    // profile/calendar column.
                    horizontalCenterOffset: -12
                }
                width: Math.min(parent.width - 12, 320)
                visible: Popups.dashboardOpen
                opacity: Popups.dashboardOpen ? 1 : 0
                Behavior on opacity {
                    enabled: !Theme.staticMode
                    NumberAnimation { duration: Theme.motionEffectsDuration; easing.type: Easing.OutCubic }
                }
            }
        }

        Item {
            id: rightGap
            anchors {
                left: centerNotch.right
                right: rightNotch.left
                top: parent.top
            }
            height: Theme.notchHeight
            clip: true

            VolumeToast {
                id: volumeToast
                width: Math.min(implicitWidth, Math.max(0, parent.width - 18))
                height: implicitHeight
                anchors.horizontalCenter: parent.horizontalCenter
                active: VolumeFeedback.visible
                        && parent.width >= implicitWidth + 18
                        && !Popups.toolboxOpen
                        && !Popups.dashboardOpen
                        && !Popups.networkOpen
                        && !Popups.notificationsOpen
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

    FocusScope {
        id: toolboxKeyScope
        anchors.fill: parent
        enabled: Popups.toolboxOpen
        focus: Popups.toolboxOpen

        Keys.onPressed: function(event) {
            if (!Popups.toolboxOpen) return

            switch (event.key) {
            case Qt.Key_Left:
            case Qt.Key_Up:
                toolboxContent.moveSelection(-1)
                event.accepted = true
                return
            case Qt.Key_Right:
            case Qt.Key_Down:
                toolboxContent.moveSelection(1)
                event.accepted = true
                return
            case Qt.Key_Return:
            case Qt.Key_Enter:
            case Qt.Key_Space:
                toolboxContent.activateCurrent()
                event.accepted = true
                return
            case Qt.Key_Escape:
                toolboxContent.closeToolbox()
                event.accepted = true
                return
            default:
                return
            }
        }
    }
}
