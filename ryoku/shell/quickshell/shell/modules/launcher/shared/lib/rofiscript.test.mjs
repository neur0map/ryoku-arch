import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { parse, parseDirectives, scriptEnv } = require("./rofiscript.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const NUL = "\0";
const US = "\x1f";

eq(parse("Firefox\nChromium").rows.map(r => r.text), ["Firefox", "Chromium"], "plain lines become rows");

const withIcon = "Firefox" + NUL + "icon" + US + "firefox" + US + "info" + US + "tab-3";
eq(parse(withIcon).rows[0], { text: "Firefox", icon: "firefox", meta: "", info: "tab-3", nonselectable: false, urgent: false, active: false }, "row directives parsed");

const global = NUL + "prompt" + US + "Spotify" + US + "no-custom" + US + "true";
eq(parse(global + "\nTrack A").options, { prompt: "Spotify", "no-custom": "true" }, "global directive line folds into options");
eq(parse(global + "\nTrack A").rows.map(r => r.text), ["Track A"], "global line is not a row");

const nonsel = "Header" + NUL + "nonselectable" + US + "true";
eq(parse(nonsel).rows[0].nonselectable, true, "nonselectable flag parsed");

eq(parseDirectives("icon" + US + "x" + US + "meta" + US + "y"), { icon: "x", meta: "y" }, "directive pairs split on US");
eq(parse("").rows, [], "empty output yields no rows");

eq(scriptEnv(0), { ROFI_RETV: "0" }, "init env has retv only");
eq(scriptEnv(1, "tab-3"), { ROFI_RETV: "1", ROFI_INFO: "tab-3" }, "selection env carries info");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
