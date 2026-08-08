import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { globalToLocal, localToGlobal, intersectRect, rectFromPoints, stitchPlan } = require("./coords.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) {
        console.log("PASS " + msg);
    } else {
        failed++;
        console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a);
    }
}

const dpX = 2560, dpY = 0;
eq(globalToLocal({ x: 2600, y: 100 }, dpX, dpY), { x: 40, y: 100 }, "globalToLocal DP-1 point");

const g = { x: 2600, y: 100 };
const local = globalToLocal(g, dpX, dpY);
eq(localToGlobal(local, dpX, dpY), g, "round-trip localToGlobal inverts");

eq(globalToLocal({ x: 300, y: 200 }, 0, 0), { x: 300, y: 200 }, "globalToLocal HDMI point");

const span = { x: 2400, y: 200, w: 400, h: 300 };
const hdmi = { x: 0, y: 0, width: 2560, height: 1440 };
const dp = { x: 2560, y: 0, width: 2560, height: 1440 };

eq(intersectRect(span, hdmi), { x: 2400, y: 200, w: 160, h: 300 }, "intersect span on HDMI-A-1");
eq(intersectRect(span, dp), { x: 0, y: 200, w: 240, h: 300 }, "intersect span on DP-1");

const onDp = { x: 2700, y: 300, w: 700, h: 450 };
eq(intersectRect(onDp, hdmi), null, "DP-only selection has no HDMI intersection");
eq(intersectRect(onDp, dp), { x: 140, y: 300, w: 700, h: 450 }, "DP-only selection local on DP-1");

eq(rectFromPoints({ x: 100, y: 100 }, { x: 40, y: 30 }), { x: 40, y: 30, w: 60, h: 70 }, "rectFromPoints normalizes");

// --- stitchPlan: multi-monitor seam offsets, all in logical px --------------
const plan = stitchPlan(span, [hdmi, dp]);
eq(plan.canvas, { w: 400, h: 300 }, "stitchPlan canvas is the selection size");
eq(plan.slices.length, 2, "stitchPlan spans two screens");
eq({ screen: plan.slices[0].screen, ox: plan.slices[0].ox, oy: plan.slices[0].oy },
   { screen: 0, ox: 0, oy: 0 }, "stitchPlan HDMI slice sits at the canvas origin");
eq({ screen: plan.slices[1].screen, ox: plan.slices[1].ox, oy: plan.slices[1].oy },
   { screen: 1, ox: 160, oy: 0 }, "stitchPlan DP slice offset by the HDMI overlap width");
eq(plan.slices[1].local, { x: 0, y: 200, w: 240, h: 300 }, "stitchPlan DP slice grabs its local rect");

// a selection on one screen only yields a single slice at the origin.
const planOne = stitchPlan(onDp, [hdmi, dp]);
eq(planOne.slices.length, 1, "stitchPlan single-screen selection is one slice");
eq({ screen: planOne.slices[0].screen, ox: planOne.slices[0].ox, oy: planOne.slices[0].oy },
   { screen: 1, ox: 0, oy: 0 }, "stitchPlan single slice sits at the origin");

// mixed scale: offsets stay logical, so a low-DPI and a HiDPI (4K logical
// 1920x1080) screen produce a contiguous seam when each slice is grabbed at its
// local logical size (the multi-monitor screenshot fix).
const lowdpi = { x: 0, y: 0, width: 1920, height: 1080 };
const hidpi = { x: 1920, y: 0, width: 1920, height: 1080 };
const spanMixed = { x: 1820, y: 0, w: 200, h: 1080 };
const planMixed = stitchPlan(spanMixed, [lowdpi, hidpi]);
eq(planMixed.slices.map(s => ({ screen: s.screen, ox: s.ox, w: s.local.w })),
   [{ screen: 0, ox: 0, w: 100 }, { screen: 1, ox: 100, w: 100 }],
   "stitchPlan mixed-scale seam is contiguous in logical px");

if (failed > 0) {
    console.log("\n" + failed + " test(s) FAILED");
    process.exit(1);
}
console.log("\nAll tests PASSED");
