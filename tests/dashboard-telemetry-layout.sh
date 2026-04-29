#!/bin/bash
# Static regression checks for fixed-height telemetry sections.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

rail="config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml"

[[ -f $rail ]] || fail "TelemetryRail.qml missing"

python3 - <<'PY' || fail "telemetry thermals/network sections can overflow"
import pathlib
import re
import sys

rail = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml").read_text()

def section(start, end):
  m = re.search(start + r"(.*?)" + end, rail, re.S)
  if not m:
    print(f"missing section between {start} and {end}", file=sys.stderr)
    sys.exit(1)
  return m.group(1)

thermals = section(r"// ── Thermals", r"// ── Network")
network = section(r"// ── Network", r"// ── GPU \+ Disk summary")

for name, body in (("Thermals", thermals), ("Network", network)):
  if re.search(r"Column\s*\{\s*anchors\.fill:\s*parent\s*spacing:\s*8", body, re.S):
    print(f"{name} still uses an overflowing filled column", file=sys.stderr)
    sys.exit(1)

if not re.search(r"text:\s*root\.fanSummary.*?anchors\.bottom:\s*parent\.bottom", thermals, re.S):
  print("fan summary should be anchored to the thermal section bottom", file=sys.stderr)
  sys.exit(1)

if not re.search(r"text:\s*net\.iface.*?anchors\.bottom:\s*parent\.bottom", network, re.S):
  print("network interface should be anchored to the network section bottom", file=sys.stderr)
  sys.exit(1)
PY

pass "telemetry sections keep thermals and network separated"
