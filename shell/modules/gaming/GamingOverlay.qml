pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components.containers
import qs.services

// RYOKU: per-screen gaming overlay. A WlrLayer.Overlay layer-shell window that hosts
// the widget canvas. Pure transparency (no dim/scrim); interactive only while
// Gaming.open, and fully click-through when closed (empty input mask) so it never
// disrupts a running game. Shows only on the focused monitor.
StyledWindow {
    id: win

    required property ShellScreen modelData

    name: "gaming"
    screen: modelData

    readonly property bool isActiveScreen: Hypr.focusedMonitor
        ? Hypr.focusedMonitor.name === modelData.name
        : (Screens.screens[0]?.name === modelData.name)
    readonly property bool anyVisible: Gaming.open || Gaming.widgetIds.some(id => Gaming.isPinned(id))

    // NOTE: lock-hide is added in a LATER task -- do NOT add a lock term here.
    visible: isActiveScreen && anyVisible

    color: "transparent"
    surfaceFormat.opaque: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: Gaming.open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // Click-through when closed: empty input region. When open, accept input.
    mask: Gaming.open ? null : emptyRegion

    Region {
        id: emptyRegion

        x: 0
        y: 0
        width: 0
        height: 0
    }

    // Click-to-close + Escape-to-close, only while open. The MouseArea holds keyboard
    // focus so Escape is delivered without stealing focus from games when closed.
    MouseArea {
        anchors.fill: parent
        enabled: Gaming.open
        focus: Gaming.open
        Keys.onEscapePressed: Gaming.open = false
        onClicked: Gaming.open = false
    }

    WidgetCanvas {
        anchors.fill: parent
    }
}
