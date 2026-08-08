
function audioRows(nodes, current, opts) {
    opts = opts || {};
    var label = opts.label || function (n) { return n ? (n.label || "") : ""; };
    var icon = opts.icon || function (n) { return n ? (n.icon || "") : ""; };
    var key = opts.key || function (n) { return n ? n.name : null; };
    var list = Array.isArray(nodes) ? nodes : [];
    var curKey = current ? key(current) : null;
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var n = list[i];
        if (!n) continue;
        out.push({ name: key(n), label: label(n), icon: icon(n), selected: curKey !== null && key(n) === curKey });
    }
    return out;
}

function btBattery(d) {
    if (!d || !d.batteryAvailable || typeof d.battery !== "number" || d.battery <= 0) return -1;
    return d.battery <= 1 ? Math.round(d.battery * 100) : Math.round(d.battery);
}

function btRows(values) {
    var list = Array.isArray(values) ? values : [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var d = list[i];
        if (!d) continue;
        var name = (d.name && d.name.length) ? d.name : "";
        if (!name.length) continue;
        out.push({ name: name, address: d.address || "", connected: !!d.connected, paired: !!d.paired, battery: btBattery(d) });
    }
    out.sort(function (a, b) {
        if (a.connected !== b.connected) return a.connected ? -1 : 1;
        return a.name.localeCompare(b.name);
    });
    return out;
}

if (typeof module !== "undefined" && module.exports) module.exports = { audioRows, btRows };
