pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import qs.components
import qs.services
import qs.settingsgui.Modules.Panels.Settings

// Ryoku settings panel host.
//
// The previous 5,507-line inline settings UI was moved aside to
// legacy/controlcenter/Wrapper.qml.orig. Hosts the Settings panel surface,
// opened from the top-center frame through the existing `visibilities.settings`
// flag. The drawer contract (offsetScale / needsKeyboard) is preserved so
// Regions.qml (exclusive zone) and ContentWindow.qml (keyboard focus) keep working.
Item {
  id: root

  required property ShellScreen screen
  required property DrawerVisibilities visibilities

  readonly property bool shouldBeActive: visibilities.settings
  property real offsetScale: shouldBeActive ? 0 : 1
  readonly property bool needsKeyboard: shouldBeActive || offsetScale < 1

  readonly property real availableHeight: Math.max(root.screen.height - Config.border.thickness * 2 - 24, 0)
  readonly property real windowRadius: 16

  // Origin width: the centre-notch width (wired from Panels as bar.islandWidth),
  // falling back to full so the panel only grows in height if no notch origin is
  // set. The panel morphs out of the centre notch and retracts back into it, just
  // like the island/dashboard dropdowns, so the close collapses into the notch
  // shape instead of sliding up and fading (which read as a separate window).
  property real collapsedWidth: 0
  readonly property real startWidth: collapsedWidth > 0 ? collapsedWidth : implicitWidth

  implicitWidth: 900
  implicitHeight: Math.min(950, availableHeight)

  // Morph width notch -> full and height 0 -> full, top pinned at the frame edge
  // (no opacity fade, no slide). The blob behind it (settingsBg, attachTop +
  // pinReach) keeps the neck fused to the notch the whole time.
  visible: offsetScale < 1
  width: startWidth + (implicitWidth - startWidth) * (1 - offsetScale)
  height: implicitHeight * (1 - offsetScale)
  clip: true

  Behavior on offsetScale {
    Anim {
      type: Anim.DefaultSpatial
    }
  }

  Rectangle {
    id: panelBackground

    // Held at full size, top-pinned and centred, so the morphing root clips it in
    // place (the growing clip reveals the content; the content never rescales).
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    implicitWidth: root.implicitWidth
    implicitHeight: root.implicitHeight
    radius: root.windowRadius
    // RYOKU: glass panel — container tone keys off transparency.layers (the
    // see-through level), so the panel is translucent + compositor-blurred like
    // ryoku's other windows and reacts to the Surface-opacity slider.
    color: Colours.tPalette.m3surfaceContainer
    border.width: Math.max(1, Config.border.thickness)
    border.color: Colours.tPalette.m3surfaceContainerHigh
    clip: true

    Loader {
      id: content

      anchors.fill: parent
      anchors.margins: Math.max(1, Config.border.thickness)
      active: root.shouldBeActive || root.visible

      sourceComponent: SettingsContent {
        screen: root.screen
        onCloseRequested: root.visibilities.settings = false
        Component.onCompleted: Qt.callLater(function () {
          if (typeof initialize === "function")
            initialize();
        })
      }
    }
  }
}
