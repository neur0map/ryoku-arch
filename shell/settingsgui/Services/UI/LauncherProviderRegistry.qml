pragma Singleton

import QtQuick
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Platform

Singleton {
  id: root

  signal pluginProviderRegistryUpdated

  property var pluginProviders: ({}) // { "plugin:pluginId": component }
  property var pluginProviderMetadata: ({}) // { "plugin:pluginId": metadata }

  // Persistent provider instances — survive LauncherCore destruction/recreation
  // so plugins don't re-parse large datasets on every launcher open.
  property var providerInstances: ({}) // { "plugin:pluginId": instance }

  function init() {
    Logger.i("LauncherProviderRegistry", "Service started");
  }

  function registerPluginProvider(pluginId, component, metadata) {
    if (!pluginId || !component) {
      Logger.e("LauncherProviderRegistry", "Cannot register plugin provider: invalid parameters");
      return false;
    }

    var providerId = "plugin:" + pluginId;

    pluginProviders[providerId] = component;
    pluginProviderMetadata[providerId] = metadata || {};

    // Instantiate immediately so data loading starts in the background
    var pluginApi = PluginService.getPluginAPI(pluginId);
    if (pluginApi) {
      var instance = component.createObject(null, {
                                              pluginApi: pluginApi
                                            });
      if (instance) {
        providerInstances[providerId] = instance;
        if (instance.init)
          instance.init();
        Logger.i("LauncherProviderRegistry", "Registered and instantiated plugin provider:", providerId);
      } else {
        Logger.e("LauncherProviderRegistry", "Failed to instantiate plugin provider:", providerId);
      }
    }

    root.pluginProviderRegistryUpdated();
    return true;
  }

  function unregisterPluginProvider(pluginId) {
    var providerId = "plugin:" + pluginId;

    if (!pluginProviders[providerId]) {
      Logger.w("LauncherProviderRegistry", "Plugin provider not registered:", providerId);
      return false;
    }

    if (providerInstances[providerId]) {
      providerInstances[providerId].destroy();
      delete providerInstances[providerId];
    }

    delete pluginProviders[providerId];
    delete pluginProviderMetadata[providerId];

    Logger.i("LauncherProviderRegistry", "Unregistered plugin provider:", providerId);
    root.pluginProviderRegistryUpdated();
    return true;
  }

  function getPluginProviders() {
    return Object.keys(pluginProviders);
  }

  function getProviderInstance(providerId) {
    return providerInstances[providerId] || null;
  }

  function getProviderComponent(providerId) {
    return pluginProviders[providerId] || null;
  }

  function getProviderMetadata(providerId) {
    return pluginProviderMetadata[providerId] || null;
  }

  function isPluginProvider(id) {
    return id.startsWith("plugin:");
  }

  function hasProvider(providerId) {
    return providerId in pluginProviders;
  }
}
