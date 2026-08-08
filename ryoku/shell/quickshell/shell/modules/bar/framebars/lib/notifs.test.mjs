import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { count, rows } = require("./notifs.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const groups = [
    { app: "Discord", count: 3, t: 200, preview: { summary: "3 new messages", body: "from #general" } },
    { app: "System", count: 1, t: 100, preview: { summary: "Update available", body: "" } }
];

eq(count(groups), 4, "count sums every notification across app groups");
eq(count([]), 0, "no groups is zero");
eq(count(null), 0, "a missing groups list is zero, not a throw");

eq(rows(groups), [
    { app: "Discord", count: 3, summary: "3 new messages", body: "from #general" },
    { app: "System", count: 1, summary: "Update available", body: "" }
], "rows normalize each group to its dismissable app row");

eq(rows(groups).map(r => r.app), ["Discord", "System"], "rows preserve the app dismissal key in order");

eq(rows([{ count: 2, preview: { summary: "x", body: "" } }])[0].app, "System",
    "an app-less group falls back to the System dismissal key");
eq(rows([{ app: "Slack", count: 1 }])[0].summary, "",
    "a group with no preview yields empty text, not a throw");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
