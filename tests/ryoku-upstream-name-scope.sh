#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
upstream_token='i''nir'

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

is_allowed_path() {
  local path="$1"

  case "$path" in
    *.md|docs/*|shell/docs/*|logs/*|plans/*)
      return 0
      ;;
    shell/modules/settings/About.qml|shell/modules/waffle/settings/pages/WAboutPage.qml)
      return 0
      ;;
  esac

  return 1
}

has_runtime_reference() {
  local file="$1"

  grep -IvE '^[[:space:]]*(#|//|/\*|\*|<!--)' "$file" \
    | grep -Iiq -- "$upstream_token"
}

mapfile -d '' files < <(
  cd "$ROOT_DIR"
  git ls-files -z --cached --others --exclude-standard
)

violations=()
for file in "${files[@]}"; do
  [[ -f "$ROOT_DIR/$file" ]] || continue
  is_allowed_path "$file" && continue
  if has_runtime_reference "$ROOT_DIR/$file"; then
    violations+=("$file")
  fi
done

if (( ${#violations[@]} > 0 )); then
  printf 'Upstream product name is only allowed in docs, comments, and Settings About files.\n' >&2
  printf 'Unexpected runtime references:\n' >&2
  printf '  %s\n' "${violations[@]}" >&2
  fail "upstream product name scope regression"
fi

echo "PASS: upstream product name scope stays limited"
