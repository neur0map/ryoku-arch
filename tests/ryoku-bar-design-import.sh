#!/bin/bash
# Isolation checks for ryoku-bar-design-import.
#
# A bar design is declarative data only. These tests assert the importer accepts
# a valid declarative design and HARD-REJECTS anything that smuggles runtime
# (commands, IPC, plugin entry points, embedded code), never writing such a file.

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

tmp="${TMPDIR:-/tmp}/ryoku-bar-design-import-test.$$"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/home" "$tmp/config"

designs_dir="$tmp/config/ryoku/bar-designs"

run() {
  HOME="$tmp/home" XDG_CONFIG_HOME="$tmp/config" bin/ryoku-bar-design-import "$@"
}

# write <name> <json>  -> creates $tmp/<name>, echoes its path
write() {
  printf '%s' "$2" >"$tmp/$1"
  printf '%s' "$tmp/$1"
}

# Assert a design is REJECTED (non-zero exit) and never written to disk.
reject() {
  local label="$1" path="$2" expect_id="$3"
  if run "$path" >/dev/null 2>&1; then
    fail "$label: should have been REJECTED but exited 0"
  fi
  if [[ -n $expect_id && -f "$designs_dir/$expect_id.json" ]]; then
    fail "$label: a rejected design must NOT be written"
  fi
}

# --- a valid declarative design installs ---
valid="$(write valid.json '{"id":"my-rice","name":"My Rice","templateId":"top-notch","edge":"top","entries":[{"id":"workspaces","enabled":true},{"id":"clock","enabled":true}],"credits":{"source":"Reddit","license":"MIT"}}')"
run "$valid" >/dev/null || fail "valid design should import"
[[ -f "$designs_dir/my-rice.json" ]] || fail "valid design should be installed"
[[ "$(jq -r '.templateId' "$designs_dir/my-rice.json")" == "top-notch" ]] || fail "installed design should preserve templateId"
[[ "$(jq -r '.edge' "$designs_dir/my-rice.json")" == "top" ]] || fail "installed design should preserve edge"
pass "valid design imports and installs"

# --- runtime/command field is rejected ---
reject "exec field" "$(write exec.json '{"id":"evil","name":"Evil","templateId":"sidebar-left","exec":"rm -rf ~"}')" evil
pass "exec field rejected"

# --- plugin-manifest mimic (entryPoints) is rejected ---
reject "entryPoints" "$(write ep.json '{"id":"evil2","name":"Evil2","templateId":"sidebar-left","entryPoints":{"main":"Main.qml"}}')" evil2
pass "plugin entryPoints rejected"

# --- nested IPC key (any depth) is rejected ---
reject "nested ipc key" "$(write ipc.json '{"id":"evil3","name":"Evil3","templateId":"sidebar-left","credits":{"ipc":"my-socket"}}')" evil3
pass "nested ipc key rejected"

# --- unknown top-level key (allowlist) is rejected ---
reject "unknown top-level key" "$(write unk.json '{"id":"evil4","name":"Evil4","templateId":"sidebar-left","telemetry":{"endpoint":"x"}}')" evil4
pass "unknown top-level key rejected"

# --- embedded QML/code in a string value is rejected ---
reject "embedded qml in description" "$(write qml.json '{"id":"evil5","name":"Evil5","templateId":"sidebar-left","description":"import Quickshell.Io; Process { command: [\"sh\"] }"}')" evil5
pass "embedded code value rejected"

# --- unknown template is rejected ---
reject "unknown templateId" "$(write tmpl.json '{"id":"evil6","name":"Evil6","templateId":"their-foreign-shell"}')" evil6
pass "unknown templateId rejected"

# --- unknown widget id in entries is rejected ---
reject "unknown widget id" "$(write badw.json '{"id":"evil7","name":"Evil7","templateId":"sidebar-left","entries":[{"id":"hackwidget","enabled":true}]}')" evil7
pass "unknown widget id rejected"

# --- malformed id slug is rejected (and not used as a path) ---
reject "path-traversal id" "$(write badid.json '{"id":"../escape","name":"Evil8","templateId":"sidebar-left"}')" ""
[[ -f "$tmp/config/ryoku/escape.json" || -f "$tmp/escape.json" ]] && fail "path-traversal id must not write outside designs dir"
pass "path-traversal id rejected"

# --- missing required name is rejected ---
reject "missing name" "$(write noname.json '{"id":"noname","templateId":"sidebar-left"}')" noname
pass "missing name rejected"

# --- overwrite protection, and --force ---
if run "$valid" >/dev/null 2>&1; then
  fail "should refuse to overwrite an existing design without --force"
fi
run "$valid" --force >/dev/null || fail "should overwrite with --force"
pass "overwrite protection and --force"

pass "ryoku bar design import"
