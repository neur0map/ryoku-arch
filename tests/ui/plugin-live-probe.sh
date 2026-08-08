#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
work="$(mktemp -d)"
shell_pid=""
server_pid=""
cleanup() {
    [ -z "$shell_pid" ] || kill "$shell_pid" 2>/dev/null || true
    [ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true
    rm -rf "$work"
}
trap cleanup EXIT

mkdir -p "$work/bin" "$work/catalogue/plugins/fixture/content" \
    "$work/catalogue/plugins/fixture/service" "$work/catalogue/plugins/fixture/shared" \
    "$work/widgets/Singletons" "$work/shell/quickshell/plugins" \
    "$work/config" "$work/data" "$work/state" "$work/cache"
cp "$repo/ryoku/shell/quickshell/widgets/PluginDesktopSlot.qml" "$work/widgets/"
cp "$repo/ryoku/shell/quickshell/widgets/PluginObjectSlot.qml" "$work/widgets/"
cp -a "$repo/ryoku/shell/quickshell/widgets/Singletons/." "$work/widgets/Singletons/"
cp "$repo/ryoku/shell/quickshell/plugins/discover.sh" "$work/shell/quickshell/plugins/"
cp "$repo/ryoku/shell/quickshell/plugins/ryoku-plugins-place" "$work/bin/"
cp "$here/plugin-live-probe.qml" "$work/probe.qml"
(
    cd "$repo/ryoku/apps/ryostore/backend"
    go build -o "$work/bin/ryostore" .
)

write_product() {
    python3 - "$work/catalogue" "$1" "$2" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
version = sys.argv[2]
marker = sys.argv[3]
product = root / "plugins" / "fixture"
files = {
    "manifest.json": json.dumps({
        "id": "fixture",
        "name": "Fixture",
        "version": version,
        "entryPoints": {"main": "service/Main.qml", "content": "content/Widget.qml"},
        "defaults": {"host": "desktopWidget"},
    }, separators=(",", ":")) + "\n",
    "service/Main.qml": """import QtQuick\nimport \"../shared/Markers.js\" as Markers\nQtObject { property var pluginApi; property string marker: Markers.service }\n""",
    "content/Widget.qml": """import QtQuick\nimport \"../shared/Markers.js\" as Markers\nItem { property var pluginApi; property string density: \"full\"; property real s: 1; property real widthBudget: 240; property bool active: true; property string marker: Markers.content; implicitWidth: 160; implicitHeight: 80 }\n""",
    "shared/Markers.js": f".pragma library\nvar service = \"service-{marker}\";\nvar content = \"content-{marker}\";\n",
}
for relative, content in files.items():
    path = product / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
manifest = {
    "schema": 1,
    "id": "fixture",
    "category": "plugins",
    "version": version,
    "destination": "ryoku/plugins/fixture",
    "files": [],
}
for relative in sorted(files):
    raw = (product / relative).read_bytes()
    manifest["files"].append({
        "source": relative,
        "destination": relative,
        "sha256": hashlib.sha256(raw).hexdigest(),
        "mode": "0644",
        "size": len(raw),
        "install": True,
    })
manifest_raw = (json.dumps(manifest, separators=(",", ":")) + "\n").encode()
(product / "product-manifest.json").write_bytes(manifest_raw)
entry = {
    "id": "fixture",
    "name": "Fixture",
    "version": version,
    "path": "plugins/fixture",
    "author": "Ryoku Team",
    "summary": "Live fixture",
    "description": "Exercises receipt-published plugin updates.",
    "tags": ["test"],
    "screenshots": [],
    "accent": "#112233",
    "surface": "#101010",
    "preview": "assets/preview.webp",
    "manifest": "product-manifest.json",
    "manifestSha256": hashlib.sha256(manifest_raw).hexdigest(),
    "official": True,
    "tagline": "Live fixture",
    "icon": "test",
    "hosts": ["desktopWidget"],
    "lastUpdated": "2026-08-02T00:00:00Z",
}
(root / "plugins" / "registry.json").write_text(
    json.dumps({"schema": 1, "plugins": [entry]}, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
PY
}

port_file="$work/port"
python3 - "$work/catalogue" "$port_file" <<'PY' &
import http.server
import os
import sys
from pathlib import Path

os.chdir(sys.argv[1])
server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), http.server.SimpleHTTPRequestHandler)
Path(sys.argv[2]).write_text(str(server.server_address[1]), encoding="utf-8")
server.serve_forever()
PY
server_pid=$!
for _ in $(seq 1 200); do
    [ -s "$port_file" ] && break
    sleep 0.025
done
[ -s "$port_file" ]
base="http://127.0.0.1:$(cat "$port_file")"

run_store() {
    HOME="$work" XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
    XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache" \
    RYOKU_EXTRAS_BASE="$base" PATH="$work/bin:$PATH" "$work/bin/ryostore" "$@"
}
run_place() {
    HOME="$work" XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
    XDG_STATE_HOME="$work/state" PATH="$work/bin:$PATH" \
    "$work/bin/ryoku-plugins-place" "$@"
}
wait_for() {
    local marker="$1"
    for _ in $(seq 1 300); do
        grep -q "$marker" "$work/log" 2>/dev/null && return 0
        sleep 0.025
    done
    return 1
}

write_product 1.0.0 v1
run_store install plugins fixture
jq -e '.fixture.enabled == false' "$work/config/ryoku/plugins.json" >/dev/null
run_place fixture enabled true
run_place fixture settings '{"label":"mine"}'

RYOKU_SHELL_DIR="$work/shell" \
HOME="$work" XDG_CONFIG_HOME="$work/config" XDG_DATA_HOME="$work/data" \
XDG_STATE_HOME="$work/state" XDG_CACHE_HOME="$work/cache" \
QML_IMPORT_PATH="$repo/ryoku/shell/quickshell:${QML_IMPORT_PATH:-$work/.local/lib/qt6/qml}" \
QT_QPA_PLATFORM=offscreen timeout 30 qs -p "$work/probe.qml" >"$work/log" 2>&1 &
shell_pid=$!
original_pid=$shell_pid
wait_for 'PLUGIN-LIVE-MARKER:service-v1:content-v1' || { cat "$work/log"; exit 1; }

write_product 2.0.0 v2
run_store install plugins fixture
kill -0 "$original_pid"
wait_for 'PLUGIN-LIVE-MARKER:service-v2:content-v2' || { cat "$work/log"; exit 1; }

run_store remove plugins fixture
kill -0 "$original_pid"
wait_for 'PLUGIN-LIVE-REMOVED' || { cat "$work/log"; exit 1; }
wait "$shell_pid"
shell_pid=""

jq -e '.fixture.enabled == true and .fixture.host == "desktopWidget" and .fixture.settings.label == "mine"' \
    "$work/config/ryoku/plugins.json" >/dev/null
jq -e '.revision == 3 and .category == "plugins" and .operation == "remove"' \
    "$work/state/ryoku/store/revision.json" >/dev/null
jq -e 'length == 0' "$work/state/ryoku/store/plugins.json" >/dev/null
grep -Eq ' ERROR|TypeError|ReferenceError' "$work/log" && { cat "$work/log"; exit 1; }
echo "plugin-live-probe: real v1 -> v2 nested dependencies -> remove in shell pid $original_pid"
