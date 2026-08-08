import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { pin, unpin, resolve } = require("./dock.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const clients = [
    { className: "firefox", address: "0x1" },
    { className: "kitty", address: "0x2" },
    { className: "firefox", address: "0x3" },
    { className: "steam", address: "0x4" }
];

eq(pin(["firefox"], "firefox"), ["firefox"], "duplicate pins are rejected");
eq(resolve(["kitty", "firefox"], clients), ["kitty", "firefox", "steam"], "pinned classes lead and live unpinned clients follow stably");
eq(resolve(["firefox"], clients), ["firefox", "kitty", "steam"], "live unpinned clients are inserted after pins");
eq(unpin(["firefox", "kitty"], "firefox"), ["kitty"], "unpin removes only the requested class");
eq(resolve(["firefox"], clients).some(value => value.includes("0x")), false, "window addresses are never persisted in dock entries");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
