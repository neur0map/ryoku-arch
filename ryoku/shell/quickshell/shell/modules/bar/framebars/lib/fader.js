
function clamp01(v) {
    return Math.max(0, Math.min(1, v));
}

function stepped(value, deltaPct) {
    return clamp01(value + deltaPct / 100);
}

if (typeof module !== "undefined" && module.exports) module.exports = { clamp01, stepped };
