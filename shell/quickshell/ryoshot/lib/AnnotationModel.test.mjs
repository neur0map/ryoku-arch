import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { create } = require("./AnnotationModel.js");

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

const r = { type: "rect", points: [{ x: 10, y: 10 }, { x: 50, y: 40 }], color: "#e0563b", width: 3 };
const r2 = { type: "rect", points: [{ x: 0, y: 0 }, { x: 5, y: 5 }], color: "#e0563b", width: 3 };

const m = create();
eq(m.items.length, 0, "starts empty");
eq([m.canUndo(), m.canRedo()], [false, false], "no undo/redo at start");

m.add(r);
eq(m.items.length, 1, "add appends one");
eq(m.canUndo(), true, "can undo after add");

m.add(r2);
eq(m.items.length, 2, "add appends second");

m.undo();
eq(m.items.length, 1, "undo removes last");
eq(m.items[0].type, "rect", "remaining item intact");
eq(m.canRedo(), true, "can redo after undo");

m.redo();
eq(m.items.length, 2, "redo re-applies");
eq(m.items[1].points[1].x, 5, "redone item is the right one");

m.undo();
m.add(r);
eq(m.canRedo(), false, "add clears redo stack");
eq(m.items.length, 2, "add-after-undo count correct");

m.undo(); m.undo(); m.undo();
eq(m.items.length, 0, "undo to empty");
eq(m.undo(), false, "undo past bottom is false");

const mm = create();
mm.add({ type: "rect", points: [{ x: 10, y: 10 }, { x: 50, y: 40 }], color: "#fff", width: 3 });
mm.add({ type: "line", points: [{ x: 0, y: 0 }, { x: 20, y: 20 }], color: "#fff", width: 2 });

eq(mm.move(0, 15, -5), true, "move returns true for valid index");
eq(mm.items[0].points, [{ x: 25, y: 5 }, { x: 65, y: 35 }], "move translates all points");
eq(mm.items[1].points, [{ x: 0, y: 0 }, { x: 20, y: 20 }], "move leaves other items untouched");
eq(mm.move(9, 1, 1), false, "move out-of-range returns false");

mm.undo();
eq(mm.items[0].points, [{ x: 10, y: 10 }, { x: 50, y: 40 }], "undo move restores positions");
eq(mm.canRedo(), true, "can redo after move undo");
mm.redo();
eq(mm.items[0].points, [{ x: 25, y: 5 }, { x: 65, y: 35 }], "redo move re-applies");

const orig = JSON.stringify(mm.items[0].points);
mm.move(0, 100, 100);
mm.undo();
eq(JSON.stringify(mm.items[0].points), orig, "undo move is deep (snapshot, not aliased)");

eq(mm.remove(0), true, "remove returns true for valid index");
eq(mm.items.length, 1, "remove deletes one item");
eq(mm.items[0].type, "line", "correct item remains after remove");
eq(mm.remove(5), false, "remove out-of-range returns false");

mm.undo();
eq(mm.items.length, 2, "undo remove restores item");
eq(mm.items[0].type, "rect", "restored item is correct");
mm.redo();
eq(mm.items.length, 1, "redo remove re-applies");

mm.add({ type: "ellipse", points: [{ x: 1, y: 1 }, { x: 2, y: 2 }], color: "#fff", width: 1 });
eq(mm.canRedo(), false, "add after remove clears redo");

if (failed > 0) {
    console.log("\n" + failed + " test(s) FAILED");
    process.exit(1);
}
console.log("\nAll tests PASSED");
