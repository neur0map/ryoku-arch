pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Modules.Panels.Settings
import qs.settingsgui.Services.Platform
import qs.settingsgui.Services.UI

Singleton {
  id: root

  signal pluginLoaded(string pluginId)
  signal pluginUnloaded(string pluginId)
  signal pluginEnabled(string pluginId)
  signal pluginDisabled(string pluginId)
  signal pluginReloaded(string pluginId)
  signal availablePluginsUpdated
  signal allPluginsLoaded

  onAvailablePluginsUpdated: {
    if (shouldCheckUpdatesAfterFetch && Object.keys(activeFetches).length === 0) {
      Logger.d("PluginService", "All registry fetches complete, performing update check");
      performUpdateCheck();
    }
  }

  property var loadedPlugins: ({}) // { pluginId: { component, instance, api } }

  property var availablePlugins: ([]) // Array of plugin metadata from all sources

  // Plugin updates available: { pluginId: { currentVersion, availableVersion } }
  property var pluginUpdates: ({})

  // Plugin updates that require a newer base version: { pluginId: { currentVersion, availableVersion, minRyokuVersion } }
  property var pluginUpdatesPending: ({})

  // Plugin load errors: { pluginId: { error: string, entryPoint: string, timestamp: date } }
  property var pluginErrors: ({})
  signal pluginLoadError(string pluginId, string entryPoint, string error)

  // Track currently installing plugins: { pluginId: true }
  property var installingPlugins: ({})

  // Hot reload: file watchers for plugin directories
  property var pluginFileWatchers: ({}) // { pluginId: FileView }
  property list<string> pluginHotReloadEnabled: [] // List of pluginIds that have hot reload enabled

  property var activeFetches: ({})

  property bool initialized: false
  property bool pluginsFullyLoaded: false

  // Plugin container from shell.qml (for placing Main instances in graphics scene)
  property var pluginContainer: null

  // Screen detector from shell.qml (for withCurrentScreen in plugin API)
  property var screenDetector: null

  // Track if we need to initialize once container is ready
  property bool needsInit: false

  onPluginContainerChanged: {
    if (root.pluginContainer && root.needsInit) {
      Logger.d("PluginService", "Plugin container now available, initializing plugins");
      root.needsInit = false;
      root.init();
    }
  }

  Connections {
    target: PluginRegistry

    function onPluginsChanged() {
      if (!root.initialized) {
        if (root.pluginContainer) {
          root.init();
        } else {
          Logger.d("PluginService", "Deferring plugin init until container is ready");
          root.needsInit = true;
        }
      }
    }
  }

  Connections {
    target: Settings

    function onIsDebugChanged() {
      if (!Settings.isDebug && root.pluginHotReloadEnabled.length > 0) {
        Logger.i("PluginService", "Debug mode disabled, removing all hot reload watchers");
        var plugins = root.pluginHotReloadEnabled.slice(); // copy since we mutate
        for (var i = 0; i < plugins.length; i++) {
          removePluginFileWatcher(plugins[i]);
        }
        root.pluginHotReloadEnabled = [];
      }
    }
  }

  Connections {
    target: I18n

    function onLanguageChanged() {
      Logger.d("PluginService", "Language changed to:", I18n.langCode, "- reloading plugin translations");

      for (var pluginId in root.loadedPlugins) {
        // Use IIFE to capture current loop values (avoid closure bug)
        (function (id, plugin) {
          if (plugin && plugin.api && plugin.manifest) {
            plugin.api.currentLanguage = I18n.langCode;

            loadPluginTranslationsAsync(id, plugin.manifest, I18n.langCode, function (translations) {
              plugin.api.pluginTranslations = translations;

              if (I18n.langCode !== "en") {
                loadPluginTranslationsAsync(id, plugin.manifest, "en", function (fallbackTranslations) {
                  plugin.api.pluginFallbackTranslations = fallbackTranslations;
                  plugin.api.translationVersion++;
                  Logger.d("PluginService", "Reloaded translations for plugin:", id);
                });
              } else {
                plugin.api.pluginFallbackTranslations = {};
                plugin.api.translationVersion++;
                Logger.d("PluginService", "Reloaded translations for plugin:", id);
              }
            });
          }
        })(pluginId, root.loadedPlugins[pluginId]);
      }

      if (root.pluginHotReloadEnabled.length > 0) {
        updateTranslationWatchers();
      }
    }
  }

  property int _pendingPluginLoads: 0

  function init() {
    if (root.initialized) {
      Logger.d("PluginService", "Already initialized, skipping");
      return;
    }

    Logger.i("PluginService", "Initializing plugin system");
    root.initialized = true;

    var allInstalled = PluginRegistry.getAllInstalledPluginIds();
    Logger.d("PluginService", "All installed plugins:", JSON.stringify(allInstalled));
    Logger.d("PluginService", "Plugin states:", JSON.stringify(PluginRegistry.pluginStates));

    var enabledIds = PluginRegistry.getEnabledPluginIds();
    Logger.i("PluginService", "Found", enabledIds.length, "enabled plugins:", JSON.stringify(enabledIds));

    var pluginsToLoad = [];
    for (var i = 0; i < enabledIds.length; i++) {
      var manifest = PluginRegistry.getPluginManifest(enabledIds[i]);
      if (manifest) {
        pluginsToLoad.push(enabledIds[i]);
      } else {
        Logger.w("PluginService", "Plugin", enabledIds[i], "is enabled but not found on disk - install");
        var sourceUrl = PluginRegistry.getPluginSourceUrl(enabledIds[i]);
        root.installPlugin({
                             id: enabledIds[i],
                             source: {
                               url: sourceUrl
                             }
                           }, false, function (success, error, registeredKey) {
                             if (success) {
                               ToastService.showNotice(I18n.tr("panels.plugins.title"), I18n.tr("panels.plugins.install-success", {
                                                                                                  "plugin": registeredKey
                                                                                                }));
                               // Load the plugin since it was already enabled (state persisted but files were missing)
                               loadPlugin(registeredKey);

                               var manifest = PluginRegistry.getPluginManifest(registeredKey);
                               if (manifest && manifest.entryPoints && manifest.entryPoints.barWidget) {
                                 var widgetId = "plugin:" + registeredKey;
                                 addWidgetToBar(widgetId, "right");
                               }
                             } else {
                               ToastService.showError(I18n.tr("panels.plugins.title"), I18n.tr("panels.plugins.install-error", {
                                                                                                 "error": error || "Unknown error"
                                                                                               }));
                             }
                           });
      }
    }

    if (pluginsToLoad.length === 0) {
      root.pluginsFullyLoaded = true;
      Logger.i("PluginService", "No plugins to load");
      root.allPluginsLoaded();
      root._isStartupCheck = true;
      refreshAvailablePlugins();
      return;
    }

    root._pendingPluginLoads = pluginsToLoad.length;

    // Load all plugins (async - they will call _onPluginLoadComplete when done)
    for (var j = 0; j < pluginsToLoad.length; j++) {
      Logger.d("PluginService", "Attempting to load plugin:", pluginsToLoad[j]);
      loadPlugin(pluginsToLoad[j]);
    }
  }

  function _onPluginLoadComplete() {
    root._pendingPluginLoads--;

    if (root._pendingPluginLoads <= 0) {
      root.pluginsFullyLoaded = true;
      Logger.i("PluginService", "All plugins loaded");
      root.allPluginsLoaded();

      root._isStartupCheck = true;
      refreshAvailablePlugins();
    }
  }

  function refreshAvailablePlugins() {
    if (Object.keys(activeFetches).length > 0) {
      Logger.d("PluginService", "Refresh already in progress, skipping duplicate refresh");
      return;
    }

    Logger.i("PluginService", "Refreshing available plugins");
    root.availablePlugins = [];

    shouldCheckUpdatesAfterFetch = true;

    var enabledSources = PluginRegistry.getEnabledSources();
    Logger.d("PluginService", "Fetching from", enabledSources.length, "enabled sources");
    for (var i = 0; i < enabledSources.length; i++) {
      fetchPluginRegistry(enabledSources[i]);
    }
  }

  function fetchPluginRegistry(source) {
    var repoUrl = source.url;
    // The main Ryoku source keeps its catalogues in subdirs of one repo
    // (ryoku-extras), so its plugin registry lives at plugins/registry.json.
    // Custom sources keep registry.json at their repo root.
    var registryPath = (source.url === PluginRegistry.mainSourceUrl) ? "plugins/registry.json" : "registry.json";

    Logger.d("PluginService", "Fetching registry from:", repoUrl);

    // Use git sparse-checkout to fetch only registry.json (--no-cone for single file)
    // GIT_TERMINAL_PROMPT=0 prevents hanging on private repos that need auth
    var fetchCmd = "temp_dir=$(mktemp -d) && GIT_TERMINAL_PROMPT=0 git clone --filter=blob:none --sparse --depth=1 --quiet '" + repoUrl + "' \"$temp_dir\" 2>/dev/null && cd \"$temp_dir\" && git sparse-checkout set --no-cone /" + registryPath + " 2>/dev/null && cat \"$temp_dir/" + registryPath + "\"; rm -rf \"$temp_dir\"";

    var fetchProcess = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { command: ["sh", "-c", "' + fetchCmd.replace(/"/g, '\\"') + '"]; stdout: StdioCollector {} }', root, "FetchRegistry_" + Date.now());

    activeFetches[source.url] = fetchProcess;

    fetchProcess.stdout.onStreamFinished.connect(function () {
      var response = fetchProcess.stdout.text;

      Logger.d("PluginService", "Registry response length:", response ? response.length : 0);

      if (!response || response.trim() === "") {
        Logger.e("PluginService", "Empty response from", source.name);
        delete activeFetches[source.url];
        fetchProcess.destroy();
        return;
      }

      try {
        var registry = JSON.parse(response);

        if (registry && registry.plugins && Array.isArray(registry.plugins)) {
          for (var i = 0; i < registry.plugins.length; i++) {
            var plugin = registry.plugins[i];
            plugin.source = source;

            var compositeKey = PluginRegistry.generateCompositeKey(plugin.id, source.url);
            plugin.downloaded = PluginRegistry.isPluginDownloaded(compositeKey);
            plugin.enabled = PluginRegistry.isPluginEnabled(compositeKey);

            root.availablePlugins.push(plugin);
          }

          Logger.i("PluginService", `Parsed ${registry.plugins.length} plugins manifest from '${source.name}'`);

          // Remove from active fetches BEFORE emitting signal so handler sees correct count
          delete activeFetches[source.url];
          fetchProcess.destroy();

          root.availablePluginsUpdated();
          return;
        }
      } catch (e) {
        Logger.e("PluginService", "Failed to parse registry from", source.name, ":", e);
        Logger.e("PluginService", "Response was:", response ? response.substring(0, 200) : "null");
      }

      delete activeFetches[source.url];
      fetchProcess.destroy();
    });

    fetchProcess.exited.connect(function (exitCode) {
      if (exitCode !== 0) {
        Logger.e("PluginService", "Failed to fetch registry from", source.name, "- exit code:", exitCode);
        delete activeFetches[source.url];
        fetchProcess.destroy();
      }
    });

    fetchProcess.running = true;
  }

  function checkPluginCollision(pluginMetadata) {
    var sourceUrl = pluginMetadata.source.url;
    var compositeKey = PluginRegistry.generateCompositeKey(pluginMetadata.id, sourceUrl);

    if (PluginRegistry.isPluginDownloaded(compositeKey)) {
      return {
        collision: true,
        reason: "already_installed",
        existingKey: compositeKey,
        message: I18n.tr("panels.plugins.collision-already-installed")
      };
    }

    // For official plugins, also check if any custom version with same base ID exists
    if (PluginRegistry.isMainSource(sourceUrl)) {
      var allInstalled = PluginRegistry.getAllInstalledPluginIds();
      for (var i = 0; i < allInstalled.length; i++) {
        var parsed = PluginRegistry.parseCompositeKey(allInstalled[i]);
        if (parsed.pluginId === pluginMetadata.id && !parsed.isOfficial) {
          var sourceName = PluginRegistry.getSourceNameByHash(parsed.sourceHash) || I18n.tr("panels.plugins.source-custom");
          return {
            collision: true,
            reason: "custom_version_exists",
            existingKey: allInstalled[i],
            message: I18n.tr("panels.plugins.collision-custom-version-exists", {
                               source: sourceName
                             })
          };
        }
      }
    }

    // For custom plugins, check if official version exists
    if (!PluginRegistry.isMainSource(sourceUrl)) {
      if (PluginRegistry.isPluginDownloaded(pluginMetadata.id)) {
        return {
          collision: true,
          reason: "official_version_exists",
          existingKey: pluginMetadata.id,
          message: I18n.tr("panels.plugins.collision-official-version-exists")
        };
      }
    }

    return {
      collision: false
    };
  }

  // skipCollisionCheck: set to true when updating an existing plugin
  function installPlugin(pluginMetadata, skipCollisionCheck, callback) {
    var pluginId = pluginMetadata.id;
    // Do not include hash for 3rd party plugins
    var pluginIdRegex = /^[a-f0-9]{6}:/;
    if (pluginIdRegex.test(pluginId)) {
      pluginId = pluginId.substring(7);
    }

    var source = pluginMetadata.source;

    if (!skipCollisionCheck) {
      var collision = checkPluginCollision(pluginMetadata);
      if (collision.collision) {
        Logger.w("PluginService", "Plugin collision detected:", collision.message);
        ToastService.showError(I18n.tr("panels.plugins.title"), collision.message);
        if (callback)
          callback(false, collision.message);
        return;
      }

      // Check base version compatibility (skip when updating - that's handled in performUpdateCheck)
      if (pluginMetadata.minRyokuVersion) {
        var baseVersion = UpdateService.baseVersion;
        if (compareVersions(pluginMetadata.minRyokuVersion, baseVersion) > 0) {
          var incompatibleMsg = I18n.tr("panels.plugins.install-incompatible", {
                                          "plugin": pluginMetadata.name,
                                          "version": pluginMetadata.minRyokuVersion
                                        });
          Logger.w("PluginService", "Plugin incompatible:", incompatibleMsg);
          if (callback)
            callback(false, incompatibleMsg);
          return;
        }
      }
    }

    var compositeKey = PluginRegistry.generateCompositeKey(pluginId, source.url);
    Logger.i("PluginService", "Installing plugin:", compositeKey, "from", source.name);

    var pluginDir = PluginRegistry.getPluginDir(compositeKey);
    var repoUrl = source.url;
    // Plugins from the main catalogue live in a subfolder (e.g. plugins/<id>); the
    // registry entry's `path` says where. Custom sources keep plugins at the repo root,
    // so fall back to the bare id there.
    var pluginPath = pluginMetadata.path || pluginId;

    // Use git sparse-checkout to clone only the plugin subfolder
    // GIT_TERMINAL_PROMPT=0 prevents hanging on private repos that need auth
    // Note: we download from the repo's plugin folder (pluginPath) but save to the
    // compositeKey folder so custom-source plugins never collide with official ones.
    var downloadCmd = "temp_dir=$(mktemp -d) && GIT_TERMINAL_PROMPT=0 git clone --filter=blob:none --sparse --depth=1 --quiet '" + repoUrl + "' \"$temp_dir\" 2>/dev/null && cd \"$temp_dir\" && git sparse-checkout set '" + pluginPath + "' 2>/dev/null && mkdir -p '" + pluginDir + "' && rm -f \"$temp_dir/" + pluginPath + "/settings.json\" && cp -r \"$temp_dir/" + pluginPath
        + "/.\" '" + pluginDir + "/'; exit_code=$?; rm -rf \"$temp_dir\"; exit $exit_code";

    var newInstalling = Object.assign({}, root.installingPlugins);
    newInstalling[pluginId] = true;
    root.installingPlugins = newInstalling;

    var downloadProcess = Qt.createQmlObject('import QtQuick; import Quickshell.Io; Process { command: ["sh", "-c", "' + downloadCmd.replace(/"/g, '\\"') + '"] }', root, "DownloadPlugin_" + pluginId);

    downloadProcess.exited.connect(function (exitCode) {
      var currentInstalling = Object.assign({}, root.installingPlugins);
      delete currentInstalling[pluginId];
      root.installingPlugins = currentInstalling;

      if (exitCode === 0) {
        Logger.i("PluginService", "Downloaded plugin:", compositeKey);

        var manifestPath = pluginDir + "/manifest.json";
        loadManifest(manifestPath, function (success, manifest) {
          if (success) {
            var validation = PluginRegistry.validateManifest(manifest);
            if (validation.valid) {
              var registeredKey = PluginRegistry.registerPlugin(manifest, source.url);
              Logger.i("PluginService", "Installed plugin:", registeredKey);

              updatePluginInAvailable(pluginId, {
                                        downloaded: true
                                      });

              if (callback)
                callback(true, null, registeredKey);
            } else {
              Logger.e("PluginService", "Invalid manifest:", validation.error);
              if (callback)
                callback(false, "Invalid manifest: " + validation.error);
            }
          } else {
            Logger.e("PluginService", "Failed to load manifest for:", compositeKey);
            if (callback)
              callback(false, "Failed to load manifest");
          }
        });
      } else {
        Logger.e("PluginService", "Failed to download plugin:", compositeKey);
        if (callback)
          callback(false, "Download failed");
      }

      downloadProcess.destroy();
    });

    downloadProcess.running = true;
  }

  // Uninstall a plugin (compositeKey is the full key like "abc123:my-plugin" or plain "my-plugin")
  function uninstallPlugin(compositeKey, callback) {
    Logger.i("PluginService", "Uninstalling plugin:", compositeKey);

    if (PluginRegistry.isPluginEnabled(compositeKey)) {
      disablePlugin(compositeKey);
    }

    var pluginDir = PluginRegistry.getPluginDir(compositeKey);

    var removeProcess = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["rm", "-rf", "${pluginDir}"]
      }
    `, root, "RemovePlugin_" + compositeKey);

    removeProcess.exited.connect(function (exitCode) {
      if (exitCode === 0) {
        PluginRegistry.unregisterPlugin(compositeKey);
        Logger.i("PluginService", "Uninstalled plugin:", compositeKey);

        // Update available plugins list (use plain ID to match against availablePlugins)
        var parsed = PluginRegistry.parseCompositeKey(compositeKey);
        updatePluginInAvailable(parsed.pluginId, {
                                  downloaded: false,
                                  enabled: false
                                });

        if (callback)
          callback(true, null);
      } else {
        Logger.e("PluginService", "Failed to uninstall plugin:", pluginId);
        if (callback)
          callback(false, "Failed to remove plugin files");
      }

      removeProcess.destroy();
    });

    removeProcess.running = true;
  }

  // Enable a plugin (compositeKey is the full key like "abc123:my-plugin" or plain "my-plugin")
  function enablePlugin(compositeKey, skipAddToBar) {
    if (PluginRegistry.isPluginEnabled(compositeKey)) {
      Logger.w("PluginService", "Plugin already enabled:", compositeKey);
      return true;
    }

    if (!PluginRegistry.isPluginDownloaded(compositeKey)) {
      Logger.e("PluginService", "Cannot enable: plugin not downloaded:", compositeKey);
      return false;
    }

    PluginRegistry.setPluginEnabled(compositeKey, true);
    loadPlugin(compositeKey);

    // Add plugin widget to bar if it provides one (unless we're restoring from backup)
    if (!skipAddToBar) {
      var manifest = PluginRegistry.getPluginManifest(compositeKey);
      if (manifest && manifest.entryPoints && manifest.entryPoints.barWidget) {
        var widgetId = "plugin:" + compositeKey;
        addWidgetToBar(widgetId, "right");
      }
    }

    // Update available plugins list (use plain ID to match against availablePlugins)
    var parsed = PluginRegistry.parseCompositeKey(compositeKey);
    updatePluginInAvailable(parsed.pluginId, {
                              enabled: true
                            });
    root.pluginEnabled(compositeKey);

    return true;
  }

  function addWidgetToBar(widgetId, section) {
    section = section || "right";

    var sections = ["left", "center", "right"];
    for (var s = 0; s < sections.length; s++) {
      var widgets = Settings.data.bar.widgets[sections[s]] || [];
      for (var i = 0; i < widgets.length; i++) {
        if (widgets[i].id === widgetId) {
          Logger.d("PluginService", "Widget already in bar:", widgetId);
          return false;
        }
      }
    }

    var globalWidgets = Settings.data.bar.widgets[section] || [];
    globalWidgets.push({
                         id: widgetId
                       });
    Settings.data.bar.widgets[section] = globalWidgets;

    var overrides = Settings.data.bar.screenOverrides || [];
    for (var o = 0; o < overrides.length; o++) {
      if (overrides[o] && overrides[o].widgets) {
        var overrideWidgets = overrides[o].widgets;
        var sectionWidgets = overrideWidgets[section] || [];
        var alreadyExists = false;
        for (var j = 0; j < sections.length; j++) {
          var owSec = overrideWidgets[sections[j]] || [];
          for (var k = 0; k < owSec.length; k++) {
            if (owSec[k].id === widgetId) {
              alreadyExists = true;
              break;
            }
          }
          if (alreadyExists)
            break;
        }
        if (!alreadyExists) {
          sectionWidgets.push({
                                id: widgetId
                              });
          overrideWidgets[section] = sectionWidgets;
          Settings.setScreenOverride(overrides[o].name, "widgets", overrideWidgets);
        }
      }
    }

    Logger.i("PluginService", "Added widget", widgetId, "to bar section:", section);
    return true;
  }

  // Disable a plugin (compositeKey is the full key like "abc123:my-plugin" or plain "my-plugin")
  function disablePlugin(compositeKey) {
    if (!PluginRegistry.isPluginEnabled(compositeKey)) {
      Logger.w("PluginService", "Plugin already disabled:", compositeKey);
      return true;
    }

    var widgetId = "plugin:" + compositeKey;
    removeWidgetFromBar(widgetId);

    PluginRegistry.setPluginEnabled(compositeKey, false);
    unloadPlugin(compositeKey);

    // Update available plugins list (use plain ID to match against availablePlugins)
    var parsed = PluginRegistry.parseCompositeKey(compositeKey);
    updatePluginInAvailable(parsed.pluginId, {
                              enabled: false
                            });
    root.pluginDisabled(compositeKey);
    return true;
  }

  function removeWidgetFromBar(widgetId) {
    var sections = ["left", "center", "right"];
    var changed = false;

    for (var s = 0; s < sections.length; s++) {
      var section = sections[s];
      var widgets = Settings.data.bar.widgets[section] || [];
      var newWidgets = [];

      for (var i = 0; i < widgets.length; i++) {
        if (widgets[i].id !== widgetId) {
          newWidgets.push(widgets[i]);
        } else {
          changed = true;
          Logger.i("PluginService", "Removed widget", widgetId, "from bar section:", section);
        }
      }

      if (changed) {
        Settings.data.bar.widgets[section] = newWidgets;
      }
    }

    var overrides = Settings.data.bar.screenOverrides || [];
    for (var o = 0; o < overrides.length; o++) {
      if (overrides[o] && overrides[o].widgets) {
        var overrideWidgets = overrides[o].widgets;
        var overrideChanged = false;
        for (var s2 = 0; s2 < sections.length; s2++) {
          var sec = sections[s2];
          var owWidgets = overrideWidgets[sec] || [];
          var owNew = [];
          for (var j = 0; j < owWidgets.length; j++) {
            if (owWidgets[j].id !== widgetId) {
              owNew.push(owWidgets[j]);
            } else {
              overrideChanged = true;
              changed = true;
              Logger.i("PluginService", "Removed widget", widgetId, "from screen override:", overrides[o].name, "section:", sec);
            }
          }
          if (overrideChanged) {
            overrideWidgets[sec] = owNew;
          }
        }
        if (overrideChanged) {
          Settings.setScreenOverride(overrides[o].name, "widgets", overrideWidgets);
        }
      }
    }

    // Signal the bar to refresh if widgets were removed
    if (changed) {
      BarService.widgetsRevision++;
    }

    return changed;
  }

  function removePluginDesktopWidgetsFromSettings(pluginId) {
    var widgetId = "plugin:" + pluginId;
    var monitorWidgets = GlobalConfig.background.desktopWidgets.monitorWidgets || [];
    var changed = false;

    for (var m = 0; m < monitorWidgets.length; m++) {
      var monitor = monitorWidgets[m];
      var widgets = monitor.widgets || [];
      var newWidgets = [];

      for (var i = 0; i < widgets.length; i++) {
        if (widgets[i].id !== widgetId) {
          newWidgets.push(widgets[i]);
        } else {
          changed = true;
          Logger.i("PluginService", "Removed desktop widget", widgetId, "from monitor:", monitor.name);
        }
      }

      if (newWidgets.length !== widgets.length) {
        monitorWidgets[m].widgets = newWidgets;
      }
    }

    if (changed) {
      GlobalConfig.background.desktopWidgets.monitorWidgets = monitorWidgets;
      GlobalConfig.save();
    }

    return changed;
  }

  // This ensures pluginApi is fully populated before being passed to createObject()
  function loadPluginData(pluginId, manifest, callback) {
    loadPluginSettings(pluginId, function (settings) {
      loadPluginTranslationsAsync(pluginId, manifest, I18n.langCode, function (translations) {
        if (I18n.langCode !== "en") {
          loadPluginTranslationsAsync(pluginId, manifest, "en", function (fallbackTranslations) {
            callback(settings, translations, fallbackTranslations);
          });
        } else {
          callback(settings, translations, {});
        }
      });
    });
  }

  function loadPlugin(pluginId) {
    if (root.loadedPlugins[pluginId]) {
      Logger.w("PluginService", "Plugin already loaded:", pluginId);
      return;
    }

    var manifest = PluginRegistry.getPluginManifest(pluginId);
    if (!manifest) {
      Logger.e("PluginService", "Cannot load: manifest not found for:", pluginId);
      return;
    }

    var pluginDir = PluginRegistry.getPluginDir(pluginId);

    Logger.i("PluginService", "Loading plugin:", pluginId);

    loadPluginData(pluginId, manifest, function (settings, translations, fallbackTranslations) {
      var pluginApi = createPluginAPI(pluginId, manifest, settings, translations, fallbackTranslations);

      root.loadedPlugins[pluginId] = {
        barWidget: null,
        desktopWidget: null,
        launcherProvider: null,
        mainInstance: null,
        api: pluginApi,
        manifest: manifest
      };

      root.clearPluginError(pluginId);

      if (manifest.entryPoints && manifest.entryPoints.main) {
        var mainPath = pluginDir + "/" + manifest.entryPoints.main;
        var loadVersion = PluginRegistry.pluginLoadVersions[pluginId] || 0;
        var mainComponent = Qt.createComponent("file://" + mainPath + "?v=" + loadVersion);

        if (mainComponent.status === Component.Ready) {
          // Get the plugin container from shell.qml (must be in graphics scene)
          if (!root.pluginContainer) {
            Logger.e("PluginService", "Plugin container not set. Shell must set PluginService.pluginContainer.");
            return;
          }

          var mainInstance = mainComponent.createObject(root.pluginContainer, {
                                                          pluginApi: pluginApi
                                                        });

          if (mainInstance) {
            root.loadedPlugins[pluginId].mainInstance = mainInstance;
            pluginApi.mainInstance = mainInstance;
            Logger.i("PluginService", "Loaded Main.qml for plugin:", pluginId);
          } else {
            root.recordPluginError(pluginId, "main", "Failed to instantiate Main.qml");
          }
        } else if (mainComponent.status === Component.Error) {
          root.recordPluginError(pluginId, "main", mainComponent.errorString());
        }
      }

      // Load bar widget component if provided (don't instantiate - BarWidgetRegistry will do that)
      if (manifest.entryPoints && manifest.entryPoints.barWidget) {
        var widgetPath = pluginDir + "/" + manifest.entryPoints.barWidget;
        var widgetLoadVersion = PluginRegistry.pluginLoadVersions[pluginId] || 0;
        var widgetComponent = Qt.createComponent("file://" + widgetPath + "?v=" + widgetLoadVersion);

        if (widgetComponent.status === Component.Ready) {
          root.loadedPlugins[pluginId].barWidget = widgetComponent;
          pluginApi.barWidget = widgetComponent;

          BarWidgetRegistry.registerPluginWidget(pluginId, widgetComponent, manifest.metadata);
          Logger.i("PluginService", "Loaded bar widget for plugin:", pluginId);

          // Now that the widget is registered, bump widgetsRevision so the bar can render it
          BarService.widgetsRevision++;
        } else if (widgetComponent.status === Component.Error) {
          root.recordPluginError(pluginId, "barWidget", widgetComponent.errorString());
        }
      }

      // Load desktop widget component if provided (don't instantiate - DesktopWidgetRegistry will do that)
      if (manifest.entryPoints && manifest.entryPoints.desktopWidget) {
        var desktopWidgetPath = pluginDir + "/" + manifest.entryPoints.desktopWidget;
        var desktopWidgetLoadVersion = PluginRegistry.pluginLoadVersions[pluginId] || 0;
        var desktopWidgetComponent = Qt.createComponent("file://" + desktopWidgetPath + "?v=" + desktopWidgetLoadVersion);

        if (desktopWidgetComponent.status === Component.Ready) {
          root.loadedPlugins[pluginId].desktopWidget = desktopWidgetComponent;
          pluginApi.desktopWidget = desktopWidgetComponent;

          DesktopWidgetRegistry.registerPluginWidget(pluginId, desktopWidgetComponent, manifest.metadata);
          Logger.i("PluginService", "Loaded desktop widget for plugin:", pluginId);
        } else if (desktopWidgetComponent.status === Component.Error) {
          root.recordPluginError(pluginId, "desktopWidget", desktopWidgetComponent.errorString());
        }
      }

      // Load launcher provider component if provided (don't instantiate - Launcher will do that)
      if (manifest.entryPoints && manifest.entryPoints.launcherProvider) {
        var launcherProviderPath = pluginDir + "/" + manifest.entryPoints.launcherProvider;
        var launcherProviderLoadVersion = PluginRegistry.pluginLoadVersions[pluginId] || 0;
        var launcherProviderComponent = Qt.createComponent("file://" + launcherProviderPath + "?v=" + launcherProviderLoadVersion);

        if (launcherProviderComponent.status === Component.Ready) {
          root.loadedPlugins[pluginId].launcherProvider = launcherProviderComponent;
          pluginApi.launcherProvider = launcherProviderComponent;

          LauncherProviderRegistry.registerPluginProvider(pluginId, launcherProviderComponent, manifest.metadata);
          Logger.i("PluginService", "Loaded launcher provider for plugin:", pluginId);
        } else if (launcherProviderComponent.status === Component.Error) {
          root.recordPluginError(pluginId, "launcherProvider", launcherProviderComponent.errorString());
        }
      }

      if (manifest.entryPoints && manifest.entryPoints.controlCenterWidget) {
        var ccWidgetPath = pluginDir + "/" + manifest.entryPoints.controlCenterWidget;
        var ccWidgetLoadVersion = PluginRegistry.pluginLoadVersions[pluginId] || 0;
        var ccWidgetComponent = Qt.createComponent("file://" + ccWidgetPath + "?v=" + ccWidgetLoadVersion);

        if (ccWidgetComponent.status === Component.Ready) {
          root.loadedPlugins[pluginId].controlCenterWidget = ccWidgetComponent;
          pluginApi.controlCenterWidget = ccWidgetComponent;

          ControlCenterWidgetRegistry.registerPluginWidget(pluginId, ccWidgetComponent, manifest.metadata);
          Logger.i("PluginService", "Loaded control center widget for plugin:", pluginId);
        } else if (ccWidgetComponent.status === Component.Error) {
          root.recordPluginError(pluginId, "controlCenterWidget", ccWidgetComponent.errorString());
        }
      }

      Logger.i("PluginService", "Plugin loaded:", pluginId);
      root.pluginLoaded(pluginId);

      setupPluginFileWatcher(pluginId);

      root._onPluginLoadComplete();
    });
  }

  // preserveSettings: if true, don't remove desktop widget settings (used for hot reload)
  function unloadPlugin(pluginId, preserveSettings) {
    var plugin = root.loadedPlugins[pluginId];
    if (!plugin) {
      Logger.w("PluginService", "Plugin not loaded:", pluginId);
      return;
    }

    Logger.i("PluginService", "Unloading plugin:", pluginId);

    removePluginFileWatcher(pluginId);

    if (plugin.manifest.entryPoints && plugin.manifest.entryPoints.barWidget) {
      BarWidgetRegistry.unregisterPluginWidget(pluginId);
    }

    if (plugin.manifest.entryPoints && plugin.manifest.entryPoints.desktopWidget) {
      // Only remove settings when uninstalling, not during hot reload
      if (!preserveSettings) {
        removePluginDesktopWidgetsFromSettings(pluginId);
      }
      DesktopWidgetRegistry.unregisterPluginWidget(pluginId);
    }

    if (plugin.manifest.entryPoints && plugin.manifest.entryPoints.launcherProvider) {
      LauncherProviderRegistry.unregisterPluginProvider(pluginId);
    }

    if (plugin.manifest.entryPoints && plugin.manifest.entryPoints.controlCenterWidget) {
      ControlCenterWidgetRegistry.unregisterPluginWidget(pluginId);
    }

    if (plugin.mainInstance) {
      plugin.mainInstance.destroy();
    }

    delete root.loadedPlugins[pluginId];
    root.pluginUnloaded(pluginId);
    Logger.i("PluginService", "Unloaded plugin:", pluginId);
  }

  function createPluginAPI(pluginId, manifest, settings, translations, fallbackTranslations) {
    var pluginDir = PluginRegistry.getPluginDir(pluginId);

    var api = Qt.createQmlObject(`
      import QtQuick

      QtObject {
        readonly property string pluginId: "${pluginId}"
        readonly property string pluginDir: "${pluginDir}"
        property var pluginSettings: ({})
        property var manifest: ({})

        property var mainInstance: null
        property var barWidget: null
        property var desktopWidget: null
        property var launcherProvider: null
        property var controlCenterWidget: null

        // Panel state: which screen the plugin's panel is currently open on (null if closed)
        property var panelOpenScreen: null

        property var ipcHandlers: ({})

        property var pluginTranslations: ({})
        property var pluginFallbackTranslations: ({})  // English fallback for missing keys
        property string currentLanguage: ""
        property int translationVersion: 0  // Increments when translations change - plugins should depend on this

        property var saveSettings: null
        property var openPanel: null
        property var closePanel: null
        property var togglePanel: null
        property var openLauncher: null
        property var closeLauncher: null
        property var toggleLauncher: null
        property var withCurrentScreen: null
        property var tr: null
        property var trp: null
        property var hasTranslation: null
      }
    `, root, "PluginAPI_" + pluginId);

    api.manifest = manifest;

    // Set current language (can't use binding in Qt.createQmlObject string)
    api.currentLanguage = I18n.langCode;

    // Merge manifest defaults with loaded settings (user settings take priority)
    var defaults = (manifest.metadata && manifest.metadata.defaultSettings) || {};
    api.pluginSettings = Object.assign({}, defaults, settings || {});
    api.pluginTranslations = translations || {};
    api.pluginFallbackTranslations = fallbackTranslations || {};

    var getNestedProperty = function (obj, path) {
      var keys = path.split('.');
      var current = obj;
      for (var i = 0; i < keys.length; i++) {
        if (current === undefined || current === null) {
          return undefined;
        }
        current = current[keys[i]];
      }
      return current;
    };

    api.saveSettings = function () {
      savePluginSettings(pluginId, api.pluginSettings);

      // Replace the entire pluginSettings object to trigger QML property bindings
      // Make a shallow copy so bindings detect the change
      api.pluginSettings = Object.assign({}, api.pluginSettings);
    };

    api.togglePanel = function (screen, buttonItem) {
      // buttonItem: optional, if provided the panel will position near this button
      if (!screen) {
        Logger.w("PluginAPI", "No screen available for toggling panel");
        return false;
      }
      return togglePluginPanel(pluginId, screen, buttonItem);
    };

    api.openPanel = function (screen, buttonItem) {
      // buttonItem: optional, if provided the panel will position near this button
      if (!screen) {
        Logger.w("PluginAPI", "No screen available for opening panel");
        return false;
      }
      return openPluginPanel(pluginId, screen, buttonItem);
    };

    api.closePanel = function (screen) {
      for (var slotNum = 1; slotNum <= 2; slotNum++) {
        var panelName = "pluginPanel" + slotNum;
        var panel = PanelService.getPanel(panelName, screen);
        if (panel && panel.currentPluginId === pluginId) {
          panel.close();
          return true;
        }
      }
      return false;
    };


    var getSearchPrefix = function () {
      var metadata = LauncherProviderRegistry.getProviderMetadata("plugin:" + pluginId);
      var prefix = (metadata && metadata.commandPrefix) ? metadata.commandPrefix : pluginId;
      return ">" + prefix + " ";
    };

    api.openLauncher = function (screen) {
      if (!screen) {
        Logger.w("PluginAPI", "No screen available for opening launcher");
        return;
      }
      PanelService.openLauncherWithSearch(screen, getSearchPrefix());
    };

    api.closeLauncher = function (screen) {
      if (!screen) {
        Logger.w("PluginAPI", "No screen available for closing launcher");
        return;
      }
      PanelService.closeLauncher(screen);
    };

    api.toggleLauncher = function (screen) {
      if (!screen) {
        Logger.w("PluginAPI", "No screen available for toggling launcher");
        return;
      }
      var searchPrefix = getSearchPrefix();
      var searchText = PanelService.getLauncherSearchText(screen);
      var isInThisMode = searchText.startsWith(searchPrefix);
      if (!PanelService.isLauncherOpen(screen)) {
        PanelService.openLauncherWithSearch(screen, searchPrefix);
      } else if (isInThisMode) {
        PanelService.closeLauncher(screen);
      } else {
        PanelService.setLauncherSearchText(screen, searchPrefix);
      }
    };

    api.withCurrentScreen = function (callback) {
      // Detect which screen the cursor is on and call callback with that screen
      if (!root.screenDetector) {
        Logger.w("PluginAPI", "Screen detector not available, using primary screen");
        callback(Quickshell.screens[0]);
        return;
      }
      root.screenDetector.withCurrentScreen(callback);
    };

    api.tr = function (key, interpolations) {
      if (typeof interpolations === 'undefined') {
        interpolations = {};
      }

      var translation = getNestedProperty(api.pluginTranslations, key);

      // Fallback to English if not found in current language
      if (translation === undefined || translation === null || typeof translation !== 'string') {
        translation = getNestedProperty(api.pluginFallbackTranslations, key);
      }

      // Return formatted key if translation not found in any language
      if (translation === undefined || translation === null) {
        return `!!${key}!!`;
      }

      if (typeof translation !== 'string') {
        return `!!${key}!!`;
      }

      // Handle interpolations (e.g., "Hello {name}!")
      var result = translation;
      for (var placeholder in interpolations) {
        var regex = new RegExp('\\{' + placeholder + '\\}', 'g');
        result = result.replace(regex, interpolations[placeholder]);
      }

      return result;
    };

    api.trp = function (key, count, interpolations) {
      if (typeof interpolations === 'undefined') {
        interpolations = {};
      }

      // Use key for singular, key-plural for plural
      const realKey = count === 1 ? key : `${key}-plural`;

      var finalInterpolations = {
        'count': count
      };
      for (var prop in interpolations) {
        finalInterpolations[prop] = interpolations[prop];
      }

      return api.tr(realKey, finalInterpolations);
    };

    api.hasTranslation = function (key) {
      return getNestedProperty(api.pluginTranslations, key) !== undefined || getNestedProperty(api.pluginFallbackTranslations, key) !== undefined;
    };

    return api;
  }

  function loadPluginTranslationsAsync(pluginId, manifest, language, callback) {
    var pluginDir = PluginRegistry.getPluginDir(pluginId);
    var translationFile = pluginDir + "/i18n/" + language + ".json";

    var readProcess = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["cat", "${translationFile}"]
        stdout: StdioCollector {}
      }
    `, root, "ReadTranslation_" + pluginId + "_" + language);

    readProcess.exited.connect(function (exitCode) {
      var translations = {};

      if (exitCode === 0) {
        try {
          translations = JSON.parse(readProcess.stdout.text);
          Logger.d("PluginService", "Loaded translations for", pluginId, "language:", language);
        } catch (e) {
          Logger.w("PluginService", "Failed to parse translations for", pluginId, "language:", language);
        }
      } else {
        Logger.d("PluginService", "No translation file for", pluginId, "language:", language);
      }

      if (callback) {
        callback(translations);
      }

      readProcess.destroy();
    });

    readProcess.running = true;
  }

  function loadPluginSettings(pluginId, callback) {
    var settingsFile = PluginRegistry.getPluginSettingsFile(pluginId);

    var readProcess = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["cat", "${settingsFile}"]
        stdout: StdioCollector {}
      }
    `, root, "ReadSettings_" + pluginId);

    readProcess.exited.connect(function (exitCode) {
      if (exitCode === 0) {
        try {
          var settings = JSON.parse(readProcess.stdout.text);
          callback(settings);
        } catch (e) {
          Logger.w("PluginService", "Failed to parse settings for", pluginId, "- using defaults");
          callback({});
        }
      } else {
        callback({});
      }

      readProcess.destroy();
    });

    readProcess.running = true;
  }

  function savePluginSettings(pluginId, settings) {
    var settingsFile = PluginRegistry.getPluginSettingsFile(pluginId);
    var settingsJson = JSON.stringify(settings, null, 2);

    // Use heredoc delimiter pattern to avoid all escaping issues
    var delimiter = "PLUGIN_SETTINGS_EOF_" + Math.random().toString(36).substr(2, 9);
    var fileEsc = settingsFile.replace(/'/g, "'\\''");

    var settingsDir = settingsFile.substring(0, settingsFile.lastIndexOf('/'));
    var dirEsc = settingsDir.replace(/'/g, "'\\''");

    var writeCmd = "mkdir -p '" + dirEsc + "' && cat > '" + fileEsc + "' << '" + delimiter + "'\n" + settingsJson + "\n" + delimiter + "\n";

    Logger.d("PluginService", "Saving settings to:", settingsFile);

    var pid = Quickshell.execDetached(["sh", "-c", writeCmd]);
    Logger.d("PluginService", "Write process started, PID:", pid);
  }

  function loadManifest(manifestPath, callback) {
    var readProcess = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["cat", "${manifestPath}"]
        stdout: StdioCollector {}
      }
    `, root, "ReadManifest_" + Date.now());

    readProcess.exited.connect(function (exitCode) {
      if (exitCode === 0) {
        try {
          var manifest = JSON.parse(readProcess.stdout.text);
          callback(true, manifest);
        } catch (e) {
          Logger.e("PluginService", "Failed to parse manifest:", e);
          callback(false, null);
        }
      } else {
        Logger.e("PluginService", "Failed to read manifest at:", manifestPath);
        callback(false, null);
      }

      readProcess.destroy();
    });

    readProcess.running = true;
  }

  function updatePluginInAvailable(pluginId, updates) {
    for (var i = 0; i < root.availablePlugins.length; i++) {
      if (root.availablePlugins[i].id === pluginId) {
        for (var key in updates) {
          root.availablePlugins[i][key] = updates[key];
        }
        root.availablePluginsUpdated();
        break;
      }
    }
  }

  function findAvailablePlugin(compositeKeyOrId) {
    var parsed = PluginRegistry.parseCompositeKey(compositeKeyOrId);
    var pluginId = parsed.pluginId;
    var sourceUrl = PluginRegistry.getPluginSourceUrl(compositeKeyOrId);

    for (var i = 0; i < root.availablePlugins.length; i++) {
      if (root.availablePlugins[i].id === pluginId && root.availablePlugins[i].source.url === sourceUrl) {
        return root.availablePlugins[i];
      }
    }
    return null;
  }

  property bool shouldCheckUpdatesAfterFetch: false

  property bool _isStartupCheck: false

  function checkForUpdates() {
    Logger.i("PluginService", "Checking for plugin updates");

    if (root.availablePlugins.length > 0) {
      Logger.d("PluginService", "Available plugins already loaded, checking now");
      performUpdateCheck();
      return;
    }

    if (Object.keys(activeFetches).length > 0) {
      Logger.d("PluginService", "Registry fetch in progress, will check after fetch completes");
      shouldCheckUpdatesAfterFetch = true;
      return;
    }

    Logger.d("PluginService", "No available plugins yet, triggering refresh");
    shouldCheckUpdatesAfterFetch = true;
    refreshAvailablePlugins();
  }

  function performUpdateCheck() {
    var updates = {};
    var pendingUpdates = {};
    var installedIds = PluginRegistry.getAllInstalledPluginIds();

    Logger.d("PluginService", "Checking", installedIds.length, "installed plugins against", root.availablePlugins.length, "available plugins");

    for (var i = 0; i < installedIds.length; i++) {
      var pluginId = installedIds[i];
      var installedManifest = PluginRegistry.getPluginManifest(pluginId);
      var availablePlugin = findAvailablePlugin(pluginId);

      if (installedManifest && availablePlugin) {
        var currentVersion = installedManifest.version;
        var availableVersion = availablePlugin.version;

        Logger.d("PluginService", "Comparing", pluginId + ":", currentVersion, "vs", availableVersion);

        if (compareVersions(availableVersion, currentVersion) > 0) {
          if (availablePlugin.minRyokuVersion) {
            var baseVersion = UpdateService.baseVersion;
            if (compareVersions(availablePlugin.minRyokuVersion, baseVersion) > 0) {
              Logger.d("PluginService", "Pending update for", pluginId + ": requires v" + availablePlugin.minRyokuVersion + " (current: v" + baseVersion + ")");
              pendingUpdates[pluginId] = {
                currentVersion: currentVersion,
                availableVersion: availableVersion,
                minRyokuVersion: availablePlugin.minRyokuVersion
              };
              continue;
            }
          }

          updates[pluginId] = {
            currentVersion: currentVersion,
            availableVersion: availableVersion
          };
          Logger.i("PluginService", "Update available for", pluginId + ":", currentVersion, "→", availableVersion);
        }
      } else if (installedManifest && !availablePlugin) {
        Logger.d("PluginService", "Plugin", pluginId, "not found in available plugins (might be from disabled source)");
      }
    }

    root.pluginUpdates = updates;
    root.pluginUpdatesPending = pendingUpdates;
    var updateCount = Object.keys(updates).length;
    var pendingCount = Object.keys(pendingUpdates).length;
    var updatesDescription = Object.keys(updates).map(function (pluginId) {
      return pluginId + ": " + updates[pluginId].currentVersion + " → " + updates[pluginId].availableVersion;
    }).join("\n");

    if (updateCount > 0) {
      Logger.i("PluginService", updateCount, "plugin update(s) available");

      if (GlobalConfig.plugins.notifyUpdates) {
        ToastService.showNotice(I18n.tr("panels.plugins.title"), I18n.trp("panels.plugins.update-available", updateCount) + "\n\n" + updatesDescription, "plugin", 5000, I18n.tr("panels.plugins.open-plugins-tab"), function () {
          if (root.screenDetector) {
            root.screenDetector.withCurrentScreen(function (screen) {
              var panel = PanelService.getPanel("settingsPanel", screen);
              if (panel) {
                panel.requestedTab = SettingsPanel.Tab.Plugins;
                panel.open();
              }
            });
          } else {
            var panel = PanelService.getPanel("settingsPanel", Quickshell.screens[0]);
            if (panel) {
              panel.requestedTab = SettingsPanel.Tab.Plugins;
              panel.open();
            }
          }
        });
      }
    } else if (pendingCount > 0) {
      Logger.i("PluginService", pendingCount, "plugin update(s) pending (require a newer base version)");
    } else {
      Logger.i("PluginService", "All installed plugins are up to date");
    }

    if (root._isStartupCheck && GlobalConfig.plugins.autoUpdate && updateCount > 0) {
      Logger.i("PluginService", "Auto-updating", updateCount, "plugin(s)");
      updateAllPlugins();
    }

    root._isStartupCheck = false;
    shouldCheckUpdatesAfterFetch = false;
  }

  function updateAllPlugins(callback) {
    var pluginIds = Object.keys(root.pluginUpdates);
    var currentIndex = 0;

    function updateNext() {
      if (currentIndex >= pluginIds.length) {
        ToastService.showNotice(I18n.tr("panels.plugins.title"), I18n.tr("panels.plugins.update-all-success"));
        if (callback)
          callback();
        return;
      }

      var pluginId = pluginIds[currentIndex];
      currentIndex++;

      root.updatePlugin(pluginId, function (success, error) {
        if (!success) {
          Logger.w("PluginService", "Failed to auto-update", pluginId + ":", error);
        }
        Qt.callLater(updateNext);
      });
    }

    updateNext();
  }

  function compareVersions(a, b) {
    var aParts = a.split('.').map(function (x) {
      return parseInt(x) || 0;
    });
    var bParts = b.split('.').map(function (x) {
      return parseInt(x) || 0;
    });

    for (var i = 0; i < 3; i++) {
      var aNum = aParts[i] || 0;
      var bNum = bParts[i] || 0;
      if (aNum > bNum)
        return 1;
      if (aNum < bNum)
        return -1;
    }
    return 0;
  }

  function updatePlugin(pluginId, callback) {
    Logger.i("PluginService", "Updating plugin:", pluginId);

    var availablePlugin = findAvailablePlugin(pluginId);
    if (!availablePlugin) {
      Logger.e("PluginService", "Plugin not found in available plugins:", pluginId);
      if (callback)
        callback(false, "Plugin not found");
      return;
    }

    if (availablePlugin.minRyokuVersion) {
      // Simple check: just warn, don't block (UpdateService would have more sophisticated logic)
      Logger.d("PluginService", "Plugin requires v" + availablePlugin.minRyokuVersion);
    }

    var barBackup = {
      left: JSON.parse(JSON.stringify(Settings.data.bar.widgets.left || [])),
      center: JSON.parse(JSON.stringify(Settings.data.bar.widgets.center || [])),
      right: JSON.parse(JSON.stringify(Settings.data.bar.widgets.right || []))
    };
    var screenOverridesBackup = JSON.parse(JSON.stringify(Settings.data.bar.screenOverrides || []));
    Logger.d("PluginService", "Backed up bar layout (global + screen overrides)");

    var desktopWidgetsBackup = JSON.parse(JSON.stringify(GlobalConfig.background.desktopWidgets.monitorWidgets || []));
    Logger.d("PluginService", "Backed up desktop widget settings");

    for (var slotNum = 1; slotNum <= 2; slotNum++) {
      var panelName = "pluginPanel" + slotNum;
      for (var s = 0; s < Quickshell.screens.length; s++) {
        var panel = PanelService.getPanel(panelName, Quickshell.screens[s]);
        if (panel && panel.currentPluginId === pluginId) {
          Logger.d("PluginService", "Closing plugin panel before update");
          panel.close();
          panel.unloadPluginPanel();
        }
      }
    }

    if (PluginRegistry.isPluginEnabled(pluginId)) {
      disablePlugin(pluginId);
    }

    installPlugin(availablePlugin, true, function (success, error) {
      if (success) {
        Logger.i("PluginService", "Plugin updated successfully:", pluginId);

        // Increment load version to invalidate Qt component cache
        PluginRegistry.incrementPluginLoadVersion(pluginId);

        // Re-enable the plugin first, so the new component is registered
        // Skip adding to bar since we'll restore the layout from backup
        enablePlugin(pluginId, true);

        // Then restore bar layout (so BarWidgetLoaders can find the new component)
        Settings.data.bar.widgets.left = barBackup.left;
        Settings.data.bar.widgets.center = barBackup.center;
        Settings.data.bar.widgets.right = barBackup.right;
        Settings.data.bar.screenOverrides = screenOverridesBackup;
        Logger.d("PluginService", "Restored bar layout (global + screen overrides)");

        GlobalConfig.background.desktopWidgets.monitorWidgets = desktopWidgetsBackup;
        GlobalConfig.save();
        Logger.d("PluginService", "Restored desktop widget settings");

        // Persist restored layout immediately to prevent race with file watcher reload
        // (the earlier disablePlugin write triggers a reload that can overwrite the restore)
        Settings.saveImmediate();

        var updates = Object.assign({}, root.pluginUpdates);
        delete updates[pluginId];
        root.pluginUpdates = updates;

        if (callback)
          callback(true, null);
      } else {
        Logger.e("PluginService", "Failed to update plugin:", pluginId, error);

        Settings.data.bar.widgets.left = barBackup.left;
        Settings.data.bar.widgets.center = barBackup.center;
        Settings.data.bar.widgets.right = barBackup.right;
        Settings.data.bar.screenOverrides = screenOverridesBackup;

        GlobalConfig.background.desktopWidgets.monitorWidgets = desktopWidgetsBackup;
        GlobalConfig.save();
        Settings.saveImmediate();

        if (callback)
          callback(false, error);
      }
    });
  }

  function getPluginAPI(pluginId) {
    return root.loadedPlugins[pluginId]?.api || null;
  }

  function isPluginLoaded(pluginId) {
    return !!root.loadedPlugins[pluginId];
  }

  function openPluginPanel(pluginId, screen, buttonItem) {
    if (!isPluginLoaded(pluginId)) {
      Logger.w("PluginService", "Cannot open panel: plugin not loaded:", pluginId);
      return false;
    }

    var plugin = root.loadedPlugins[pluginId];
    if (!plugin || !plugin.manifest || !plugin.manifest.entryPoints || !plugin.manifest.entryPoints.panel) {
      Logger.w("PluginService", "Plugin does not provide a panel:", pluginId);
      return false;
    }

    // Priority: 1) toggle same plugin, 2) empty slot, 3) closed slot, 4) replace open slot
    var closedSlot = null;

    for (var slotNum = 1; slotNum <= 2; slotNum++) {
      var panelName = "pluginPanel" + slotNum;
      var panel = PanelService.getPanel(panelName, screen);

      if (panel) {
        if (panel.currentPluginId === pluginId) {
          panel.toggle(buttonItem);
          return true;
        }

        if (panel.currentPluginId === "") {
          panel.currentPluginId = pluginId;
          panel.open(buttonItem);
          return true;
        }

        if (!closedSlot && !panel.isPanelOpen) {
          closedSlot = panel;
        }
      }
    }

    if (closedSlot) {
      closedSlot.currentPluginId = pluginId;
      closedSlot.open(buttonItem);
      return true;
    }

    var panel1 = PanelService.getPanel("pluginPanel1", screen);
    if (panel1) {
      var wasAlreadyOpen = panel1.isPanelOpen;
      panel1.unloadPluginPanel();
      panel1.currentPluginId = pluginId;

      // If panel was already open, Component.onCompleted won't fire again
      // since panelContent is already loaded. We need to load the plugin manually.
      if (wasAlreadyOpen && panel1.contentLoader) {
        panel1.loadPluginPanel(pluginId);
      }

      panel1.open(buttonItem);
      return true;
    }

    Logger.e("PluginService", "Failed to find plugin panel slot");
    return false;
  }

  // buttonItem: optional, if provided the panel will position near this button
  function togglePluginPanel(pluginId, screen, buttonItem) {
    if (!isPluginLoaded(pluginId)) {
      Logger.w("PluginService", "Cannot toggle panel: plugin not loaded:", pluginId);
      return false;
    }

    var plugin = root.loadedPlugins[pluginId];
    if (!plugin || !plugin.manifest || !plugin.manifest.entryPoints || !plugin.manifest.entryPoints.panel) {
      Logger.w("PluginService", "Plugin does not provide a panel:", pluginId);
      return false;
    }

    for (var slotNum = 1; slotNum <= 2; slotNum++) {
      var panelName = "pluginPanel" + slotNum;
      var panel = PanelService.getPanel(panelName, screen);

      if (panel && panel.currentPluginId === pluginId) {
        panel.toggle(buttonItem);
        return true;
      }
    }

    return openPluginPanel(pluginId, screen, buttonItem);
  }


  function recordPluginError(pluginId, entryPoint, errorMessage) {
    var errors = Object.assign({}, root.pluginErrors);
    errors[pluginId] = {
      error: errorMessage,
      entryPoint: entryPoint,
      timestamp: new Date()
    };
    root.pluginErrors = errors;
    root.pluginLoadError(pluginId, entryPoint, errorMessage);
    Logger.e("PluginService", "Plugin load error [" + pluginId + "/" + entryPoint + "]:", errorMessage);
  }

  function clearPluginError(pluginId) {
    if (pluginId in root.pluginErrors) {
      var errors = Object.assign({}, root.pluginErrors);
      delete errors[pluginId];
      root.pluginErrors = errors;
    }
  }

  function getPluginError(pluginId) {
    return root.pluginErrors[pluginId] || null;
  }

  function hasPluginError(pluginId) {
    return pluginId in root.pluginErrors;
  }


  function setupPluginFileWatcher(pluginId) {
    if (!isPluginHotReloadEnabled(pluginId)) {
      return;
    }

    if (root.pluginFileWatchers[pluginId]) {
      return;
    }

    var manifest = PluginRegistry.getPluginManifest(pluginId);
    if (!manifest) {
      return;
    }

    var pluginDir = PluginRegistry.getPluginDir(pluginId);

    var debounceTimer = Qt.createQmlObject(`
      import QtQuick
      Timer {
        property string targetPluginId: ""
        property var reloadCallback: null
        interval: 500
        repeat: false
        onTriggered: {
          if (reloadCallback) reloadCallback(targetPluginId);
        }
      }
    `, root, "HotReloadDebounce_" + pluginId);

    debounceTimer.targetPluginId = pluginId;
    debounceTimer.reloadCallback = root.reloadPlugin;

    var manifestWatcher = Qt.createQmlObject(`
      import Quickshell.Io
      FileView {
        path: "${pluginDir}/manifest.json"
        watchChanges: true
      }
    `, root, "ManifestWatcher_" + pluginId);

    var watchers = [manifestWatcher];

    // Only watch .qml and .js files, also follow symlinks since some of the plugins might have been symlinked in.
    var qmlWatcher = Qt.createQmlObject(`
        import QtQuick
        import Quickshell.Io

        import qs.settingsgui.Commons

        Item {
            id: root
            signal fileChanged();

            Process {
                command: [ "sh", "-c", "find -L ${pluginDir} -name '*.qml' -o -name '*.js'" ]
                running: true
                stdout: SplitParser {
                    splitMarker: "\n"
                    onRead: line => {
                        fileWatcher.createObject(root, { path: Qt.resolvedUrl(line) });
                    }
                }
            }

            Component {
                id: fileWatcher
                FileView {
                    watchChanges: true

                    onFileChanged: {
                        root.fileChanged();
                    }
                }
            }

        }
    `, root, "QmlWatcher_" + pluginId);
    watchers.push(qmlWatcher);

    for (var j = 0; j < watchers.length; j++) {
      watchers[j].fileChanged.connect(function () {
        debounceTimer.restart();
      });
    }

    var translationDebounceTimer = Qt.createQmlObject(`
      import QtQuick
      Timer {
        property string targetPluginId: ""
        property var reloadCallback: null
        interval: 300
        repeat: false
        onTriggered: {
          if (reloadCallback) reloadCallback(targetPluginId);
        }
      }
    `, root, "TranslationReloadDebounce_" + pluginId);

    translationDebounceTimer.targetPluginId = pluginId;
    translationDebounceTimer.reloadCallback = root.reloadPluginTranslations;

    var translationWatcher = createTranslationWatcher(pluginId, pluginDir, I18n.langCode, translationDebounceTimer);

    root.pluginFileWatchers[pluginId] = {
      watchers: watchers,
      debounceTimer: debounceTimer,
      translationWatcher: translationWatcher,
      translationDebounceTimer: translationDebounceTimer,
      pluginDir: pluginDir
    };

    Logger.d("PluginService", "Set up hot reload watcher for plugin:", pluginId, "(including translations)");
  }

  function createTranslationWatcher(pluginId, pluginDir, language, debounceTimer) {
    var translationFile = pluginDir + "/i18n/" + language + ".json";

    var watcher = Qt.createQmlObject(`
      import Quickshell.Io
      FileView {
        path: "${translationFile}"
        watchChanges: true
      }
    `, root, "TranslationWatcher_" + pluginId + "_" + language);

    watcher.fileChanged.connect(function () {
      debounceTimer.restart();
    });

    Logger.d("PluginService", "Watching translation file:", translationFile);
    return watcher;
  }

  function updateTranslationWatchers() {
    for (var pluginId in root.pluginFileWatchers) {
      var watcherData = root.pluginFileWatchers[pluginId];
      if (!watcherData || !watcherData.translationDebounceTimer)
        continue;

      if (watcherData.translationWatcher) {
        watcherData.translationWatcher.destroy();
      }

      watcherData.translationWatcher = createTranslationWatcher(pluginId, watcherData.pluginDir, I18n.langCode, watcherData.translationDebounceTimer);
    }
    Logger.d("PluginService", "Updated translation watchers for language:", I18n.langCode);
  }

  function removePluginFileWatcher(pluginId) {
    var watcherData = root.pluginFileWatchers[pluginId];
    if (!watcherData) {
      return;
    }

    if (watcherData.watchers) {
      for (var i = 0; i < watcherData.watchers.length; i++) {
        if (watcherData.watchers[i]) {
          watcherData.watchers[i].destroy();
        }
      }
    }

    if (watcherData.debounceTimer) {
      watcherData.debounceTimer.destroy();
    }

    if (watcherData.translationWatcher) {
      watcherData.translationWatcher.destroy();
    }

    if (watcherData.translationDebounceTimer) {
      watcherData.translationDebounceTimer.destroy();
    }

    delete root.pluginFileWatchers[pluginId];
    Logger.d("PluginService", "Removed hot reload watcher for plugin:", pluginId);
  }

  function reloadPlugin(pluginId) {
    if (!root.loadedPlugins[pluginId]) {
      Logger.w("PluginService", "Cannot reload: plugin not loaded:", pluginId);
      return false;
    }

    Logger.i("PluginService", "Hot reloading plugin:", pluginId);

    var manifest = PluginRegistry.getPluginManifest(pluginId);
    if (!manifest) {
      Logger.e("PluginService", "Cannot reload: manifest not found for:", pluginId);
      return false;
    }

    BarService.destroyPluginWidgetInstances(pluginId);

    // Pass true to preserve desktop widget settings during hot reload
    unloadPlugin(pluginId, true);

    // Increment load version to invalidate Qt's component cache
    PluginRegistry.incrementPluginLoadVersion(pluginId);

    // Use Qt.callLater to ensure destruction is complete before reloading
    // This prevents IPC handler conflicts and other timing issues
    Qt.callLater(function () {
      loadPlugin(pluginId);

      // Re-setup file watcher (it was destroyed during unload)
      setupPluginFileWatcher(pluginId);

      root.pluginReloaded(pluginId);

      var pluginName = manifest.name || pluginId;
      ToastService.showNotice(I18n.tr("panels.plugins.title"), I18n.tr("panels.plugins.hot-reloaded", {
                                                                         "name": pluginName
                                                                       }));

      Logger.i("PluginService", "Hot reload complete for plugin:", pluginId);
    });

    return true;
  }

  function reloadPluginTranslations(pluginId) {
    var plugin = root.loadedPlugins[pluginId];
    if (!plugin || !plugin.api || !plugin.manifest) {
      Logger.w("PluginService", "Cannot reload translations: plugin not loaded:", pluginId);
      return false;
    }

    Logger.i("PluginService", "Hot reloading translations for plugin:", pluginId);

    loadPluginTranslationsAsync(pluginId, plugin.manifest, I18n.langCode, function (translations) {
      plugin.api.pluginTranslations = translations;

      if (I18n.langCode !== "en") {
        loadPluginTranslationsAsync(pluginId, plugin.manifest, "en", function (fallbackTranslations) {
          plugin.api.pluginFallbackTranslations = fallbackTranslations;
          plugin.api.translationVersion++;

          var pluginName = plugin.manifest.name || pluginId;
          ToastService.showNotice(I18n.tr("panels.plugins.title"), I18n.tr("panels.plugins.translations-reloaded", {
                                                                             "name": pluginName
                                                                           }));
          Logger.i("PluginService", "Translation hot reload complete for plugin:", pluginId);
        });
      } else {
        plugin.api.pluginFallbackTranslations = {};
        plugin.api.translationVersion++;

        var pluginName = plugin.manifest.name || pluginId;
        ToastService.showNotice(I18n.tr("panels.plugins.title"), I18n.tr("panels.plugins.translations-reloaded", {
                                                                           "name": pluginName
                                                                         }));
        Logger.i("PluginService", "Translation hot reload complete for plugin:", pluginId);
      }
    });

    return true;
  }

  function isPluginHotReloadEnabled(pluginId) {
    return root.pluginHotReloadEnabled.indexOf(pluginId) !== -1;
  }

  function togglePluginHotReload(pluginId) {
    const index = root.pluginHotReloadEnabled.indexOf(pluginId);
    if (index === -1) {
      root.pluginHotReloadEnabled.push(pluginId);
      setupPluginFileWatcher(pluginId);
      Logger.i("PluginService", "Hot reload enabled for plugin:", pluginId);
    } else {
      root.pluginHotReloadEnabled.splice(index, 1);
      removePluginFileWatcher(pluginId);
      Logger.i("PluginService", "Hot reload disabled for plugin:", pluginId);
    }
  }
}
