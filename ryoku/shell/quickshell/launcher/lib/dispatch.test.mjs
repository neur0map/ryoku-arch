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

const prefixes = { "=": "calc", ";": "clipboard", "/": "actions", "/file": "find", "/folder": "find", "/image": "find", "/video": "find", ">": "packages", "?": "web", "s:": "spotify", "@": "ytmusic" };

eq(routePrefix("=2+2", prefixes), { provider: "calc", query: "2+2", prefix: "=" }, "math prefix routes and strips");
eq(routePrefix(";link", prefixes), { provider: "clipboard", query: "link", prefix: ";" }, "clipboard prefix routes");
eq(routePrefix("/wifi", prefixes), { provider: "actions", query: "wifi", prefix: "/" }, "bare slash routes to actions");
eq(routePrefix("/file report", prefixes), { provider: "find", query: "report", prefix: "/file" }, "longest match: /file routes to find, not actions");
eq(routePrefix("/image cat", prefixes), { provider: "find", query: "cat", prefix: "/image" }, "/image routes to find with its prefix");
eq(routePrefix(">search yay", prefixes), { provider: "packages", query: "search yay", prefix: ">" }, "package prefix keeps the subcommand in the query");
eq(routePrefix("firefox", prefixes), { provider: null, query: "firefox", prefix: "" }, "no prefix is default fan-out");
eq(routePrefix("", prefixes), { provider: null, query: "", prefix: "" }, "empty text is default with empty query");
eq(routePrefix("= 2 + 2", prefixes), { provider: "calc", query: "2 + 2", prefix: "=" }, "prefix strips a following space");
eq(routePrefix("?", prefixes), { provider: "web", query: "", prefix: "?" }, "bare prefix routes with empty query");
eq(routePrefix("s:daft punk", prefixes), { provider: "spotify", query: "daft punk", prefix: "s:" }, "multi-char prefix routes and strips");
eq(routePrefix("settings", prefixes), { provider: null, query: "settings", prefix: "" }, "a word starting with s is not the spotify prefix");
eq(routePrefix("@lofi", prefixes), { provider: "ytmusic", query: "lofi", prefix: "@" }, "single-char @ prefix routes");

eq(looksNumeric("2+2"), true, "leading digit looks numeric");
eq(looksNumeric("3 * 4"), true, "leading digit with spaces looks numeric");
eq(looksNumeric("firefox"), false, "leading letter is not numeric");
eq(looksNumeric(""), false, "empty is not numeric");
eq(looksNumeric("  5"), true, "leading whitespace then digit is numeric");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
