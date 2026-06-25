import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"
import "clock"
import "weather"

/**
 * Desktop widgets: a wallpaper layer (WlrLayer.Bottom, below windows) carrying the
 * clock and weather, one per monitor. The layer is interactive across the
 * wallpaper so a right-click anywhere on the bare desktop opens the desktop menu;
 * windows above still receive their own input, so only clicks on visible wallpaper
 * reach it. Drag a widget to move it (it snaps to the grid that fades in),
 * right-click a widget for its own menu, right-click the desktop for the global
 * one. Everything is read live from the widgets Config; the drag, the menus, and
 * Ryoku Settings' Desktop Widgets section all write the same file, so the surfaces
 * retune with no reload.
 */
ShellRoot {
    id: root

    // One IP-located weather fetch shared by every monitor, in the user's unit.
    Binding {
        target: WeatherData
        property: "unit"
        value: Config.weatherUnit
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "ryoku-widgets"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; left: true; right: true; bottom: true }

            // Input mask: this layer sits ON TOP of `ryoku-plugins` (also
            // WlrLayer.Bottom). Without a mask the full-screen surface swallows
            // every pointer event over the wallpaper and starves plugin tiles
            // beneath. So claim input ONLY over the visible widget rects, with the
            // whole screen folded in while a slot is being dragged so motion past
            // the rect still reaches the grip (and the release tracks correctly).
            // An empty Region (width/height 0) contributes nothing to the union,
            // which is how a hidden or undragged state collapses cleanly.
            mask: widgetMask
            Region {
                id: widgetMask
                Region {
                    x: clockSlot.x; y: clockSlot.y
                    width: clockSlot.visible ? clockSlot.width : 0
                    height: clockSlot.visible ? clockSlot.height : 0
                }
                Region {
                    x: weatherSlot.x; y: weatherSlot.y
                    width: weatherSlot.visible ? weatherSlot.width : 0
                    height: weatherSlot.visible ? weatherSlot.height : 0
                }
                // Drag tracking: claim the screen while a widget is being dragged
                // so the cursor can leave the rect without losing the grip.
                Region {
                    readonly property bool tracking: clockSlot.dragging || weatherSlot.dragging
                    x: 0; y: 0
                    width: tracking ? win.width : 0
                    height: tracking ? win.height : 0
                }
            }

            // Right-click the bare desktop for the global menu. Sits behind the
            // widgets (which handle their own right-click) and takes only the right
            // button, so a left click on the wallpaper does nothing rather than
            // being swallowed in a way that feels broken.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: (mouse) => menu.openDesktop(mouse.x, mouse.y)
            }

            WidgetGrid {
                anchors.fill: parent
                active: clockSlot.dragging || weatherSlot.dragging
                gridSize: clockSlot.gridSize
            }

            WidgetSlot {
                id: clockSlot
                widget: "clock"
                visible: Config.clockEnabled
                anchor: Config.clockAnchor
                freeX: Config.clockX
                freeY: Config.clockY
                locked: Config.clockLocked
                bg: Config.clockBg
                radius: Config.clockRadius
                scaleCfg: Config.clockScale
                pad: Config.clockBg === "none" ? 0 : Math.round(24 * Config.clockScale)
                opacity: Config.clockOpacity
                onMenuRequested: (x, y, w) => menu.openFor(w, x, y)
                Clock {}
            }

            WidgetSlot {
                id: weatherSlot
                widget: "weather"
                visible: Config.weatherEnabled
                anchor: Config.weatherAnchor
                freeX: Config.weatherX
                freeY: Config.weatherY
                locked: Config.weatherLocked
                bg: Config.weatherBg
                radius: Config.weatherRadius
                scaleCfg: Config.weatherScale
                pad: Config.weatherBg === "none" ? 0 : Math.round(24 * Config.weatherScale)
                opacity: Config.weatherOpacity
                onMenuRequested: (x, y, w) => menu.openFor(w, x, y)
                Weather {}
            }

            WidgetMenu { id: menu }
        }
    }
}
