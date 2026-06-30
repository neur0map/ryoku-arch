import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { routePrefix, looksNumeric } = require("./dispatch.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const prefixes = { "=": "calc", ";": "clipboard", ":": "emoji", "/": "actions", "$": "shell", "?": "web", ">": "apps" };

eq(routePrefix("=2+2", prefixes), { provider: "calc", query: "2+2" }, "math prefix routes and strips");
eq(routePrefix(";link", prefixes), { provider: "clipboard", query: "link" }, "clipboard prefix routes");
eq(routePrefix("/wifi", prefixes), { provider: "actions", query: "wifi" }, "action prefix routes");
eq(routePrefix(">fire", prefixes), { provider: "apps", query: "fire" }, "explicit app prefix routes");
eq(routePrefix("firefox", prefixes), { provider: null, query: "firefox" }, "no prefix is default fan-out");
eq(routePrefix("", prefixes), { provider: null, query: "" }, "empty text is default with empty query");
eq(routePrefix("= 2 + 2", prefixes), { provider: "calc", query: "2 + 2" }, "prefix strips a following space");
eq(routePrefix("?", prefixes), { provider: "web", query: "" }, "bare prefix routes with empty query");

eq(looksNumeric("2+2"), true, "leading digit looks numeric");
eq(looksNumeric("3 * 4"), true, "leading digit with spaces looks numeric");
eq(looksNumeric("firefox"), false, "leading letter is not numeric");
eq(looksNumeric(""), false, "empty is not numeric");
eq(looksNumeric("  5"), true, "leading whitespace then digit is numeric");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
