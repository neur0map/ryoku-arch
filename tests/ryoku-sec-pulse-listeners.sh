#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PARSER="$ROOT_DIR/shell/services/ryoku_sec_pulse.js"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $PARSER ]] || fail "shell/services/ryoku_sec_pulse.js should exist"

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP: node is not available"
  exit 0
fi

node - "$PARSER" <<'JS'
const assert = require("assert");
const parser = require(process.argv[2]);

const sample = [
  'LISTEN 0 4096 127.0.0.1:11434 0.0.0.0:* users:(("ollama",pid=321,fd=3))',
  'LISTEN 0 128 0.0.0.0:22 0.0.0.0:* users:(("sshd",pid=812,fd=3))',
  'LISTEN 0 4096 [::1]:631 [::]:* users:(("cupsd",pid=922,fd=7))',
  'LISTEN 0 4096 127.0.0.53%lo:53 0.0.0.0:* uid:974 ino:10159 sk:4 cgroup:/system.slice/systemd-resolved.service <->',
  'LISTEN 0 4096 0.0.0.0:5355 0.0.0.0:* uid:974 ino:10146 sk:3 cgroup:/system.slice/systemd-resolved.service <->',
  'LISTEN 0 4096 [fd7a:115c:a1e0::143b:7948]:55422 [::]:* ino:96648 sk:1002 cgroup:/system.slice/tailscaled.service v6only:1 <->',
  'LISTEN 0 4096 127.0.0.1:8022 0.0.0.0:* cgroup:/user.slice/user-1000.slice/user@1000.service/app.slice/app-alacritty.scope <->'
].join("\n");

const result = parser.parseListeningSockets(sample);

assert.strictEqual(result.count, 7);
assert.deepStrictEqual(result.listeners.map(listener => listener.port), ["11434", "22", "631", "53", "5355", "55422", "8022"]);
assert.strictEqual(result.listeners[0].address, "127.0.0.1");
assert.strictEqual(result.listeners[0].endpoint, "127.0.0.1:11434");
assert.strictEqual(result.listeners[0].process, "ollama");
assert.strictEqual(result.listeners[0].pid, "321");
assert.strictEqual(result.listeners[0].processLabel, "ollama (321)");
assert.strictEqual(result.listeners[0].purpose, "Ollama API");
assert.strictEqual(result.listeners[1].purpose, "SSH");
assert.strictEqual(result.listeners[2].endpoint, "[::1]:631");
assert.strictEqual(result.listeners[2].purpose, "CUPS printing");
assert.strictEqual(result.listeners[3].service, "systemd-resolved.service");
assert.strictEqual(result.listeners[3].processLabel, "systemd-resolved.service");
assert.strictEqual(result.listeners[3].purpose, "DNS resolver");
assert.strictEqual(result.listeners[4].processLabel, "systemd-resolved.service");
assert.strictEqual(result.listeners[4].purpose, "LLMNR name resolution");
assert.strictEqual(result.listeners[5].endpoint, "[fd7a:115c:a1e0::143b:7948]:55422");
assert.strictEqual(result.listeners[5].service, "tailscaled.service");
assert.strictEqual(result.listeners[5].processLabel, "tailscaled.service");
assert.strictEqual(result.listeners[5].purpose, "Tailscale");
assert.strictEqual(result.listeners[6].service, "app-alacritty.scope");
assert.strictEqual(result.listeners[6].processLabel, "app-alacritty.scope");

console.log("PASS: ryoku sec pulse listeners");
JS
