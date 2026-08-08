// Parse qalc's terse (`-t`) output into the result string shown in the launcher.
// qalc may prefix the value with "=" or the approximate sign; both are dropped so
// the row shows just the number. Empty output (an invalid expression, which qalc
// reports on stderr) yields null so no row appears. Pure logic, node-tested.

function parseResult(raw) {
    if (raw == null)
        return null;
    var s = String(raw).trim();
    if (s.length === 0)
        return null;
    s = s.replace(/^[=\u2248]\s*/, "").trim();
    return s.length ? s : null;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parseResult };
}
