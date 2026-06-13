pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Power
import qs.settingsgui.Services.Theming
import qs.settingsgui.Services.UI

Singleton {
  id: root

  readonly property ListModel fillModeModel: ListModel {}
  readonly property string defaultDirectory: Settings.preprocessPath(GlobalConfig.wallpaper.directory)
  readonly property string solidColorPrefix: "solid://"

  readonly property ListModel transitionsModel: ListModel {}

  // All transition keys but filter out "none" and "random" so we are left with the real transitions
  readonly property var allTransitions: Array.from({
                                                     "length": transitionsModel.count
                                                   }, (_, i) => transitionsModel.get(i).key).filter(key => key !== "random" && key != "none")

  property var wallpaperLists: ({})
  property int scanningCount: 0

  // Cache for current wallpapers - can be updated directly since we use signals for notifications
  property var currentWallpapers: ({})

  property var alphabeticalIndices: ({})

  // Track used wallpapers for random mode (persisted across reboots)
  property var usedRandomWallpapers: ({})

  property bool isInitialized: false
  property string wallpaperCacheFile: ""

  readonly property bool scanning: (scanningCount > 0)
  readonly property string ryokuDefaultWallpaper: Quickshell.shellDir + "/settingsgui" + "/Assets/Wallpaper/ryoku.png"
  property string defaultWallpaper: ryokuDefaultWallpaper

  signal wallpaperChanged(string screenName, string path)
  signal wallpaperProcessingComplete(string screenName, string path, string cachedPath)
  // Emitted when wallpaper processing (resize/cache) is complete. cachedPath is the resized version.
  signal wallpaperDirectoryChanged(string screenName, string directory)
  signal wallpaperListChanged(string screenName, int count)


  // Browse mode: track current browse path per screen (separate from root directory)
  property var currentBrowsePaths: ({})

  // Wallpaper panel: which appearance slot (light/dark) new selections apply to — like picking a monitor tab
  property string wallpaperSelectionAppearance: "light"

  // Bumped when favorites are added/removed so grid delegates can refresh star state
  property int favoritesRevision: 0

  // After favoriting, refresh snapshot once theme colors finish transitioning
  property var pendingFavoriteSchemeRefresh: null

  signal browsePathChanged(string screenName, string path)

  Timer {
    id: favoriteSchemeDebounceTimer
    interval: 450
    repeat: false
    property string pendingPath: ""
    property string pendingSlot: ""
    onTriggered: {
      var p = pendingPath;
      var s = pendingSlot;
      pendingPath = "";
      pendingSlot = "";
      if (p && root.isFavorite(p)) {
        root.updateFavoriteColorScheme(p, s);
      }
    }
  }

  function scheduleFavoriteSchemeSnapshot(path, slot) {
    Qt.callLater(function () {
      if (root.isFavorite(path)) {
        root.updateFavoriteColorScheme(path, slot);
      }
    });
    favoriteSchemeDebounceTimer.pendingPath = path;
    favoriteSchemeDebounceTimer.pendingSlot = slot;
    favoriteSchemeDebounceTimer.restart();
    if (Color.isTransitioning) {
      root.pendingFavoriteSchemeRefresh = {
        "path": path,
        "slot": slot
      };
    }
  }

  Connections {
    target: GlobalConfig.wallpaper
    function onDirectoryChanged() {
      root.usedRandomWallpapers = {};
      root.refreshWallpapersList();
      if (!GlobalConfig.wallpaper.enableMultiMonitorDirectories) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          root.wallpaperDirectoryChanged(Quickshell.screens[i].name, root.defaultDirectory);
        }
      } else {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          var screenName = Quickshell.screens[i].name;
          var monitor = root.getMonitorConfig(screenName);
          if (!monitor || !monitor.directory) {
            root.wallpaperDirectoryChanged(screenName, root.defaultDirectory);
          }
        }
      }
    }
    function onEnableMultiMonitorDirectoriesChanged() {
      root.usedRandomWallpapers = {};
      root.refreshWallpapersList();
      for (var i = 0; i < Quickshell.screens.length; i++) {
        var screenName = Quickshell.screens[i].name;
        root.wallpaperDirectoryChanged(screenName, root.getMonitorDirectory(screenName));
      }
    }
    function onAutomationEnabledChanged() {
      root.toggleRandomWallpaper();
    }
    function onRandomIntervalSecChanged() {
      root.restartRandomWallpaperTimer();
    }
    function onWallpaperChangeModeChanged() {
      root.alphabeticalIndices = {};
      if (GlobalConfig.wallpaper.automationEnabled) {
        root.restartRandomWallpaperTimer();
        root.setNextWallpaper();
      }
    }
    function onViewModeChanged() {
      root.currentBrowsePaths = {};
      root.refreshWallpapersList();
    }
    function onShowHiddenFilesChanged() {
      root.refreshWallpapersList();
    }
    function onUseSolidColorChanged() {
      if (GlobalConfig.wallpaper.useSolidColor) {
        var solidPath = root.createSolidColorPath(GlobalConfig.wallpaper.solidColor.toString());
        for (var i = 0; i < Quickshell.screens.length; i++) {
          root.wallpaperChanged(Quickshell.screens[i].name, solidPath);
        }
      } else {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          var screenName = Quickshell.screens[i].name;
          root.wallpaperChanged(screenName, root.getWallpaper(screenName) || root.defaultWallpaper);
        }
      }
    }
    function onSolidColorChanged() {
      if (GlobalConfig.wallpaper.useSolidColor) {
        var solidPath = root.createSolidColorPath(GlobalConfig.wallpaper.solidColor.toString());
        for (var i = 0; i < Quickshell.screens.length; i++) {
          root.wallpaperChanged(Quickshell.screens[i].name, solidPath);
        }
      }
    }
    function onSortOrderChanged() {
      root.refreshWallpapersList();
    }
    function onLinkLightAndDarkWallpapersChanged() {
      if (GlobalConfig.wallpaper.linkLightAndDarkWallpapers) {
        root.wallpaperSelectionAppearance = GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
        root._syncWallpaperSlotsWhenLinking();
      }
      root._notifyAllWallpapersChanged();
    }
  }

  Connections {
    target: GlobalConfig.colorSchemes
    function onDarkModeChanged() {
      if (GlobalConfig.wallpaper.linkLightAndDarkWallpapers) {
        root.wallpaperSelectionAppearance = GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
      }
      // Restore scheme from favorite for this light/dark slot before wallpaper refresh
      root.reapplyFavoriteThemeForActiveWallpaper();
      root._notifyAllWallpapersChanged();
    }
  }

  Connections {
    target: WallhavenService
    function onWallpaperDownloaded() {
      root.refreshWallpapersList();
    }
  }

  function init() {
    Logger.i("Wallpaper", "Service started");

    translateModels();
    Qt.callLater(root._dedupeWallpaperFavoritesByPath);

    Qt.callLater(() => {
                   if (typeof Settings !== 'undefined' && Settings.cacheDir) {
                     wallpaperCacheFile = Settings.cacheDir + "wallpapers.json";
                     wallpaperCacheView.path = wallpaperCacheFile;
                   }
                 });

    // Note: isInitialized will be set to true in wallpaperCacheView.onLoaded
    Logger.d("Wallpaper", "Triggering initial wallpaper scan");
    Qt.callLater(refreshWallpapersList);
  }

  // Cache restore updates currentWallpapers without _setWallpaper, so wallpaperChanged does not fire.
  function _scheduleThemeSyncFromCachedWallpaper() {
    Qt.callLater(function () {
      root.reapplyFavoriteThemeForActiveWallpaper();
      if (GlobalConfig.colorSchemes.useWallpaperColors) {
        AppThemeService.generate();
      }
    });
  }

  function translateModels() {
    // Wait for i18n to be ready by retrying every time
    if (!I18n.isLoaded) {
      Qt.callLater(translateModels);
      return;
    }

    fillModeModel.append({
                           "key": "center",
                           "name": I18n.tr("positions.center"),
                           "uniform": 0.0
                         });
    fillModeModel.append({
                           "key": "crop",
                           "name": I18n.tr("wallpaper.fill-modes.crop"),
                           "uniform": 1.0
                         });
    fillModeModel.append({
                           "key": "fit",
                           "name": I18n.tr("wallpaper.fill-modes.fit"),
                           "uniform": 2.0
                         });
    fillModeModel.append({
                           "key": "stretch",
                           "name": I18n.tr("wallpaper.fill-modes.stretch"),
                           "uniform": 3.0
                         });
    fillModeModel.append({
                           "key": "repeat",
                           "name": I18n.tr("wallpaper.fill-modes.repeat"),
                           "uniform": 4.0
                         });

    transitionsModel.append({
                              "key": "none",
                              "name": I18n.tr("common.none")
                            });
    transitionsModel.append({
                              "key": "random",
                              "name": I18n.tr("common.random")
                            });
    transitionsModel.append({
                              "key": "fade",
                              "name": I18n.tr("wallpaper.transitions.fade")
                            });
    transitionsModel.append({
                              "key": "disc",
                              "name": I18n.tr("wallpaper.transitions.disc")
                            });
    transitionsModel.append({
                              "key": "stripes",
                              "name": I18n.tr("wallpaper.transitions.stripes")
                            });
    transitionsModel.append({
                              "key": "wipe",
                              "name": I18n.tr("wallpaper.transitions.wipe")
                            });
    transitionsModel.append({
                              "key": "pixelate",
                              "name": I18n.tr("wallpaper.transitions.pixelate")
                            });
    transitionsModel.append({
                              "key": "honeycomb",
                              "name": I18n.tr("wallpaper.transitions.honeycomb")
                            });
  }

  function getFillModeUniform() {
    for (var i = 0; i < fillModeModel.count; i++) {
      const mode = fillModeModel.get(i);
      if (mode.key === GlobalConfig.wallpaper.fillMode) {
        return mode.uniform;
      }
    }
    // Fallback to crop
    return 1.0;
  }

  function isSolidColorPath(path) {
    return path && typeof path === "string" && path.startsWith(solidColorPrefix);
  }

  function getSolidColor(path) {
    if (!isSolidColorPath(path)) {
      return null;
    }
    return path.substring(solidColorPrefix.length);
  }

  function createSolidColorPath(colorString) {
    return solidColorPrefix + colorString;
  }

  function setSolidColor(colorString) {
    GlobalConfig.wallpaper.solidColor = colorString;
    GlobalConfig.wallpaper.useSolidColor = true;
    GlobalConfig.save();
  }

  // Per-screen wallpaper: persisted as { light, dark } (legacy string loads are normalized)
  function _isSplitWallpaperEntry(entry) {
    if (!entry || typeof entry !== "object") {
      return false;
    }
    return entry.light !== undefined || entry.dark !== undefined;
  }

  function _pathsFromEntry(entry) {
    if (!entry) {
      return {
        light: "",
        dark: ""
      };
    }
    if (typeof entry === "string") {
      return {
        light: entry,
        dark: entry
      };
    }
    return {
      light: entry.light || "",
      dark: entry.dark || ""
    };
  }

  function _cloneWallpaperEntry(entry) {
    if (typeof entry === "string") {
      return {
        light: entry,
        dark: entry
      };
    }
    var p = _pathsFromEntry(entry);
    return {
      light: p.light,
      dark: p.dark
    };
  }

  function _entriesEqual(a, b) {
    if (a === b) {
      return true;
    }
    if (typeof a === "string" && typeof b === "string") {
      return a === b;
    }
    if (typeof a === "string" || typeof b === "string") {
      return false;
    }
    if (!_isSplitWallpaperEntry(a) || !_isSplitWallpaperEntry(b)) {
      return false;
    }
    var pa = _pathsFromEntry(a);
    var pb = _pathsFromEntry(b);
    return pa.light === pb.light && pa.dark === pb.dark;
  }

  function _entryToEffectivePath(entry) {
    if (!entry) {
      return "";
    }
    if (typeof entry === "string") {
      return entry;
    }
    var p = _pathsFromEntry(entry);
    if (GlobalConfig.colorSchemes.darkMode) {
      return p.dark || p.light || "";
    }
    return p.light || p.dark || "";
  }

  function _normalizeAppearanceSlot(slot) {
    return slot === "dark" ? "dark" : "light";
  }

  function _defaultAppearanceSlotForChange(slot) {
    if (slot === "light" || slot === "dark") {
      return slot;
    }
    return GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
  }

  function getWallpaperPathForSlot(screenName, appearanceSlot) {
    if (GlobalConfig.wallpaper.useSolidColor) {
      return createSolidColorPath(GlobalConfig.wallpaper.solidColor.toString());
    }
    var slot = _normalizeAppearanceSlot(appearanceSlot);
    var entry = currentWallpapers[screenName];
    if (!entry) {
      return "";
    }
    var p = _pathsFromEntry(entry);
    if (slot === "dark") {
      return p.dark || p.light || "";
    }
    return p.light || p.dark || "";
  }

  function getWallpapersEffectiveMap() {
    var out = {};
    for (var i = 0; i < Quickshell.screens.length; i++) {
      var n = Quickshell.screens[i].name;
      out[n] = getWallpaper(n);
    }
    return out;
  }

  function _ensureObjectWallpaperEntries() {
    var names = {};
    Object.keys(currentWallpapers).forEach(function (k) {
      names[k] = true;
    });
    for (var i = 0; i < Quickshell.screens.length; i++) {
      names[Quickshell.screens[i].name] = true;
    }
    Object.keys(names).forEach(function (name) {
      var e = currentWallpapers[name];
      if (!e) {
        return;
      }
      if (typeof e === "string") {
        if (GlobalConfig.wallpaper.linkLightAndDarkWallpapers) {
          currentWallpapers[name] = {
            light: e,
            dark: e
          };
        } else {
          currentWallpapers[name] = {
            light: e,
            dark: e
          };
        }
      } else if (_isSplitWallpaperEntry(e)) {
        var p = _pathsFromEntry(e);
        if (GlobalConfig.wallpaper.linkLightAndDarkWallpapers) {
          currentWallpapers[name] = {
            light: p.light || p.dark || "",
            dark: p.dark || p.light || ""
          };
        } else {
          currentWallpapers[name] = {
            light: p.light || "",
            dark: p.dark || ""
          };
        }
      }
    });
    saveTimer.restart();
  }

  function _notifyAllWallpapersChanged() {
    for (var i = 0; i < Quickshell.screens.length; i++) {
      var n = Quickshell.screens[i].name;
      root.wallpaperChanged(n, getWallpaper(n));
    }
  }

  function getMonitorConfig(screenName) {
    var monitors = GlobalConfig.wallpaper.monitorDirectories;
    if (monitors !== undefined) {
      for (var i = 0; i < monitors.length; i++) {
        if (monitors[i].name !== undefined && monitors[i].name === screenName) {
          return monitors[i];
        }
      }
    }
  }

  function getMonitorDirectory(screenName) {
    if (!GlobalConfig.wallpaper.enableMultiMonitorDirectories) {
      return root.defaultDirectory;
    }

    var monitor = getMonitorConfig(screenName);
    if (monitor !== undefined && monitor.directory !== undefined) {
      return Settings.preprocessPath(monitor.directory);
    }

    return root.defaultDirectory;
  }

  function setMonitorDirectory(screenName, directory) {
    var monitors = GlobalConfig.wallpaper.monitorDirectories || [];
    var found = false;

    var newMonitors = monitors.map(function (monitor) {
      if (monitor.name === screenName) {
        found = true;
        return {
          "name": screenName,
          "directory": directory,
          "wallpaper": monitor.wallpaper || ""
        };
      }
      return monitor;
    });

    if (!found) {
      newMonitors.push({
                         "name": screenName,
                         "directory": directory,
                         "wallpaper": ""
                       });
    }

    // Update Settings with new array to ensure proper persistence
    GlobalConfig.wallpaper.monitorDirectories = newMonitors.slice();
    GlobalConfig.save();
    root.wallpaperDirectoryChanged(screenName, Settings.preprocessPath(directory));
  }

  function getWallpaper(screenName) {
    if (GlobalConfig.wallpaper.useSolidColor) {
      return createSolidColorPath(GlobalConfig.wallpaper.solidColor.toString());
    }
    var entry = currentWallpapers[screenName];
    if (entry) {
      var effective = _entryToEffectivePath(entry);
      if (effective) {
        return effective;
      }
    }

    var inherited = _inheritWallpaperFromExistingScreen(screenName);
    if (inherited) {
      return inherited;
    }

    return root.defaultWallpaper;
  }

  function changeWallpaper(path, screenName, appearanceSlot) {
    if (GlobalConfig.wallpaper.useSolidColor) {
      GlobalConfig.wallpaper.useSolidColor = false;
      GlobalConfig.save();
    }

    var slot = _defaultAppearanceSlotForChange(appearanceSlot);

    // Save current favorite color schemes before switching away.
    // This must happen before applyFavoriteTheme (called by the UI)
    // overwrites the settings that _createFavoriteEntry reads.
    _saveOutgoingFavorites(path, screenName, slot);

    if (screenName !== undefined) {
      _setWallpaper(screenName, path, slot);
    } else {
      var allScreenNames = new Set(Object.keys(currentWallpapers));
      for (var i = 0; i < Quickshell.screens.length; i++) {
        allScreenNames.add(Quickshell.screens[i].name);
      }
      allScreenNames.forEach(name => _setWallpaper(name, path, slot));
    }
  }

  // Save the color scheme of any favorited wallpapers that are about
  // to be replaced, while the current settings still reflect them.
  function _saveOutgoingFavorites(newPath, screenName, appearanceSlot) {
    var paths = [];
    var slot = _normalizeAppearanceSlot(appearanceSlot);

    function collectFromEntry(e) {
      if (!e) {
        return;
      }
      if (typeof e === "string") {
        if (e && e !== newPath) {
          paths.push(e);
        }
        return;
      }
      if (!_isSplitWallpaperEntry(e)) {
        return;
      }
      var p = _pathsFromEntry(e);
      if (GlobalConfig.wallpaper.linkLightAndDarkWallpapers) {
        if (p.light && p.light !== newPath) {
          paths.push(p.light);
        }
        if (p.dark && p.dark !== newPath && p.dark !== p.light) {
          paths.push(p.dark);
        }
      } else {
        var old = slot === "dark" ? p.dark : p.light;
        if (old && old !== newPath) {
          paths.push(old);
        }
      }
    }

    if (screenName !== undefined) {
      collectFromEntry(currentWallpapers[screenName]);
    } else {
      var names = new Set(Object.keys(currentWallpapers));
      for (var i = 0; i < Quickshell.screens.length; i++) {
        names.add(Quickshell.screens[i].name);
      }
      names.forEach(function (name) {
        collectFromEntry(currentWallpapers[name]);
      });
    }

    var unique = [];
    for (var j = 0; j < paths.length; j++) {
      if (unique.indexOf(paths[j]) === -1) {
        unique.push(paths[j]);
      }
    }

    unique.forEach(function (path) {
      if (!path || path === newPath) {
        return;
      }
      var favIdx = _findAnyFavoriteIndexForPath(path);
      if (favIdx === _favoriteNotFound) {
        return;
      }
      var app = _favoriteAppearanceSlot(GlobalConfig.wallpaper.favorites[favIdx]);
      updateFavoriteColorScheme(path, app);
    });
  }

  function _inheritWallpaperFromExistingScreen(screenName) {
    for (var i = 0; i < Quickshell.screens.length; i++) {
      var otherName = Quickshell.screens[i].name;
      if (otherName === screenName) {
        continue;
      }
      var entry = currentWallpapers[otherName];
      if (!entry) {
        continue;
      }
      var cloned = _cloneWallpaperEntry(entry);
      if (_entriesEqual(currentWallpapers[screenName], cloned)) {
        return _entryToEffectivePath(cloned);
      }
      currentWallpapers[screenName] = cloned;
      saveTimer.restart();
      root.wallpaperChanged(screenName, _entryToEffectivePath(cloned));
      if (randomWallpaperTimer.running) {
        randomWallpaperTimer.restart();
      }
      return _entryToEffectivePath(cloned);
    }
    return "";
  }

  function _syncWallpaperSlotsWhenLinking() {
    var names = new Set(Object.keys(currentWallpapers));
    for (var i = 0; i < Quickshell.screens.length; i++) {
      names.add(Quickshell.screens[i].name);
    }
    names.forEach(function (name) {
      var e = currentWallpapers[name];
      if (!e) {
        return;
      }
      var eff = _entryToEffectivePath(e);
      if (!eff) {
        return;
      }
      var merged = {
        light: eff,
        dark: eff
      };
      if (_entriesEqual(e, merged)) {
        return;
      }
      currentWallpapers[name] = merged;
      saveTimer.restart();
      root.wallpaperChanged(name, eff);
    });
    if (randomWallpaperTimer.running) {
      randomWallpaperTimer.restart();
    }
  }

  function _setWallpaper(screenName, path, appearanceSlot) {
    if (path === "" || path === undefined) {
      return;
    }

    if (screenName === undefined) {
      Logger.w("Wallpaper", "setWallpaper", "no screen specified");
      return;
    }

    var slot = _normalizeAppearanceSlot(appearanceSlot);
    var oldEntry = currentWallpapers[screenName];
    var p = _pathsFromEntry(oldEntry);
    var newEntry;
    if (GlobalConfig.wallpaper.linkLightAndDarkWallpapers) {
      newEntry = {
        light: path,
        dark: path
      };
    } else if (slot === "dark") {
      newEntry = {
        light: p.light || "",
        dark: path
      };
    } else {
      newEntry = {
        light: path,
        dark: p.dark || ""
      };
    }

    if (_entriesEqual(oldEntry, newEntry)) {
      return;
    }

    currentWallpapers[screenName] = newEntry;
    saveTimer.restart();
    root.wallpaperChanged(screenName, _entryToEffectivePath(newEntry));

    if (randomWallpaperTimer.running) {
      randomWallpaperTimer.restart();
    }
  }

  function setRandomWallpaper(screen) {
    Logger.d("Wallpaper", "setRandomWallpaper");

    if (GlobalConfig.wallpaper.enableMultiMonitorDirectories) {
      if (screen === undefined) {
        for (var i = 0; i < Quickshell.screens.length; i++) {
          var screenName = Quickshell.screens[i].name;
          var wallpaperList = getWallpapersList(screenName);

          if (wallpaperList.length > 0) {
            var randomPath = _pickUnusedRandom(screenName, wallpaperList);
            changeWallpaper(randomPath, screenName);
          }
        }
      } else {
        var wallpaperList = getWallpapersList(screen);
        if (wallpaperList.length > 0) {
          var randomPath = _pickUnusedRandom(screen, wallpaperList);
          changeWallpaper(randomPath, screen);
        }
      }
    } else {
      // We can use any screenName here, so we just pick the primary one.
      var wallpaperList = getWallpapersList(Screen.name);
      if (wallpaperList.length > 0) {
        var randomPath = _pickUnusedRandom("all", wallpaperList);
        changeWallpaper(randomPath, screen);
      }
    }
  }

  // Pick a random wallpaper that hasn't been used yet in the current cycle.
  // Once all wallpapers have been shown, resets the pool (keeping only the
  // last-shown wallpaper to avoid an immediate repeat).
  function _pickUnusedRandom(key, wallpaperList) {
    var used = usedRandomWallpapers[key] || [];

    // Clean stale entries (files that were removed from the directory)
    var wallpaperSet = new Set(wallpaperList);
    used = used.filter(function (path) {
      return wallpaperSet.has(path);
    });

    var unused = wallpaperList.filter(function (path) {
      return used.indexOf(path) === -1;
    });

    // If all have been used, reset but keep the last one to avoid immediate repeat
    if (unused.length === 0) {
      var lastUsed = used.length > 0 ? used[used.length - 1] : "";
      used = lastUsed ? [lastUsed] : [];
      unused = wallpaperList.filter(function (path) {
        return used.indexOf(path) === -1;
      });
      // Edge case: only one wallpaper in the directory
      if (unused.length === 0) {
        unused = wallpaperList;
      }
      Logger.d("Wallpaper", "All wallpapers used for", key, "- resetting pool");
    }

    var randomIndex = Math.floor(Math.random() * unused.length);
    var picked = unused[randomIndex];

    used.push(picked);
    usedRandomWallpapers[key] = used;

    saveTimer.restart();

    return picked;
  }

  function setAlphabeticalWallpaper() {
    Logger.d("Wallpaper", "setAlphabeticalWallpaper");

    if (GlobalConfig.wallpaper.enableMultiMonitorDirectories) {
      for (var i = 0; i < Quickshell.screens.length; i++) {
        var screenName = Quickshell.screens[i].name;
        var wallpaperList = getWallpapersList(screenName);

        if (wallpaperList.length > 0) {
          if (alphabeticalIndices[screenName] === undefined) {
            var currentWallpaper = getWallpaper(screenName) || "";
            var foundIndex = wallpaperList.indexOf(currentWallpaper);
            alphabeticalIndices[screenName] = (foundIndex >= 0) ? foundIndex : 0;
          }

          var currentIndex = alphabeticalIndices[screenName];
          var nextIndex = (currentIndex + 1) % wallpaperList.length;
          alphabeticalIndices[screenName] = nextIndex;

          var nextPath = wallpaperList[nextIndex];
          changeWallpaper(nextPath, screenName);
        }
      }
    } else {
      var wallpaperList = getWallpapersList(Screen.name);
      if (wallpaperList.length > 0) {
        var key = "all";
        if (alphabeticalIndices[key] === undefined) {
          var currentWallpaper = getWallpaper(Screen.name) || "";
          var foundIndex = wallpaperList.indexOf(currentWallpaper);
          alphabeticalIndices[key] = (foundIndex >= 0) ? foundIndex : 0;
        }

        var currentIndex = alphabeticalIndices[key];
        var nextIndex = (currentIndex + 1) % wallpaperList.length;
        alphabeticalIndices[key] = nextIndex;

        var nextPath = wallpaperList[nextIndex];
        changeWallpaper(nextPath, undefined);
      }
    }
  }

  function toggleRandomWallpaper() {
    Logger.d("Wallpaper", "toggleRandomWallpaper");
    if (GlobalConfig.wallpaper.automationEnabled) {
      restartRandomWallpaperTimer();
      setNextWallpaper();
    }
  }

  function setNextWallpaper() {
    var mode = GlobalConfig.wallpaper.wallpaperChangeMode || "random";
    if (mode === "alphabetical") {
      setAlphabeticalWallpaper();
    } else {
      setRandomWallpaper();
    }
  }

  function restartRandomWallpaperTimer() {
    if (GlobalConfig.wallpaper.automationEnabled) {
      randomWallpaperTimer.restart();
    }
  }

  function getWallpapersList(screenName) {
    if (screenName != undefined && wallpaperLists[screenName] != undefined) {
      return wallpaperLists[screenName];
    }
    return [];
  }

  function getCurrentBrowsePath(screenName) {
    if (currentBrowsePaths[screenName] !== undefined) {
      var stored = currentBrowsePaths[screenName];
      var root = getMonitorDirectory(screenName);
      if (root && stored.startsWith(root)) {
        return stored;
      }
      // Stored path is outside the root directory, reset it
      delete currentBrowsePaths[screenName];
    }
    return getMonitorDirectory(screenName);
  }

  function setBrowsePath(screenName, path) {
    if (!screenName)
      return;
    currentBrowsePaths[screenName] = path;
    browsePathChanged(screenName, path);
  }

  function navigateUp(screenName) {
    if (!screenName)
      return;
    var currentPath = getCurrentBrowsePath(screenName);
    var rootPath = getMonitorDirectory(screenName);

    if (!rootPath || currentPath === rootPath)
      return;

    // Get parent directory
    var parentPath = currentPath.replace(/\/[^\/]+\/?$/, "");
    if (parentPath === "")
      parentPath = rootPath;

    // Don't go above root
    if (!parentPath.startsWith(rootPath)) {
      parentPath = rootPath;
    }

    setBrowsePath(screenName, parentPath);
  }

  function navigateToRoot(screenName) {
    if (!screenName)
      return;
    var rootPath = getMonitorDirectory(screenName);
    setBrowsePath(screenName, rootPath);
  }

  // callback receives { files: [], directories: [] }
  function scanDirectoryWithDirs(screenName, directory, callback) {
    if (!directory || directory === "") {
      callback({
                 files: [],
                 directories: []
               });
      return;
    }

    var result = {
      files: [],
      directories: []
    };
    var pendingScans = 2;

    function checkComplete() {
      pendingScans--;
      if (pendingScans === 0) {
        // Files are already sorted by _scanDirectoryInternal according to sortOrder setting
        // Only sort directories alphabetically
        result.directories.sort();
        callback(result);
      }
    }

    _scanDirectoryInternal(screenName, directory, false, false, function (files) {
      result.files = files;
      checkComplete();
    });

    _scanForDirectories(directory, function (dirs) {
      result.directories = dirs;
      checkComplete();
    });
  }

  function _scanForDirectories(directory, callback) {
    var findArgs = ["find", "-L", directory, "-maxdepth", "1", "-mindepth", "1", "-type", "d"];

    var processString = `
    import QtQuick
    import Quickshell.Io
    Process {
      id: process
      command: ${JSON.stringify(findArgs)}
      stdout: StdioCollector {}
      stderr: StdioCollector {}
    }
    `;

    var processObject = Qt.createQmlObject(processString, root, "DirScan");

    processObject.exited.connect(function (exitCode) {
      var dirs = [];
      if (exitCode === 0) {
        var lines = processObject.stdout.text.split('\n');
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();
          if (line !== '') {
            var showHidden = GlobalConfig.wallpaper.showHiddenFiles;
            var name = line.split('/').pop();
            if (showHidden || !name.startsWith('.')) {
              dirs.push(line);
            }
          }
        }
      }
      callback(dirs);
      processObject.destroy();
    });

    processObject.running = true;
  }

  function refreshWallpapersList() {
    // Wait for imageMagickAvailable to be correctly set for ImageCacheService.imageFilters
    if (!ImageCacheService.initialized) {
      Qt.callLater(refreshWallpapersList);
      return;
    }

    var mode = GlobalConfig.wallpaper.viewMode;
    Logger.d("Wallpaper", "refreshWallpapersList", "viewMode:", mode);
    scanningCount = 0;

    if (mode === "recursive") {
      for (var i = 0; i < Quickshell.screens.length; i++) {
        var screenName = Quickshell.screens[i].name;
        var directory = getMonitorDirectory(screenName);
        scanDirectoryRecursive(screenName, directory);
      }
    } else if (mode === "browse") {
      // Note: The actual directory+subdirectory scanning happens in WallpaperPanel
      for (var i = 0; i < Quickshell.screens.length; i++) {
        var screenName = Quickshell.screens[i].name;
        var directory = getCurrentBrowsePath(screenName);
        _scanDirectoryInternal(screenName, directory, false, true, null);
      }
    } else {
      for (var i = 0; i < Quickshell.screens.length; i++) {
        var screenName = Quickshell.screens[i].name;
        var directory = getMonitorDirectory(screenName);
        _scanDirectoryInternal(screenName, directory, false, true, null);
      }
    }
  }

  // recursive: whether to scan subdirectories
  // updateList: whether to update wallpaperLists and emit signal
  // callback: optional callback with files array
  function _scanDirectoryInternal(screenName, directory, recursive, updateList, callback) {
    if (!directory || directory === "") {
      Logger.w("Wallpaper", "Empty directory for", screenName);
      if (updateList) {
        wallpaperLists[screenName] = [];
        wallpaperListChanged(screenName, 0);
      }
      if (callback)
        callback([]);
      return;
    }

    if (recursiveProcesses[screenName]) {
      Logger.d("Wallpaper", "Cancelling existing scan for", screenName);
      recursiveProcesses[screenName].running = false;
      recursiveProcesses[screenName].destroy();
      delete recursiveProcesses[screenName];
      if (updateList)
        scanningCount--;
    }

    if (updateList)
      scanningCount++;
    Logger.i("Wallpaper", "Starting scan for", screenName, "in", directory, "recursive:", recursive);

    var filters = ImageCacheService.imageFilters;
    var findArgs = ["find", "-L", directory];

    if (!recursive) {
      findArgs.push("-maxdepth", "1", "-mindepth", "1");
    }

    findArgs.push("-type", "f", "(");
    for (var i = 0; i < filters.length; i++) {
      if (i > 0) {
        findArgs.push("-o");
      }
      findArgs.push("-iname");
      findArgs.push(filters[i]);
    }
    findArgs.push(")");
    // Add printf to get modification time
    findArgs.push("-printf", "%T@|%p\\n");

    var processString = `
    import QtQuick
    import Quickshell.Io
    Process {
      id: process
      command: ${JSON.stringify(findArgs)}
      stdout: StdioCollector {}
      stderr: StdioCollector {}
    }
    `;

    var processObject = Qt.createQmlObject(processString, root, "Scan_" + screenName);

    // Store reference to avoid garbage collection
    if (updateList) {
      recursiveProcesses[screenName] = processObject;
    }

    var handler = function (exitCode) {
      if (updateList)
        scanningCount--;
      Logger.d("Wallpaper", "Process exited with code", exitCode, "for", screenName);

      var files = [];
      if (exitCode === 0) {
        var lines = processObject.stdout.text.split('\n');
        var parsedFiles = [];

        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim();
          if (line !== '') {
            var parts = line.split('|');
            if (parts.length >= 2) { // Handle potential extra pipes in filename by joining rest
              var timestamp = parseFloat(parts[0]);
              var path = parts.slice(1).join('|');

              var showHidden = GlobalConfig.wallpaper.showHiddenFiles;
              var name = path.split('/').pop();
              if (showHidden || !name.startsWith('.')) {
                parsedFiles.push({
                                   path: path,
                                   time: timestamp,
                                   name: name
                                 });
              }
            } else if (line.indexOf('|') === -1) {
              // Fallback for unexpected output format or old find versions (unlikely but safe)
              var path = line;
              var showHidden = GlobalConfig.wallpaper.showHiddenFiles;
              var name = path.split('/').pop();
              if (showHidden || !name.startsWith('.')) {
                parsedFiles.push({
                                   path: path,
                                   time: 0,
                                   name: name
                                 });
              }
            }
          }
        }
        var sortOrder = GlobalConfig.wallpaper.sortOrder || "name";

        // Fischer-Yates shuffle
        if (sortOrder === "random") {
          for (let i = parsedFiles.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const temp = parsedFiles[i];
            parsedFiles[i] = parsedFiles[j];
            parsedFiles[j] = temp;
          }
        } else {
          parsedFiles.sort(function (a, b) {
            if (sortOrder === "date_desc") { // Newest first
              return b.time - a.time;
            } else if (sortOrder === "date_asc") { // Oldest first
              return a.time - b.time;
            } else if (sortOrder === "name_desc") {
              return b.name.localeCompare(a.name);
            } else { // name (asc)
              return a.name.localeCompare(b.name);
            }
          });
        }

        files = parsedFiles.map(f => f.path);

        if (updateList) {
          wallpaperLists[screenName] = files;

          if (alphabeticalIndices[screenName] !== undefined) {
            var currentWallpaper = getWallpaper(screenName) || "";
            var foundIndex = files.indexOf(currentWallpaper);
            alphabeticalIndices[screenName] = (foundIndex >= 0) ? foundIndex : 0;
          }

          Logger.i("Wallpaper", "Scan completed for", screenName, "found", files.length, "files");
          wallpaperListChanged(screenName, files.length);
        }
      } else {
        Logger.w("Wallpaper", "Scan failed for", screenName, "exit code:", exitCode, "(directory might not exist)");
        if (updateList) {
          wallpaperLists[screenName] = [];
          if (alphabeticalIndices[screenName] !== undefined) {
            alphabeticalIndices[screenName] = 0;
          }
          wallpaperListChanged(screenName, 0);
        }
      }

      if (updateList) {
        delete recursiveProcesses[screenName];
      }

      if (callback)
        callback(files);
      processObject.destroy();
    };

    processObject.exited.connect(handler);
    Logger.d("Wallpaper", "Starting process for", screenName);
    processObject.running = true;
  }

  property var recursiveProcesses: ({})

  function scanDirectoryRecursive(screenName, directory) {
    _scanDirectoryInternal(screenName, directory, true, true, null);
  }

  // TODO (~few weeks): Remove per-favorite `darkMode` (the boolean on each
  // GlobalConfig.wallpaper.favorites[] entry). It duplicates `appearance` and is
  // unrelated to GlobalConfig.colorSchemes.darkMode (global shell light/dark).
  // Plan: one-time migration, then drop writes and the fallback in _favoriteAppearanceSlot.
  readonly property int _favoriteNotFound: -1

  function _favoriteAppearanceSlot(f) {
    if (f.appearance === "light" || f.appearance === "dark") {
      return f.appearance;
    }
    return f.darkMode ? "dark" : "light";
  }

  function _findFavoriteIndex(path, appearanceSlot) {
    var favorites = GlobalConfig.wallpaper.favorites;
    var searchPath = Settings.preprocessPath(path);
    var slot = _normalizeAppearanceSlot(appearanceSlot);
    for (var i = 0; i < favorites.length; i++) {
      if (Settings.preprocessPath(favorites[i].path) !== searchPath) {
        continue;
      }
      if (_favoriteAppearanceSlot(favorites[i]) === slot) {
        return i;
      }
    }
    return _favoriteNotFound;
  }

  function _findAnyFavoriteIndexForPath(path) {
    var favorites = GlobalConfig.wallpaper.favorites;
    var searchPath = Settings.preprocessPath(path);
    for (var i = 0; i < favorites.length; i++) {
      if (Settings.preprocessPath(favorites[i].path) === searchPath) {
        return i;
      }
    }
    return _favoriteNotFound;
  }

  function _dedupeWallpaperFavoritesByPath() {
    var favorites = GlobalConfig.wallpaper.favorites;
    if (!favorites || !favorites.length) {
      return;
    }
    var seen = {};
    var out = [];
    for (var i = 0; i < favorites.length; i++) {
      var key = Settings.preprocessPath(favorites[i].path);
      if (!key || seen[key]) {
        continue;
      }
      seen[key] = true;
      out.push(favorites[i]);
    }
    if (out.length !== favorites.length) {
      GlobalConfig.wallpaper.favorites = out;
      root.favoritesRevision++;
      GlobalConfig.save();
    }
  }

  function _createFavoriteEntry(path, appearanceSlot) {
    var app = _normalizeAppearanceSlot(appearanceSlot);
    return {
      "path": path,
      "appearance": app,
      "colorScheme": GlobalConfig.colorSchemes.predefinedScheme,
      "darkMode": app === "dark" // TODO: remove per-favorite field (see Favorites section note)
                  ,
      "useWallpaperColors": GlobalConfig.colorSchemes.useWallpaperColors,
      "generationMethod": GlobalConfig.colorSchemes.generationMethod,
      "paletteColors": [Color.mPrimary.toString(), Color.mSecondary.toString(), Color.mTertiary.toString(), Color.mError.toString()]
    };
  }

  // Favorites are per (path, light|dark): at most one entry per path, tagged with the tab you starred from.
  function isFavorite(path, appearanceSlot) {
    if (appearanceSlot === undefined || appearanceSlot === null || appearanceSlot === "") {
      return _findAnyFavoriteIndexForPath(path) !== _favoriteNotFound;
    }
    return _findFavoriteIndex(path, appearanceSlot) !== _favoriteNotFound;
  }

  // Single favorite entry per path; use _favoriteAppearanceSlot(entry) for light vs dark it was starred under.
  function favoriteEntryForPath(path) {
    var idx = _findAnyFavoriteIndexForPath(path);
    if (idx === _favoriteNotFound) {
      return null;
    }
    return GlobalConfig.wallpaper.favorites[idx];
  }

  function getFavoriteForDisplay(path) {
    return favoriteEntryForPath(path);
  }

  function toggleFavorite(path, appearanceSlot, screenName) {
    var slot;
    if (appearanceSlot !== undefined && appearanceSlot !== null && appearanceSlot !== "") {
      slot = _normalizeAppearanceSlot(appearanceSlot);
    } else {
      slot = _normalizeAppearanceSlot(root.wallpaperSelectionAppearance);
    }
    var favorites = GlobalConfig.wallpaper.favorites.slice();
    var anyIdx = _findAnyFavoriteIndexForPath(path);
    var applyWallpaperForSlot = false;

    if (anyIdx !== _favoriteNotFound) {
      var existingSlot = _favoriteAppearanceSlot(favorites[anyIdx]);
      if (existingSlot === slot) {
        favorites.splice(anyIdx, 1);
        Logger.d("Wallpaper", "Removed favorite:", path, slot);
        if (favoriteSchemeDebounceTimer.pendingPath === path && favoriteSchemeDebounceTimer.pendingSlot === slot) {
          favoriteSchemeDebounceTimer.stop();
          favoriteSchemeDebounceTimer.pendingPath = "";
          favoriteSchemeDebounceTimer.pendingSlot = "";
        }
        if (root.pendingFavoriteSchemeRefresh && root.pendingFavoriteSchemeRefresh.path === path && root.pendingFavoriteSchemeRefresh.slot === slot) {
          root.pendingFavoriteSchemeRefresh = null;
        }
      } else if (GlobalConfig.wallpaper.linkLightAndDarkWallpapers) {
        favorites[anyIdx] = _createFavoriteEntry(path, slot);
        Logger.d("Wallpaper", "Moved favorite to other appearance:", path, slot);
        root.scheduleFavoriteSchemeSnapshot(path, slot);
        applyWallpaperForSlot = true;
        if (root.pendingFavoriteSchemeRefresh && root.pendingFavoriteSchemeRefresh.path === path) {
          root.pendingFavoriteSchemeRefresh = {
            "path": path,
            "slot": slot
          };
        }
      } else {
        // Separate light/dark wallpapers: star is remove-only (no sun/moon hint for "move" vs unfavorite).
        favorites.splice(anyIdx, 1);
        Logger.d("Wallpaper", "Removed favorite (star on other appearance tab, separate wallpapers):", path);
        if (favoriteSchemeDebounceTimer.pendingPath === path) {
          favoriteSchemeDebounceTimer.stop();
          favoriteSchemeDebounceTimer.pendingPath = "";
          favoriteSchemeDebounceTimer.pendingSlot = "";
        }
        if (root.pendingFavoriteSchemeRefresh && root.pendingFavoriteSchemeRefresh.path === path) {
          root.pendingFavoriteSchemeRefresh = null;
        }
      }
    } else {
      favorites.push(_createFavoriteEntry(path, slot));
      Logger.d("Wallpaper", "Added favorite:", path, slot);
      root.scheduleFavoriteSchemeSnapshot(path, slot);
      applyWallpaperForSlot = true;
    }

    GlobalConfig.wallpaper.favorites = favorites;
    root.favoritesRevision++;
    GlobalConfig.save();

    if (applyWallpaperForSlot) {
      var scr;
      if (GlobalConfig.wallpaper.setWallpaperOnAllMonitors) {
        scr = undefined;
      } else if (screenName !== undefined && screenName !== null && screenName !== "") {
        scr = screenName;
      } else if (Quickshell.screens.length > 0) {
        scr = Quickshell.screens[0].name;
      } else {
        scr = undefined;
      }
      root.changeWallpaper(path, scr, slot);
      root.applyFavoriteTheme(path, scr, slot);
    }

    favoritesChanged(path);
  }

  // Apply saved scheme from a favorite. Optional appearanceSlotOverride sets light vs dark target (UI tab or system mode).
  function _applyFavoriteThemeFromEntry(favorite, appearanceSlotOverride) {
    if (!favorite) {
      return;
    }

    var favApp;
    if (appearanceSlotOverride !== undefined && appearanceSlotOverride !== null && appearanceSlotOverride !== "") {
      favApp = _normalizeAppearanceSlot(appearanceSlotOverride);
    } else {
      favApp = _favoriteAppearanceSlot(favorite);
    }
    var targetDark = favApp === "dark";

    var generationMethodChanging = GlobalConfig.colorSchemes.generationMethod !== favorite.generationMethod;
    var darkModeChanging = GlobalConfig.colorSchemes.darkMode !== targetDark;
    var useWallpaperColorsChanging = GlobalConfig.colorSchemes.useWallpaperColors !== favorite.useWallpaperColors;

    GlobalConfig.colorSchemes.useWallpaperColors = favorite.useWallpaperColors;
    GlobalConfig.colorSchemes.predefinedScheme = favorite.colorScheme;
    GlobalConfig.colorSchemes.generationMethod = favorite.generationMethod;
    GlobalConfig.colorSchemes.darkMode = targetDark;
    GlobalConfig.save();

    // If nothing triggered AppThemeService via change handlers, regenerate once.
    if (!generationMethodChanging && !darkModeChanging && !useWallpaperColorsChanging) {
      AppThemeService.generate();
    } else if (!generationMethodChanging && !darkModeChanging && useWallpaperColorsChanging) {
      AppThemeService.generate();
    }
  }

  // When light/dark changes (or on startup), re-load scheme from the favorite for the wallpaper now shown for that slot.
  function reapplyFavoriteThemeForActiveWallpaper() {
    var effectiveMonitor = GlobalConfig.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }
    var wp = getWallpaper(effectiveMonitor);
    if (!wp || isSolidColorPath(wp)) {
      return;
    }
    var slot = GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
    var favorite = favoriteEntryForPath(wp);
    if (!favorite) {
      return;
    }
    _applyFavoriteThemeFromEntry(favorite, slot);
  }

  function applyFavoriteTheme(path, screenName, appearanceSlot) {
    // Only apply theme if the wallpaper is on the monitor driving colors
    var effectiveMonitor = GlobalConfig.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }
    if (screenName !== undefined && screenName !== effectiveMonitor) {
      return;
    }

    var slot;
    if (appearanceSlot !== undefined && appearanceSlot !== null && appearanceSlot !== "") {
      slot = _normalizeAppearanceSlot(appearanceSlot);
    } else {
      slot = _normalizeAppearanceSlot(root.wallpaperSelectionAppearance);
    }
    var favorite = favoriteEntryForPath(path);
    if (!favorite) {
      return;
    }

    var schemeSlot = slot;
    if (GlobalConfig.wallpaper.linkLightAndDarkWallpapers) {
      schemeSlot = _favoriteAppearanceSlot(favorite);
    }
    _applyFavoriteThemeFromEntry(favorite, schemeSlot);
  }

  function updateFavoriteColorScheme(path, appearanceSlot) {
    var slot = _normalizeAppearanceSlot(appearanceSlot);
    var existingIndex = _findFavoriteIndex(path, slot);
    if (existingIndex === _favoriteNotFound) {
      return;
    }

    var favorites = GlobalConfig.wallpaper.favorites.slice();
    favorites[existingIndex] = _createFavoriteEntry(favorites[existingIndex].path, slot);
    GlobalConfig.wallpaper.favorites = favorites;
    GlobalConfig.save();
    Logger.d("Wallpaper", "Updated color scheme for favorite:", path, slot);
    favoriteDataUpdated(path);
  }

  signal favoritesChanged(string path)
  signal favoriteDataUpdated(string path)

  // Auto-update favorite palette colors when theme colors finish transitioning
  Connections {
    target: Color
    function onIsTransitioningChanged() {
      if (!Color.isTransitioning) {
        _updateCurrentWallpaperFavorites();
      }
    }
  }

  function _updateCurrentWallpaperFavorites() {
    var effectiveMonitor = GlobalConfig.colorSchemes.monitorForColors;
    if (effectiveMonitor === "" || effectiveMonitor === undefined) {
      effectiveMonitor = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }
    var wp = getWallpaper(effectiveMonitor);
    if (!wp) {
      return;
    }
    var favIdx = _findAnyFavoriteIndexForPath(wp);
    if (favIdx === _favoriteNotFound) {
      return;
    }
    var app = _favoriteAppearanceSlot(GlobalConfig.wallpaper.favorites[favIdx]);
    updateFavoriteColorScheme(wp, app);
  }

  Timer {
    id: randomWallpaperTimer
    interval: GlobalConfig.wallpaper.randomIntervalSec * 1000
    running: GlobalConfig.wallpaper.automationEnabled && !PowerProfileService.performanceMode
    repeat: true
    onTriggered: setNextWallpaper()
    triggeredOnStart: false
  }

  FileView {
    id: wallpaperCacheView
    printErrors: false
    watchChanges: false

    adapter: JsonAdapter {
      id: wallpaperCacheAdapter
      property var wallpapers: ({})
      property string defaultWallpaper: root.ryokuDefaultWallpaper
      property var usedRandomWallpapers: ({})
    }

    onLoaded: {
      root.currentWallpapers = wallpaperCacheAdapter.wallpapers || {};
      root.usedRandomWallpapers = wallpaperCacheAdapter.usedRandomWallpapers || {};

      root._ensureObjectWallpaperEntries();

      if (GlobalConfig.wallpaper.linkLightAndDarkWallpapers) {
        root.wallpaperSelectionAppearance = GlobalConfig.colorSchemes.darkMode ? "dark" : "light";
        root._syncWallpaperSlotsWhenLinking();
      }

      if (wallpaperCacheAdapter.defaultWallpaper && wallpaperCacheAdapter.defaultWallpaper !== "") {
        root.defaultWallpaper = wallpaperCacheAdapter.defaultWallpaper;
        Logger.d("Wallpaper", "Loaded default wallpaper from cache:", wallpaperCacheAdapter.defaultWallpaper);
      } else {
        root.defaultWallpaper = root.ryokuDefaultWallpaper;
        Logger.d("Wallpaper", "Using Ryoku default wallpaper");
      }

      Logger.d("Wallpaper", "Loaded wallpapers from cache file:", Object.keys(root.currentWallpapers).length, "screens");
      root.isInitialized = true;
      root._scheduleThemeSyncFromCachedWallpaper();
    }

    onLoadFailed: error => {
      root.currentWallpapers = {};
      Logger.d("Wallpaper", "Cache file doesn't exist or failed to load, starting with empty wallpapers");
      root.isInitialized = true;
      root._scheduleThemeSyncFromCachedWallpaper();
    }
  }

  Timer {
    id: saveTimer
    interval: 500
    repeat: false
    onTriggered: {
      wallpaperCacheAdapter.wallpapers = root.currentWallpapers;
      wallpaperCacheAdapter.defaultWallpaper = root.defaultWallpaper;
      wallpaperCacheAdapter.usedRandomWallpapers = root.usedRandomWallpapers;
      wallpaperCacheView.writeAdapter();
      Logger.d("Wallpaper", "Saved wallpapers to cache file");
    }
  }
}
