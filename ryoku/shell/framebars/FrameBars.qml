pragma Singleton
import QtQuick
import "FrameBars.js" as Lib

// Frame-bar config schema: defaults, normalization and the bar-studio mutation
// helpers. Wrapped as an installed-module singleton (Ryoku.FrameBars) so every
// config root and the Hub Bar Studio reach one copy by module import, rather
// than a relative JS import that Quickshell sandboxes to the pill config root.
QtObject {
    // A config crossing into this module changes JS engines: a JsonAdapter or
    // store snapshot arrives as a QVariant wrapper that passes typeof checks
    // but fails the module-side Array.isArray, which silently normalizes every
    // zone back to the defaults. Rehydrating through JSON at the boundary gives
    // the library pure objects of its own engine, whatever the caller held.
    function rehydrate(value) {
        if (value === null || value === undefined || typeof value !== "object") return value;
        return JSON.parse(JSON.stringify(value));
    }

    function defaultConfig() { return Lib.defaultConfig(MenuCatalog); }
    // barCatalog / menuCatalog are the sibling BarCatalog / MenuCatalog
    // singletons; the JS reaches entry()/anchors()/widget()/menu()/surface()
    // through them, so callers keep passing them by name.
    function normalize(raw, barCatalog, menuCatalog) { return Lib.normalize(rehydrate(raw), barCatalog, menuCatalog); }
    function addWidget(config, edge, zone, id, barCatalog) { return Lib.addWidget(rehydrate(config), edge, zone, id, barCatalog); }
    function moveWidget(config, fromEdge, fromZone, index, toEdge, toZone, targetIndex, barCatalog) { return Lib.moveWidget(rehydrate(config), fromEdge, fromZone, index, toEdge, toZone, targetIndex, barCatalog); }
    function removeWidget(config, edge, zone, index) { return Lib.removeWidget(rehydrate(config), edge, zone, index); }
    function setMenu(config, id, value, menuCatalog) { return Lib.setMenu(rehydrate(config), id, rehydrate(value), menuCatalog); }
    function setSurface(config, id, value, menuCatalog) { return Lib.setSurface(rehydrate(config), id, rehydrate(value), menuCatalog); }
}
