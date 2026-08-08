import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { clamp01, stepped } = require("./fader.js");

let failed = 0;
function eq(actual, expected, msg) {
    if (actual === expected) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + expected + "\n  got      " + actual); }
}

eq(clamp01(0.5), 0.5, "a mid value passes through");
eq(clamp01(-0.3), 0, "below zero clamps to the floor");
eq(clamp01(1.4), 1, "above one clamps to the ceiling");

eq(stepped(0.5, 5), 0.55, "a positive step raises the level by percent");
eq(stepped(0.02, -5), 0, "a step past the floor clamps to zero");
eq(stepped(0.98, 5), 1, "a step past the ceiling clamps to one");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
