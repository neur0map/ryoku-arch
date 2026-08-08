import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { watchDelta, setOwnership } = require("./menupoll.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

eq(watchDelta(false, true), { watching: true, delta: 1 }, "opening a closed menu starts one scan");
eq(watchDelta(true, true), { watching: true, delta: 0 }, "re-affirming an open menu adds no duplicate scan");
eq(watchDelta(true, false), { watching: false, delta: -1 }, "closing an open menu releases its scan");
eq(watchDelta(false, false), { watching: false, delta: 0 }, "a menu that was never watching releases nothing");

let w = false, net = 0;
for (const open of [true, true, false, false]) {
    const r = watchDelta(w, open);
    w = r.watching;
    net += r.delta;
}
eq(net, 0, "open, open, close, close leaves the refcount balanced");

const first = {};
const second = {};
let owners = [];
owners = setOwnership(owners, first, true);
owners = setOwnership(owners, second, true);
eq(owners.length, 2, "two menu instances retain two shared acquisitions");
owners = setOwnership(owners, first, false);
eq(owners.length, 1, "closing the first instance retains the second acquisition");
owners = setOwnership(owners, first, false);
eq(owners.length, 1, "closing an already released instance retains the other acquisition");
owners = setOwnership(owners, second, false);
eq(owners.length, 0, "closing the final instance releases shared ownership");

owners = setOwnership([], first, true);
owners = setOwnership(owners, second, true);
owners = setOwnership(owners, second, false);
eq(owners.length, 1, "destroying the second instance retains the first acquisition");
owners = setOwnership(owners, first, false);
eq(owners.length, 0, "destroying the final instance releases shared ownership");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
