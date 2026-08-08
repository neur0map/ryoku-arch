import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { parseBang, buildUrl, engineName } = require("./engines.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

eq(parseBang("!yt lofi beats"), { bang: "yt", query: "lofi beats" }, "bang splits leading token");
eq(parseBang("plain query"), { bang: "", query: "plain query" }, "no bang leaves query whole");
eq(parseBang("!gh"), { bang: "gh", query: "" }, "bang with no query");
eq(parseBang("  !W spaced  "), { bang: "w", query: "spaced" }, "bang is lowercased and trimmed");

eq(buildUrl("!yt cats", "g"), "https://www.youtube.com/results?search_query=cats", "known bang routes to its engine");
eq(buildUrl("cats", "g"), "https://www.google.com/search?q=cats", "no bang uses default engine");
eq(buildUrl("!zzz cats", "g"), "https://www.google.com/search?q=" + encodeURIComponent("!zzz cats"), "unknown bang falls back to default over whole text");
eq(buildUrl("a b&c", "ddg"), "https://duckduckgo.com/?q=" + encodeURIComponent("a b&c"), "default key honored and query encoded");

eq(engineName("!gh repo", "g"), "GitHub", "engine name for a bang");
eq(engineName("repo", "ddg"), "DuckDuckGo", "engine name for default");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
