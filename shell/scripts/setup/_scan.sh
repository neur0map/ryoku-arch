#!/bin/bash
# Emit setup recipe metadata as a JSON array.

set -euo pipefail
shopt -s nullglob

dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
sep=""

printf '['
for f in "$dir"/*.sh; do
  base=${f##*/}
  base=${base%.sh}
  [[ $base == _* ]] && continue

  printf '%s' "$sep"
  awk -v slug="$base" '
    function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
    /^# @meta name:/        { sub(/^# @meta name:[[:space:]]*/, "");        n=$0 }
    /^# @meta description:/ { sub(/^# @meta description:[[:space:]]*/, ""); d=$0 }
    /^# @meta icon:/        { sub(/^# @meta icon:[[:space:]]*/, "");        i=$0 }
    /^# @meta keywords:/    { sub(/^# @meta keywords:[[:space:]]*/, "");    k=$0 }
    NR >= 60 { exit }
    END {
      printf "{\"slug\":\"%s\",\"name\":\"%s\",\"description\":\"%s\",\"icon\":\"%s\",\"keywords\":\"%s\"}",
        esc(slug), esc(n), esc(d), esc(i), esc(k)
    }
  ' "$f"
  sep=","
done
printf ']\n'
