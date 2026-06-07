pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Helpers/sha256.js" as Crypto
import qs.settingsgui.Commons

Singleton {
  id: root

  readonly property string pluginsDir: Settings.configDir + "plugins"
  readonly property string pluginsFile: Settings.configDir + "plugins.json"

  readonly property int currentVersion: 2
  // Main source URL - plugins from this source keep plain IDs
  readonly property string mainSourceUrl: "https://github.com/neur0map/ryoku-extras"

  Component.onCompleted: {
    ensurePluginsDirectory();
    ensurePluginsFile();
  }

  function generateSourceHash(sourceUrl) {
    var hash = Crypto.sha256(sourceUrl);
    return hash.substring(0, 6);
  }

  function isMainSource(sourceUrl) {
    return sourceUrl === root.mainSourceUrl;
  }

  // Generate composite key: plain ID for official, "hash:id" for custom
  function generateCompositeKey(pluginId, sourceUrl) {
    if (!sourceUrl || isMainSource(sourceUrl)) {
      return pluginId;
    }
    var hash = generateSourceHash(sourceUrl);
    return hash + ":" + pluginId;
  }

  function parseCompositeKey(compositeKey) {
    var colonIndex = compositeKey.indexOf(":");
    // If no colon or colon is after position 6 (hash length), it's a plain ID
    if (colonIndex === -1 || colonIndex > 6) {
      return {
        sourceHash: null,
        pluginId: compositeKey,
        isOfficial: true
      };
    }
    // Has hash prefix (custom source plugin)
    return {
      sourceHash: compositeKey.substring(0, colonIndex),
      pluginId: compositeKey.substring(colonIndex + 1),
      isOfficial: false
    };
  }

  function getSourceNameByUrl(sourceUrl) {
    for (var i = 0; i < root.pluginSources.length; i++) {
      if (root.pluginSources[i].url === sourceUrl) {
        return root.pluginSources[i].name;
      }
    }
    return null;
  }

  function getSourceNameByHash(hash) {
    for (var i = 0; i < root.pluginSources.length; i++) {
      if (generateSourceHash(root.pluginSources[i].url) === hash) {
        return root.pluginSources[i].name;
      }
    }
    return null;
  }

  function getPluginSourceUrl(compositeKey) {
    var state = root.pluginStates[compositeKey];
    return state?.sourceUrl || root.mainSourceUrl;
  }

  signal pluginsChanged
  signal pluginKeybindChanged(string pluginId)

  // In-memory plugin cache (populated by scanning disk)
  property var installedPlugins: ({}) // { pluginId: manifest }
  property var pluginStates: ({}) // { pluginId: { enabled: bool } }
  property var pluginSources: [] // Array of { name, url }
  property var pluginLoadVersions: ({}) // { pluginId: versionNumber } - for cache busting

  property int pendingManifests: 0

  // File storage (minimal - only states and sources)
  property FileView pluginsFileView: FileView {
    id: pluginsFileView
    path: root.pluginsFile

    adapter: JsonAdapter {
      id: adapter
      property int version: root.currentVersion
      property var states: ({})
      property list<var> sources: []
    }

    onLoaded: {
      Logger.i("PluginRegistry", "Loaded plugin states from:", path);
      root.pluginStates = adapter.states || {};
      root.pluginSources = adapter.sources || [];

      if (root.pluginSources.length === 0) {
        root.pluginSources = [
          {
            "name": "Ryoku Plugins",
            "url": "https://github.com/neur0map/ryoku-extras",
            "enabled": true
          }
        ];
        root.save();
      }

      root.migratePluginData();

      scanPluginFolder();
    }

    onLoadFailed: function (error) {
      Logger.w("PluginRegistry", "Failed to load plugins.json, will create it:", error);
      root.pluginStates = {};
      root.pluginSources = [
            {
              "name": "Ryoku Plugins",
              "url": "https://github.com/neur0map/ryoku-extras",
              "enabled": true
            }
          ];
      root.scanPluginFolder();
    }
  }

  function init() {
    Logger.d("PluginRegistry", "Initialized");
    // Force instantiation of PluginService to set up signal listener
    PluginService.initialized;
  }

  function migratePluginData() {
    var needsSave = false;

    // Migration v1 -> v2: add sourceUrl to states
    for (var pluginId in root.pluginStates) {
      if (root.pluginStates[pluginId].sourceUrl === undefined) {
        Logger.i("PluginRegistry", "Migrating plugin data to v2 (adding sourceUrl)");

        var newStates = {};
        for (var id in root.pluginStates) {
          // For v1 -> v2 migration, we assume plugins are from main source
          // Custom plugins installed before this feature need to be reinstalled
          newStates[id] = {
            enabled: root.pluginStates[id].enabled,
            sourceUrl: root.mainSourceUrl
          };
        }
        root.pluginStates = newStates;
        needsSave = true;
        break;
      }
    }

    // Migration: rename legacy plugin sources to Ryoku and repoint the URL.
    var newSources = [];
    var sourcesChanged = false;
    for (var i = 0; i < root.pluginSources.length; i++) {
      var source = root.pluginSources[i];
      var migratedName = source.name;
      var migratedUrl = source.url;
      if (migratedName === "Official Noctalia Plugins" || migratedName === "Noctalia Plugins") {
        migratedName = "Ryoku Plugins";
      }
      if (migratedUrl === "https://github.com/noctalia-dev/noctalia-plugins") {
        migratedUrl = root.mainSourceUrl;
      }
      if (migratedName !== source.name || migratedUrl !== source.url) {
        newSources.push({
                          name: migratedName,
                          url: migratedUrl,
                          enabled: source.enabled
                        });
        sourcesChanged = true;
        Logger.i("PluginRegistry", "Migrating plugin source to Ryoku:", source.name);
      } else {
        newSources.push(source);
      }
    }
    if (sourcesChanged) {
      root.pluginSources = newSources;
      needsSave = true;
    }

    if (needsSave) {
      root.save();
      Logger.i("PluginRegistry", "Migration complete");
    }
  }

  function ensurePluginsDirectory() {
    var mkdirProcess = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["mkdir", "-p", "${root.pluginsDir}"]
      }
    `, root, "MkdirPlugins");

    mkdirProcess.exited.connect(function (exitCode) {
      if (exitCode === 0) {
        Logger.d("PluginRegistry", "Plugins directory ensured:", root.pluginsDir);
      } else {
        Logger.e("PluginRegistry", "Failed to create plugins directory");
      }
      mkdirProcess.destroy();
    });

    mkdirProcess.running = true;
  }

  function ensurePluginsFile() {
    var checkProcess = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["sh", "-c", "test -f '${root.pluginsFile}' || echo '{\\"version\\":${root.currentVersion},\\"states\\":{},\\"sources\\":[]}' > '${root.pluginsFile}'"]
      }
    `, root, "EnsurePluginsFile");

    checkProcess.exited.connect(function (exitCode) {
      if (exitCode === 0) {
        Logger.d("PluginRegistry", "Plugins file ensured:", root.pluginsFile);
      }
      checkProcess.destroy();
    });

    checkProcess.running = true;
  }

  // Scan plugin folder to discover installed plugins (single process reads all manifests)
  function scanPluginFolder() {
    Logger.i("PluginRegistry", "Scanning plugin folder:", root.pluginsDir);

    var scanProcess = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["sh", "-c", "for d in '${root.pluginsDir}'/*/; do [ -d \\"$d\\" ] || continue; [ -f \\"$d/manifest.json\\" ] || continue; echo \\"@@PLUGIN@@$(basename \\"$d\\")\\" ; cat \\"$d/manifest.json\\" ; done"]
        stdout: StdioCollector {}
        running: true
      }
    `, root, "ScanAllPlugins");

    scanProcess.exited.connect(function (exitCode) {
      var output = String(scanProcess.stdout.text || "");
      var sections = output.split("@@PLUGIN@@");
      var loadedCount = 0;

      for (var i = 1; i < sections.length; i++) {
        var section = sections[i];
        var newlineIdx = section.indexOf('\n');
        if (newlineIdx === -1)
          continue;

        var pluginId = section.substring(0, newlineIdx).trim();
        var manifestJson = section.substring(newlineIdx + 1).trim();

        if (!pluginId || !manifestJson)
          continue;

        try {
          var manifest = JSON.parse(manifestJson);
          var validation = validateManifest(manifest);

          if (validation.valid) {
            manifest.compositeKey = pluginId;
            root.installedPlugins[pluginId] = manifest;
            Logger.i("PluginRegistry", "Loaded plugin:", pluginId, "-", manifest.name);

            if (!root.pluginStates[pluginId]) {
              root.pluginStates[pluginId] = {
                enabled: false
              };
            }
            loadedCount++;
          } else {
            Logger.e("PluginRegistry", "Invalid manifest for", pluginId + ":", validation.error);
          }
        } catch (e) {
          Logger.e("PluginRegistry", "Failed to parse manifest for", pluginId + ":", e.toString());
        }
      }

      Logger.i("PluginRegistry", "All plugin manifests loaded. Total plugins:", loadedCount);
      root.pluginsChanged();
      scanProcess.destroy();
    });
  }

  function loadPluginManifest(pluginId) {
    var manifestPath = root.pluginsDir + "/" + pluginId + "/manifest.json";

    var catProcess = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["cat", "${manifestPath}"]
        stdout: StdioCollector {}
        running: true
      }
    `, root, "LoadManifest_" + pluginId);

    catProcess.exited.connect(function (exitCode) {
      var output = String(catProcess.stdout.text || "");
      if (exitCode === 0 && output) {
        try {
          var manifest = JSON.parse(output);
          var validation = validateManifest(manifest);

          if (validation.valid) {
            manifest.compositeKey = pluginId;
            root.installedPlugins[pluginId] = manifest;
            Logger.i("PluginRegistry", "Loaded plugin:", pluginId, "-", manifest.name);

            if (!root.pluginStates[pluginId]) {
              root.pluginStates[pluginId] = {
                enabled: false
              };
            }
          } else {
            Logger.e("PluginRegistry", "Invalid manifest for", pluginId + ":", validation.error);
          }
        } catch (e) {
          Logger.e("PluginRegistry", "Failed to parse manifest for", pluginId + ":", e.toString());
        }
      } else {
        Logger.d("PluginRegistry", "No manifest found for:", pluginId);
      }

      root.pendingManifests--;
      Logger.d("PluginRegistry", "Pending manifests remaining:", root.pendingManifests);
      if (root.pendingManifests === 0) {
        var installedIds = Object.keys(root.installedPlugins);
        Logger.i("PluginRegistry", "All plugin manifests loaded. Total plugins:", installedIds.length);
        Logger.d("PluginRegistry", "Installed plugin IDs:", JSON.stringify(installedIds));
        root.pluginsChanged();
      }

      catProcess.destroy();
    });
  }

  function save() {
    adapter.version = root.currentVersion;
    adapter.states = root.pluginStates;
    adapter.sources = root.pluginSources;

    Qt.callLater(() => {
                   pluginsFileView.writeAdapter();
                   Logger.d("PluginRegistry", "Plugin states saved");
                 });
  }

  function setPluginEnabled(pluginId, enabled) {
    if (!root.installedPlugins[pluginId]) {
      Logger.w("PluginRegistry", "Cannot set state for non-existent plugin:", pluginId);
      return;
    }

    if (!root.pluginStates[pluginId]) {
      root.pluginStates[pluginId] = {
        enabled: enabled
      };
    } else {
      root.pluginStates[pluginId].enabled = enabled;
    }

    save();
    root.pluginsChanged();
    Logger.i("PluginRegistry", "Plugin", pluginId, enabled ? "enabled" : "disabled");
  }

  function isPluginEnabled(pluginId) {
    return root.pluginStates[pluginId]?.enabled || false;
  }

  function isPluginDownloaded(pluginId) {
    return pluginId in root.installedPlugins;
  }

  function getPluginManifest(pluginId) {
    return root.installedPlugins[pluginId] || null;
  }

  function getAllInstalledPluginIds() {
    return Object.keys(root.installedPlugins);
  }

  function getEnabledPluginIds() {
    return Object.keys(root.pluginStates).filter(function (id) {
      return root.pluginStates[id].enabled === true;
    });
  }

  // User's per-plugin shortcut key override (in the Super+X plugins menu). Empty = use the
  // author default from the manifest's frame.key.
  function getPluginKeybind(pluginId) {
    var s = root.pluginStates[pluginId];
    return (s && s.keybind) ? s.keybind : "";
  }

  function setPluginKeybind(pluginId, keybind) {
    if (!root.pluginStates[pluginId])
      root.pluginStates[pluginId] = {
        enabled: false
      };
    if (keybind && keybind.length > 0)
      root.pluginStates[pluginId].keybind = keybind;
    else
      delete root.pluginStates[pluginId].keybind;
    save();
    root.pluginKeybindChanged(pluginId);
    root.pluginsChanged();
  }

  // sourceUrl is required for new plugins to generate composite key
  function registerPlugin(manifest, sourceUrl) {
    var compositeKey = generateCompositeKey(manifest.id, sourceUrl);
    manifest.compositeKey = compositeKey;
    root.installedPlugins[compositeKey] = manifest;

    if (!root.pluginStates[compositeKey]) {
      root.pluginStates[compositeKey] = {
        enabled: false,
        sourceUrl: sourceUrl || root.mainSourceUrl
      };
    } else {
      // Preserve enabled state but update sourceUrl
      root.pluginStates[compositeKey].sourceUrl = sourceUrl || root.mainSourceUrl;
    }

    save();
    root.pluginsChanged();
    Logger.i("PluginRegistry", "Registered plugin:", compositeKey);
    return compositeKey;
  }

  function unregisterPlugin(pluginId) {
    delete root.pluginStates[pluginId];
    delete root.installedPlugins[pluginId];
    save();
    root.pluginsChanged();
    Logger.i("PluginRegistry", "Unregistered plugin:", pluginId);
  }

  function incrementPluginLoadVersion(pluginId) {
    var versions = Object.assign({}, root.pluginLoadVersions);
    versions[pluginId] = (versions[pluginId] || 0) + 1;
    root.pluginLoadVersions = versions;
    Logger.d("PluginRegistry", "Incremented load version for", pluginId, "to", versions[pluginId]);
    return versions[pluginId];
  }

  function removePluginState(pluginId) {
    delete root.pluginStates[pluginId];
    delete root.installedPlugins[pluginId];
    save();
    root.pluginsChanged();
    Logger.i("PluginRegistry", "Removed plugin state:", pluginId);
  }

  function addPluginSource(name, url) {
    for (var i = 0; i < root.pluginSources.length; i++) {
      if (root.pluginSources[i].url === url) {
        Logger.w("PluginRegistry", "Source already exists:", url);
        return false;
      }
    }

    // Create a new array to trigger property change notification
    var newSources = root.pluginSources.slice();
    newSources.push({
                      name: name,
                      url: url,
                      enabled: true
                    });
    root.pluginSources = newSources;
    save();
    Logger.i("PluginRegistry", "Added plugin source:", name);
    return true;
  }

  function removePluginSource(url) {
    var newSources = [];
    for (var i = 0; i < root.pluginSources.length; i++) {
      if (root.pluginSources[i].url !== url) {
        newSources.push(root.pluginSources[i]);
      }
    }

    if (newSources.length === root.pluginSources.length) {
      Logger.w("PluginRegistry", "Source not found:", url);
      return false;
    }

    root.pluginSources = newSources;
    save();
    Logger.i("PluginRegistry", "Removed plugin source:", url);
    return true;
  }

  function setSourceEnabled(url, enabled) {
    var newSources = [];
    var found = false;
    for (var i = 0; i < root.pluginSources.length; i++) {
      if (root.pluginSources[i].url === url) {
        newSources.push({
                          name: root.pluginSources[i].name,
                          url: root.pluginSources[i].url,
                          enabled: enabled
                        });
        found = true;
      } else {
        newSources.push(root.pluginSources[i]);
      }
    }

    if (!found) {
      Logger.w("PluginRegistry", "Source not found:", url);
      return false;
    }

    root.pluginSources = newSources;
    save();
    Logger.i("PluginRegistry", "Source", url, enabled ? "enabled" : "disabled");
    return true;
  }

  function isSourceEnabled(url) {
    for (var i = 0; i < root.pluginSources.length; i++) {
      if (root.pluginSources[i].url === url) {
        return root.pluginSources[i].enabled !== false; // Default to true if not set
      }
    }
    return false;
  }

  function getEnabledSources() {
    var enabledSources = [];
    for (var i = 0; i < root.pluginSources.length; i++) {
      if (root.pluginSources[i].enabled !== false) {
        enabledSources.push(root.pluginSources[i]);
      }
    }
    return enabledSources;
  }

  function getPluginDir(pluginId) {
    return root.pluginsDir + "/" + pluginId;
  }

  function getPluginSettingsFile(pluginId) {
    return getPluginDir(pluginId) + "/settings.json";
  }

  function validateManifest(manifest) {
    if (!manifest) {
      return {
        valid: false,
        error: "Manifest is null or undefined"
      };
    }

    var required = ["id", "name", "version", "author", "description"];
    for (var i = 0; i < required.length; i++) {
      if (!manifest[required[i]]) {
        return {
          valid: false,
          error: "Missing required field: " + required[i]
        };
      }
    }

    if (!manifest.entryPoints) {
      return {
        valid: false,
        error: "Missing 'entryPoints' field"
      };
    }

    var versionRegex = /^\d+\.\d+\.\d+$/;
    if (!versionRegex.test(manifest.version)) {
      return {
        valid: false,
        error: "Invalid version format (must be x.y.z)"
      };
    }

    return {
      valid: true,
      error: null
    };
  }
}
