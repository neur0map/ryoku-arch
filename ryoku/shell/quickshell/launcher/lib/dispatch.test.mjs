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
eq(looksNumeric(null), false, "null is not numeric");
eq(looksNumeric(undefined), false, "undefined is not numeric");
// Unprefixed math shapes we now route to calc.
eq(looksNumeric("(1+2)*3"), true, "leading paren looks numeric");
eq(looksNumeric(".5"), true, "leading decimal looks numeric");
eq(looksNumeric(".5*2"), true, "leading decimal then op looks numeric");
eq(looksNumeric("-3"), true, "leading minus digit is numeric");
eq(looksNumeric("-3+1"), true, "leading minus digit with op is numeric");
eq(looksNumeric("+5"), true, "leading plus digit is numeric");
eq(looksNumeric("-.5"), true, "leading minus decimal is numeric");
eq(looksNumeric("-(1+2)"), true, "leading minus paren is numeric");
eq(looksNumeric("sqrt(16)"), true, "sqrt call is numeric");
eq(looksNumeric("sin(0)"), true, "sin call is numeric");
eq(looksNumeric("log(10)"), true, "log call is numeric");
eq(looksNumeric("log2(8)"), true, "log2 call is numeric");
eq(looksNumeric("log10(100)"), true, "log10 call is numeric");
eq(looksNumeric("ln(e)"), true, "ln call is numeric");
eq(looksNumeric("pi*2"), true, "pi constant with op is numeric");
eq(looksNumeric("pi"), true, "bare pi is numeric");
eq(looksNumeric("tau/2"), true, "tau constant with op is numeric");
eq(looksNumeric("e"), true, "bare e constant is numeric");
eq(looksNumeric("e+3"), true, "e constant with op is numeric");
// The conservative negatives: ordinary words and identifiers that happen to
// contain digits or start with math-token letters MUST route as normal search.
eq(looksNumeric("route66"), false, "identifier with a digit is not numeric");
eq(looksNumeric("s3cret"), false, "identifier with a middle digit is not numeric");
eq(looksNumeric("hello"), false, "plain word is not numeric");
eq(looksNumeric("settings"), false, "leading s is not numeric (not spotify prefix either)");
eq(looksNumeric("spotify"), false, "word starting with s is not numeric");
eq(looksNumeric("sine wave"), false, "sine is not sin (word boundary guard)");
eq(looksNumeric("expert"), false, "expert is not exp (word boundary guard)");
eq(looksNumeric("email"), false, "email is not the e constant (word boundary guard)");
eq(looksNumeric("pipe"), false, "pipe is not pi (word boundary guard)");
eq(looksNumeric("edit"), false, "edit is not the e constant (word boundary guard)");
eq(looksNumeric("logout"), false, "logout is not log (word boundary guard)");
eq(looksNumeric("--flag"), false, "double dash is not numeric");
eq(looksNumeric("-flag"), false, "dash then letter is not numeric");
if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
