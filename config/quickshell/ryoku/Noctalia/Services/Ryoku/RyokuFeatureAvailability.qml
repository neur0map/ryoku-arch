pragma Singleton

import Quickshell

Singleton {
  id: root

  readonly property string unavailableReason: "This Noctalia settings page is not available in Ryoku yet."
  readonly property var enabledRoutes: ({
                                          "general": true,
                                          "user-interface": true,
                                          "color-scheme": true,
                                          "wallpaper": true,
                                          "connections": true,
                                          "wifi": true,
                                          "bluetooth": true,
                                          "audio": true,
                                          "display": true,
                                          "session-menu": true,
                                          "lock-screen": true,
                                          "about": true
                                        })
  readonly property var disabledRoutes: ({
                                           "bar": true,
                                           "dock": true,
                                           "desktop-widgets": true,
                                           "control-center": true,
                                           "launcher": true,
                                           "notifications": true,
                                           "osd": true,
                                           "idle": true,
                                           "location": true,
                                           "system": true,
                                           "plugins": true,
                                           "hooks": true
                                         })

  function isRouteEnabled(route) {
    return enabledRoutes[route] === true;
  }

  function isRouteDisabled(route) {
    return disabledRoutes[route] === true;
  }

  function disabledReason(route) {
    return isRouteEnabled(route) ? "" : unavailableReason;
  }
}
