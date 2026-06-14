pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import qs.components

// Host for a plugin frame popout. Loads the plugin's framePanel QML, positions it at the
// frame edge/corner the manifest asks for, and slides it in when active. The plugin panel
// only draws itself; this wrapper owns position, animation and the blob deform (driven
// from ContentWindow via deformMatrix).
Item {
  id: root

  required property ShellScreen screen
  required property string pluginId
  required property var pluginApi
  required property string panelPath
  required property var frame
  property bool active
  property matrix4x4 deformMatrix

  readonly property string edge: (frame && frame.edge) || "top"
  readonly property string align: (frame && frame.align) || "end"
  // Author-controlled hover zone (px). 0 = let the shell pick a default.
  readonly property real activationWidth: (frame && frame.activationWidth) || 0
  readonly property real activationHeight: (frame && frame.activationHeight) || 0
  readonly property bool shouldBeActive: active

  // Only slide in once the panel has actually loaded, so the host never animates an
  // empty zero-sized surface in (which looks like squashed/overlapping content and
  // gives the hover tracker the wrong bounds, closing the popout as the cursor moves in).
  property real offsetScale: shouldBeActive && content.item ? 0 : 1

  x: align === "start" ? 0 : align === "center" ? Math.max(0, Math.round((parent.width - width) / 2)) : Math.max(0, parent.width - width)
  // Grow out of the frame edge instead of sliding a whole panel in from off-screen:
  // pin to the edge and animate only the visible (clipped) height so the popout
  // begins and ends at the frame. Content is held at full size and revealed.
  y: edge === "bottom" ? parent.height - height : 0
  implicitWidth: content.item ? content.item.implicitWidth : 0
  implicitHeight: content.item ? content.item.implicitHeight : 0
  height: implicitHeight * (1 - offsetScale)
  clip: true
  visible: offsetScale < 1

  transform: Matrix4x4 {
    matrix: root.deformMatrix
  }

  Behavior on offsetScale {
    Anim {
      type: Anim.DefaultSpatial
    }
  }

  Behavior on implicitHeight {
    Anim {
      type: Anim.DefaultSpatial
    }
  }

  Loader {
    id: content

    width: root.width
    height: root.implicitHeight
    y: root.edge === "bottom" ? root.height - root.implicitHeight : 0
    asynchronous: true
    // Build the panel as soon as the plugin registers (off-screen) rather than on first
    // hover. Lazy loading made the corner feel broken: the popout appeared slowly and,
    // until content.item existed, implicitWidth/Height were 0 so the hover zone collapsed
    // and moving toward the content closed it. Async keeps startup non-blocking.
    active: true
    source: "file://" + root.panelPath

    onLoaded: {
      if (item) {
        item.pluginApi = root.pluginApi;
        item.screen = root.screen;
      }
    }

    Binding {
      target: content.item
      property: "active"
      value: root.active
      when: content.item !== null
    }
  }
}
