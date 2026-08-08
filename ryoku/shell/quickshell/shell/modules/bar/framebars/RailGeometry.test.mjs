import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { edgeRect, reserve } = require("./RailGeometry.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const width = 1920;
const height = 1080;
eq(edgeRect("top", 32, width, height), { x: 0, y: 0, width: 1920, height: 32 }, "top rail rect");
eq(edgeRect("bottom", 32, width, height), { x: 0, y: 1048, width: 1920, height: 32 }, "bottom rail rect");
eq(edgeRect("left", 48, width, height), { x: 0, y: 0, width: 48, height: 1080 }, "left rail rect");
eq(edgeRect("right", 48, width, height), { x: 1872, y: 0, width: 48, height: 1080 }, "right rail rect");
eq(reserve("left", 9, 48, true), 57, "left reserve includes frame lip");
eq(reserve("right", 9, 48, false), 0, "disabled rail reserves nothing");
eq({ top: reserve("top", 9, 32, true), left: reserve("left", 9, 48, true) }, { top: 41, left: 57 }, "top and left reserve independently");
const frameLip = 9;
const activeBottomInset = reserve("bottom", frameLip, 32, true) || frameLip;
const plainBottomInset = reserve("bottom", frameLip, 32, false) || frameLip;
eq(activeBottomInset, 41, "OSD clears an active bottom rail");
eq(plainBottomInset, 9, "OSD falls back to the frame lip");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
