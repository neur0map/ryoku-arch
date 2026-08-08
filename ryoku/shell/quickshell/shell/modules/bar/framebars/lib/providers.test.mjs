import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { parseVpn, parseProfiles, parseLayouts } = require("./providers.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

eq(parseVpn("vpn:connected:Work\n"), { active: true, name: "Work" }, "connected VPN is exposed");
eq(parseVpn(""), { active: false, name: "" }, "no VPN is inactive");
eq(parseVpn("wifi:connected:Home\n"), { active: false, name: "" }, "non-VPN connections are ignored");
eq(parseVpn("vpn:disconnected:Work\n"), { active: false, name: "" }, "inactive VPN is ignored");
eq(parseProfiles("balanced\nperformance\n"), ["balanced", "performance"], "profiles parse in order");
eq(parseProfiles("* balanced:\n  Driver: placeholder\n  CpuDriver: intel_pstate\n  performance:\n    Driver: placeholder\n"), ["balanced", "performance"], "powerprofilesctl list entries exclude details");
eq(parseLayouts("dwindle\nmaster\nbogus\n"), ["dwindle", "master"], "only supported layouts remain");
eq(parseLayouts(" master \nscrolling\nmonocle\ndwindle\n"), ["master", "scrolling", "monocle", "dwindle"], "layout names are normalized");
eq(parseProfiles(null), [], "failed provider response clears profiles");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
