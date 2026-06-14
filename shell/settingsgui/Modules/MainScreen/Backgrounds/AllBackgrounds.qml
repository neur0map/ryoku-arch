import QtQuick
import QtQuick.Shapes
import qs.settingsgui.Commons
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

/**
* AllBackgrounds - Unified Shape container for all bar and panel backgrounds
*
* Unified shadow system. This component contains a single Shape
* with multiple ShapePath children (one for bar, one for each panel type).
*
* Benefits:
* - Single GPU-accelerated rendering pass for all backgrounds
* - Unified shadow system (one MultiEffect for everything)
*/
Item {
  id: root

  required property var bar

  required property var windowRoot

  readonly property color panelBackgroundColor: Color.mSurface

  anchors.fill: parent

  Item {
    anchors.fill: parent

    // When not using separate bar opacity, use unified approach (original behavior)
    Item {
      anchors.fill: parent
      visible: !Settings.data.bar.useSeparateOpacity

      // Enable layer caching to prevent continuous re-rendering
      layer.enabled: true
      opacity: Style.effectivePanelOpacity

      Shape {
        id: unifiedBackgroundsShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        enabled: false

        Component.onCompleted: {
          Logger.d("AllBackgrounds", "AllBackgrounds initialized");
        }

        /**
        *  Bar
        */
        BarBackground {
          bar: root.bar
          shapeContainer: unifiedBackgroundsShape
          windowRoot: root.windowRoot
          backgroundColor: panelBackgroundColor
        }

        /**
        *  Panel Background Slots
        *  Only 2 slots needed: one for currently open/opening panel, one for closing panel
        */

        // Slot 0: Currently open/opening panel
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[0];
            // Only render if this panel belongs to this screen
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: panelBackgroundColor
        }

        // Slot 1: Closing panel (during transitions)
        PanelBackground {
          assignedPanel: {
            var p = PanelService.backgroundSlotAssignments[1];
            // Only render if this panel belongs to this screen
            return (p && p.screen === root.windowRoot.screen) ? p : null;
          }
          shapeContainer: unifiedBackgroundsShape
          defaultBackgroundColor: panelBackgroundColor
        }
      }

      NDropShadow {
        anchors.fill: parent
        source: unifiedBackgroundsShape
      }
    }

    // When using separate bar opacity, separate the rendering
    Item {
      anchors.fill: parent
      visible: Settings.data.bar.useSeparateOpacity

      Item {
        anchors.fill: parent

        layer.enabled: true
        opacity: Style.effectivePanelOpacity

        Shape {
          id: panelBackgroundsShape
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          asynchronous: true
          enabled: false

          /**
          *  Panel Background Slots
          *  Only 2 slots needed: one for currently open/opening panel, one for closing panel
          */

          // Slot 0: Currently open/opening panel
          PanelBackground {
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[0];
              // Only render if this panel belongs to this screen
              return (p && p.screen === root.windowRoot.screen) ? p : null;
            }
            shapeContainer: panelBackgroundsShape
            defaultBackgroundColor: panelBackgroundColor
          }

          // Slot 1: Closing panel (during transitions)
          PanelBackground {
            assignedPanel: {
              var p = PanelService.backgroundSlotAssignments[1];
              // Only render if this panel belongs to this screen
              return (p && p.screen === root.windowRoot.screen) ? p : null;
            }
            shapeContainer: panelBackgroundsShape
            defaultBackgroundColor: panelBackgroundColor
          }
        }

        NDropShadow {
          anchors.fill: parent
          source: panelBackgroundsShape
        }
      }

      Item {
        anchors.fill: parent

        layer.enabled: true
        opacity: Style.effectiveBarOpacity

        Shape {
          id: barBackgroundShape
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          asynchronous: true
          enabled: false

          BarBackground {
            bar: root.bar
            shapeContainer: barBackgroundShape
            windowRoot: root.windowRoot
            backgroundColor: panelBackgroundColor
          }
        }

        NDropShadow {
          anchors.fill: parent
          source: barBackgroundShape
        }
      }
    }
  }
}
