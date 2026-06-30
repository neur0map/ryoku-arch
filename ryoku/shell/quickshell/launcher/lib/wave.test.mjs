import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { samplePoints, phaseFor } = require("./wave.js");

let failed = 0;
function eq(actual, expected, msg) {
    if (actual === expected) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + expected + "\n  got      " + actual); }
}
function near(actual, expected, msg) {
    if (Math.abs(actual - expected) < 1e-9) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected ~" + expected + "\n  got      " + actual); }
}

const pts = samplePoints(100, 10, 4, 1, 0, 4);
eq(pts.length, 5, "steps+1 points returned");
near(pts[0].x, 0, "first point at x=0");
near(pts[4].x, 100, "last point at x=width");
near(pts[0].y, 10, "phase 0 starts at center (sin 0)");
near(pts[1].y, 14, "quarter wave peaks at cy+amplitude");
near(pts[2].y, 10, "half wave back at center");

// flat line when amplitude is 0 (paused).
const flat = samplePoints(100, 10, 0, 1, 0, 4);
near(flat[1].y, 10, "zero amplitude is a flat line");

near(phaseFor(400), 1, "phase advances 1 rad per 400ms");
near(phaseFor(0), 0, "phase starts at 0");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
