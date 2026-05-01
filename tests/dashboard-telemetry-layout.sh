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

python3 - <<'PY' || fail "telemetry CPU header can overlap compact power control"
import pathlib
import re
import sys

rail = pathlib.Path("config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml").read_text()

cpu = re.search(r"// ── CPU.*?// ── Memory", rail, re.S)
if not cpu:
  print("missing CPU section", file=sys.stderr)
  sys.exit(1)

body = cpu.group(0)

advanced = re.search(r"Rectangle\s*\{\s*id:\s*advancedButton(.*?)Text\s*\{\s*id:\s*cpuPct", body, re.S)
if not advanced:
  print("missing advanced button block", file=sys.stderr)
  sys.exit(1)
advanced_body = advanced.group(1)
if not re.search(r"anchors\.right:\s*parent\.right", advanced_body, re.S):
  print("advanced button should sit on the right side of the telemetry header", file=sys.stderr)
  sys.exit(1)
if not re.search(r"id:\s*powerToggle.*?anchors\.left:\s*cpuPct\.right", body, re.S):
  print("power toggle should start after the CPU percentage", file=sys.stderr)
  sys.exit(1)
if not re.search(r"id:\s*powerToggle.*?anchors\.right:\s*parent\.right", body, re.S):
  print("power toggle should keep a fixed right edge inside the rail", file=sys.stderr)
  sys.exit(1)
if not re.search(r"id:\s*powerSaverLabel.*?elide:\s*Text\.ElideRight", body, re.S):
  print("power saver label should elide before colliding with the CPU percentage", file=sys.stderr)
  sys.exit(1)
if not re.search(r"id:\s*switchControl.*?anchors\.top:\s*powerSaverLabel\.bottom", body, re.S):
  print("power switch should sit below the label to keep the compact rail readable", file=sys.stderr)
  sys.exit(1)
if re.search(r"Row\s*\{\s*id:\s*powerToggle", body, re.S):
  print("power toggle should not use the old wide horizontal row", file=sys.stderr)
  sys.exit(1)
PY

pass "telemetry sections keep thermals and network separated"
