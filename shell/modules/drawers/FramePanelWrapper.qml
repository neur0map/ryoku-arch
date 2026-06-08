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
  readonly property real slideHidden: implicitHeight + 5

  // Only slide in once the panel has actually loaded, so the host never animates an
  // empty zero-sized surface in (which looks like squashed/overlapping content and
  // gives the hover tracker the wrong bounds, closing the popout as the cursor moves in).
  property real offsetScale: shouldBeActive && content.item ? 0 : 1

  x: align === "start" ? 0 : align === "center" ? Math.max(0, Math.round((parent.width - width) / 2)) : Math.max(0, parent.width - width)
  y: edge === "bottom" ? parent.height - implicitHeight + slideHidden * offsetScale : -slideHidden * offsetScale

  implicitWidth: content.item ? content.item.implicitWidth : 0
  implicitHeight: content.item ? content.item.implicitHeight : 0
  visible: offsetScale < 1
  // Fade content in only over the back half of the slide. The blob surface lives in a
  // separate blurred layer that composites a frame or two behind this directly-rendered
  // content; ramping opacity late guarantees the wrapper is on screen before its UI shows.
  opacity: Math.max(0, 1 - offsetScale * 2)

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

    anchors.fill: parent
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
