#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

bin="$ROOT_DIR/bin/ryoku-default-apps"

[[ -x $bin ]] || fail "ryoku-default-apps should be executable"
bash -n "$bin" || fail "ryoku-default-apps has a syntax error"

# `list` must emit valid JSON with all five category arrays. Arrays may be empty
# where no candidate is installed (e.g. CI), but the keys must always be present
# so the settings UI can build every dropdown.
out="$("$bin" list)" || fail "list exited non-zero"
echo "$out" | jq -e '
  ([.terminal, .browser, .filemanager, .media, .mixer] | map(type) | all(. == "array"))
  and ([.[][] | select((.key | type) != "string" or (.name | type) != "string")] | length == 0)
' >/dev/null || fail "list must emit five category arrays of {key,name} objects"

# Detection is presence-gated: every listed candidate must resolve on PATH (so
# the selector never offers an app that is not actually installed).
while IFS= read -r key; do
  [[ -z $key ]] && continue
  command -v "$key" >/dev/null 2>&1 || fail "listed candidate '$key' is not on PATH"
done < <(echo "$out" | jq -r '.[][].key')

# An unknown subcommand is a usage error.
if "$bin" definitely-not-a-subcommand >/dev/null 2>&1; then
  fail "unknown subcommand should exit non-zero"
fi

echo "PASS: default-apps"
