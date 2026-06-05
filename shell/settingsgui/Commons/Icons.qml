pragma Singleton

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.settingsgui.Commons

Singleton {
  id: root

  readonly property string fontFamily: currentFontLoader ? currentFontLoader.name : ""
  readonly property string defaultIcon: IconsTabler.defaultIcon
  readonly property var icons: IconsTabler.icons
  readonly property var aliases: IconsTabler.aliases
  readonly property string fontPath: "/Assets/Fonts/tabler/ryoku-tabler-icons.ttf"

  property FontLoader currentFontLoader: null
  property int fontVersion: 0

  readonly property string cacheBustingPath: Quickshell.shellDir + "/settingsgui" + fontPath + "?v=" + fontVersion + "&t=" + Date.now()

  signal fontReloaded

  Component.onCompleted: {
    Logger.i("Icons", "Service started");
    loadFontWithCacheBusting();
  }

  Connections {
    target: Quickshell
    function onReloadCompleted() {
      Logger.d("Icons", "Quickshell reload completed - forcing font reload");
      reloadFont();
    }
  }

  function get(iconName) {
    if (aliases[iconName] !== undefined) {
      iconName = aliases[iconName];
    }

    return icons[iconName];
  }

  function loadFontWithCacheBusting() {
    Logger.d("Icons", "Loading font with cache busting");

    if (currentFontLoader) {
      currentFontLoader.destroy();
      currentFontLoader = null;
    }

    currentFontLoader = Qt.createQmlObject(`
                                           import QtQuick
                                           FontLoader {
                                           source: "${cacheBustingPath}"
                                           }
                                           `, root, "dynamicFontLoader_" + fontVersion);

    currentFontLoader.statusChanged.connect(function () {
      if (currentFontLoader.status === FontLoader.Ready) {
        Logger.d("Icons", "Font loaded successfully:", currentFontLoader.name, "(version " + fontVersion + ")");
        fontReloaded();
      } else if (currentFontLoader.status === FontLoader.Error) {
        Logger.e("Icons", "Font failed to load (version " + fontVersion + ")");
      }
    });
  }

  function reloadFont() {
    Logger.d("Icons", "Forcing font reload...");
    fontVersion++;
    loadFontWithCacheBusting();
  }
}
