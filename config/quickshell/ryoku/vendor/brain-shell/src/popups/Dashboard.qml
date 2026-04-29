import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shapes"
import "../services/"
import "../"

// Dashboard popup window — pill-expansion model (after Axenide/Ambxst, MIT).
//
// Architecture:
//   - The dashboard does not slide in. Instead a card collapsed to the
//     same size and position as the bar's center pill grows outward and
//     downward into the full dashboard size. With TopBar on Overlay and
//     this window on Top, the pill always paints over the card's top
//     notchHeight strip, so visually it reads as the pill itself
//     expanding into the dashboard.
//   - PanelWindow surface is fixed-size (always full-height of the
//     dashboard area + headroom). Only the inner card resizes — the
//     Wayland surface never reconfigures during animation.
//   - mask = card region only, so clicks outside the card fall through
//     to PopupDismiss (which closes all popups).
//
// Easing follows Ambxst exactly:
//   - Open:  OutBack with overshoot 1.2 (the pill "springs" outward)
//   - Close: OutQuart (smooth retraction, no overshoot)

PanelWindow {
    id: root

    required property var anchorWindow

    Binding { target: Popups; property: "dashboardPageWidth"; value: Theme.dashboardWidth }
    // Bar binds its layer to this — stays Overlay throughout close anim,
    // drops back to Top once the card is fully retracted so the bar
    // yields to fullscreen apps (screensaver, video, etc.).
    Binding { target: Popups; property: "dashboardVisible";   value: card.visible }

    readonly property int  fw:                Theme.notchRadius
    readonly property int  fh:                Theme.notchRadius
    readonly property real fullCardWidth:     Popups.dashboardPageWidth + 2 * root.fw
    readonly property real fullCardHeight:    Theme.notchHeight + Theme.dashboardHeight
    // Initial card matches the bar's center pill: same width (plus the
    // 2*fw flare allowance so the popup body equals the pill body), and
    // height equal to the notch strip. At expandScale=0 the card is
    // entirely hidden behind the pill.
    readonly property real initialCardWidth:  ShellState.topBarCWidth + 2 * root.fw
    readonly property real initialCardHeight: Theme.notchHeight

    // 0 = collapsed into the pill, 1 = fully expanded dashboard.
    property real expandScale: Popups.dashboardOpen ? 1 : 0

    Behavior on expandScale {
        enabled: !Theme.staticMode
        NumberAnimation {
            duration:         Theme.motionExpandDuration
            easing.type:      Popups.dashboardOpen ? Easing.OutBack : Easing.OutQuart
            easing.overshoot: 1.2
        }
    }

    color: "transparent"

    anchors {
        top:   true
        left:  true
        right: true
    }
    implicitHeight: root.fullCardHeight + 8
    exclusionMode:  ExclusionMode.Ignore

    WlrLayershell.layer:         WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Map / mask choreography. Read docs/superpowers/specs/2026-04-29-
    // dashboard-click-architecture.md before changing any of this.
    //
    // Surface visibility uses a manual flag + close-delay timer (the
    // pattern brain-shell shipped originally) rather than binding
    // `visible:` straight to `card.visible || Popups.dashboardOpen`.
    // The straight-bind version has a Quickshell quirk: on a rapid
    // unmap → remap, the new Wayland input region doesn't always pick
    // up the current `mask` value, so the dashboard surface ends up
    // mapped but with no input region — every click falls through to
    // PopupDismiss → closeAll → dashboard closes.
    //
    // The mask reads from `maskProxy`, an Item whose geometry shadows
    // `card`'s. Going through a proxy (rather than `Region { item: card }`)
    // avoids a second Quickshell quirk where the mask doesn't refresh
    // when `card.visible` toggles. The proxy's height is forced
    // negative when the card is hidden, which Quickshell's Region
    // treats as "empty" — clicks fall through cleanly.
    visible: windowVisible
    property bool windowVisible: false

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (Popups.dashboardOpen) {
                closeTimer.stop()
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Theme.motionExpandDuration + 50
        onTriggered: root.windowVisible = false
    }

    mask: Region { item: maskProxy }
    Item {
        id: maskProxy
        x:      card.x
        y:      card.y
        width:  card.width
        height: card.visible ? card.height : -1
    }

    // The popup card. Anchored at the screen top, horizontally centered.
    // Width and height interpolate between the pill's size (collapsed)
    // and the full dashboard size (expanded).
    Item {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top

        width:   root.initialCardWidth
                 + (root.fullCardWidth - root.initialCardWidth)  * root.expandScale
        height:  root.initialCardHeight
                 + (root.fullCardHeight - root.initialCardHeight) * root.expandScale
        visible: root.expandScale > 0
        clip:    true

        PopupShape {
            anchors.fill: parent
            attachedEdge: "top"
            color:        Theme.background
            radius:       Theme.cornerRadius
            flareWidth:   root.fw
            flareHeight:  root.fh
        }

        Item {
            anchors {
                fill:         parent
                topMargin:    Theme.notchHeight + 8
                leftMargin:   root.fw + 8
                rightMargin:  root.fw + 8
                bottomMargin: 8
            }

            DashHome {
                anchors.fill: parent
            }
        }
    }
}
