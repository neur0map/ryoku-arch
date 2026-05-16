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

  [[ ! -e $ROOT_DIR/$path ]] || fail "$path should not exist"
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
  assert_contains ".github/workflows/shellcheck.yml" 'shellcheck -x -s bash --severity=warning' \
    "ShellCheck workflow should keep Bash mode explicit and avoid info/style-only noise"
}

assert_pr_sensitive_path_alert() {
  assert_file ".github/workflows/pr-shell-script-alert.yml"
  assert_contains ".github/workflows/pr-shell-script-alert.yml" 'is_security_sensitive_path' \
    "PR alert workflow should keep a named security-sensitive path classifier"

  for pattern in \
    '\.github/\*' \
    '\.githooks/\*' \
    'bin/\*' \
    'install/\*' \
    'lib/\*' \
    'migrations/\*'; do
    assert_contains ".github/workflows/pr-shell-script-alert.yml" "$pattern" \
      "PR alert workflow should flag changes matching $pattern"
  done

  assert_contains ".github/workflows/pr-shell-script-alert.yml" 'security-sensitive path' \
    "PR alert workflow should explain why guarded path changes need review"
}

assert_woke_workflow() {
  assert_file ".woke.yml"
  assert_file ".github/workflows/inclusive-language.yml"
  assert_contains ".github/workflows/inclusive-language.yml" 'go install github\.com/get-woke/woke@v0\.19\.0' \
    "Inclusive language workflow should pin woke so rule updates do not create surprise failures"
  assert_contains ".github/workflows/inclusive-language.yml" 'woke-files\.txt' \
    "Inclusive language workflow should lint a collected file list"
  assert_contains ".woke.yml" 'iso/configs/airootfs/etc/modprobe\.d/\*\*' \
    "Inclusive language config should ignore technical modprobe blocklist directives"
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
  assert_not_contains ".github/workflows/qmllint.yml" 'max-warnings' \
    "QML lint workflow should stay compatible with Ubuntu's Qt 6.4 qmllint"
  assert_contains ".qmllint.ini" 'ImportFailure=disable' \
    "qmllint config should suppress missing Quickshell import noise"
  assert_contains ".qmllint.ini" 'UnknownProperty=disable' \
    "qmllint config should suppress old Qt missing-property noise"
  assert_not_contains ".github/workflows/qmllint.yml" '\*/qmldir\).*lint_all=true' \
    "QML lint workflow should not full-scan all 800+ QML files on metadata-only qmldir changes"
  assert_not_contains ".github/workflows/qmllint.yml" '\.qmllint\.ini\).*lint_all=true' \
    "QML lint workflow should keep config-only changes from forcing a full-shell scan"
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
  assert_contains ".github/workflows/build-iso.yml" 'var/cache/ryoku/nvim' \
    "ISO Trivy scan should skip offline Neovim plugin cache noise"
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
  assert_no_path "docs/media/showcase.mp4"
  assert_no_path "docs/media/showcase-poster.jpg"
  assert_contains "README.md" 'img\.youtube\.com/vi/u3rzJe3d49U/maxresdefault\.jpg' \
    "README should use the current YouTube showcase thumbnail"
  assert_contains "README.md" 'https://discord\.gg/8KjBmUEyKA' \
    "README should link to the Ryoku Discord"
  assert_contains "README.md" 'https://www\.reddit\.com/r/RyokuArch/' \
    "README should link to the Ryoku subreddit"
  assert_contains "migrations/1755867743.sh" 'assets/brand/logo\.txt' \
    "Historical logo migration should read the grouped ASCII logo"
  assert_contains "migrations/1755904244.sh" 'assets/brand/icon\.txt' \
    "Historical icon migration should read the grouped text icon"
  assert_file "VERSION"
  assert_no_path "shell/VERSION"
  assert_no_path "version"
  assert_contains "docs/maintenance.md" 'single tracked release version file' \
    "Maintenance docs should explain the canonical version file"
  assert_contains "docs/maintenance.md" 'root `VERSION`' \
    "Maintenance docs should point to root VERSION as canonical"
  assert_contains "bin/ryoku-version" 'VERSION' \
    "Ryoku version command should read the canonical shell version"
  assert_not_contains "bin/ryoku-version" 'shell/VERSION' \
    "Ryoku version command should not read the legacy shell version file"
  assert_contains "shell/services/ShellUpdates.qml" ':VERSION' \
    "Shell update UI should read the remote canonical shell version"
  assert_not_contains "shell/services/ShellUpdates.qml" ':shell/VERSION|/shell/VERSION' \
    "Shell update UI should not read the legacy shell version file"
}

assert_shellcheck_workflow
assert_pr_sensitive_path_alert
assert_woke_workflow
assert_qmllint_workflow
assert_trivy_noise_controls
assert_brand_assets_are_grouped
assert_root_docs_are_grouped
assert_asset_references_are_updated

echo "PASS: repo hygiene"
