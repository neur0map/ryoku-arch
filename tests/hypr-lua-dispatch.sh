#!/bin/bash
# Regression: services/Hypr.qml must translate the legacy Hyprland dispatch verbs
# this shell emits into Hyprland's Lua dispatcher syntax. Hyprland v0.55+ can run
# with configProvider=lua (e.g. after a HyprMod migration), where the IPC `dispatch`
# is evaluated as Lua (hl.dispatch(hl.dsp.*)) and bare strings like "workspace 2"
# fail outright -- which is what broke bar workspace switching. This test runs the
# actual toLuaDispatch/luaQuote logic from the QML and asserts each mapping.
#
# Run from any working directory; resolves repo root via BASH_SOURCE.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

HYPR="shell/services/Hypr.qml"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

test -f "$HYPR" || fail "$HYPR is missing"

# 1. Lua-mode detection wiring is present (probe + branch).
grep -q 'hl.dsp.no_op()' "$HYPR" || fail "$HYPR lost the hl.dsp.no_op() Lua-mode probe"
grep -q 'useLuaDispatch'  "$HYPR" || fail "$HYPR lost the useLuaDispatch dispatch branch"
ok "Lua dispatch detection wiring present"

# 2. Execute the real toLuaDispatch/luaQuote and assert every translation. The
#    function bodies are pure JS (only the QML type-annotated signatures are QML),
#    so we slice them out by brace-matching and run them with node.
node - "$HYPR" <<'NODE'
const fs = require("fs");
const src = fs.readFileSync(process.argv[2], "utf8");

// Extract a QML function body (text between its outer braces). All brace pairs in
// the body -- switch blocks, object/template literals -- are balanced, so a depth
// counter lands exactly on the function's closing brace.
function functionBody(name) {
  const head = src.match(new RegExp("function\\s+" + name + "\\s*\\([^)]*\\)\\s*:\\s*\\w+\\s*\\{"));
  if (!head) throw new Error("function not found: " + name);
  let i = head.index + head[0].length;
  let depth = 1;
  let body = "";
  while (i < src.length && depth > 0) {
    const c = src[i];
    if (c === "{") depth++;
    else if (c === "}") depth--;
    if (depth > 0) body += c;
    i++;
  }
  if (depth !== 0) throw new Error("unbalanced braces while extracting " + name);
  return body;
}

const luaQuote = new Function("value", functionBody("luaQuote"));
const toLua = new Function("request", "luaQuote", functionBody("toLuaDispatch"));
const t = (r) => toLua(r, luaQuote);

const cases = [
  // workspace switch (the bar click path the user reported broken)
  ["workspace 2",                    'hl.dsp.focus({ workspace = 2 })'],
  ["workspace 10",                   'hl.dsp.focus({ workspace = 10 })'],
  // relative scroll-to-switch
  ["workspace r+1",                  'hl.dsp.focus({ workspace = "r+1" })'],
  ["workspace r-1",                  'hl.dsp.focus({ workspace = "r-1" })'],
  // named / special workspace focus
  ["workspace special:magic",        'hl.dsp.focus({ workspace = "special:magic" })'],
  // special workspace toggle (clicking the active dot / SpecialWorkspaces)
  ["togglespecialworkspace",         "hl.dsp.workspace.toggle_special()"],
  ["togglespecialworkspace special", 'hl.dsp.workspace.toggle_special({ name = "special" })'],
  // window-info popout buttons
  ["movetoworkspace 3,address:0x5d", 'hl.dsp.window.move({ workspace = 3, window = "address:0x5d" })'],
  ["togglefloating address:0x5d",    'hl.dsp.window.float({ window = "address:0x5d" })'],
  ["pin address:0x5d",               'hl.dsp.window.pin({ window = "address:0x5d" })'],
  ["killwindow address:0x5d",        'hl.dsp.window.close({ window = "address:0x5d" })'],
  // monitor focus (multi-monitor: bar targets its own monitor before switching)
  ["focusmonitor DP-2",              'hl.dsp.focus({ monitor = "DP-2" })'],
  ["focusmonitor eDP-1",             'hl.dsp.focus({ monitor = "eDP-1" })'],
];

let failed = 0;
for (const [input, expected] of cases) {
  const got = t(input);
  if (got !== expected) {
    console.error(`  MISMATCH "${input}"\n    expected: ${expected}\n    got:      ${got}`);
    failed++;
  }
}

// Quoting safety: embedded quotes/backslashes must be escaped for the Lua literal.
if (luaQuote('a"b\\c') !== 'a\\"b\\\\c') {
  console.error("  luaQuote failed to escape quotes/backslashes: " + luaQuote('a"b\\c'));
  failed++;
}

if (failed) {
  console.error(failed + " dispatch translation check(s) failed");
  process.exit(1);
}
console.log("  all " + cases.length + " dispatch translations correct");
NODE
ok "toLuaDispatch translates every legacy verb the shell emits"

echo "PASS: hypr-lua-dispatch"
