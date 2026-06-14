pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.settingsgui.Commons
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Services.Power
import qs.settingsgui.Services.System
import Ryoku.Config

Singleton {
  id: root

  property var searchIndex: []

  // RYOKU: Hyprland appearance/behaviour is configured in the external Hyprmod GUI, so
  // there are no in-panel widgets to auto-index. Surface these as search entries that
  // point at the Hyprland tab (which hosts "Open Hyprmod"), and reuse the list to render
  // the tab. Labels live under panels.hyprland.items.* for i18n. Defined in code rather
  // than the JSON index so they survive an upstream index re-sync.
  readonly property var hyprmodKeys: ["cursor", "ring", "borders", "gaps", "rounding", "blur", "opacity", "shadows", "animations"]

  function buildHyprmodEntries() {
    var entries = [];
    for (var i = 0; i < hyprmodKeys.length; i++) {
      var k = hyprmodKeys[i];
      entries.push({
                     "labelKey": "panels.hyprland.items." + k,
                     "descriptionKey": "panels.hyprland.items." + k + "-desc",
                     "widget": "NButton",
                     // Fallback position only; navigateToResult resolves the tab by tabLabel.
                     "tab": 14,
                     "tabLabel": "panels.hyprland.title",
                     "subTab": 0,
                     "subTabLabel": "panels.hyprland.hyprmod"
                   });
    }
    return entries;
  }

  FileView {
    path: Quickshell.shellDir + "/settingsgui" + "/Assets/settings-search-index.json"
    watchChanges: false
    printErrors: false

    onLoaded: {
      try {
        root.searchIndex = JSON.parse(text()).concat(root.buildHyprmodEntries());
      } catch (e) {
        root.searchIndex = root.buildHyprmodEntries();
      }
    }
  }

  readonly property var _roots: ({
                                   "CompositorService": CompositorService,
                                   "Settings": Settings,
                                   "GlobalConfig": GlobalConfig,
                                   "Quickshell": Quickshell,
                                   "IdleService": IdleService,
                                   "SystemStatService": SystemStatService,
                                   "SoundService": SoundService
                                 })

  function isEntryVisible(entry) {
    if (!entry.visibleWhen || entry.visibleWhen.length === 0)
      return true;
    for (let i = 0; i < entry.visibleWhen.length; i++) {
      if (!_evalCondition(entry.visibleWhen[i]))
        return false;
    }
    return true;
  }

  function _resolveValue(path) {
    const parts = path.split(".");
    const rootObj = _roots[parts[0]];
    if (rootObj === undefined)
      return undefined;

    let obj = rootObj;
    for (let i = 1; i < parts.length; i++) {
      if (obj === undefined || obj === null)
        return undefined;
      let key = parts[i];
      if (key.endsWith("?"))
        key = key.slice(0, -1);
      obj = obj[key];
    }
    return obj;
  }

  function _splitAnd(expr) {
    const parts = [];
    let depth = 0;
    let current = "";
    for (let i = 0; i < expr.length; i++) {
      const ch = expr[i];
      if (ch === "(")
        depth++;
      else if (ch === ")")
        depth--;
      else if (depth === 0 && ch === "&" && i + 1 < expr.length && expr[i + 1] === "&") {
        parts.push(current);
        current = "";
        i++;
        continue;
      }
      current += ch;
    }
    parts.push(current);
    return parts;
  }

  function _evalCondition(expr) {
    expr = expr.trim();

    if (expr.startsWith("(") && expr.endsWith(")")) {
      let depth = 0;
      let allWrapped = true;
      for (let i = 0; i < expr.length - 1; i++) {
        if (expr[i] === "(")
          depth++;
        else if (expr[i] === ")")
          depth--;
        if (depth === 0) {
          allWrapped = false;
          break;
        }
      }
      if (allWrapped)
        return _evalCondition(expr.slice(1, -1));
    }

    if (expr.includes("&&")) {
      const parts = _splitAnd(expr);
      if (parts.length > 1) {
        for (let i = 0; i < parts.length; i++) {
          if (!_evalCondition(parts[i]))
            return false;
        }
        return true;
      }
    }

    if (expr.startsWith("!"))
      return !_evalCondition(expr.slice(1).trim());

    if (expr === "false")
      return false;

    const nullishMatch = expr.match(/^(.+?)\s*\?\?\s*(?:false|true)\s*$/);
    if (nullishMatch)
      return _evalCondition(nullishMatch[1]);

    let m = expr.match(/^(.+?)\s*===\s*"([^"]*)"\s*$/);
    if (m)
      return _resolveValue(m[1].trim()) === m[2];

    m = expr.match(/^(.+?)\s*!==\s*"([^"]*)"\s*$/);
    if (m)
      return _resolveValue(m[1].trim()) !== m[2];

    m = expr.match(/^(.+?)\s*>\s*(\d+)\s*$/);
    if (m)
      return _resolveValue(m[1].trim()) > parseInt(m[2]);

    const val = _resolveValue(expr);
    if (val !== undefined)
      return !!val;

    // Unrecognized expression — assume visible
    return true;
  }
}
