import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { svgSmooth, wavePath } = require("./spectrum.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

// Nothing-to-draw cases: wavePath returns "" so the caller can hide the shape.
eq(wavePath(null, 400, 100, 0.55, 0), "", "null levels => empty path");
eq(wavePath(undefined, 400, 100, 0.55, 0), "", "undefined levels => empty path");
eq(wavePath([0.5], 400, 100, 0.55, 0), "", "single-element levels => empty path");
eq(wavePath([0.5, 0.5], 0, 100, 0.55, 0), "", "w=0 => empty path");
eq(wavePath([0.5, 0.5], -10, 100, 0.55, 0), "", "negative w => empty path");
eq(wavePath([0.5, 0.5], 400, 0, 0.55, 0), "", "h=0 => empty path");
eq(wavePath([0.5, 0.5], 400, -10, 0.55, 0), "", "negative h => empty path");
eq(wavePath([0.02, 0.02, 0.02, 0.02], 400, 100, 0.55, 0), "", "settled flat (max<0.03) => empty path");

// Real path shape: starts at baseline bottom-left, smooths across tips, closes with Z.
const w = 400, h = 100, maxFrac = 0.55, minFrac = 0;
const path = wavePath([0.1, 0.8, 0.3, 0.9], w, h, maxFrac, minFrac);
eq(typeof path === "string" && path.length > 0, true, "real levels produce a non-empty string");
eq(path.startsWith("M0 " + h), true, "path starts at baseline bottom-left (M0 h)");
eq(path.includes("Q"), true, "path contains Q smoothing segments");
eq(path.endsWith("Z"), true, "path closes with Z so it is fillable");

// Higher level => higher tip => smaller y. Recompute the same way the module does
// and assert both tip ys appear in the path, with peak strictly above trough.
const twoLevels = [0.1, 0.9];
const troughY = h - maxFrac * h * twoLevels[0]; // low band sits near the bottom
const peakY   = h - maxFrac * h * twoLevels[1]; // high band sits near the top
eq(peakY < troughY, true, "higher level maps to smaller y (higher tip)");
const twoPath = wavePath(twoLevels, w, h, maxFrac, minFrac);
eq(twoPath.includes(String(troughY)), true, "trough tip y present in path");
eq(twoPath.includes(String(peakY)), true, "peak tip y present in path");

// maxFrac caps the tallest band. levels=[1.0] is length 1 (empty), so use [1.0,1.0]
// and assert the tip y equals h - maxFrac*h.
eq(wavePath([1.0], w, h, maxFrac, minFrac), "", "levels of length 1 => empty even at full amplitude");
const cappedPath = wavePath([1.0, 1.0], w, h, maxFrac, minFrac);
const cappedY = h - maxFrac * h;
eq(cappedPath.includes(String(cappedY)), true, "tallest band respects maxFrac cap (y == h - maxFrac*h)");

// svgSmooth: n points => n Q commands (n-1 across neighbours + 1 terminator at the last point).
const smoothed = svgSmooth([0, 50, 100], [10, 20, 30]);
eq(typeof smoothed, "string", "svgSmooth returns a string");
eq((smoothed.match(/Q/g) || []).length, 3, "svgSmooth emits one Q per point (3 points => 3 Q segments)");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
