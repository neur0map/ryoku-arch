pragma Singleton

import Quickshell

Singleton {
  property var pluginSources: []
  property var pluginLoadVersions: ({})

  function getPluginManifest(pluginId) {
    return null;
  }

  function getPluginDir(pluginId) {
    return "";
  }

  function isMainSource(url) {
    return false;
  }

  function removePluginSource(url) {
    return false;
  }

  function setSourceEnabled(url, enabled) {
    return false;
  }

  function addPluginSource(name, url) {
    return false;
  }

  function getAllInstalledPluginIds() {
    return [];
  }

  function isPluginEnabled(pluginId) {
    return false;
  }

  function parseCompositeKey(pluginId) {
    return {
      "pluginId": pluginId || "",
      "sourceHash": ""
    };
  }

  function getSourceNameByHash(sourceHash) {
    return "";
  }

  function getPluginSourceUrl(pluginId) {
    return "";
  }
}
