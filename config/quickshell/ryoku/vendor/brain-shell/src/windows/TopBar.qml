import Quickshell
import Quickshell.Wayland
import QtQuick
import "../components"
import "../modules/Center/"
import "../modules/Right/"
import "../modules/Left/"
import "../services/home"
import "../"
import "../shapes/"

PanelWindow {
    id: root

    property string screenName: screen ? screen.name : ""

    color: "transparent"

    // Layer is dynamic. Default Top so the bar yields to fullscreen
    // apps (screensaver, video) the way every other layer-shell bar
    // does. Promoted to Overlay only while the dashboard card is
    // visually present, so the bar's center pill paints over the
    // card's top strip — the card's flares tuck behind the notch and
    // the two shapes read as one continuous surface during open and
    // close. Bound to Popups.dashboardVisible (set by Dashboard.qml)
    // so the layer holds through the full close animation.
    WlrLayershell.layer: Popups.dashboardVisible || Popups.launcherVisible || Popups.wallpaperVisible ? WlrLayer.Overlay : WlrLayer.Top

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

    readonly property int lWidth: Math.max(
        Theme.lNotchMinWidth,
        Math.min(Theme.lNotchMaxWidth,
                 leftContent.implicitWidth + Theme.notchPadding * 2)
    )

    // Keep the center notch at its natural pill width. The dashboard popup
    // animates independently so the bar does not widen as a separate motion.
    property int cWidth: Math.max(
        Theme.cNotchMinWidth,
        Math.min(Theme.cNotchMaxWidth,
                 centerContent.implicitWidth + Theme.notchPadding * 2)
      )
    Behavior on cWidth {
        enabled: !Theme.staticMode
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
            id:               centerNotch
            width:            root.cWidth
            height:           Theme.notchHeight
            anchors.centerIn: parent

            CenterContent {
                id: centerContent
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
