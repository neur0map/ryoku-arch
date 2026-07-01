// calendar-event model, shared by the Events singleton and the node tests.
// event = { id, date, endDate, time, endTime, text }. date/endDate are
// zero-padded "YYYY-MM-DD", so plain string compare both orders and spans dates,
// no Date parse needed. endDate "" = single day; time/endTime "" = all-day or
// open-ended. framework-free on purpose: no QML, no Date, no Math
// (Math.random / Date.now throw in the QML JS engine), so the same code runs
// under Quickshell and under node.

function pad2(n) { return (n < 10 ? "0" : "") + n; }

// zero-padded "YYYY-MM-DD" for (year, 0-based month, day). matches the keys
// the month grid builds, so coverage stays a plain string compare.
function dateKey(year, month, day) {
    return year + "-" + pad2(month + 1) + "-" + pad2(day);
}

// last day an event covers: endDate, or date when single-day.
function lastDay(e) {
    return e.endDate && e.endDate.length > 0 ? e.endDate : e.date;
}

function covers(e, dateStr) {
    return dateStr >= e.date && dateStr <= lastDay(e);
}

// events covering dateStr, sorted by start time; an all-day (empty time) entry
// sorts first. runs on a filtered copy, caller's array stays untouched.
function forDate(events, dateStr) {
    var out = events.filter(function (e) { return covers(e, dateStr); });
    out.sort(function (a, b) {
        var at = a.time || "";
        var bt = b.time || "";
        if (at === bt) return 0;
        if (at === "") return -1;
        if (bt === "") return 1;
        return at < bt ? -1 : 1;
    });
    return out;
}

function hasEvents(events, dateStr) {
    for (var i = 0; i < events.length; i++)
        if (covers(events[i], dateStr)) return true;
    return false;
}

// max(id) + 1, so a fresh event never collides with one loaded from disk
// (ids are monotonic, never reused).
function nextIdFrom(events) {
    var maxId = 0;
    for (var i = 0; i < events.length; i++) {
        var n = Number(events[i].id);
        if (n > maxId) maxId = n;
    }
    return maxId + 1;
}

// append, returning a NEW array (input untouched) so QML bindings refresh on
// reassignment. omitted fields default to "".
function add(events, id, fields) {
    var next = events.slice();
    next.push({
        id: id,
        date: fields.date,
        endDate: fields.endDate || "",
        time: fields.time || "",
        endTime: fields.endTime || "",
        text: fields.text || ""
    });
    return next;
}

function remove(events, id) {
    return events.filter(function (e) { return e.id !== id; });
}

// split a typed line into { time, text }. leading "H:MM" / "HH:MM" in valid
// ranges -> start time (normalised to "HH:MM"), rest is text. anything else =
// all-day with the whole trimmed line as text.
function parseEntry(raw) {
    var s = (raw || "").trim();
    var m = s.match(/^(\d{1,2}):(\d{2})\s+(.+)$/);
    if (m) {
        var h = Number(m[1]);
        var min = Number(m[2]);
        if (h >= 0 && h <= 23 && min >= 0 && min <= 59)
            return { time: pad2(h) + ":" + pad2(min), text: m[3].trim() };
    }
    return { time: "", text: s };
}

// guarded parse: truncated / non-array / corrupt body returns [] instead of
// throwing, so a bad file can't wipe or crash the model.
function parse(text) {
    try {
        if (text && text.trim().length > 0) {
            var parsed = JSON.parse(text);
            if (Array.isArray(parsed)) return parsed;
        }
    } catch (e) {}
    return [];
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { pad2, dateKey, lastDay, covers, forDate, hasEvents, nextIdFrom, add, remove, parseEntry, parse };
}
