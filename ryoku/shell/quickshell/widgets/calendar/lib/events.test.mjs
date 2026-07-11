import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { dateKey, lastDay, covers, forDate, hasEvents, nextIdFrom, add, remove, parseEntry, parse } = require("./events.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }

eq(dateKey(2026, 0, 1), "2026-01-01", "dateKey pads single-digit month and day");
eq(dateKey(2026, 11, 25), "2026-12-25", "dateKey month is 0-based");

const single = { id: 1, date: "2026-06-23", endDate: "", time: "09:30", endTime: "", text: "standup" };
const span = { id: 2, date: "2026-06-22", endDate: "2026-06-24", time: "", endTime: "", text: "conf" };
const allday = { id: 3, date: "2026-06-23", endDate: "", time: "", endTime: "", text: "holiday" };
const evs = [single, span, allday];

eq(lastDay(single), "2026-06-23", "lastDay of single-day is its start");
eq(lastDay(span), "2026-06-24", "lastDay of multi-day is its endDate");

ok(covers(single, "2026-06-23"), "single covers its own day");
ok(!covers(single, "2026-06-24"), "single excludes the next day");
ok(covers(span, "2026-06-22"), "span covers its first day");
ok(covers(span, "2026-06-23"), "span covers a middle day");
ok(covers(span, "2026-06-24"), "span covers its last day");
ok(!covers(span, "2026-06-21"), "span excludes the day before");
ok(!covers(span, "2026-06-25"), "span excludes the day after");

ok(hasEvents(evs, "2026-06-22"), "hasEvents true on a covered day");
ok(!hasEvents(evs, "2026-07-01"), "hasEvents false on an empty day");

eq(forDate(evs, "2026-06-23").map(e => e.id), [2, 3, 1], "forDate puts all-day before timed and includes covering spans");
eq(forDate(evs, "2026-06-22").map(e => e.id), [2], "forDate returns only the span on the 22nd");
eq(forDate(evs, "2026-06-30"), [], "forDate empty on an uncovered day");

eq(nextIdFrom(evs), 4, "nextIdFrom is one past the highest id");
eq(nextIdFrom([]), 1, "nextIdFrom of empty is 1");

const base = [single];
const added = add(base, 5, { date: "2026-06-25", text: "deploy" });
eq(base.length, 1, "add does not mutate the input array");
eq(added.length, 2, "add appends one");
eq(added[1], { id: 5, date: "2026-06-25", endDate: "", time: "", endTime: "", text: "deploy" }, "add fills defaults for omitted fields");

const removed = remove(evs, 2);
eq(removed.map(e => e.id), [1, 3], "remove drops the matching id");
eq(remove(evs, 99).length, 3, "remove of an absent id is a no-op copy");

eq(parseEntry("09:30 standup"), { time: "09:30", text: "standup" }, "parseEntry reads a leading HH:MM");
eq(parseEntry("9:00 gym"), { time: "09:00", text: "gym" }, "parseEntry normalizes H:MM to HH:MM");
eq(parseEntry("standup"), { time: "", text: "standup" }, "parseEntry with no time is all-day");
eq(parseEntry("25:00 nope"), { time: "", text: "25:00 nope" }, "parseEntry rejects an out-of-range hour");
eq(parseEntry("  spaced  "), { time: "", text: "spaced" }, "parseEntry trims surrounding space");
eq(parseEntry("12:5 odd"), { time: "", text: "12:5 odd" }, "parseEntry needs two minute digits");
eq(parseEntry("09:30-10:30 standup"), { time: "09:30", endTime: "10:30", text: "standup" }, "parseEntry reads a HH:MM-HH:MM range");
eq(parseEntry("9:00-10:30 gym"), { time: "09:00", endTime: "10:30", text: "gym" }, "parseEntry normalizes range endpoints to HH:MM");
eq(parseEntry("09:30\u201310:30 standup"), { time: "09:30", endTime: "10:30", text: "standup" }, "parseEntry accepts an en-dash range");
eq(parseEntry("09:30 - 10:30 standup"), { time: "09:30", endTime: "10:30", text: "standup" }, "parseEntry tolerates spaces around the range dash");
eq(parseEntry("09:30-25:00 nope"), { time: "", text: "09:30-25:00 nope" }, "parseEntry rejects an out-of-range end time");
eq(parseEntry("09:30-10:30"), { time: "", text: "09:30-10:30" }, "parseEntry needs text after a range");

eq(parse('[{"id":1}]'), [{ id: 1 }], "parse reads a valid array");
eq(parse(""), [], "parse of empty string is []");
eq(parse("not json"), [], "parse of garbage is []");
eq(parse('{"id":1}'), [], "parse of a non-array object is []");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
