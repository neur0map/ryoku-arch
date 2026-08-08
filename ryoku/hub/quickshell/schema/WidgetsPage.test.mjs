import fs from "node:fs";
import vm from "node:vm";

const source = fs.readFileSync(new URL("./WidgetsPage.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);
const rows = context.rows;

let failed = 0;
function eq(actual, expected, message) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + message);
    else { failed++; console.log("FAIL " + message + "\n  expected " + e + "\n  got      " + a); }
}

const calendar = rows.filter(row => row.tab === "calendar");
const byKey = Object.fromEntries(calendar.map(row => [row.key, row]));
eq(calendar.map(row => row.key), [
    "calendarEnabled", "calendarStyle", "calendarWeeks", "calendarWeekNumbers",
    "calendarHolidayRegion", "calendarScale", "calendarOpacity", "calendarAnchor",
    "calendarX", "calendarY", "calendarLocked"
], "calendar settings expose the complete config contract");
eq(byKey.calendarStyle.opts, ["glass", "paper"], "calendar ships exactly two styles");
eq([byKey.calendarWeeks.lo, byKey.calendarWeeks.hi], [4, 8], "visible weeks clamp to four through eight");
eq(calendar.every(row => row.src === "widgets.json"), true, "every calendar setting persists to widgets.json");

if (failed > 0) process.exit(1);
console.log("\nAll tests PASSED");
