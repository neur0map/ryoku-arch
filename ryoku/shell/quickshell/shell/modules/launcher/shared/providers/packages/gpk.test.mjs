import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { parse, isInstalled, supportsSearch, ZERO_TIME } = require("./gpk.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }

const envelope = JSON.stringify({
    gpk_version: "1.0.0", schema: 1, data: [
        { name: "ripgrep", version: "15.1.0-2", source: "pacman", description: "fast grep", installed_at: ZERO_TIME },
        { name: "fd", version: "10.1.0", source: "pacman", description: "fast find", installed_at: "2026-01-02T03:04:05Z" }
    ]
});

eq(parse(envelope).length, 2, "parses both rows");
eq(parse(envelope)[0], { name: "ripgrep", version: "15.1.0-2", source: "pacman", description: "fast grep", installed: false }, "not-installed flagged by zero time");
eq(parse(envelope)[1].installed, true, "real installed_at flags installed");

const withBool = JSON.stringify({
    gpk_version: "1.0.0", schema: 1, data: [
        { name: "kitty", version: "0.47.1-2", source: "pacman", installed: true, installed_at: ZERO_TIME },
        { name: "kitty", version: "0.47.4", source: "nix", installed_at: ZERO_TIME }
    ]
});
eq(parse(withBool)[0].installed, true, "installed bool wins over zero installed_at");
eq(parse(withBool)[1].installed, false, "absent bool falls back to installed_at");

ok(isInstalled("2026-01-02T03:04:05Z"), "real date is installed");
ok(!isInstalled(ZERO_TIME), "zero time is not installed");
ok(!isInstalled(""), "empty is not installed");

ok(supportsSearch({ schema: 1, data: [] }), "schema 1 with data array supported");
ok(!supportsSearch({ schema: 0, data: [] }), "schema 0 unsupported");
ok(!supportsSearch({}), "missing schema unsupported (stale gpk)");

eq(parse("not json"), [], "invalid json yields no rows");
eq(parse(JSON.stringify({ schema: 1, data: [{ version: "1" }] })), [], "row without a name is dropped");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
