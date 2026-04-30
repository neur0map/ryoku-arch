pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  property var fontModel: ListModel {}
  property var filteredModel: ListModel {}

  property string currentFont: ""
  property string searchQuery: ""
  property string statusText: ""
  property bool loading: false
  property bool applying: false
  property string pendingFamily: ""
  property string pendingId: ""

  function refresh() {
    if (listProc.running) return

    root.loading = true
    root.statusText = ""
    root.fontModel.clear()
    root.filteredModel.clear()
    listProc.command = [
      Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
      "font", "list", "--jsonl"
    ]
    listProc.running = true
  }

  function itemLabel(item) {
    if (item.display && item.display !== "") return item.display
    if (item.family && item.family !== "") return item.family
    return ""
  }

  function updateFilteredModel() {
    var q = root.searchQuery.toLowerCase()
    var rows = []

    for (var i = 0; i < root.fontModel.count; i++) {
      var item = root.fontModel.get(i)
      var label = root.itemLabel(item)
      var family = item.family || ""

      if (item.active) root.currentFont = family
      if (q !== ""
          && label.toLowerCase().indexOf(q) === -1
          && family.toLowerCase().indexOf(q) === -1) {
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

  function setActiveFont(family) {
    root.currentFont = family

    for (var i = 0; i < root.fontModel.count; i++) {
      root.fontModel.setProperty(i, "active", root.fontModel.get(i).family === family)
      if (root.fontModel.get(i).family === family) {
        root.fontModel.setProperty(i, "installed", true)
      }
    }

    root.updateFilteredModel()
  }

  function applyItem(item) {
    if (root.applying || !item) return

    root.applying = true
    root.statusText = ""
    root.pendingFamily = item.family || ""
    root.pendingId = item.fontId || ""

    if (item.installed) {
      applyProc.command = [
        Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
        "font", "apply", root.pendingFamily
      ]
    } else {
      applyProc.command = [
        Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
        "font", "install", root.pendingId
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
          root.fontModel.append(JSON.parse(t))
        } catch(e) {
          root.statusText = "Could not parse fonts"
        }
      }
    }

    onExited: function(exitCode, exitStatus) {
      root.loading = false
      if (exitCode !== 0) root.statusText = "Could not load fonts"
      root.updateFilteredModel()
    }
  }

  property var applyProc: Process {
    onExited: function(exitCode, exitStatus) {
      root.applying = false
      if (exitCode === 0) {
        root.setActiveFont(root.pendingFamily)
      } else {
        root.statusText = "Could not apply font"
      }
      root.pendingFamily = ""
      root.pendingId = ""
    }
  }

  onSearchQueryChanged: updateFilteredModel()
}
