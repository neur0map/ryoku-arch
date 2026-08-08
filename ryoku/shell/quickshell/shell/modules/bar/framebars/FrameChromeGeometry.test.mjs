import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
let Geometry = {};
try {
    Geometry = require("./FrameChromeGeometry.js");
} catch {
    // The RED phase intentionally runs before the geometry module exists.
}

let failed = 0;

function eq(actual, expected, message) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + message);
    else {
        failed++;
        console.log("FAIL " + message + "\n  expected " + e + "\n  got      " + a);
    }
}

function ok(value, message) {
    if (value) console.log("PASS " + message);
    else {
        failed++;
        console.log("FAIL " + message);
    }
}

ok(typeof Geometry.offsetPoints === "function"
    && typeof Geometry.offsetRadii === "function"
    && typeof Geometry.roundedPath === "function"
    && typeof Geometry.framePath === "function",
    "scene-graph frame geometry API is available");

if (typeof Geometry.offsetPoints !== "function") {
    console.log("\n" + failed + " frame chrome geometry assertion(s) FAILED");
    process.exit(1);
}

const plain = [
    { x: 10, y: 12 }, { x: 90, y: 12 },
    { x: 90, y: 68 }, { x: 10, y: 68 }
];

eq(Geometry.offsetPoints(plain, 2), [
    { x: 8, y: 10 }, { x: 92, y: 10 },
    { x: 92, y: 70 }, { x: 8, y: 70 }
], "surface inset leaves a two-pixel outline on the band side");

eq(Geometry.offsetRadii(plain, 8, 2), [10, 10, 10, 10],
    "surface offset expands the static hole radii");
const rounded = Geometry.roundedPath(plain, 8);
ok(/^M /.test(rounded) && rounded.includes(" Q ") && rounded.endsWith(" Z")
    && !rounded.includes("NaN") && !rounded.includes("Infinity"),
    "rounded static hole is finite closed scene-graph geometry");


const frame = Geometry.framePath(100, 80, plain, 8);
ok(frame.startsWith("M 0 0 H 100 V 80 H 0 Z ") && frame.endsWith(" Z"),
    "frame path combines the screen and hole for odd-even fill");

if (failed > 0) {
    console.log("\n" + failed + " frame chrome geometry assertion(s) FAILED");
    process.exit(1);
}
console.log("\nFrame chrome geometry tests PASSED");
