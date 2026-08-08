import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { audioRows, btRows } = require("./devices.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const speaker = { name: "alsa_output.pci-0000_65_00.6.analog-stereo", label: "ALC285 Analog", icon: "speaker" };
const bt = { name: "bluez_output.80_99_E7_F7_25_1B.1", label: "WH-1000XM6", icon: "headphones" };
const nodes = [speaker, bt];
const opts = { label: n => n.label, icon: n => n.icon, key: n => n.name };

eq(audioRows(nodes, bt, opts), [
    { name: speaker.name, label: "ALC285 Analog", icon: "speaker", selected: false },
    { name: bt.name, label: "WH-1000XM6", icon: "headphones", selected: true }
], "audio rows normalize label/icon and flag the selected node");
eq(audioRows(null, null, opts), [], "a missing node list normalizes to empty");
eq(audioRows(nodes, null, opts).some(r => r.selected), false, "no default means nothing is selected");

const devices = [
    { name: "Keyboard K380", address: "AA:BB", connected: false, paired: true, batteryAvailable: false },
    { name: "WH-1000XM6", address: "80:99:E7:F7:25:1B", connected: true, paired: false, batteryAvailable: true, battery: 0.8 },
    null,
    { name: "", address: "CC:DD", connected: false, paired: false }
];
eq(btRows(devices), [
    { name: "WH-1000XM6", address: "80:99:E7:F7:25:1B", connected: true, paired: false, battery: 80 },
    { name: "Keyboard K380", address: "AA:BB", connected: false, paired: true, battery: -1 }
], "bt rows drop nameless/null entries, sort connected first, scale fractional battery");
eq(btRows([{ name: "Mouse", address: "EE:FF", connected: false, paired: true, batteryAvailable: true, battery: 55 }])[0].battery, 55,
    "an already-percentage battery is kept as-is");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
