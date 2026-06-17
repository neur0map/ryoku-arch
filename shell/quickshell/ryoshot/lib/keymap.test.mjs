import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { keyName, bindString, luaFile, parseBind } = require("./keymap.js");

const K = {
    Print: 0x01000009, Escape: 0x01000000, Tab: 0x01000001, Return: 0x01000004,
    Space: 0x20, Delete: 0x01000007, Up: 0x01000013,
    F1: 0x01000030, F5: 0x01000034, F12: 0x0100003b,
    A: 0x41, P: 0x50, Z: 0x5a, D0: 0x30, D7: 0x37,
    Period: 0x2e, Slash: 0x2f, Minus: 0x2d,
    Shift: 0x01000020, Control: 0x01000022, Meta: 0x01000025
};
const M = { SHIFT: 0x02000000, CTRL: 0x04000000, ALT: 0x08000000, SUPER: 0x10000000 };

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual), e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

eq(keyName(K.Print, ""), "Print", "Print -> Print");
eq(keyName(K.Escape, ""), "Escape", "Escape -> Escape");
eq(keyName(K.Space, " "), "Space", "Space -> Space");
eq(keyName(K.F5, ""), "F5", "F5 -> F5");
eq(keyName(K.F12, ""), "F12", "F12 -> F12");
eq(keyName(K.A, "a"), "a", "A -> a (lowercase)");
eq(keyName(K.Z, "z"), "z", "Z -> z");
eq(keyName(K.D7, "7"), "7", "digit 7 -> 7");
eq(keyName(K.Up, ""), "Up", "Up arrow -> Up");
eq(keyName(K.Shift, ""), null, "bare Shift -> null (keep listening)");
eq(keyName(K.Control, ""), null, "bare Control -> null");
eq(keyName(K.Meta, ""), null, "bare Meta/Super -> null");

eq(keyName(K.Period, "."), "period", "period -> 'period' (not '.')");
eq(keyName(K.Slash, "/"), "slash", "slash -> 'slash'");
eq(keyName(K.Minus, "-"), "minus", "minus -> 'minus'");
eq(bindString(K.Period, M.CTRL, "."), "CTRL + period", "Ctrl+. -> 'CTRL + period'");

eq(keyName(0x0fffffff, "/"), null, "unmapped key -> null (no raw-text fallback)");

eq(bindString(K.Print, 0, ""), "Print", "plain Print -> 'Print'");
eq(bindString(K.P, M.CTRL | M.SHIFT, "p"), "CTRL + SHIFT + P".replace("P", "p"),
    "Ctrl+Shift+p -> 'CTRL + SHIFT + p'");
eq(bindString(K.S = 0x53, M.SHIFT | M.SUPER, "s"), "SUPER + SHIFT + s",
    "Super+Shift+s -> 'SUPER + SHIFT + s'");
eq(bindString(K.A, M.SUPER, "a"), "SUPER + a", "Super+a -> 'SUPER + a'");
eq(bindString(K.Shift, M.SHIFT, ""), null, "modifier-only chord -> null");

eq(bindString(K.P, M.CTRL | M.SHIFT, "p").toUpperCase(), "CTRL + SHIFT + P",
    "Ctrl+Shift+P structural form (upper) == 'CTRL + SHIFT + P'");

const file = luaFile("CTRL + SHIFT + P");
if (file.includes('hl.bind("CTRL + SHIFT + P", hl.dsp.exec_cmd("flock -n /tmp/ryoshot.lock qs -c ryoshot"))'))
    console.log("PASS luaFile contains correct bind line");
else { failed++; console.log("FAIL luaFile bind line\n  got:\n" + file); }
eq(parseBind(file), "CTRL + SHIFT + P", "parseBind round-trips the written bind");
eq(parseBind('hl.bind("Print", hl.dsp.exec_cmd("qs -c ryoshot"))'), "Print", "parseBind reads default Print");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
