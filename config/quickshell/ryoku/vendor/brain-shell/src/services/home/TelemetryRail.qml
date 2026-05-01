import QtQuick
import Quickshell.Io
import "../../"
import "../../services/"

// Telemetry rail — wavy-line visualisation. Each metric's filled length
// encodes its value (0..1); the wavelength is fixed in pixels so longer
// fills naturally show more cycles. A passive phase animation keeps the
// lines breathing even when values are static.
//
// All numeric data uses JetBrains Mono to match ClockCard / PlayerCard /
// CalendarCard typography.
Item {
  id: root

  readonly property int railRadius:       Theme.cornerRadius + 6
  readonly property int contentMargin:    12
  readonly property int sectionSpacing:    9
  readonly property int cpuSectionH:      82
  readonly property int memorySectionH:   46
  readonly property int thermalsSectionH: 68
  readonly property int networkSectionH:  64
  readonly property int summarySectionH: Math.max(76,
    root.height - root.contentMargin * 2 - root.sectionSpacing * 4
    - root.cpuSectionH - root.memorySectionH
    - root.thermalsSectionH - root.networkSectionH)

  property real _upBps:   0
  property real _downBps: 0
  property real _netPeak: 65536
  property string activeDisplayName: "Display"
  property int currentDisplayRefreshHz: 0
  readonly property string displaySummary: root.currentDisplayRefreshHz > 0
    ? root.activeDisplayName + " · " + root.currentDisplayRefreshHz + " Hz"
    : root.activeDisplayName

  CpuService         { id: cpu;     active: root.visible }
  MemService         { id: mem;     active: root.visible }
  NetService         { id: net;     active: root.visible }
  ThermalService     { id: thermal; active: root.visible }
  DiskService        { id: disk;    active: root.visible }
  EnvyControlService { id: envy }
  CpuFreqService     { id: cpuFreq }
  GpuService {
    id:       gpu
    active:   root.visible
    envyMode: envy.currentMode
  }

  readonly property var rootDisk: {
    var list = disk.disks
    for (var i = 0; i < list.length; i++) {
      if (list[i].mount === "/") return list[i]
    }
    return list.length > 0 ? list[0] : null
  }

  readonly property bool   usingDgpu: gpu.dgpu.active
  readonly property string gpuLabel:  usingDgpu ? "dGPU" : "iGPU"
  readonly property string gpuValue:  usingDgpu
    ? (Math.round(gpu.dgpu.usagePercent) + "%  ·  " + gpu.dgpu.usedVram + " / " + gpu.dgpu.totalVram)
    : gpu.igpu.curMhz
  readonly property real gpuFill: usingDgpu
    ? Math.max(0, Math.min(1, gpu.dgpu.usagePercent / 100))
    : Math.max(0, Math.min(1, gpu.igpu.freqPercent / 100))

  readonly property string fanSummary: {
    if (thermal.fanCount === 0) return "Fans unavailable"
    if (thermal.fanCount === 1) return "Fan " + thermal.fan1Str
    return "Fans " + thermal.fan1Str + " / " + thermal.fan2Str
  }

  function _parseBps(text) {
    var m = text.match(/([0-9.]+)\s*([KMG]?B)\/s/)
    if (!m) return 0
    var n = parseFloat(m[1])
    var unit = m[2]
    if (unit === "GB") return n * 1024 * 1024 * 1024
    if (unit === "MB") return n * 1024 * 1024
    if (unit === "KB") return n * 1024
    return n
  }

  function _tempColor(t) {
    if (t >= 85) return "#f38ba8"
    if (t >= 70) return "#f5c47a"
    if (t >= 60) return "#fab387"
    return "#8bd5ca"
  }

  Process {
    id: displayRead
    command: ["hyprctl", "monitors", "-j"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var mons = JSON.parse(text)
          if (!mons || mons.length === 0) return

          var mon = mons[0]
          for (var i = 0; i < mons.length; i++) {
            if (mons[i].focused) {
              mon = mons[i]
              break
            }
          }

          root.activeDisplayName = mon.name || "Display"
          root.currentDisplayRefreshHz = Math.round(mon.refreshRate || 0)
        } catch (e) {
        }
      }
    }
  }

  Process {
    id: advancedLauncher
    command: ["ryoku-launch-tui", "btop"]
    running: false
  }

  Connections {
    target: PowerProfile
    function onDisplayRefreshGenerationChanged() {
      displayRead.running = false
      displayRead.running = true
    }
  }

  Timer {
    interval: 1000
    running:  root.visible
    repeat:   true
    onTriggered: {
      root._upBps   = root._parseBps(net.upSpeed)
      root._downBps = root._parseBps(net.downSpeed)
      root._netPeak = Math.max(65536, root._upBps, root._downBps, root._netPeak * 0.92)
    }
  }

  Timer {
    interval: 2000
    running: root.visible
    repeat: true
    onTriggered: {
      displayRead.running = false
      displayRead.running = true
    }
  }

  Component.onCompleted: displayRead.running = true

  component RailDivider: Rectangle {
    height: 1
    color:  Qt.rgba(1, 1, 1, 0.07)
  }

  component SectionHeader: Item {
    id: header

    property string title: ""
    property string value: ""
    property color valueColor: Qt.rgba(1, 1, 1, 0.56)

    height: 14

    Text {
      anchors.left:           parent.left
      anchors.verticalCenter: parent.verticalCenter
      text:                   header.title
      font.pixelSize:         10
      font.weight:            Font.DemiBold
      color:                  Qt.rgba(1, 1, 1, 0.42)
    }

    Text {
      anchors.right:          parent.right
      anchors.verticalCenter: parent.verticalCenter
      text:                   header.value
      font.pixelSize:         9
      font.family:            "JetBrains Mono"
      font.weight:            Font.DemiBold
      color:                  header.valueColor
      visible:                header.value !== ""
    }
  }

  component MetricLine: Item {
    id: line

    property string label: ""
    property string value: ""
    property real fill: 0
    property color accent: Theme.active
    property color labelColor: Qt.rgba(1, 1, 1, 0.46)
    property color valueColor: Qt.rgba(1, 1, 1, 0.68)
    property int labelWidth: 34
    property int valueWidth: 58
    property int valueSize: 10
    property bool showWave: true

    height: 18

    Text {
      anchors.left:           parent.left
      anchors.verticalCenter: parent.verticalCenter
      width:                  line.labelWidth
      elide:                  Text.ElideRight
      text:                   line.label
      font.pixelSize:         10
      font.weight:            Font.DemiBold
      color:                  line.labelColor
    }

    WaveBar {
      visible:                line.showWave
      anchors.left:           parent.left
      anchors.leftMargin:     line.labelWidth
      anchors.right:          valueText.left
      anchors.rightMargin:    8
      anchors.verticalCenter: parent.verticalCenter
      value:                  Math.max(0, Math.min(1, line.fill))
      color:                  line.accent
      wavelength:             12
      amplitude:              2
      strokeWidth:            2
    }

    Text {
      id:                     valueText
      anchors.right:          parent.right
      anchors.verticalCenter: parent.verticalCenter
      width:                  line.valueWidth
      horizontalAlignment:    Text.AlignRight
      elide:                  Text.ElideRight
      text:                   line.value
      font.pixelSize:         line.valueSize
      font.family:            "JetBrains Mono"
      color:                  line.valueColor
    }
  }

  component InfoLine: Item {
    id: line

    property string label: ""
    property string value: ""
    property color valueColor: Qt.rgba(1, 1, 1, 0.58)

    height: 16

    Text {
      anchors.left:           parent.left
      anchors.verticalCenter: parent.verticalCenter
      width:                  46
      elide:                  Text.ElideRight
      text:                   line.label
      font.pixelSize:         9
      font.weight:            Font.DemiBold
      color:                  Qt.rgba(1, 1, 1, 0.34)
    }

    Text {
      anchors.left:           parent.left
      anchors.leftMargin:     52
      anchors.right:          parent.right
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment:    Text.AlignRight
      elide:                  Text.ElideRight
      text:                   line.value
      font.pixelSize:         9
      font.family:            "JetBrains Mono"
      color:                  line.valueColor
    }
  }

  Rectangle {
    anchors.fill: parent
    radius:       root.railRadius
    gradient: Gradient {
      GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, 0.08) }
      GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.04) }
      GradientStop { position: 1.0;  color: Qt.rgba(1, 1, 1, 0.06) }
    }
    border.color: Qt.rgba(1, 1, 1, 0.10)
    border.width: 1
  }

  Rectangle {
    anchors.fill: parent
    radius:       root.railRadius
    color:        Qt.rgba(8/255, 12/255, 18/255, 0.55)
  }

  Column {
    anchors {
      fill:    parent
      margins: root.contentMargin
    }
    spacing: root.sectionSpacing

    Item {
      width:  parent.width
      height: root.cpuSectionH

      Text {
        id: telemetryLabel
        anchors.left: parent.left
        anchors.top:  parent.top
        text:           "Telemetry"
        font.pixelSize: 11
        font.weight:    Font.DemiBold
        color:          Qt.rgba(1, 1, 1, 0.44)
      }

      Item {
        id: advancedButton
        anchors.right:          parent.right
        anchors.verticalCenter: telemetryLabel.verticalCenter
        width:                  58
        height:                 16

        Text {
          anchors.right:          parent.right
          anchors.verticalCenter: parent.verticalCenter
          text:                   "Advanced"
          font.pixelSize:         9
          font.weight:            Font.DemiBold
          color: advancedHit.containsMouse
            ? Theme.active
            : Qt.rgba(1, 1, 1, 0.52)
        }

        Rectangle {
          anchors.left:   parent.left
          anchors.right:  parent.right
          anchors.bottom: parent.bottom
          height:         1
          color:          Theme.active
          opacity:        advancedHit.containsMouse ? 0.55 : 0

          Behavior on opacity {
            enabled: !Theme.staticMode
            NumberAnimation { duration: 120 }
          }
        }

        MouseArea {
          id: advancedHit
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            advancedLauncher.running = false
            advancedLauncher.running = true
            Popups.closeAll()
          }
        }
      }

      Text {
        id: cpuLabel
        anchors.left:      parent.left
        anchors.top:       parent.top
        anchors.topMargin: 23
        text:              "CPU"
        font.pixelSize:    10
        font.weight:       Font.DemiBold
        color:             Qt.rgba(1, 1, 1, 0.46)
      }

      Text {
        anchors.left:      parent.left
        anchors.top:       cpuLabel.bottom
        anchors.topMargin: 2
        text:              cpuFreq.curFreqStr
        font.pixelSize:    9
        font.family:       "JetBrains Mono"
        color:             Qt.rgba(1, 1, 1, 0.45)
      }

      Text {
        id: cpuPct
        anchors.right:     parent.right
        anchors.top:       parent.top
        anchors.topMargin: 17
        text:              Math.round(cpu.usagePercent) + "%"
        font.pixelSize:    27
        font.weight:       Font.Bold
        font.family:       "JetBrains Mono"
        font.letterSpacing: 0
        color:             Theme.active
      }

      WaveBar {
        anchors.left:   parent.left
        anchors.right:  parent.right
        y:              52
        value:          Math.max(0, Math.min(1, cpu.usagePercent / 100))
        color:          Theme.active
        wavelength:     15
        amplitude:      2.5
        strokeWidth:    2
      }

      Item {
        id: powerToggle
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         18

        readonly property bool savingOn: PowerProfile.mode === "powersave"

        Text {
          anchors.left:           parent.left
          anchors.verticalCenter: parent.verticalCenter
          text:                   "Saver"
          font.pixelSize:         9
          font.weight:            Font.DemiBold
          color:                  Qt.rgba(1, 1, 1, 0.38)
        }

        Text {
          anchors.right:          switchControl.left
          anchors.rightMargin:    7
          anchors.verticalCenter: parent.verticalCenter
          text:                   powerToggle.savingOn ? "on" : "off"
          font.pixelSize:         9
          font.family:            "JetBrains Mono"
          color: powerToggle.savingOn
            ? Theme.active
            : Qt.rgba(1, 1, 1, 0.42)
        }

        Item {
          id: switchControl
          anchors.right:          parent.right
          anchors.verticalCenter: parent.verticalCenter
          width:                  32
          height:                 16

          Rectangle {
            anchors.fill: parent
            radius:       height / 2
            color: powerToggle.savingOn
              ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45)
              : Qt.rgba(1, 1, 1, 0.11)
            border.color: powerToggle.savingOn
              ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.80)
              : Qt.rgba(1, 1, 1, 0.25)
            border.width: 1

            Behavior on color {
              enabled: !Theme.staticMode
              ColorAnimation { duration: 160 }
            }
            Behavior on border.color {
              enabled: !Theme.staticMode
              ColorAnimation { duration: 160 }
            }
          }

          Rectangle {
            width:  parent.height - 4
            height: parent.height - 4
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: powerToggle.savingOn ? parent.width - width - 2 : 2
            color: powerToggle.savingOn ? "#ffffff" : Qt.rgba(1, 1, 1, 0.58)

            Behavior on x {
              enabled: !Theme.staticMode
              NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on color {
              enabled: !Theme.staticMode
              ColorAnimation { duration: 160 }
            }
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: PowerProfile.toggle()
          }
        }
      }
    }

    Item {
      width:  parent.width
      height: root.memorySectionH

      RailDivider {
        anchors.left:  parent.left
        anchors.right: parent.right
      }

      SectionHeader {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             7
        title:         "Memory"
        value:         mem.usedStr + " / " + mem.totalStr
      }

      MetricLine {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             26
        label:         "RAM"
        value:         Math.round(mem.usagePercent) + "%"
        fill:          mem.usagePercent / 100
        accent:        "#cba6f7"
        labelWidth:    34
        valueWidth:    42
        valueColor:    "#cba6f7"
      }
    }

    Item {
      width:  parent.width
      height: root.thermalsSectionH

      RailDivider {
        anchors.left:  parent.left
        anchors.right: parent.right
      }

      SectionHeader {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             7
        title:         "Thermals"
      }

      MetricLine {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             24
        height:        16
        label:         "CPU"
        value:         thermal.cpuTempStr
        fill:          thermal.cpuTemp / 100
        accent:        root._tempColor(thermal.cpuTemp)
        labelWidth:    32
        valueWidth:    42
      }

      MetricLine {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             40
        height:        16
        label:         "GPU"
        value:         root.usingDgpu ? thermal.gpuTempStr : "idle"
        fill:          thermal.gpuTemp / 100
        accent:        root._tempColor(thermal.gpuTemp)
        labelWidth:    32
        valueWidth:    42
        valueColor:    root.usingDgpu ? Qt.rgba(1, 1, 1, 0.68) : Qt.rgba(1, 1, 1, 0.42)
      }

      Text {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        elide:          Text.ElideRight
        text:           root.fanSummary
        font.pixelSize: 8
        font.family:    "JetBrains Mono"
        color:          Qt.rgba(1, 1, 1, 0.34)
      }
    }

    Item {
      width:  parent.width
      height: root.networkSectionH

      RailDivider {
        anchors.left:  parent.left
        anchors.right: parent.right
      }

      SectionHeader {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             7
        title:         "Network"
      }

      MetricLine {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             24
        height:        16
        label:         "UP"
        value:         net.upSpeed
        fill:          root._upBps / root._netPeak
        accent:        "#90ef90"
        labelColor:    "#90ef90"
        labelWidth:    40
        valueWidth:    56
      }

      MetricLine {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             40
        height:        16
        label:         "DOWN"
        value:         net.downSpeed
        fill:          root._downBps / root._netPeak
        accent:        "#a6d0f7"
        labelColor:    "#a6d0f7"
        labelWidth:    40
        valueWidth:    56
      }

      Text {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        elide:          Text.ElideRight
        text:           net.iface !== "—" ? ("Interface  " + net.iface) : "Interface unavailable"
        font.pixelSize: 8
        font.family:    "JetBrains Mono"
        color:          Qt.rgba(1, 1, 1, 0.34)
      }
    }

    Item {
      width:  parent.width
      height: root.summarySectionH

      RailDivider {
        anchors.left:  parent.left
        anchors.right: parent.right
      }

      SectionHeader {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             7
        title:         "System"
      }

      MetricLine {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             26
        label:         root.gpuLabel
        value:         root.gpuValue
        fill:          root.gpuFill
        accent:        root.usingDgpu ? "#a6e3a1" : Qt.rgba(1, 1, 1, 0.35)
        labelWidth:    34
        valueWidth:    82
        valueColor:    root.usingDgpu ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(1, 1, 1, 0.42)
      }

      MetricLine {
        anchors.left:  parent.left
        anchors.right: parent.right
        y:             45
        visible:       root.rootDisk !== null
        label:         root.rootDisk ? ("Disk " + root.rootDisk.mount) : "Disk"
        value:         root.rootDisk ? (root.rootDisk.usedStr + " / " + root.rootDisk.totalStr) : "—"
        fill:          root.rootDisk ? root.rootDisk.usedPct / 100 : 0
        accent:        root.rootDisk && root.rootDisk.usedPct >= 85 ? "#f38ba8" : Theme.active
        labelWidth:    46
        valueWidth:    82
      }

      InfoLine {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        label:          "Display"
        value:          root.displaySummary
      }
    }
  }
}
