#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_no_path() {
  local path="$1"

  [[ ! -e $ROOT_DIR/$path ]] || fail "$path should not live at the repo root"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

assert_shellcheck_workflow() {
  assert_file ".github/workflows/shellcheck.yml"
  assert_contains ".github/workflows/shellcheck.yml" 'before == "0000000000000000000000000000000000000000"' \
    "ShellCheck workflow should handle initial push events without a bogus diff"
  assert_not_contains ".github/workflows/shellcheck.yml" '\|install/\*' \
    "ShellCheck workflow should not lint install package-list data as shell"
  assert_contains ".github/workflows/shellcheck.yml" 'shellcheck -x -s bash' \
    "ShellCheck workflow should keep Bash mode explicit"
}

assert_woke_workflow() {
  assert_file ".woke.yml"
  assert_file ".github/workflows/inclusive-language.yml"
  assert_contains ".github/workflows/inclusive-language.yml" 'go install github\.com/get-woke/woke@v0\.19\.0' \
    "Inclusive language workflow should pin woke so rule updates do not create surprise failures"
  assert_contains ".github/workflows/inclusive-language.yml" 'woke-files\.txt' \
    "Inclusive language workflow should lint a collected file list"
  assert_contains ".woke.yml" 'iso/configs/airootfs/etc/modprobe\.d/\*\*' \
    "Inclusive language config should ignore technical modprobe blacklist directives"
  assert_not_contains ".github/workflows/inclusive-language.yml" 'config/\*\|default/\*\|install/\*' \
    "Inclusive language workflow should not use broad directory globs that pick up binary or package-list files"
}

assert_qmllint_workflow() {
  assert_file ".qmllint.ini"
  assert_file ".github/workflows/qmllint.yml"
  assert_contains ".github/workflows/qmllint.yml" 'qt6-declarative-dev' \
    "QML lint workflow should install Qt declarative tooling"
  assert_contains ".github/workflows/qmllint.yml" 'QMLLINT_BIN' \
    "QML lint workflow should resolve the official qmllint binary"
  assert_contains ".github/workflows/qmllint.yml" 'qmllint-files\.txt' \
    "QML lint workflow should lint a collected file list"
  assert_contains ".github/workflows/qmllint.yml" '\$import_root/qs' \
    "QML lint workflow should expose shell/ as qs imports"
  assert_contains ".qmllint.ini" 'ImportFailure=disable' \
    "qmllint config should suppress missing Quickshell import noise"
  assert_not_contains ".github/workflows/qmllint.yml" '\*/qmldir\).*lint_all=true' \
    "QML lint workflow should not full-scan all 800+ QML files on metadata-only qmldir changes"
}

assert_trivy_noise_controls() {
  assert_file ".github/workflows/trivy.yml"
  assert_contains ".github/workflows/trivy.yml" 'shell/docs' \
    "Trivy source scan should skip inherited shell docs"
  assert_contains ".github/workflows/trivy.yml" 'shell/sdata' \
    "Trivy source scan should skip shell data caches and generated metadata"
  assert_contains ".github/workflows/trivy.yml" 'iso/release' \
    "Trivy source scan should skip local ISO build artifacts"
  assert_contains ".github/workflows/build-iso.yml" 'var/cache/ryoku/mirror/offline' \
    "ISO Trivy scan should skip offline package cache noise"
  assert_contains ".github/workflows/build-iso.yml" 'root/ryoku/\.git' \
    "ISO Trivy scan should skip bundled git history"
  assert_contains ".github/workflows/build-iso.yml" 'root/ryoku/shell/docs' \
    "ISO Trivy scan should skip inherited shell documentation"
}

assert_brand_assets_are_grouped() {
  local asset

  for asset in icon.png icon.txt logo-mark.png logo-mark.svg logo.svg logo.txt dark.png light.png; do
    assert_file "assets/brand/$asset"
    assert_no_path "$asset"
  done

  assert_no_path "logo"
}

assert_root_docs_are_grouped() {
  assert_file "docs/TODO.md"
  assert_no_path "todo.md"
}

assert_asset_references_are_updated() {
  assert_contains "README.md" 'assets/brand/logo-mark\.png' \
    "README should render the grouped brand mark"
  assert_contains "docs.json" '/assets/brand/logo\.svg' \
    "Docs config should use the grouped favicon"
  assert_contains "docs.json" '/assets/brand/light\.png' \
    "Docs config should use the grouped light logo"
  assert_contains "docs.json" '/assets/brand/dark\.png' \
    "Docs config should use the grouped dark logo"
  assert_contains "install/helpers/presentation.sh" 'assets/brand/logo\.txt' \
    "Presentation helper should read the grouped ASCII logo"
  assert_contains "install/config/branding.sh" 'assets/brand/icon\.txt' \
    "Branding installer should copy the grouped text icon"
  assert_contains "install/config/ryoku-shell-branding.sh" 'assets/brand/logo-mark\.svg' \
    "Shell branding installer should copy the grouped SVG mark"
  assert_contains "bin/ryoku-show-logo" 'assets/brand/logo\.txt' \
    "Logo display command should read the grouped ASCII logo"
  assert_contains "install/post-install/finished.sh" 'assets/brand/logo\.txt' \
    "Post-install finished screen should read the grouped ASCII logo"
  assert_contains "migrations/1755867743.sh" 'assets/brand/logo\.txt' \
    "Historical logo migration should read the grouped ASCII logo"
  assert_contains "migrations/1755904244.sh" 'assets/brand/icon\.txt' \
    "Historical icon migration should read the grouped text icon"
  assert_contains "docs/maintenance.md" 'root `version`' \
    "Maintenance docs should explain why the root version file remains"
  assert_contains "docs/maintenance.md" '`shell/VERSION`' \
    "Maintenance docs should explain why shell/VERSION remains"
}

assert_shellcheck_workflow
assert_woke_workflow
assert_qmllint_workflow
assert_trivy_noise_controls
assert_brand_assets_are_grouped
assert_root_docs_are_grouped
assert_asset_references_are_updated

echo "PASS: repo hygiene"
