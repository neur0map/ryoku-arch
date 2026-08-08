function cloneState(state) {
    return state && typeof state === "object" ? JSON.parse(JSON.stringify(state)) : {};
}

function valid(menu) {
    return !!menu && typeof menu.id === "string" && menu.id.length > 0
        && typeof menu.anchor === "string" && menu.anchor.length > 0;
}

function open(state, monitor, menu) {
    if (typeof monitor !== "string" || monitor.length === 0 || !valid(menu)) return state;
    const next = cloneState(state);
    if (!next[monitor]) next[monitor] = {};
    next[monitor][menu.anchor] = JSON.parse(JSON.stringify(menu));
    return next;
}

function closeAt(state, monitor, anchor) {
    if (!state || !state[monitor] || !state[monitor][anchor]) return state;
    const next = cloneState(state);
    delete next[monitor][anchor];
    return next;
}

function activeAt(state, monitor, anchor) {
    if (!state || !state[monitor] || !state[monitor][anchor]) return null;
    return state[monitor][anchor];
}

function recordFor(menus, id) {
    if (!Array.isArray(menus)) return null;
    for (let i = 0; i < menus.length; ++i) if (menus[i] && menus[i].id === id) return menus[i];
    return null;
}

if (typeof module !== "undefined" && module.exports) module.exports = { open, closeAt, activeAt, recordFor };
