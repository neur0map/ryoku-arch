pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Local mirror of the ryoku-extras catalogue plus the install orchestration the
// Settings -> Extras tab drives.
//
// refresh() git-pulls the whole repo (full clone first time, then pull --ff-only),
// rescan() reloads bundles and re-detects what is already present. Installs run
// through ryoku-extras-install inside a floating terminal so the sudo/yay prompt
// has a TTY; the command writes a per-item JSON report to reportPath, which this
// service watches (FileView + a poll fallback for long AUR builds) to drive the
// per-item loader / success / failure state in the UI - mirroring how
// PluginService.installingPlugins drives the Plugins tab.
Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME") || "/root"
  readonly property string dataDir: Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`
  readonly property string repoDir: `${dataDir}/ryoku-extras`
  readonly property string repoUrl: "https://github.com/neur0map/ryoku-extras"
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  readonly property string reportPath: `${runtimeDir}/ryoku/extras-install.json`

  property var bundles: []
  property bool refreshing: false
  property string refreshError: ""
  property bool hasGit: false

  // Per-item state, keyed by item name (names are unique across the curated
  // catalogue). Only package/script items flow through here; plugin items are
  // handled by PluginService in the UI, exactly like the Plugins tab.
  property var presence: ({})   // { name: bool }   - already installed?
  property var installing: ({}) // { name: true }   - terminal install in flight
  property var results: ({})    // { name: { status, error } } - last install run
  property bool busy: false
  property double launchTs: 0
  property int pollCount: 0

  function rescan(): void {
    bundlesProc.running = true;
    gitCheckProc.running = true;
    detectProc.running = true;
  }

  // Pull the catalogue so new bundles/plugins appear, then rescan. Best-effort: a
  // network failure leaves whatever is already on disk intact.
  function refresh(): void {
    if (root.refreshing)
      return;
    root.refreshing = true;
    refreshProc.running = true;
  }

  function _setInstalling(names, on) {
    var m = Object.assign({}, root.installing);
    for (var i = 0; i < names.length; i++) {
      if (on)
        m[names[i]] = true;
      else
        delete m[names[i]];
    }
    root.installing = m;
  }

  function _pkgScriptNames(items) {
    var out = [];
    for (var i = 0; i < (items || []).length; i++)
      if (items[i].type === "package" || items[i].type === "script")
        out.push(items[i].name);
    return out;
  }

  function _launch(args, names) {
    root.launchTs = Date.now() / 1000;
    root.pollCount = 0;
    _setInstalling(names, true);
    root.busy = true;
    launchProc.command = ["ryoku-launch-floating-terminal-with-presentation", "ryoku-extras-install"].concat(args).concat(["--report", root.reportPath]);
    launchProc.running = true;
    pollTimer.restart();
  }

  // Install every package/script item in a bundle. Returns false when busy or when
  // the bundle has nothing this path installs (e.g. plugin-only bundles).
  function installBundle(id): bool {
    if (root.busy)
      return false;
    var b = null;
    for (var i = 0; i < root.bundles.length; i++)
      if (root.bundles[i].id === id) {
        b = root.bundles[i];
        break;
      }
    if (!b)
      return false;
    var names = _pkgScriptNames(b.items);
    if (names.length === 0)
      return false;
    _launch(["bundle", id], names);
    return true;
  }

  // Install a single package/script item. Plugins are not installed here.
  function installItem(type, name): bool {
    if (root.busy || type === "plugin")
      return false;
    _launch(["item", type, name], [name]);
    return true;
  }

  // Remove the installed package items of a bundle (scripts/plugins are not
  // auto-removed here). Returns false when busy or nothing is removable.
  function uninstallBundle(id): bool {
    if (root.busy)
      return false;
    var b = null;
    for (var i = 0; i < root.bundles.length; i++)
      if (root.bundles[i].id === id) {
        b = root.bundles[i];
        break;
      }
    if (!b)
      return false;
    var names = _pkgScriptNames(b.items);
    if (names.length === 0)
      return false;
    _launch(["uninstall", "bundle", id], names);
    return true;
  }

  // Remove a single package item. Plugins are not handled here.
  function uninstallItem(type, name): bool {
    if (root.busy || type === "plugin")
      return false;
    _launch(["uninstall", "item", type, name], [name]);
    return true;
  }

  function _applyReport(txt) {
    var data;
    try {
      data = JSON.parse(txt);
    } catch (e) {
      return;
    }
    if (!data || !data.items)
      return;
    // Ignore the initial/leftover report until we have launched something this
    // session, and ignore reports older than the current run.
    if (root.launchTs <= 0 || (data.ts || 0) < Math.floor(root.launchTs))
      return;

    var res = Object.assign({}, root.results);
    var inst = Object.assign({}, root.installing);
    for (var i = 0; i < data.items.length; i++) {
      var it = data.items[i];
      res[it.name] = {
        "status": it.status,
        "error": it.error || ""
      };
      delete inst[it.name];
    }
    root.results = res;
    root.installing = inst;
    root.busy = false;
    pollTimer.stop();
    detectProc.running = true; // re-confirm what is now present
  }

  Process {
    id: bundlesProc
    command: ["sh", "-c", `
      repo="${root.repoDir}"
      reg="$repo/bundles/registry.json"
      if [ ! -f "$reg" ]; then echo '{"bundles":[]}'; exit 0; fi
      jq -c '.bundles[]' "$reg" 2>/dev/null | while IFS= read -r b; do
        path=$(printf '%s' "$b" | jq -r '.path // ("bundles/" + .id)')
        items=$(jq -c '.items // []' "$repo/$path/bundle.json" 2>/dev/null || printf '[]')
        printf '%s' "$b" | jq -c --argjson items "$items" '. + {items: $items}'
      done | jq -s -c '{bundles: .}'
    `]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.bundles = JSON.parse(text).bundles || [];
        } catch (e) {
          root.bundles = [];
        }
      }
    }
  }

  Process {
    id: detectProc
    command: ["ryoku-extras-install", "status", "all"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.presence = JSON.parse(text) || ({});
        } catch (e) {
          root.presence = ({});
        }
      }
    }
  }

  Process {
    id: gitCheckProc
    command: ["sh", "-c", `[ -d "${root.repoDir}/.git" ] && echo 1 || echo 0`]
    stdout: StdioCollector {
      onStreamFinished: root.hasGit = (text.trim() === "1")
    }
  }

  Process {
    id: refreshProc
    command: ["sh", "-c", `
      repo="${root.repoDir}"
      mkdir -p "$(dirname "$repo")"
      err=""
      if [ -d "$repo/.git" ]; then
        git -C "$repo" pull --ff-only >/dev/null 2>&1 || err="update failed"
      else
        tmp=$(mktemp -d) || { echo "no temp dir" >&2; exit 1; }
        if git clone --depth=1 "${root.repoUrl}" "$tmp/ryoku-extras" >/dev/null 2>&1; then
          rm -rf "$repo"
          mv "$tmp/ryoku-extras" "$repo"
        else
          err="download failed"
          rm -rf "$tmp"
        fi
      fi
      [ -z "$err" ] || { echo "$err" >&2; exit 3; }
    `]
    onExited: function (exitCode) {
      root.refreshing = false;
      root.refreshError = (exitCode === 0) ? "" : "Refresh failed - check your connection and try again.";
      root.rescan();
    }
  }

  // Fire-and-forget: the launcher setsid-detaches the terminal, so completion is
  // observed through the report file, not this process exit.
  Process {
    id: launchProc
  }

  // Primary completion signal. The CLI writes the report atomically (mktemp+mv),
  // which the watcher catches; the poll below is a fallback while busy.
  FileView {
    id: reportView
    path: root.reportPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root._applyReport(text())
  }

  Timer {
    id: pollTimer
    interval: 4000
    repeat: true
    onTriggered: {
      reportView.reload();
      detectProc.running = true;
      root.pollCount++;
      if (root.pollCount > 225) {
        // ~15 min cap: assume the terminal was closed/cancelled and reset.
        root.busy = false;
        root.installing = ({});
        stop();
      }
    }
  }

  Component.onCompleted: root.rescan()
}
