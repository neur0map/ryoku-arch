// Expand a snippet template's dynamic placeholders against a context. Supported:
//   {date}            ctx.now formatted YYYY-MM-DD
//   {time}            ctx.now formatted HH:MM
//   {clipboard}       ctx.clipboard
//   {selection}       ctx.selection
//   {cursor}          removed; its index is returned as `cursor`
// Pure so substitution is node-tested; the provider supplies the live context.

function pad2(n) { return (n < 10 ? "0" : "") + n; }

function fmtDate(d) {
    return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
}

function fmtTime(d) {
    return pad2(d.getHours()) + ":" + pad2(d.getMinutes());
}

function expand(template, ctx) {
    ctx = ctx || {};
    var now = ctx.now || new Date();
    var s = String(template == null ? "" : template);
    s = s.replace(/\{date\}/g, fmtDate(now));
    s = s.replace(/\{time\}/g, fmtTime(now));
    s = s.replace(/\{clipboard\}/g, ctx.clipboard != null ? String(ctx.clipboard) : "");
    s = s.replace(/\{selection\}/g, ctx.selection != null ? String(ctx.selection) : "");

    var cursor = s.indexOf("{cursor}");
    if (cursor !== -1)
        s = s.replace("{cursor}", "");
    return { text: s, cursor: cursor };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { expand, fmtDate, fmtTime };
}
