// Pure calendar-event model, shared by the Events singleton and its node tests.
// An event is a plain object { id, date, endDate, time, endTime, text } with
// date/endDate as zero-padded "YYYY-MM-DD", so a string compare orders and spans
// dates without Date parsing. endDate "" means a single day; time/endTime "" mean
// all-day or open-ended. Framework-free on purpose: no QML, no Date, no Math
// (Math.random/Date.now throw in the QML JS engine), so the same code runs under
// Quickshell and under node.

function pad2(n) { return (n < 10 ? "0" : "") + n; }

// Zero-padded "YYYY-MM-DD" for (year, 0-based month, day), matching the keys the
// month grid builds so coverage checks stay plain string compares.
function dateKey(year, month, day) {
    return year + "-" + pad2(month + 1) + "-" + pad2(day);
}

// Last day an event covers: its endDate, or its start when single-day.
function lastDay(e) {
    return e.endDate && e.endDate.length > 0 ? e.endDate : e.date;
}

function covers(e, dateStr) {
    return dateStr >= e.date && dateStr <= lastDay(e);
}

// Events covering dateStr, sorted by start time; an all-day (empty time) entry
// sorts first. Builds on a filtered copy so the caller's array is never mutated.
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

// One past the highest id present, so a freshly added event never collides with
// one loaded from disk (ids are monotonic and never reused).
function nextIdFrom(events) {
    var maxId = 0;
    for (var i = 0; i < events.length; i++) {
        var n = Number(events[i].id);
        if (n > maxId) maxId = n;
    }
    return maxId + 1;
}

// Append an event, returning a NEW array (never mutates the input) so QML
// bindings refresh on reassignment. Omitted fields default to "".
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

// Split one typed line into { time, text }: a leading "H:MM" or "HH:MM" in valid
// ranges becomes the start time (normalized to "HH:MM"), the rest is the text.
// Anything else is an all-day entry with the whole trimmed line as text.
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

// Guarded parse: a truncated, non-array, or corrupt body yields [] rather than
// throwing, so a bad file never wipes or crashes the model.
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
