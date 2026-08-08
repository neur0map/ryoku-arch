function safeQmlPath(value) {
  return typeof value === "string"
    && /^variants\/[a-z0-9-]+\/[A-Za-z][A-Za-z0-9]*\.qml$/.test(value)
    && value.indexOf("..") < 0;
}

function normalize(raw) {
  if (!raw || raw.version !== 1 || !Array.isArray(raw.variants))
    throw new Error("launcher catalog must be version 1");

  var ids = {};
  var variants = raw.variants.map(function (source) {
    var id = String(source.id || "");
    if (!/^[a-z0-9-]+$/.test(id) || ids[id])
      throw new Error("launcher catalog has an invalid or duplicate id: " + id);
    if (!safeQmlPath(source.entrypoint) || !safeQmlPath(source.preview))
      throw new Error("launcher catalog has an unsafe QML path for: " + id);
    ids[id] = true;
    return {
      id: id,
      name: String(source.name || id),
      description: String(source.description || ""),
      entrypoint: source.entrypoint,
      preview: source.preview,
      capabilities: Array.isArray(source.capabilities)
        ? source.capabilities.map(String) : []
    };
  });

  var defaultId = String(raw.default || "");
  var fallbackId = String(raw.fallback || "");
  if (!ids[defaultId] || !ids[fallbackId])
    throw new Error("launcher catalog default and fallback must name entries");
  return { defaultId: defaultId, fallbackId: fallbackId, variants: variants };
}

function find(catalog, id) {
  for (var i = 0; i < catalog.variants.length; i++)
    if (catalog.variants[i].id === id) return catalog.variants[i];
  return null;
}

function defaultEntry(catalog) { return find(catalog, catalog.defaultId); }
function fallbackEntry(catalog) { return find(catalog, catalog.fallbackId); }
function entry(catalog, requestedId) {
  return find(catalog, String(requestedId || "")) || defaultEntry(catalog);
}

if (typeof module !== "undefined" && module.exports)
  module.exports = { safeQmlPath, normalize, find, entry, defaultEntry, fallbackEntry };
