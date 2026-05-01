pragma Singleton

import Quickshell

Singleton {
  readonly property string root: Quickshell.shellDir + "/Noctalia"
  readonly property string assets: root + "/Assets"
  readonly property string modules: root + "/Modules"
  readonly property string services: root + "/Services"
  readonly property string widgets: root + "/Widgets"
  readonly property string shaders: root + "/Shaders"
}
