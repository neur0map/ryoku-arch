pragma Singleton

import QtQuick

// Shared hover state for the dock's window-preview strip. RailDock writes the
// hovered app class and the hovered icon's screen-centre on hover; the
// DockPreviewPopout (hosted by FrameMenuManager, one per monitor) reads them to
// grow a live preview welded to that icon. Empty `hoveredClass` = nothing
// hovered, which lets the popout's own hover-grace melt it shut. Only the dock
// writes here, so a second dock instance on another rail simply retargets it.
QtObject {
    id: root

    // The app class currently hovered on the dock ("" = none). The popout shows
    // one live tile per open window of this class.
    property string hoveredClass: ""
    // Hovered icon centre, in global (screen) coordinates. The popout maps these
    // into its own space to weld the strip to the icon along the rail.
    property real gx: -1
    property real gy: -1
    // The rail edge the dock sits on ("left" | "right" | "top" | "bottom"), so
    // the strip grows off the correct side.
    property string edge: "left"
}
