import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const Store = require("./store.js");

const eq = (got, want, message) => assert.deepEqual(got, want, message);
const items = [
    { id: "market", category: "plugins", name: "Market", summary: "Widget source", installed: true, enabled: true, updateAvailable: true, tags: ["shell"] },
    { id: "clock", category: "lockscreens", name: "Clockwork", summary: "Mechanical clock", installed: true, active: false, tags: ["time"] },
    { id: "bundle", category: "bundles", name: "Creator", installedCount: 2, totalCount: 4 },
    { id: "plain", category: "plugins", name: "Plain", installed: false }
];

const products = [
    { id: "hero", category: "rices", name: "Hero", art: "hero.jpg", installed: false },
    { id: "lock", category: "lockscreens", name: "Lock", art: "lock.jpg", installed: true },
    { id: "partial", category: "bundles", installedCount: 2, totalCount: 4 }
];

eq(Store.itemKey(products[0]), "rices:hero", "stable item key");
eq(Store.collection(products, { view: "discover", categoryID: "lockscreens" }).map(Store.itemKey), ["lockscreens:lock"], "category collection");
eq(Store.collection(products, { view: "library" }).map(Store.itemKey), ["lockscreens:lock", "bundles:partial"], "library collection");
eq(Store.collection(products, { view: "discover", query: "hero" }).map(Store.itemKey), ["rices:hero"], "search collection");
eq(Store.selectionKey(products, "lockscreens:lock", 0), "lockscreens:lock", "preserve valid selection");
eq(Store.selectionKey(products, "missing:item", 1), "lockscreens:lock", "fallback by bounded index");
eq(Store.selectionKey([], "missing:item", 0), "", "empty selection");

const activeUpdate = { active: true, installed: true, updateAvailable: true };
eq(Store.statusLabels(activeUpdate), ["UPDATE", "ACTIVE"], "update and active are both explicit");
eq(Store.statusLabels(items[2]), ["2 / 4 INSTALLED"], "partial bundle is explicit");
eq(Store.statusLabels(items[3]), ["AVAILABLE"], "available state is explicit");

eq(
    Store.filter(items, { category: "plugins", installedOnly: true, query: "market" }).map(item => item.id),
    ["market"],
    "combined filter"
);
eq(Store.groupSearch(items, "installed clock").map(item => item.id), ["clock"], "state words participate in search");

const schemes = [
    { id: "hancore-kanso", category: "colorschemes", name: "Kanso", installed: false, metadata: { provider: "HANCORE-linux" }, tags: ["dark"] },
    { id: "noctalia-adw", category: "colorschemes", name: "ADW", installed: true, metadata: { provider: "Noctalia" }, tags: ["dark", "light"] },
    { id: "hancore-demon", category: "colorschemes", name: "Demon", installed: true, metadata: { provider: "HANCORE-linux" }, tags: ["dark"] }
];
eq(Store.filter(schemes, { category: "colorschemes", provider: "HANCORE-linux" }).map(i => i.id), ["hancore-kanso", "hancore-demon"], "provider filter narrows to one provider");
eq(Store.collection(schemes, { view: "discover", categoryID: "colorschemes", provider: "Noctalia" }).map(Store.itemKey), ["colorschemes:noctalia-adw"], "provider collection");
eq(Store.collection(schemes, { view: "discover", categoryID: "colorschemes", installedOnly: true }).map(i => i.id), ["noctalia-adw", "hancore-demon"], "my themes collection is installed-only");
eq(Store.filter(schemes, { category: "colorschemes", provider: "HANCORE-linux", installedOnly: true }).map(i => i.id), ["hancore-demon"], "provider and installed filter compose");

eq(
    Store.sortCategories([
        { id: "plugins", group: "extend" },
        { id: "rices", group: "wear" },
        { id: "installed", group: "find" },
        { id: "bundles", group: "extend" },
        { id: "locks", group: "wear" }
    ]).map(category => category.id),
    ["installed", "rices", "locks", "plugins", "bundles"],
    "category groups remain stable"
);

eq(
    Store.featured([
        { id: "broken", category: "rices", name: "Broken", art: "poster.png", sourceError: true },
        { id: "owned", category: "plugins", name: "Owned", art: "owned.png", installed: true },
        { id: "archive", category: "lockscreens", name: "Archive", art: "archive.png", installed: false }
    ]).id,
    "archive",
    "featured is deterministic and prefers available real art"
);
eq(Store.installed(items).map(item => item.id), ["market", "clock", "bundle"], "installed projection includes active, enabled, and partial state");
eq(
    Store.categoryPlates([{ id: "plugins", count: 12, installedCount: 3 }])[0],
    { id: "plugins", count: 12, installedCount: 3 },
    "category plates preserve backend counts"
);

eq(Store.primaryAction({ installed: false }), "INSTALL", "available action");
eq(Store.primaryAction({ installed: true }), "INSTALLED", "installed action");
eq(Store.primaryAction({ installed: false, busy: true }), "INSTALLING", "busy action");
eq(Store.secondaryAction({ installed: true, hasSettings: true }), "OPEN IN SETTINGS", "management handoff when the product has a settings page");
eq(Store.secondaryAction({ installed: true }), "", "installed product without a settings page has no handoff");
eq(Store.secondaryAction({ installed: false }), "", "available item has no management handoff");
eq(
    Store.filter(items, { query: "plugin update" }).map(item => item.id),
    ["market"],
    "multiword search preserves source order"
);

const snapshot = JSON.stringify(items);
Store.filter(items, { query: "installed" });
Store.groupSearch(items, "clock");
eq(JSON.stringify(items), snapshot, "helpers do not mutate source arrays");

console.log("RYOSTORE-STORE-HELPERS-PASS");
