function pad2(n) { return (n < 10 ? "0" : "") + n; }

function dateKey(year, month, day) {
    return year + "-" + pad2(month + 1) + "-" + pad2(day);
}

function daysInMonth(year, month) {
    return new Date(year, month + 1, 0, 12).getDate();
}

function isoWeek(date) {
    var d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
    var weekday = d.getUTCDay() || 7;
    d.setUTCDate(d.getUTCDate() + 4 - weekday);
    var year = d.getUTCFullYear();
    var first = new Date(Date.UTC(year, 0, 1));
    return { week: Math.ceil((((d - first) / 86400000) + 1) / 7), year: year };
}

function weekStart(date, firstDay) {
    var start = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 12);
    var normalized = ((Number(firstDay) % 7) + 7) % 7;
    var offset = (start.getDay() - normalized + 7) % 7;
    start.setDate(start.getDate() - offset);
    return start;
}

function shiftMonth(year, month, delta) {
    var shifted = new Date(year, month + delta, 1, 12);
    return { year: shifted.getFullYear(), month: shifted.getMonth() };
}

function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear()
        && a.getMonth() === b.getMonth()
        && a.getDate() === b.getDate();
}

function buildRange(today, viewYear, viewMonth, weeks, firstDay) {
    var preferred = Math.max(4, Math.min(8, Math.round(Number(weeks) || 6)));
    var monthStart = new Date(viewYear, viewMonth, 1, 12);
    var normalized = ((Number(firstDay) % 7) + 7) % 7;
    var leading = (monthStart.getDay() - normalized + 7) % 7;
    var required = Math.ceil((leading + daysInMonth(viewYear, viewMonth)) / 7);
    var count = Math.min(8, Math.max(preferred, required));
    var start = weekStart(monthStart, firstDay);
    var out = [];
    for (var i = 0; i < count * 7; i++) {
        var date = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i, 12);
        out.push({
            key: dateKey(date.getFullYear(), date.getMonth(), date.getDate()),
            year: date.getFullYear(),
            month: date.getMonth(),
            day: date.getDate(),
            inMonth: date.getMonth() === viewMonth && date.getFullYear() === viewYear,
            today: sameDay(date, today),
            weekend: date.getDay() === 0 || date.getDay() === 6,
            isoWeek: isoWeek(date).week,
            row: Math.floor(i / 7),
            column: i % 7
        });
    }
    return out;
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { pad2, dateKey, daysInMonth, isoWeek, weekStart, shiftMonth, buildRange };
