pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  signal monitorScreenshotReady(string monitorName, string path)
  signal captureReady()
  signal imageSaved(string path)
  signal errorOccurred(string message)
  signal windowListReady(var windows)

  property string tempPathBase: "/tmp/ryoku-shell/screenshot-freeze"
  property string lensPath: "/tmp/image.png"
  property string qrPath: "/tmp/ryoku-qr-capture.png"
  property string screenshotsDir: ""
  property string finalPath: ""
  property string captureMode: "normal"
  property string currentMode: "region"
  property int selectionX: 0
  property int selectionY: 0
  property int selectionW: 0
  property int selectionH: 0
  property int captureSerial: 0
  property bool freezing: false
  property string lastMonitorName: ""
  property var monitors: []
  property var windows: []

  property bool _initialized: false

  function initialize() {
    if (_initialized) return

    _initialized = true
    dirProcess.running = true
  }

  function startCapture(mode) {
    initialize()
    captureMode = mode || "normal"
    currentMode = "region"
    selectionX = 0
    selectionY = 0
    selectionW = 0
    selectionH = 0
    captureSerial++
    _mapScreens()
    captureReady()
    fetchWindows()
  }

  function cancelCapture() {
    freezing = false
    selectionW = 0
    selectionH = 0
    captureMode = "normal"
  }

  function _shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\"'\"'") + "'"
  }

  function _safeName(value) {
    return String(value).replace(/[^A-Za-z0-9_.-]/g, "_")
  }

  function _parentDir(value) {
    var path = String(value)
    var index = path.lastIndexOf("/")
    return index > 0 ? path.substring(0, index) : "."
  }

  function pathForMonitor(monitorName) {
    return tempPathBase + "_" + _safeName(monitorName) + ".png"
  }

  function _mapScreens() {
    var mapped = []
    var screens = Quickshell.screens

    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      mapped.push({
        name: s.name,
        x: s.x || 0,
        y: s.y || 0,
        width: s.width || 0,
        height: s.height || 0,
        scale: s.devicePixelRatio || s.scale || 1
      })
    }

    monitors = mapped
  }

  function freezeScreen() {
    if (freezing) return

    _mapScreens()
    if (monitors.length === 0) {
      errorOccurred("No monitors available for screenshot")
      return
    }

    freezing = true
    executeFreezeBatch()
  }

  function executeFreezeBatch() {
    var cmd = "mkdir -p /tmp/ryoku-shell && "

    for (var i = 0; i < monitors.length; i++) {
      var monitor = monitors[i]
      var path = pathForMonitor(monitor.name)
      cmd += "grim -o " + _shellQuote(monitor.name) + " " + _shellQuote(path) + " & "
    }

    cmd += "wait"

    freezeProcess.command = ["bash", "-c", cmd]
    freezeProcess.running = false
    freezeProcess.running = true
  }

  function fetchWindows() {
    clientsProcess.running = false
    clientsProcess.running = true
  }

  function _timestamp() {
    return Qt.formatDateTime(new Date(), "yyyy-MM-dd-hh-mm-ss")
  }

  function _targetPath() {
    if (captureMode === "lens") {
      finalPath = lensPath
      return finalPath
    }

    if (captureMode === "qr") {
      finalPath = qrPath
      return finalPath
    }

    var dir = screenshotsDir
    if (dir === "") dir = Quickshell.env("HOME") + "/Pictures/Screenshots"

    finalPath = dir + "/Screenshot_" + _timestamp() + ".png"
    return finalPath
  }

  function _monitorForRegion(x, y) {
    for (var i = 0; i < monitors.length; i++) {
      var monitor = monitors[i]
      var width = monitor.width
      var height = monitor.height
      if (x >= monitor.x && x < monitor.x + width && y >= monitor.y && y < monitor.y + height)
        return monitor
    }

    return monitors.length > 0 ? monitors[0] : null
  }

  function processRegion(x, y, w, h) {
    var monitor = _monitorForRegion(x, y)
    if (!monitor) {
      errorOccurred("No monitor found for screenshot region")
      return
    }

    var targetPath = _targetPath()
    var geometry = Math.round(x) + "," + Math.round(y) + " " + Math.round(w) + "x" + Math.round(h)
    var cmd = "mkdir -p " + _shellQuote(_parentDir(targetPath)) + " && " +
              "sleep 0.08; grim -g " + _shellQuote(geometry) + " " + _shellQuote(targetPath)

    lastMonitorName = monitor.name
    cropProcess.command = ["bash", "-c", cmd]
    cropProcess.running = false
    cropProcess.running = true
  }

  function processMonitorScreen(monitorName) {
    var targetPath = _targetPath()

    lastMonitorName = monitorName
    cropProcess.command = ["bash", "-c", "mkdir -p " + _shellQuote(_parentDir(targetPath)) + " && sleep 0.08; grim -o " + _shellQuote(monitorName) + " " + _shellQuote(targetPath)]
    cropProcess.running = false
    cropProcess.running = true
  }

  function openScreenshotsFolder() {
    var dir = screenshotsDir
    if (dir === "") dir = Quickshell.env("HOME") + "/Pictures/Screenshots"

    openFolderProcess.command = ["bash", "-c", "mkdir -p " + _shellQuote(dir) + " && xdg-open " + _shellQuote(dir)]
    openFolderProcess.running = false
    openFolderProcess.running = true
  }

  function _runPostCapture(command) {
    postCaptureProcess.running = false
    postCaptureProcess.command = command
    postCaptureProcess.running = true
  }

  function _finishCapture() {
    var mode = captureMode
    var path = finalPath

    if (mode === "lens") {
      _runPostCapture(["ryoku-cmd-google-lens", "--file", path])
      captureMode = "normal"
      return
    }

    if (mode === "qr") {
      _runPostCapture(["ryoku-cmd-qr-scan", "--file", path])
      captureMode = "normal"
      return
    }

    copyProcess.command = ["bash", "-c", "wl-copy --type image/png < " + _shellQuote(path)]
    copyProcess.running = false
    copyProcess.running = true
    imageSaved(path)
    captureMode = "normal"
  }

  property var dirProcess: Process {
    command: [
      "bash", "-c",
      "[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs; " +
      "if [[ -n ${RYOKU_SCREENSHOT_DIR:-} ]]; then printf '%s\\n' \"$RYOKU_SCREENSHOT_DIR\"; " +
      "else printf '%s\\n' \"${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots\"; fi"
    ]
    stdout: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) {
        var dir = stdout.text.trim()
        if (dir !== "") root.screenshotsDir = dir
      }
      ensureDirProcess.running = true
    }
  }

  property var ensureDirProcess: Process {
    command: ["bash", "-c", "mkdir -p " + root._shellQuote(root.screenshotsDir || (Quickshell.env("HOME") + "/Pictures/Screenshots"))]
    running: false
  }

  property var freezeProcess: Process {
    command: []
    running: false
    onExited: function(exitCode, exitStatus) {
      root.freezing = false
      if (exitCode !== 0) {
        root.errorOccurred("Failed to freeze screenshots with grim")
        return
      }

      for (var i = 0; i < root.monitors.length; i++)
        root.monitorScreenshotReady(root.monitors[i].name, root.pathForMonitor(root.monitors[i].name))
    }
  }

  property var clientsProcess: Process {
    command: ["bash", "-c", "hyprctl clients -j"]
    running: false
    stdout: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0) return

      try {
        var clients = JSON.parse(stdout.text)
        root.windows = clients.filter(function(client) {
          return client.mapped !== false && client.hidden !== true
        }).map(function(client) {
          return {
            title: client.title || "",
            app_id: client.class || client.initialClass || "",
            at: client.at || [0, 0],
            size: client.size || [0, 0],
            workspace: client.workspace || {}
          }
        })
        root.windowListReady(root.windows)
      } catch (e) {
        console.warn("ScreenshotService: failed to parse window list:", e.message)
      }
    }
  }

  property var cropProcess: Process {
    command: []
    running: false
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0) {
        root.errorOccurred("Failed to save screenshot")
        return
      }

      root._finishCapture()
    }
  }

  property var copyProcess: Process {
    command: []
    running: false
  }

  property var openFolderProcess: Process {
    command: []
    running: false
  }

  property var postCaptureProcess: Process {
    command: []
    running: false
    stderr: StdioCollector {}
    onExited: function(exitCode, exitStatus) {
      if (exitCode !== 0 && stderr.text.trim() !== "")
        console.warn("ScreenshotService post-capture:", stderr.text.trim())
    }
  }
}
