import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { pad2, firstWeekdayOffset, daysInMonth, weekRows, weekdayOrder, isWeekend, weekOf, daysFrom } = require("./cal.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }

eq(pad2(0), "00", "pad2 zero-pads 0");
eq(pad2(9), "09", "pad2 zero-pads a single digit");
eq(pad2(10), "10", "pad2 leaves 10 unchanged");
eq(pad2(31), "31", "pad2 leaves two digits unchanged");

// Feb 1 2026 is a Sunday.
eq(firstWeekdayOffset(2026, 1, 1), 6, "firstWeekdayOffset Feb 2026 mon-start = 6 (1st is Sun)");
eq(firstWeekdayOffset(2026, 1, 0), 0, "firstWeekdayOffset Feb 2026 sun-start = 0 (1st is Sun)");
// Aug 1 2026 is a Saturday.
eq(firstWeekdayOffset(2026, 7, 1), 5, "firstWeekdayOffset Aug 2026 mon-start = 5 (1st is Sat)");
eq(firstWeekdayOffset(2026, 7, 0), 6, "firstWeekdayOffset Aug 2026 sun-start = 6 (1st is Sat)");
// Jan 1 2026 is a Thursday: mon-start offset 3, sun-start offset 4.
eq(firstWeekdayOffset(2026, 0, 1), 3, "firstWeekdayOffset Jan 2026 mon-start = 3 (1st is Thu)");
eq(firstWeekdayOffset(2026, 0, 0), 4, "firstWeekdayOffset Jan 2026 sun-start = 4 (1st is Thu)");

eq(daysInMonth(2026, 0), 31, "daysInMonth Jan 2026 = 31");
eq(daysInMonth(2026, 3), 30, "daysInMonth Apr 2026 = 30");
eq(daysInMonth(2024, 1), 29, "daysInMonth Feb 2024 = 29 (leap)");
eq(daysInMonth(2026, 1), 28, "daysInMonth Feb 2026 = 28 (non-leap)");
eq(daysInMonth(2026, 11), 31, "daysInMonth Dec via month index 11 = 31 (confirms 0-based)");

// Aug 2026 mon-start: offset 5 + 31 days = 36 cells -> 6 rows.
eq(weekRows(2026, 7, 1), 6, "weekRows Aug 2026 mon-start needs 6 rows");
// Jan 2026 mon-start: offset 3 + 31 days = 34 cells -> 5 rows.
eq(weekRows(2026, 0, 1), 5, "weekRows Jan 2026 mon-start needs 5 rows");
// Feb 2026 sun-start: offset 0 + 28 days = 28 cells -> 4 rows exact.
eq(weekRows(2026, 1, 0), 4, "weekRows Feb 2026 sun-start fits in 4 rows exactly");
// Feb 2026 mon-start: offset 6 + 28 = 34 -> 5 rows (same month, different weekStart).
eq(weekRows(2026, 1, 1), 5, "weekRows Feb 2026 mon-start needs 5 rows");

eq(weekdayOrder(1), [1, 2, 3, 4, 5, 6, 0], "weekdayOrder mon-start");
eq(weekdayOrder(0), [0, 1, 2, 3, 4, 5, 6], "weekdayOrder sun-start");

ok(isWeekend(0), "isWeekend Sun");
ok(isWeekend(6), "isWeekend Sat");
ok(!isWeekend(1), "isWeekend Mon false");
ok(!isWeekend(2), "isWeekend Tue false");
ok(!isWeekend(3), "isWeekend Wed false");
ok(!isWeekend(4), "isWeekend Thu false");
ok(!isWeekend(5), "isWeekend Fri false");

// Mar 1 2026 is a Sunday; mon-start week runs Feb 23 (Mon) .. Mar 1 (Sun),
// so the week straddles the Feb -> Mar boundary.
const wk = weekOf(new Date(2026, 2, 1), 1);
eq(wk.length, 7, "weekOf returns 7 days");
eq(wk[0].weekday, 1, "weekOf first day matches weekStart=1 (Mon)");
eq(wk[6].weekday, 0, "weekOf last day is Sunday under mon-start");
// contiguity: each successive day advances by one via real Date arithmetic.
let contiguous = true;
for (let i = 1; i < wk.length; i++) {
    const prev = new Date(wk[i - 1].year, wk[i - 1].month, wk[i - 1].day);
    const cur = new Date(wk[i].year, wk[i].month, wk[i].day);
    if ((cur - prev) !== 86400000) contiguous = false;
}
ok(contiguous, "weekOf yields contiguous calendar days");
eq({ year: wk[0].year, month: wk[0].month, day: wk[0].day }, { year: 2026, month: 1, day: 23 }, "weekOf starts on Feb 23 2026");
eq({ year: wk[5].year, month: wk[5].month, day: wk[5].day }, { year: 2026, month: 1, day: 28 }, "weekOf includes Feb 28 mid-week");
eq({ year: wk[6].year, month: wk[6].month, day: wk[6].day }, { year: 2026, month: 2, day: 1 }, "weekOf rolls into Mar 1 on the last day");

// Sun-start on the same reference date: Sunday Mar 1 is itself the week start.
const wkSun = weekOf(new Date(2026, 2, 1), 0);
eq(wkSun[0].weekday, 0, "weekOf sun-start first day is Sunday");
eq({ year: wkSun[0].year, month: wkSun[0].month, day: wkSun[0].day }, { year: 2026, month: 2, day: 1 }, "weekOf sun-start begins at Mar 1 itself");

// daysFrom rolling across a month end: Jan 30 2026 (Fri) + 4 days -> Feb 2 2026 (Mon).
eq(daysFrom(new Date(2026, 0, 30), 4), [
    { year: 2026, month: 0, day: 30, weekday: 5 },
    { year: 2026, month: 0, day: 31, weekday: 6 },
    { year: 2026, month: 1, day: 1, weekday: 0 },
    { year: 2026, month: 1, day: 2, weekday: 1 },
], "daysFrom rolls Jan 30 2026 across into Feb");

// daysFrom rolling across a year end: Dec 30 2026 (Wed) + 4 days -> Jan 2 2027 (Sat).
eq(daysFrom(new Date(2026, 11, 30), 4), [
    { year: 2026, month: 11, day: 30, weekday: 3 },
    { year: 2026, month: 11, day: 31, weekday: 4 },
    { year: 2027, month: 0, day: 1, weekday: 5 },
    { year: 2027, month: 0, day: 2, weekday: 6 },
], "daysFrom rolls Dec 30 2026 across into Jan 2027");

eq(daysFrom(new Date(2026, 5, 15), 10).length, 10, "daysFrom length === count");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
