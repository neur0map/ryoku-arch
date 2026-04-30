pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  property var themeModel: ListModel {}
  property var filteredModel: ListModel {}

  property string currentTheme: ""
  property string searchQuery: ""
  property string statusText: ""
  property bool loading: false
  property bool applying: false
  property string pendingTheme: ""

  function refresh() {
    if (listProc.running) return

    root.loading = true
    root.statusText = ""
    root.themeModel.clear()
    root.filteredModel.clear()
    listProc.command = [
      Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
      "theme", "list", "--jsonl"
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

    for (var i = 0; i < root.themeModel.count; i++) {
      var item = root.themeModel.get(i)
      var label = root.itemLabel(item)
      var name = item.name || ""

      if (item.active) root.currentTheme = name
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
      return root.itemLabel(a).localeCompare(root.itemLabel(b))
    })

    root.filteredModel.clear()
    for (var j = 0; j < rows.length; j++) {
      root.filteredModel.append(rows[j])
    }
  }

  function setActiveTheme(name) {
    root.currentTheme = name

    for (var i = 0; i < root.themeModel.count; i++) {
      root.themeModel.setProperty(i, "active", root.themeModel.get(i).name === name)
    }

    root.updateFilteredModel()
  }

  function applyItem(item) {
    if (root.applying || !item || !item.name || item.name === "") return

    root.applying = true
    root.statusText = ""
    root.pendingTheme = item.name
    applyProc.command = [
      Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
      "theme", "apply", item.name
    ]
    applyProc.running = true
  }

  property var listProc: Process {
    stdout: SplitParser {
      onRead: function(line) {
        var t = line.trim()
        if (t === "") return

        try {
          root.themeModel.append(JSON.parse(t))
        } catch(e) {
          root.statusText = "Could not parse themes"
        }
      }
    }

    onExited: function(exitCode, exitStatus) {
      root.loading = false
      if (exitCode !== 0) root.statusText = "Could not load themes"
      root.updateFilteredModel()
    }
  }

  property var applyProc: Process {
    onExited: function(exitCode, exitStatus) {
      root.applying = false
      if (exitCode === 0) {
        root.setActiveTheme(root.pendingTheme)
      } else {
        root.statusText = "Could not apply theme"
      }
      root.pendingTheme = ""
    }
  }

  onSearchQueryChanged: updateFilteredModel()
}
