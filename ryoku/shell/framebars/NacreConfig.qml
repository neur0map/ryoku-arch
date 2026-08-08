pragma Singleton

import QtQuick
import "NacreConfig.js" as Lib

QtObject {
    function value(input) {
        if (input === null || input === undefined || typeof input !== "object")
            return input;
        return JSON.parse(JSON.stringify(input));
    }

    function defaultConfig() { return Lib.defaultConfig(); }
    function normalize(raw) { return Lib.normalize(value(raw)); }
    function move(config, widgetId, sourceIsland, targetIsland, targetIndex) {
        return Lib.move(value(config), widgetId, sourceIsland, targetIsland, targetIndex);
    }
    function remove(config, widgetId) { return Lib.remove(value(config), widgetId); }
    function setValue(config, key, next) { return Lib.setValue(value(config), key, next); }
    function widgetIds() { return Lib.widgetIds(); }
    function entry(id) { return Lib.entry(id); }
    function unused(config) { return Lib.unused(value(config)); }
}
