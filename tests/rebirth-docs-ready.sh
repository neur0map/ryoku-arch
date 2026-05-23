#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

doc_roots=(
  AGENTS.md
  README.md
  CHANGELOG.md
  CREDITS.md
  CONTRIBUTING.md
  index.mdx
  docs
  logs
  distro
)

doc_files=()
for root in "${doc_roots[@]}"; do
  [[ -e $root ]] || continue

  if [[ -d $root ]]; then
    while IFS= read -r file; do
      doc_files+=("$file")
    # Skip makepkg working dirs (src/, pkg/) under distro/arch/* - those hold
    # untracked upstream source tarballs whose READMEs mention unrelated names
    # (e.g. cava-ryoku's vendored cava README has a "CelestialWalrus" contributor)
    # and would trip the blocked-term scan with false positives.
    done < <(rg --files --hidden --no-ignore \
      --glob '!distro/arch/*/src/**' \
      --glob '!distro/arch/*/pkg/**' \
      "$root" | rg '\.(md|mdx)$' || true)
  elif [[ $root == *.md || $root == *.mdx ]]; then
    doc_files+=("$root")
  fi
done

if (( ${#doc_files[@]} == 0 )); then
  echo "No documentation files found"
  exit 1
fi

# CREDITS.md is the one file where upstream-project names (Caelestia, etc.)
# MUST appear - it exists to attribute the rebirth shell's heritage. Drop it
# from the scan; the blocked-terms guard targets user-facing docs that should
# read as Ryoku-native, not the attribution file itself.
filtered=()
for f in "${doc_files[@]}"; do
  case "$f" in
    CREDITS.md | */CREDITS.md) continue ;;
  esac
  filtered+=("$f")
done
doc_files=("${filtered[@]}")

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
