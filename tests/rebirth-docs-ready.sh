#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

doc_files=()
while IFS= read -r doc_file; do
  [[ -f $doc_file ]] || continue
  doc_files+=("$doc_file")
done < <(
  git ls-files '*.md' '*.mdx' \
    ':!:CREDITS.md' \
    ':!:docs/_archive/**' \
    ':!:distro/arch/*/src/**' \
    ':!:distro/arch/*/pkg/**' \
    ':!:shell/noctalia/ATTRIBUTION.md'
)

if (( ${#doc_files[@]} == 0 )); then
  echo "No tracked documentation files found"
  exit 1
fi

blocked_terms=(
  "cae""lestia"
  "ce""lestia"
  "in""ir"
  "ni""ri"
  "noc""talia"
)

blocked_pattern=$(IFS='|'; echo "${blocked_terms[*]}")

set +e
matches=$(rg -n -i -- "$blocked_pattern" "${doc_files[@]}" 2>&1)
status=$?
set -e

if (( status == 0 )); then
  echo "Retired shell/compositor references remain in documentation:"
  echo "$matches"
  exit 1
fi

if (( status > 1 )); then
  echo "$matches"
  exit "$status"
fi

echo "Documentation is clear of retired shell/compositor references"
