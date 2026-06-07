pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Local mirror of the ryoku-extras catalogue (plugins + bundles). One refresh() git-pulls
// the whole repo, mirroring how LockThemes pulls qylock: a full clone the first time, then
// `pull --ff-only`. The Extras settings tab reads `bundles` from here, and the
// ryoku-extras-install command reads bundle.json from the same checkout.
Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME") || "/root"
  readonly property string dataDir: Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`
  readonly property string repoDir: `${dataDir}/ryoku-extras`
  readonly property string repoUrl: "https://github.com/neur0map/ryoku-extras"

  property var bundles: []
  property bool refreshing: false
  property string refreshError: ""
  property bool hasGit: false

  function rescan(): void {
    bundlesProc.running = true;
    gitCheckProc.running = true;
  }

  // Pull the catalogue so new bundles/plugins appear, then rescan. Best-effort: a network
  // failure leaves whatever is already on disk intact.
  function refresh(): void {
    if (root.refreshing)
      return;
    root.refreshing = true;
    refreshProc.running = true;
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

  Component.onCompleted: root.rescan()
}
