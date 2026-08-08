import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { parseResult } = require("./calc.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

eq(parseResult("4"), "4", "plain result passes through");
eq(parseResult("= 4"), "4", "leading equals stripped");
eq(parseResult("\u2248 3.14159"), "3.14159", "approximate sign stripped");
eq(parseResult("  42 EUR  "), "42 EUR", "whitespace trimmed, units kept");
eq(parseResult(""), null, "empty output yields no row");
eq(parseResult("   "), null, "whitespace-only yields no row");
eq(parseResult(null), null, "null yields no row");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
