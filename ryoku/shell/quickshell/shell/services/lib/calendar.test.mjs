import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { dateKey, daysInMonth, isoWeek, weekStart, shiftMonth, buildRange } = require("./calendar.js");

let failed = 0;
function eq(actual, expected, message) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + message);
    else { failed++; console.log("FAIL " + message + "\n  expected " + e + "\n  got      " + a); }
}

eq(dateKey(2026, 0, 3), "2026-01-03", "dateKey pads month and day");
eq(daysInMonth(2024, 1), 29, "daysInMonth handles leap years");
eq(daysInMonth(2026, 7), 31, "daysInMonth handles ordinary months");
eq(isoWeek(new Date(2021, 0, 1)), { week: 53, year: 2020 }, "January 1 can belong to the previous ISO year");
eq(isoWeek(new Date(2026, 11, 31)), { week: 53, year: 2026 }, "December boundary keeps the correct ISO year");
eq(weekStart(new Date(2026, 7, 5), 1).getDate(), 3, "Monday week starts on the preceding Monday");
eq(weekStart(new Date(2026, 7, 5), 0).getDate(), 2, "Sunday week starts on the preceding Sunday");
eq(shiftMonth(2026, 11, 1), { year: 2027, month: 0 }, "December advances into January");
eq(shiftMonth(2026, 0, -1), { year: 2025, month: 11 }, "January retreats into December");

const four = buildRange(new Date(2026, 7, 3), 2026, 7, 4, 1);
const eight = buildRange(new Date(2026, 7, 3), 2026, 7, 8, 1);
eq(four.length, 42, "four-week preference expands to the six rows August needs");
eq(eight.length, 56, "eight weeks create 56 cells");
eq(four[0].key, "2026-07-27", "range starts at the week containing month start");
eq(four[0].inMonth, false, "leading adjacent-month day is marked outside the month");
eq(four[7].row, 1, "second week has row index one");
eq(four[7].column, 0, "second week starts in column zero");
eq(four[7].isoWeek, 32, "row carries its ISO week number");
eq(four.filter(day => day.inMonth).length, 31, "compact range never drops days from the month");
eq(four.some(day => day.key === "2026-08-31"), true, "compact range includes the final day of the month");
eq(buildRange(new Date(2026, 7, 3), 2026, 7, 2, 1).length, 42, "week preference clamps to four before expanding for the month");
eq(buildRange(new Date(2026, 7, 3), 2026, 7, 10, 1).length, 56, "week count clamps to eight");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
