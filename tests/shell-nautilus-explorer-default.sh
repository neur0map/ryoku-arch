#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  grep -Fq -- "$needle" "$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  if grep -Fq -- "$needle" "$path"; then
    fail "$message"
  fi
}

assert_contains shell/plugin/src/Ryoku/Config/generalconfig.hpp \
  'CONFIG_GLOBAL_PROPERTY(QStringList, explorer, { u"nautilus"_s })' \
  "Global shell explorer default should use Nautilus"
assert_not_contains shell/plugin/src/Ryoku/Config/generalconfig.hpp \
  'CONFIG_GLOBAL_PROPERTY(QStringList, explorer, { u"thunar"_s })' \
  "Global shell explorer default should not use Thunar"
assert_contains install/ryoku-base.packages 'nautilus' \
  "Nautilus should be part of the shipped package set"

migration="$(grep -Rsl 'Use Nautilus for shell folder actions' migrations || true)"
[[ -n $migration ]] || fail "Existing installs should get a migration for the shell explorer default"

bash -n "$migration"
assert_contains "$migration" '.general.apps.explorer' \
  "Migration should update the typed shell explorer config"
assert_contains "$migration" '["nautilus"]' \
  "Migration should write Nautilus as the shell explorer"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

run_migration() {
  local case_name="$1"
  local config_payload="$2"
  local home="$tmp_dir/$case_name"

  mkdir -p "$home/.config/ryoku"
  if [[ -n $config_payload ]]; then
    printf '%s\n' "$config_payload" >"$home/.config/ryoku/shell.json"
  fi

  HOME="$home" \
  XDG_CONFIG_HOME="$home/.config" \
  RYOKU_PATH="$ROOT_DIR" \
  PATH="$ROOT_DIR/bin:$PATH" \
    bash "$migration" >/dev/null

  printf '%s\n' "$home/.config/ryoku/shell.json"
}

missing_config="$(run_migration missing '{}')"
jq -e '.general.apps.explorer == ["nautilus"]' "$missing_config" >/dev/null \
  || fail "Migration should set Nautilus when explorer config is missing"

stock_config="$(run_migration stock '{"general":{"apps":{"explorer":["thunar"]}}}')"
jq -e '.general.apps.explorer == ["nautilus"]' "$stock_config" >/dev/null \
  || fail "Migration should replace the old stock Thunar explorer"

string_stock_config="$(run_migration string-stock '{"general":{"apps":{"explorer":"thunar"}}}')"
jq -e '.general.apps.explorer == ["nautilus"]' "$string_stock_config" >/dev/null \
  || fail "Migration should replace malformed string Thunar explorer config"

custom_config="$(run_migration custom '{"general":{"apps":{"explorer":["dolphin"]}}}')"
jq -e '.general.apps.explorer == ["dolphin"]' "$custom_config" >/dev/null \
  || fail "Migration should preserve user-customized explorer commands"

echo "PASS: shell folder actions default to Nautilus"
