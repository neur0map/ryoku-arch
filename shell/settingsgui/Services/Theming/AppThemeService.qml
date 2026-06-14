pragma Singleton

import QtQuick
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.UI

Singleton {
  id: root

  Connections {
    target: WallpaperService

    function onWallpaperChanged(screenName, path) {
      var effectiveMonitor = GlobalConfig.colorSchemes.monitorForColors;
      if (effectiveMonitor === "" || effectiveMonitor === undefined) {
        effectiveMonitor = Screen.name;
      }

      if (screenName !== effectiveMonitor)
        return;

      if (GlobalConfig.colorSchemes.useWallpaperColors) {
        generateFromWallpaper();
      } else if (ColorSchemeService.lastPredefinedSchemeData) {
        // Regenerate templates only; skip applyScheme so colors.json and scheme reload stay untouched
        // when outputs are unchanged (see template processor skip-identical writes).
        generateFromPredefinedScheme(ColorSchemeService.lastPredefinedSchemeData);
      } else {
        ColorSchemeService.applyScheme(GlobalConfig.colorSchemes.predefinedScheme);
      }
    }
  }

  Connections {
    target: GlobalConfig.colorSchemes
    function onDarkModeChanged() {
      Logger.d("AppThemeService", "Detected dark mode change");
      generate();
    }
    function onMonitorForColorsChanged() {
      if (GlobalConfig.colorSchemes.useWallpaperColors) {
        Logger.d("AppThemeService", "Monitor for colors changed to:", GlobalConfig.colorSchemes.monitorForColors);
        generateFromWallpaper();
      }
    }
    function onGenerationMethodChanged() {
      Logger.d("AppThemeService", "Generation method changed to:", GlobalConfig.colorSchemes.generationMethod);
      generate();
    }
  }

  function init() {
    Logger.i("AppThemeService", "Service started");
  }

  function generate() {
    if (GlobalConfig.colorSchemes.useWallpaperColors) {
      generateFromWallpaper();
    } else {
      // applyScheme will trigger template generation via schemeReader.onLoaded
      ColorSchemeService.applyScheme(GlobalConfig.colorSchemes.predefinedScheme);
    }
  }

  function generateFromWallpaper() {
    var effectiveMonitor = GlobalConfig.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Screen.name;
    }

    const wp = WallpaperService.getWallpaper(effectiveMonitor);
    if (!wp) {
      Logger.e("AppThemeService", "No wallpaper found for monitor:", effectiveMonitor);
      return;
    }
    const mode = GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
    TemplateProcessor.processWallpaperColors(wp, mode);
  }

  function generateFromPredefinedScheme(schemeData) {
    Logger.i("AppThemeService", "Generating templates from predefined color scheme");
    const mode = GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
    var effectiveMonitor = GlobalConfig.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Screen.name;
    }
    const wallpaperPath = WallpaperService.getWallpaper(effectiveMonitor) || "";
    TemplateProcessor.processPredefinedScheme(schemeData, mode, wallpaperPath);
  }
}
