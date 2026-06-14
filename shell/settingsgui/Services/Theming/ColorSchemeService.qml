pragma Singleton
import Qt.labs.folderlistmodel

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Theming
import qs.settingsgui.Services.UI

Singleton {
  id: root

  property var schemes: []
  property bool scanning: false
  property string schemesDirectory: Quickshell.shellDir + "/settingsgui" + "/Assets/ColorScheme"
  property string downloadedSchemesDirectory: Settings.configDir + "colorschemes"
  property string colorsJsonFilePath: Settings.configDir + "colors.json"
  // Last successfully parsed predefined scheme JSON (full object). Used to refresh app templates
  // on wallpaper changes without re-running applyScheme (avoids rewriting colors.json when unchanged).
  property var lastPredefinedSchemeData: null
  readonly property string gtkRefreshScript: Quickshell.shellDir + "/settingsgui" + "/Scripts/python/src/theming/gtk-refresh.py"

  // prefer-light/prefer-dark only; GTK template post_hook still runs full gtk-refresh.
  function pushSystemColorScheme() {
    if (!GlobalConfig.colorSchemes.syncGsettings)
      return;
    if (TemplateProcessor.isTemplateEnabled("gtk"))
      return;
    const mode = GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
    Quickshell.execDetached(["python3", gtkRefreshScript, "--appearance-only", mode]);
  }

  Connections {
    target: GlobalConfig.colorSchemes
    function onDarkModeChanged() {
      Logger.d("ColorScheme", "Detected dark mode change");
      if (!GlobalConfig.colorSchemes.useWallpaperColors && GlobalConfig.colorSchemes.predefinedScheme) {
        // Re-apply current scheme to pick the right variant
        applyScheme(GlobalConfig.colorSchemes.predefinedScheme);
      }
      root.pushSystemColorScheme();
      const enabled = !!GlobalConfig.colorSchemes.darkMode;
      const label = enabled ? I18n.tr("tooltips.switch-to-dark-mode") : I18n.tr("tooltips.switch-to-light-mode");
      const description = I18n.tr("common.enabled");
      ToastService.showNotice(label, description, "dark-mode");
    }
  }

  function init() {
    // does nothing but ensure the singleton is created
    // do not remove
    Logger.i("ColorScheme", "Service started");
    loadColorSchemes();
  }

  function loadColorSchemes() {
    Logger.d("ColorScheme", "Load colorScheme");
    scanning = true;
    schemes = [];
    Quickshell.execDetached(["mkdir", "-p", downloadedSchemesDirectory]);
    findProcess.command = ["find", "-L", schemesDirectory, downloadedSchemesDirectory, "-mindepth", "2", "-name", "*.json", "-type", "f"];
    findProcess.running = true;
  }

  function getBasename(path) {
    if (!path)
      return "";
    var chunks = path.split("/");
    var filename = chunks[chunks.length - 1];
    var schemeName = filename.replace(".json", "");
    if (schemeName === "ryoku-default") {
      return "Ryoku (default)";
    } else if (schemeName === "ryoku-legacy") {
      return "Ryoku (legacy)";
    } else if (schemeName === "Tokyo-Night") {
      return "Tokyo Night";
    } else if (schemeName === "Rosepine") {
      return "Rose Pine";
    }
    return schemeName;
  }

  function resolveSchemePath(nameOrPath) {
    if (!nameOrPath)
      return "";
    if (nameOrPath.indexOf("/") !== -1) {
      return nameOrPath;
    }
    var schemeName = nameOrPath.replace(".json", "");
    if (schemeName === "Ryoku (default)") {
      schemeName = "ryoku-default";
    } else if (schemeName === "Ryoku (legacy)") {
      schemeName = "ryoku-legacy";
    } else if (schemeName === "Tokyo Night") {
      schemeName = "Tokyo-Night";
    } else if (schemeName === "Rose Pine") {
      schemeName = "Rosepine";
    }
    var preinstalledPath = schemesDirectory + "/" + schemeName + "/" + schemeName + ".json";
    var downloadedPath = downloadedSchemesDirectory + "/" + schemeName + "/" + schemeName + ".json";
    for (var i = 0; i < schemes.length; i++) {
      if (schemes[i].indexOf("/" + schemeName + "/") !== -1 || schemes[i].indexOf("/" + schemeName + ".json") !== -1) {
        return schemes[i];
      }
    }
    // Fallback: prefer preinstalled, then downloaded
    return preinstalledPath;
  }

  function applyScheme(nameOrPath) {
    // Force reload by bouncing the path
    var filePath = resolveSchemePath(nameOrPath);
    schemeReader.path = "";
    schemeReader.path = filePath;
  }

  function setPredefinedScheme(schemeName) {
    Logger.i("ColorScheme", "Attempting to set predefined scheme to:", schemeName);

    var resolvedPath = resolveSchemePath(schemeName);
    var basename = getBasename(schemeName);

    var schemeExists = false;
    for (var i = 0; i < schemes.length; i++) {
      if (getBasename(schemes[i]) === basename) {
        schemeExists = true;
        break;
      }
    }

    if (schemeExists) {
      GlobalConfig.colorSchemes.predefinedScheme = basename;
      GlobalConfig.save();
      applyScheme(schemeName);
      ToastService.showNotice(I18n.tr("panels.color-scheme.title"), basename, "settings-color-scheme");
    } else {
      Logger.e("ColorScheme", "Scheme not found:", schemeName);
      ToastService.showError(I18n.tr("panels.color-scheme.title"), `'${basename}' ` + I18n.tr("common.not-found"));
    }
  }

  Process {
    id: findProcess
    running: false

    onExited: function (exitCode) {
      if (exitCode === 0) {
        var output = stdout.text.trim();
        var files = output.split('\n').filter(function (line) {
          return line.length > 0;
        });
        files.sort(function (a, b) {
          var nameA = getBasename(a).toLowerCase();
          var nameB = getBasename(b).toLowerCase();
          return nameA.localeCompare(nameB);
        });
        schemes = files;
        scanning = false;
        Logger.d("ColorScheme", "Listed", schemes.length, "schemes");
        var stored = GlobalConfig.colorSchemes.predefinedScheme;
        if (stored) {
          var basename = getBasename(stored);
          if (basename !== stored) {
            GlobalConfig.colorSchemes.predefinedScheme = basename;
            GlobalConfig.save();
          }
          if (!GlobalConfig.colorSchemes.useWallpaperColors) {
            applyScheme(basename);
          }
        }
      } else {
        Logger.e("ColorScheme", "Failed to find color scheme files");
        schemes = [];
        scanning = false;
      }
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }

  FileView {
    id: schemeReader
    onLoaded: {
      try {
        var data = JSON.parse(text());
        var variant = data;
        if (data && (data.dark || data.light)) {
          if (GlobalConfig.colorSchemes.darkMode) {
            variant = data.dark || data.light;
          } else {
            variant = data.light || data.dark;
          }
        }
        writeColorsToDisk(variant);
        lastPredefinedSchemeData = data;
        Logger.i("ColorScheme", "Applying color scheme:", getBasename(path));

        if (hasEnabledTemplates() || GlobalConfig.templates.enableUserTheming) {
          AppThemeService.generateFromPredefinedScheme(data);
        }
      } catch (e) {
        Logger.e("ColorScheme", "Failed to parse scheme JSON:", path, e);
      }
    }
  }

  function hasEnabledTemplates() {
    const activeTemplates = GlobalConfig.templates.activeTemplates;
    if (!activeTemplates || activeTemplates.length === 0) {
      return false;
    }
    for (let i = 0; i < activeTemplates.length; i++) {
      if (activeTemplates[i].enabled) {
        return true;
      }
    }
    return false;
  }

  FileView {
    id: colorsWriter
    path: colorsJsonFilePath
    printErrors: false
    onSaved:

    // Logger.i("ColorScheme", "Colors saved")
    {}
    JsonAdapter {
      id: out
      property color mPrimary: "#000000"
      property color mOnPrimary: "#000000"
      property color mSecondary: "#000000"
      property color mOnSecondary: "#000000"
      property color mTertiary: "#000000"
      property color mOnTertiary: "#000000"
      property color mError: "#000000"
      property color mOnError: "#000000"
      property color mSurface: "#000000"
      property color mOnSurface: "#000000"
      property color mSurfaceVariant: "#000000"
      property color mOnSurfaceVariant: "#000000"
      property color mOutline: "#000000"
      property color mShadow: "#000000"
      property color mHover: "#000000"
      property color mOnHover: "#000000"
    }
  }

  function writeColorsToDisk(obj) {
    function pick(o, a, b, fallback) {
      return (o && (o[a] || o[b])) || fallback;
    }
    out.mPrimary = pick(obj, "mPrimary", "primary", out.mPrimary);
    out.mOnPrimary = pick(obj, "mOnPrimary", "onPrimary", out.mOnPrimary);
    out.mSecondary = pick(obj, "mSecondary", "secondary", out.mSecondary);
    out.mOnSecondary = pick(obj, "mOnSecondary", "onSecondary", out.mOnSecondary);
    out.mTertiary = pick(obj, "mTertiary", "tertiary", out.mTertiary);
    out.mOnTertiary = pick(obj, "mOnTertiary", "onTertiary", out.mOnTertiary);
    out.mError = pick(obj, "mError", "error", out.mError);
    out.mOnError = pick(obj, "mOnError", "onError", out.mOnError);
    out.mSurface = pick(obj, "mSurface", "surface", out.mSurface);
    out.mOnSurface = pick(obj, "mOnSurface", "onSurface", out.mOnSurface);
    out.mSurfaceVariant = pick(obj, "mSurfaceVariant", "surfaceVariant", out.mSurfaceVariant);
    out.mOnSurfaceVariant = pick(obj, "mOnSurfaceVariant", "onSurfaceVariant", out.mOnSurfaceVariant);
    out.mOutline = pick(obj, "mOutline", "outline", out.mOutline);
    out.mShadow = pick(obj, "mShadow", "shadow", out.mShadow);
    out.mHover = pick(obj, "mHover", "hover", out.mHover);
    out.mOnHover = pick(obj, "mOnHover", "onHover", out.mOnHover);

    // Force a rewrite by updating the path
    colorsWriter.path = "";
    colorsWriter.path = colorsJsonFilePath;
    colorsWriter.writeAdapter();
  }
}
