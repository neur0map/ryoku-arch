import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { expand } = require("./placeholders.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const fixed = new Date(2026, 5, 30, 9, 5);   // 2026-06-30 09:05 (month is 0-based)

eq(expand("Today is {date}", { now: fixed }), { text: "Today is 2026-06-30", cursor: -1 }, "date placeholder");
eq(expand("At {time}", { now: fixed }), { text: "At 09:05", cursor: -1 }, "time placeholder zero-padded");
eq(expand("Paste: {clipboard}", { clipboard: "hello" }), { text: "Paste: hello", cursor: -1 }, "clipboard placeholder");
eq(expand("Sel: {selection}", { selection: "abc" }), { text: "Sel: abc", cursor: -1 }, "selection placeholder");
eq(expand("Hi {clipboard}", {}), { text: "Hi ", cursor: -1 }, "missing context expands empty");
eq(expand("a{cursor}b", {}), { text: "ab", cursor: 1 }, "cursor removed, index returned");
eq(expand("{date} x {date}", { now: fixed }), { text: "2026-06-30 x 2026-06-30", cursor: -1 }, "all occurrences replaced");
eq(expand("plain", {}), { text: "plain", cursor: -1 }, "no placeholders unchanged");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
