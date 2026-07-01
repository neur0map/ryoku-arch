// month-grid geometry for the calendar widget designs, shared by every face
// and unit-tested under node. week start is configurable (0 = Sunday,
// 1 = Monday). framework-free: plain JS with Date construction, which is fine
// in the Quickshell JS engine (only Date.now() / Math.random() throw there),
// so the same code runs under Quickshell and under node.

function pad2(n) { return (n < 10 ? "0" : "") + n; }

// English names, indexed by JS weekday (0 = Sunday) and 0-based month. widget
// UI is English, so these are deterministic here rather than routed through a
// locale, keeping the faces free of Qt's month/weekday index quirks.
var WEEKDAY_MIN = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
var WEEKDAY_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
var WEEKDAY = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
var MONTH = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
var MONTH_SHORT = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// leading blank cells before the 1st for a week starting on `weekStart`.
// Monday layout matches the pill's calendar and is the default.
function firstWeekdayOffset(year, month, weekStart) {
    var d = new Date(year, month, 1).getDay();
    return (d - weekStart + 7) % 7;
}

function daysInMonth(year, month) {
    return new Date(year, month + 1, 0).getDate();
}

// week-rows the month needs (4 to 6), so a face can size to exactly its month.
function weekRows(year, month, weekStart) {
    var offset = firstWeekdayOffset(year, month, weekStart);
    return Math.ceil((offset + daysInMonth(year, month)) / 7);
}

// display order of JS weekday indices for a header row: mon-start yields
// [1,2,3,4,5,6,0]. designs map these to locale names themselves.
function weekdayOrder(weekStart) {
    var out = [];
    for (var i = 0; i < 7; i++)
        out.push((weekStart + i) % 7);
    return out;
}

// Saturday and Sunday, whatever the week start.
function isWeekend(jsWeekday) {
    return jsWeekday === 0 || jsWeekday === 6;
}

// the 7 dates of the week containing `date`, each { year, month, day, weekday },
// in display order for `weekStart`. drives the week face.
function weekOf(date, weekStart) {
    var d = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    var back = (d.getDay() - weekStart + 7) % 7;
    d.setDate(d.getDate() - back);
    return spanFrom(d, 7);
}

// `count` consecutive days from `date` forward, each { year, month, day,
// weekday }. drives the agenda face's day list.
function daysFrom(date, count) {
    return spanFrom(new Date(date.getFullYear(), date.getMonth(), date.getDate()), count);
}

// shared walk: `count` days from a start Date, advancing a real Date so month
// and year roll over correctly.
function spanFrom(start, count) {
    var d = new Date(start.getFullYear(), start.getMonth(), start.getDate());
    var out = [];
    for (var i = 0; i < count; i++) {
        out.push({ year: d.getFullYear(), month: d.getMonth(), day: d.getDate(), weekday: d.getDay() });
        d.setDate(d.getDate() + 1);
    }
    return out;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { pad2, firstWeekdayOffset, daysInMonth, weekRows, weekdayOrder, isWeekend, weekOf, daysFrom, WEEKDAY_MIN, WEEKDAY_SHORT, WEEKDAY, MONTH, MONTH_SHORT };
}
