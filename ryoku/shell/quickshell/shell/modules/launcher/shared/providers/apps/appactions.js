// Converts Quickshell DesktopAction objects into a primitive snapshot. The
// source index is enough for Apps.qml to resolve the current QObject again at
// execution time without retaining it across DesktopEntries model revisions.
function describeDesktopActions(source) {
    var actions = source && typeof source.length === "number" ? source : [];
    var seen = {};
    var out = [];

    for (var index = 0; index < actions.length; index++) {
        var action = actions[index];
        if (!action || typeof action.id !== "string")
            continue;

        var desktopId = action.id.trim();
        var seenKey = "$" + desktopId;
        if (desktopId.length === 0 || seen[seenKey])
            continue;

        seen[seenKey] = true;
        out.push({
            id: "desktop:" + desktopId,
            desktopId: desktopId,
            name: String(action.name || desktopId),
            icon: String(action.icon || ""),
            sourceIndex: index
        });
    }

    return out;
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { describeDesktopActions: describeDesktopActions };
