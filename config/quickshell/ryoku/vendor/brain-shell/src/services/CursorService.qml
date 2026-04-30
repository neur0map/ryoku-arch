pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  property var cursorModel: ListModel {}
  property var filteredModel: ListModel {}

  property string currentCursor: ""
  property string searchQuery: ""
  property string statusText: ""
  property bool loading: false
  property bool applying: false
  property string pendingName: ""

  function refresh() {
    if (listProc.running) return

    root.loading = true
    root.statusText = ""
    root.cursorModel.clear()
    root.filteredModel.clear()
    listProc.command = [
      Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
      "cursor", "list", "--jsonl"
    ]
    listProc.running = true
  }

  function itemLabel(item) {
    if (item.display && item.display !== "") return item.display
    if (item.name && item.name !== "") return item.name
    return ""
  }

  function updateFilteredModel() {
    var q = root.searchQuery.toLowerCase()
    var rows = []

    for (var i = 0; i < root.cursorModel.count; i++) {
      var item = root.cursorModel.get(i)
      var label = root.itemLabel(item)
      var name = item.name || ""

      if (item.active) root.currentCursor = name
      if (q !== ""
          && label.toLowerCase().indexOf(q) === -1
          && name.toLowerCase().indexOf(q) === -1) {
        continue
      }

      rows.push(item)
    }

    rows.sort(function(a, b) {
      if (a.active && !b.active) return -1
      if (!a.active && b.active) return 1
      if (a.installed && !b.installed) return -1
      if (!a.installed && b.installed) return 1
      if (a.source === "curated" && b.source !== "curated") return -1
      if (a.source !== "curated" && b.source === "curated") return 1
      return root.itemLabel(a).localeCompare(root.itemLabel(b))
    })

    root.filteredModel.clear()
    for (var j = 0; j < rows.length; j++) {
      root.filteredModel.append(rows[j])
    }
  }

  function setActiveCursor(name) {
    root.currentCursor = name

    for (var i = 0; i < root.cursorModel.count; i++) {
      root.cursorModel.setProperty(i, "active", root.cursorModel.get(i).name === name)
      if (root.cursorModel.get(i).name === name) {
        root.cursorModel.setProperty(i, "installed", true)
      }
    }

    root.updateFilteredModel()
  }

  function applyItem(item) {
    if (root.applying || !item || !item.name || item.name === "") return

    root.applying = true
    root.statusText = ""
    root.pendingName = item.name

    if (item.installed) {
      applyProc.command = [
        Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
        "cursor", "apply", root.pendingName, "24"
      ]
    } else {
      applyProc.command = [
        Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
        "cursor", "install", root.pendingName, "24"
      ]
    }
    applyProc.running = true
  }

  property var listProc: Process {
    stdout: SplitParser {
      onRead: function(line) {
        var t = line.trim()
        if (t === "") return

        try {
          root.cursorModel.append(JSON.parse(t))
        } catch(e) {
          root.statusText = "Could not parse cursors"
        }
      }
    }

    onExited: function(exitCode, exitStatus) {
      root.loading = false
      if (exitCode !== 0) root.statusText = "Could not load cursors"
      root.updateFilteredModel()
    }
  }

  property var applyProc: Process {
    onExited: function(exitCode, exitStatus) {
      root.applying = false
      if (exitCode === 0) {
        root.setActiveCursor(root.pendingName)
      } else {
        root.statusText = "Could not apply cursor"
      }
      root.pendingName = ""
    }
  }

  onSearchQueryChanged: updateFilteredModel()
}
