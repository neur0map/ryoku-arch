
function watchDelta(watching, active) {
    var on = active === true;
    if (on === (watching === true)) return { watching: on, delta: 0 };
    return { watching: on, delta: on ? 1 : -1 };
}

function setOwnership(owners, owner, active) {
    var current = Array.isArray(owners) ? owners : [];
    var index = current.indexOf(owner);
    if (active === true)
        return index < 0 ? current.concat([owner]) : current;
    if (index < 0)
        return current;
    return current.slice(0, index).concat(current.slice(index + 1));
}

if (typeof module !== "undefined" && module.exports) module.exports = { watchDelta, setOwnership };
