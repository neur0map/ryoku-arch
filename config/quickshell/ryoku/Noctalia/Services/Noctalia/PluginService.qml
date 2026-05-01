pragma Singleton

import Quickshell

Singleton {
  property bool initialized: true
  property bool pluginsFullyLoaded: true
  property var availablePlugins: []
  property var installingPlugins: ({})
  property var activeFetches: ({})
  property var pluginUpdates: ({})
  property var pluginUpdatesPending: ({})

  function init() {}

  function getPluginAPI(pluginId) {
    return null;
  }

  function refreshAvailablePlugins() {}

  function checkForUpdates() {}

  function installPlugin(pluginMetadata, hotReload, callback) {
    if (callback) {
      callback(false, "Plugin support is unavailable in this runtime", "");
    }
  }

  function enablePlugin(pluginId) {}

  function disablePlugin(pluginId) {}

  function updatePlugin(pluginId, callback) {
    if (callback) {
      callback(false, "Plugin support is unavailable in this runtime");
    }
  }

  function hasPluginError(pluginId) {
    return false;
  }

  function isPluginHotReloadEnabled(pluginId) {
    return false;
  }

  function togglePluginHotReload(pluginId) {}

  function getPluginError(pluginId) {
    return null;
  }

  function uninstallPlugin(pluginId, callback) {
    if (callback) {
      callback(false, "Plugin support is unavailable in this runtime");
    }
  }
}
