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

  property real offsetScale: shouldBeActive ? 0 : 1

  x: align === "start" ? 0 : align === "center" ? Math.max(0, Math.round((parent.width - width) / 2)) : Math.max(0, parent.width - width)
  y: edge === "bottom" ? parent.height - implicitHeight + slideHidden * offsetScale : -slideHidden * offsetScale

  implicitWidth: content.item ? content.item.implicitWidth : 0
  implicitHeight: content.item ? content.item.implicitHeight : 0
  visible: offsetScale < 1
  opacity: 1 - offsetScale

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
    active: root.shouldBeActive || root.visible
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
