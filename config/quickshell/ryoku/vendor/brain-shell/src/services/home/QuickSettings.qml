import Quickshell
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "../../"
import "../../components"
import "../"

// Right column — brightness slider + scrollable quick-settings grid.

StatCard {
    id: root
    padding: 0

    // ─────────────────────────────────────────────────────────────────────────
    //  Brightness
    // ─────────────────────────────────────────────────────────────────────────
    property real _brightVal:  0.72
    property int  _brightMax:  100
    property bool _brightBusy: false

    Process {
        id: brightRead; command: ["bash", "-c", "brightnessctl -m"]; running: false
        stdout: SplitParser {
            onRead: function(line) {
                var p = line.split(",")
                if (p.length >= 5) {
                    var cur = parseInt(p[2]); var max = parseInt(p[4])
                    if (max > 0) { root._brightMax = max; root._brightVal = cur / max }
                }
            }
        }
    }
    Process {
        id: brightWrite
        command: ["bash", "-c", "brightnessctl set " +
            (Math.round(root._brightVal * root._brightMax) <= 0
             ? 2 : Math.round(root._brightVal * root._brightMax))]
        running: false
        onRunningChanged: if (!running) root._brightBusy = false
    }
    Timer { id: brightDebounce; interval: 50; repeat: false
        onTriggered: { root._brightBusy = true; brightWrite.running = true } }
    Timer { interval: 1000; running: true; repeat: true
        onTriggered: if (!root._brightBusy) brightRead.running = true }
    function _setBright(v) {
        root._brightVal = Math.max(0.0, Math.min(1.0, v))
        brightDebounce.restart()
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Wi-Fi
    // ─────────────────────────────────────────────────────────────────────────
    property bool   wifiOn:   false
    property string wifiSSID: ""

    Process { id: wifiRadioRead; command: ["bash", "-c", "nmcli radio wifi"]; running: false
        stdout: SplitParser { onRead: function(l) {
            root.wifiOn = l.trim() === "enabled"
            // Expose to ShellState — suppressed while hotspot owns the interface
            ShellState.wifiOn = root.wifiOn && !ShellState.hotspot
        } } }
    Process { id: wifiSSIDRead
        command: ["bash", "-c",
            "nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | head -1 | cut -d: -f2"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.wifiSSID = l.trim() } } }
    Process { id: wifiToggleProc; command: []; running: false
        onRunningChanged: if (!running) _wifiPoll() }
    function _wifiPoll() {
        wifiRadioRead.running = false; wifiRadioRead.running = true
        wifiSSIDRead.running  = false; wifiSSIDRead.running  = true
    }
    function _wifiToggle() {
        // Do not allow wifi toggle while hotspot is using the interface
        if (root.hotspotOn || root.hotspotBusy) return
        root.wifiOn = !root.wifiOn           // optimistic — tile updates now
        ShellState.wifiOn = root.wifiOn
        wifiToggleProc.command = ["bash", "-c",
            "nmcli radio wifi " + (root.wifiOn ? "on" : "off")]
        wifiToggleProc.running = false
        wifiToggleProc.running = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Bluetooth
    // ─────────────────────────────────────────────────────────────────────────
    property bool   btOn:     false
    property string btDevice: ""

    Process { id: btPowerRead
        command: ["bash", "-c",
            "bluetoothctl show 2>/dev/null | grep '^\\s*Powered:' | awk '{print $2}'"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.btOn = l.trim() === "yes" } } }
    Process { id: btDeviceRead
        command: ["bash", "-c",
            "bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-"]
        running: false
        stdout: SplitParser { onRead: function(l) { root.btDevice = l.trim() } } }
    Process { id: btToggleProc; command: []; running: false
        onRunningChanged: if (!running) {
            _btPoll()
            ShellState.btPowered = root.btOn
            if (!root.btOn) ShellState.btConnected = false
        }
    }        
    function _btPoll() {
        btPowerRead.running  = false; btPowerRead.running  = true
        btDeviceRead.running = false; btDeviceRead.running = true
    }
    function _btToggle() {
        var turningOn = !root.btOn
        root.btOn = turningOn                // optimistic
        // Mirror to ShellState immediately so Network.qml bar icon reacts
        ShellState.btPowered = turningOn
        if (!turningOn) ShellState.btConnected = false

        btToggleProc.command = ["bash", "-c",
            "bluetoothctl power " + (turningOn ? "on" : "off")]
        btToggleProc.running = false
        btToggleProc.running = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Night Light  (hyprsunset)
    // ─────────────────────────────────────────────────────────────────────────
    property bool nightLightOn: false

    Process { id: nlCheck; command: ["bash", "-c", "pgrep -x hyprsunset"]; running: false
        stdout: SplitParser { onRead: function(l) { if (l.trim() !== "") root.nightLightOn = true } } }
    Process { id: nlProc; command: ["hyprsunset", "-t", "5600"]; running: false }
    Process { id: nlKill; command: ["bash", "-c", "pkill hyprsunset"]; running: false }
    function _nightLightToggle() {
        if (root.nightLightOn) {
            nlProc.running = false; nlKill.running = false; nlKill.running = true
            root.nightLightOn = false
        } else { nlProc.running = true; root.nightLightOn = true }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Caffeine  (systemd-inhibit)
    // ─────────────────────────────────────────────────────────────────────────
    property bool caffeineOn: false

    Process { id: caffeineCheck
        command: ["bash", "-c", "pgrep -f 'systemd-inhibit.*Caffeine'"]; running: false
        stdout: SplitParser { onRead: function(l) { if (l.trim() !== "") root.caffeineOn = true } } }
    Process { id: caffeineProc
        command: ["systemd-inhibit","--what=idle:sleep",
                  "--who=Brain Shell","--why=Caffeine mode","sleep","infinity"]
        running: false }
    Process { id: caffeineKill
        command: ["bash", "-c", "pkill -f 'systemd-inhibit.*Caffeine'"]; running: false
        onRunningChanged: if (!running) root.caffeineOn = false }
    function _caffeineToggle() {
        if (root.caffeineOn) {
            caffeineProc.running = false
            caffeineKill.running = false; caffeineKill.running = true
        } else { caffeineProc.running = true; root.caffeineOn = true }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Do Not Disturb
    // ─────────────────────────────────────────────────────────────────────────
    function _dndToggle() {
        ShellState.dnd = !ShellState.dnd
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Hotspot — direct toggle; requires ethernet connection
    // ─────────────────────────────────────────────────────────────────────────
    property bool   hotspotOn:     false
    property bool   hotspotBusy:   false
    property bool   _hsWifiWasOff: false  // wifi radio was off when hotspot started; restore on stop
    property string hotspotLabel:  ""    // sublabel: "Active" | "Not on ethernet" | ""
    property string _hsSSID:       "BrainShell"
    property string _hsPassword:   "changeme1"
    property string _hsWifiIface:  "wlan0"

    readonly property string _hsCfgPath:
        Quickshell.shellDir + "/src/user_data/hotspot.json"

    // Load config on startup
    Process {
        id: hsCfgLoadProc
        command: ["bash", "-c",
            "[ -f '" + root._hsCfgPath + "' ] || " +
            "(mkdir -p \"$(dirname '" + root._hsCfgPath + "')\" && " +
            "printf '%s' '{\"ssid\":\"BrainShell\",\"password\":\"changeme1\"}' > '" + root._hsCfgPath + "'); " +
            "cat '" + root._hsCfgPath + "'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(text.trim())
                    if (o.ssid)     root._hsSSID     = o.ssid
                    if (o.password) root._hsPassword = o.password
                } catch(e) {}
            }
        }
    }

    // Detect WiFi interface name
    Process {
        id: hsIfaceProc
        command: ["bash", "-c",
            "nmcli -g DEVICE,TYPE dev 2>/dev/null | awk -F: '$2==\"wifi\"{print $1; exit}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var n = text.trim()
                if (n !== "") root._hsWifiIface = n
            }
        }
    }

    // Check if ethernet is connected
    Process {
        id: hsEthernetCheck
        command: ["bash", "-c",
            "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c 'ethernet:connected'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var hasEth = parseInt(text.trim()) > 0
                if (!hasEth) {
                    root.hotspotLabel = "Not on ethernet"
                    root.hotspotBusy  = false
                    return
                }
                // Remember whether wifi radio was off so we can restore it on stop
                root._hsWifiWasOff = !root.wifiOn
                // Ethernet confirmed — start hotspot
                root._hsDoStart()
            }
        }
    }

    // Check hotspot status
    Process {
        id: hotspotCheck
        command: ["bash", "-c",
            "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c 'wifi:connected'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                // If WiFi device shows 'connected' in AP mode that's our hotspot
                // Cross-check with ap-like connection
                hsActiveCheckProc.running = false; hsActiveCheckProc.running = true
            }
        }
    }

    Process {
        id: hsActiveCheckProc
        command: ["bash", "-c",
            "nmcli -t -f NAME,STATE,DEVICE con show --active 2>/dev/null" +
            " | awk -F: '$1~/[Hh]otspot/{found=1} END{print found+0}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.hotspotOn     = parseInt(text.trim()) > 0
                ShellState.hotspot = root.hotspotOn
                root.hotspotLabel  = root.hotspotOn ? "Active" : ""
                // WiFi interface is owned by hotspot — suppress from ShellState
                if (root.hotspotOn) ShellState.wifiOn = false
            }
        }
    }

    // Start hotspot
    Process {
        id: hsStartProc
        command: []
        running: false
        stderr: StdioCollector { id: hsStartErr }
        onRunningChanged: if (!running) {
            root.hotspotBusy = false
            // Re-check actual state after nmcli exits
            hsActiveCheckProc.running = false; hsActiveCheckProc.running = true
        }
        onExited: function(code, status) {
            if (code === 0) {
                root.hotspotOn     = true
                root.hotspotLabel  = "Active"
                ShellState.hotspot = true
                // WiFi interface now owned by hotspot
                ShellState.wifiOn  = false
            } else {
                root.hotspotOn    = false
                root.hotspotLabel = "Failed"
                ShellState.hotspot = false
                hsLabelResetTimer.restart()
            }
        }
    }

    // Stop hotspot
    Process {
        id: hsStopProc
        // Disconnect by interface — works regardless of what nmcli named the connection
        command: ["bash", "-c",
            "nmcli device disconnect " + root._hsWifiIface + " 2>/dev/null; " +
            "nmcli con delete BrainShellHotspot 2>/dev/null; true"]
        running: false
        onRunningChanged: if (!running) {
            root.hotspotBusy   = false
            root.hotspotOn     = false
            ShellState.hotspot = false
            if (root._hsWifiWasOff) {
                // Wifi radio was off before hotspot started — restore that state.
                // Turn the radio back off so the interface cycle is clean.
                root.wifiOn       = false
                ShellState.wifiOn = false
                wifiToggleProc.command = ["bash", "-c", "nmcli radio wifi off"]
                wifiToggleProc.running = false
                wifiToggleProc.running = true
                root._hsWifiWasOff = false
            } else {
                // Radio was already on — just re-expose wifi state and re-poll for SSID
                ShellState.wifiOn = root.wifiOn
                _wifiPoll()
            }
        }
    }

    Timer { id: hsLabelResetTimer; interval: 3000; repeat: false
        onTriggered: { if (root.hotspotLabel === "Failed") root.hotspotLabel = "" } }

    // Ethernet disconnect watcher — runs during polling when hotspot is active
    Process {
        id: hsEthernetLiveCheck
        command: ["bash", "-c",
            "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c 'ethernet:connected'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.hotspotOn || root.hotspotBusy) return
                var hasEth = parseInt(text.trim()) > 0
                if (!hasEth) {
                    // Ethernet lost — tear down hotspot automatically
                    root.hotspotLabel = "Ethernet lost"
                    root.hotspotBusy  = true
                    // Rebuild stop command with current iface before running
                    hsStopProc.command = ["bash", "-c",
                        "nmcli device disconnect " + root._hsWifiIface + " 2>/dev/null; " +
                        "nmcli con delete BrainShellHotspot 2>/dev/null; true"]
                    hsStopProc.running = false; hsStopProc.running = true
                    hsLabelResetTimer.restart()
                }
            }
        }
    }

    function _hsDoStart() {
        var ssid = root._hsSSID
        var pass = root._hsPassword
        var iface = root._hsWifiIface
        hsStartProc.command = ["bash", "-c",
            // Silently bring the wifi radio up if it was off (ethernet-only scenario).
            // nmcli needs the radio enabled before it can create an AP connection.
            "nmcli radio wifi on 2>/dev/null; " +
            "sleep 1; " +
            // Disconnect whatever is currently on the interface 
            "nmcli device disconnect \"" + iface + "\" 2>/dev/null; " +
            "nmcli con delete BrainShellHotspot 2>/dev/null; " +
            "nmcli device wifi hotspot " +
                "ifname \"" + iface + "\" " +
                "ssid \"" + ssid + "\" " +
                "password \"" + pass + "\" " +
                "con-name BrainShellHotspot 2>&1"]
        hsStartProc.running = false; hsStartProc.running = true
    }

    function _hotspotToggle() {
        if (root.hotspotBusy) return
        if (root.hotspotOn) {
            root.hotspotBusy  = true
            root.hotspotLabel = ""
            // Rebuild with current iface (detected after startup)
            hsStopProc.command = ["bash", "-c",
                "nmcli device disconnect \"" + root._hsWifiIface + "\" 2>/dev/null; " +
                "nmcli con delete BrainShellHotspot 2>/dev/null; true"]
            hsStopProc.running = false; hsStopProc.running = true
        } else {
            root.hotspotBusy  = true
            root.hotspotLabel = ""
            // Check ethernet first, then start
            hsEthernetCheck.running = false; hsEthernetCheck.running = true
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Airplane Mode  (rfkill)
    // ─────────────────────────────────────────────────────────────────────────
    property bool airplaneOn: false

    Process { id: airplaneCheck
        command: ["bash", "-c",
            // Airplane = ALL radios soft-blocked.
            // nmcli radio wifi off blocks only wifi via rfkill — not bluetooth/wwan.
            // So count devices that are NOT blocked; if zero, airplane mode is on.
            "notBlocked=$(rfkill list all 2>/dev/null | grep -c 'Soft blocked: no');" +
            " total=$(rfkill list all 2>/dev/null | grep -c 'Soft blocked:');" +
            " [ \"$total\" -gt 0 ] && [ \"$notBlocked\" -eq 0 ] && echo yes || echo no"]
        running: false
        stdout: SplitParser {
            onRead: function(l) { root.airplaneOn = l.trim() === "yes" }
        }
    }
    Process { id: airplaneOn_proc
        command: ["bash", "-c", "rfkill block all"]; running: false
        onRunningChanged: if (!running) root.airplaneOn = true }
    Process { id: airplaneOff_proc
        command: ["bash", "-c", "rfkill unblock all"]; running: false
        onRunningChanged: if (!running) root.airplaneOn = false }
    function _airplaneToggle() {
        if (root.airplaneOn) {
            airplaneOff_proc.running = false; airplaneOff_proc.running = true
        } else {
            airplaneOn_proc.running = false; airplaneOn_proc.running = true
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Focus Mode  (hyprctl gaps)
    // ─────────────────────────────────────────────────────────────────────────
    property int _savedGapsIn: 5; property int _savedGapsOut: 10

    Process { id: readGapsIn
        command: ["bash", "-c",
            "hyprctl getoption general:gaps_in -j | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('int',5))\""]
        running: false
        stdout: SplitParser { onRead: function(l) { var v=parseInt(l.trim()); if(!isNaN(v)) root._savedGapsIn=v } }
        onRunningChanged: if (!running) readGapsOut.running = true }
    Process { id: readGapsOut
        command: ["bash", "-c",
            "hyprctl getoption general:gaps_out -j | python3 -c \"import sys,json; d=json.load(sys.stdin); print(d.get('int',10))\""]
        running: false
        stdout: SplitParser { onRead: function(l) { var v=parseInt(l.trim()); if(!isNaN(v)) root._savedGapsOut=v } }
        onRunningChanged: if (!running) applyFocusGaps.running = true }
    Process { id: applyFocusGaps
        command: ["bash", "-c",
            "hyprctl keyword general:gaps_in 0 && hyprctl keyword general:gaps_out 10"]
        running: false; onRunningChanged: if (!running) ShellState.focusMode = true }
    Process { id: restoreGaps; command: []; running: false
        onRunningChanged: if (!running) ShellState.focusMode = false }
    function _focusToggle() {
        if (ShellState.focusMode) {
            restoreGaps.command = ["bash", "-c",
                "hyprctl keyword general:gaps_in "  + root._savedGapsIn  +
                " && hyprctl keyword general:gaps_out " + root._savedGapsOut]
            restoreGaps.running = false; restoreGaps.running = true
        } else { readGapsIn.running = false; readGapsIn.running = true }
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Filter  (hyprshade)
    //
    //  Tile click: runs `hyprshade ls`, opens picker popup above the tile.
    //  Picker has "Off" at top + all available shaders.
    //  Selecting a shader: `hyprshade on <name>` and stores in currentFilter.
    //  Selecting the active shader or "Off": `hyprshade off`, clears currentFilter.
    // ─────────────────────────────────────────────────────────────────────────
    property string currentFilter:    ""
    property var    filterList:       []
    property bool   filterPickerOpen: false

    // Read the actual active shader from Hyprland on startup and after wallpaper change.
    // Hyprland stores the full path; normalize to the stem (filename without extension)
    // so it matches what hyprshade ls returns, enabling correct picker highlighting.
    Process {
        id: filterCheckProc
        command: ["bash", "-c",
            "hyprctl getoption decoration:screen_shader -j 2>/dev/null" +
            " | python3 -c \"" +
            "import sys,json,os;" +
            "d=json.load(sys.stdin);" +
            "s=d.get('str','').strip();" +
            "print('' if s in ('','[[EMPTY]]') else os.path.splitext(os.path.basename(s))[0])\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.currentFilter = text.trim()
            }
        }
    }

    Process {
        id: filterApplyProc
        command: []
        running: false
        // Re-check confirmed state after apply — hyprshade may normalise the name differently
        onRunningChanged: if (!running) {
            filterCheckProc.running = false
            filterCheckProc.running = true
        }
    }

    function _filterApply(name) {
        var turningOff = (name === "" || name === root.currentFilter)
        filterApplyProc.command = turningOff
            ? ["hyprshade", "off"]
            : ["hyprshade", "on", name]
        // Optimistic update — confirmed by filterCheckProc after proc exits
        root.currentFilter  = turningOff ? "" : name
        filterApplyProc.running = false
        filterApplyProc.running = true
        root.filterPickerOpen   = false
    }

    // Wallpaper change resets the shader — re-check actual state
    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) {
            filterCheckProc.running = false
            filterCheckProc.running = true
        }
    }

    // Close filter picker when dashboard closes
    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (!Popups.dashboardOpen) root.filterPickerOpen = false
        }
    }

    Process {
        id: filterListProc
        command: ["hyprshade", "ls"]
        running: false
        stdout: SplitParser {
            onRead: function(l) {
                var n = l.trim()
                if (n !== "") root.filterList = root.filterList.concat([n])
            }
        }
    }

    function _filterOpen() {
        root.filterList = []
        filterListProc.running = false
        filterListProc.running = true
        root.filterPickerOpen  = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  Polling timer
    // ─────────────────────────────────────────────────────────────────────────
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            _wifiPoll(); _btPoll()
            hsActiveCheckProc.running = false; hsActiveCheckProc.running = true
            airplaneCheck.running = false; airplaneCheck.running = true
            // Monitor ethernet while hotspot is active
            if (root.hotspotOn && !root.hotspotBusy) {
                hsEthernetLiveCheck.running = false; hsEthernetLiveCheck.running = true
            }
        }
    }

    Component.onCompleted: {
        brightRead.running      = true
        _wifiPoll(); _btPoll()
        nlCheck.running         = true
        caffeineCheck.running   = true
        hotspotCheck.running    = true
        airplaneCheck.running   = true
        filterCheckProc.running = true
        hsCfgLoadProc.running   = true
        hsIfaceProc.running     = true
        hsActiveCheckProc.running = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    //  UI
    // ─────────────────────────────────────────────────────────────────────────
    Column {
        anchors { fill: parent; margins: 12 }
        spacing: 0

        // ── Brightness ────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 52

            Text {
                id: brightLbl
                anchors { left: parent.left; top: parent.top }
                text: "BRIGHTNESS"; font.pixelSize: 9; font.weight: Font.Bold
                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
            }
            Text {
                anchors { right: parent.right; top: parent.top }
                text: Math.round(root._brightVal * 100) + "%"
                font.pixelSize: 9; font.family: "JetBrains Mono"; font.weight: Font.Bold
                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.7)
            }

            Row {
                anchors { left: parent.left; right: parent.right; top: brightLbl.bottom; topMargin: 8 }
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰃞"; font.pixelSize: 13
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.35)
                }

                Item {
                    id: btw
                    width: parent.width - 13 - 13 - parent.spacing * 2
                    height: 20; anchors.verticalCenter: parent.verticalCenter
                    readonly property int thumbD: 14

                    Rectangle {
                        id: btrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 5; radius: height / 2
                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
                        Rectangle {
                            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                            width: Math.max(parent.radius * 2, parent.width * root._brightVal)
                            radius: parent.radius; color: Theme.active
                            Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.SizeHorCursor
                            function _c(mx) {
                                return Math.max(0.0, Math.min(1.0,
                                    (mx - btw.thumbD/2) / (btrack.width - btw.thumbD)))
                            }
                            onPressed:         root._setBright(_c(mouseX))
                            onPositionChanged: if (pressed) root._setBright(_c(mouseX))
                        }
                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: function(e) {
                                root._setBright(root._brightVal + (e.angleDelta.y > 0 ? 0.05 : -0.05))
                            }
                        }
                    }
                    Rectangle {
                        width: btw.thumbD; height: btw.thumbD; radius: btw.thumbD / 2
                        color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(btw.width - width, root._brightVal * (btw.width - width)))
                        Behavior on x { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰃠"; font.pixelSize: 13
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.75)
                }
            }
        }

        Rectangle {
            width: parent.width; height: 1
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
        }
        Item { width: parent.width; height: 8 }

        Text {
            id: qsLbl; width: parent.width
            text: "QUICK SETTINGS"; font.pixelSize: 9; font.weight: Font.Bold
            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
        }
        Item { width: parent.width; height: 8 }

        // ── Tile grid ─────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: root.height - 12 - 52 - 1 - 8 - qsLbl.height - 8

            Flickable {
                id: flick
                anchors.fill:   parent
                contentWidth:   width
                contentHeight:  tileGrid.implicitHeight + 8
                clip:           true
                boundsBehavior: Flickable.StopAtBounds

                component TglBtn: Rectangle {
                    id: btn
                    required property bool   on
                    required property string icon
                    required property string label
                    property  string sublabel: ""
                    signal toggled()

                    radius: 10
                    color: on
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                        : bH.hovered
                            ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                            : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)
                    border.color: on
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30)
                        : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    Rectangle {
                        anchors { top: parent.top; right: parent.right; margins: 8 }
                        width: 6; height: 6; radius: 3
                        color: btn.on ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.18)
                        Behavior on color { ColorAnimation { duration: 130 } }
                    }

                    Column {
                        anchors { left: parent.left; bottom: parent.bottom; margins: 9 }
                        spacing: 2
                        Text {
                            text: btn.icon; font.pixelSize: 17
                            color: btn.on ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.40)
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                        Text {
                            text: btn.label; font.pixelSize: 9; font.weight: Font.Medium
                            color: btn.on ? Theme.text : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.45)
                            Behavior on color { ColorAnimation { duration: 130 } }
                        }
                        Text {
                            visible: btn.sublabel !== ""
                            text:    btn.sublabel
                            font.pixelSize: 8; font.family: "JetBrains Mono"
                            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.65)
                            width: btn.width - 18; elide: Text.ElideRight
                        }
                    }
                    HoverHandler { id: bH; cursorShape: Qt.PointingHandCursor }
                    MouseArea    { anchors.fill: parent; onClicked: btn.toggled() }
                }

                Grid {
                    id: tileGrid
                    width: flick.width
                    columns: 2; spacing: 6

                    readonly property real btnW: (width - spacing) / 2
                    readonly property real btnH: btnW * 0.85

                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.wifiOn && !root.hotspotOn
                        icon: (root.wifiOn && !root.hotspotOn) ? "󰤨" : "󰤭"; label: "Wi-Fi"
                        sublabel: (root.wifiOn && !root.hotspotOn) && root.wifiSSID !== "" ? root.wifiSSID : (root.hotspotOn ? "Used by Hotspot" : "")
                        onToggled: root._wifiToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.btOn; icon: root.btOn ? "󰂱" : "󰂲"; label: "Bluetooth"
                        sublabel: root.btOn && root.btDevice !== "" ? root.btDevice : ""
                        onToggled: root._btToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.airplaneOn; icon: "󰀝"; label: "Airplane Mode"
                        onToggled: root._airplaneToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.hotspotOn || root.hotspotBusy
                        icon: "󰀃"
                        label: "Hotspot"
                        sublabel: root.hotspotLabel
                        onToggled: root._hotspotToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.nightLightOn; icon: "󰖐"; label: "Night Light"
                        onToggled: root._nightLightToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: root.caffeineOn; icon: "󰅶"; label: "Caffeine"
                        onToggled: root._caffeineToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: ShellState.focusMode
                        icon: ShellState.focusMode ? "󱃕" : "󰍻"; label: "Focus Mode"
                        onToggled: root._focusToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on: ShellState.dnd; icon: ShellState.dnd ? "󰂛" : "󰂚"
                        label: "Do Not Disturb"
                        onToggled: root._dndToggle()
                    }
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on:    ShellState.screenRecord || ScreenRecService.recording
                        icon:  ScreenRecService.recording ? "⏹" : "󰻂"
                        label: ScreenRecService.recording ? "Recording" : "Screen Capture"
                        onToggled: {
                            if (ScreenRecService.recording) {
                                ScreenRecService.stopRecording()
                            } else if (ShellState.screenRecord) {
                                ScreenRecService.cancelSetup()
                            } else {
                                Popups.closeAll()
                                ShellState.screenRecord = true
                            }
                        }
                    }
                    // Filter tile — opens picker, does not toggle directly
                    TglBtn {
                        width: tileGrid.btnW; height: tileGrid.btnH
                        on:       root.currentFilter !== ""
                        icon:     "󱡓"
                        label:    "Filter"
                        sublabel: root.currentFilter !== "" ? root.currentFilter : ""
                        onToggled: root._filterOpen()
                    }
                }
            }
        }
    }

    // ── Filter picker popup ───────────────────────────────────────────────────
    // Floats above the bottom-right tile. z:20 renders it over the grid.
    // Anchored bottom-right of the StatCard's inner area.
    Rectangle {
        id: filterPicker
        visible:  root.filterPickerOpen
        z:        20

        anchors {
            right:        parent.right
            bottom:       parent.bottom
            rightMargin:  12
            bottomMargin: 12
        }

        width:  180
        // Height fits "Off" row + all shader rows, capped at 280
        height: Math.min(280, pickerCol.implicitHeight + 16)
        radius: Theme.cornerRadius

        color: Qt.rgba(
            Math.min(1, Theme.background.r + 0.05),
            Math.min(1, Theme.background.g + 0.05),
            Math.min(1, Theme.background.b + 0.05),
            0.98)
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
        border.width: 1

        // Subtle entrance scale + fade
        opacity: root.filterPickerOpen ? 1 : 0
        scale:   root.filterPickerOpen ? 1 : 0.95
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale   { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        transformOrigin: Item.BottomRight

        // Dismiss when clicking outside the picker
        MouseArea {
            anchors.fill: parent
            // Swallow clicks so they don't fall through to tiles below
            onClicked: {} // intentionally empty — keeps picker open on internal clicks
        }

        Flickable {
            anchors { fill: parent; margins: 8 }
            contentWidth:   width
            contentHeight:  pickerCol.implicitHeight
            clip:           true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: pickerCol
                width: parent.width
                spacing: 2

                // Header label
                Text {
                    width: parent.width
                    text: "SHADER"
                    font.pixelSize: 9; font.weight: Font.Bold
                    color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
                    leftPadding: 4
                    bottomPadding: 4
                }

                // "Off" row — always first
                Rectangle {
                    width:  parent.width
                    height: 28
                    radius: 6
                    property bool isActive: root.currentFilter === ""
                    color: isActive
                        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                        : offH.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Row {
                        anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        spacing: 8
                        Text {
                            text:           parent.parent.isActive ? "●" : "○"
                            font.pixelSize: 9
                            color: parent.parent.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.30)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            text:           "Off"
                            font.pixelSize: 12
                            color: parent.parent.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.65)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                    }
                    HoverHandler { id: offH; cursorShape: Qt.PointingHandCursor }
                    TapHandler   { onTapped: root._filterApply("") }
                }

                // Divider
                Rectangle {
                    width: parent.width; height: 1
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)
                }

                // Shader rows — populated by hyprshade ls
                Repeater {
                    model: root.filterList
                    delegate: Rectangle {
                        required property string modelData
                        property bool isActive: root.currentFilter === modelData

                        width:  pickerCol.width
                        height: 28
                        radius: 6
                        color: isActive
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
                            : itemH.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Row {
                            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            spacing: 8
                            Text {
                                text:           parent.parent.isActive ? "●" : "○"
                                font.pixelSize: 9
                                color: parent.parent.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.30)
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                text:           modelData
                                font.pixelSize: 12
                                color: parent.parent.isActive ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.65)
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                width: pickerCol.width - 38
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }
                        HoverHandler { id: itemH; cursorShape: Qt.PointingHandCursor }
                        TapHandler   { onTapped: root._filterApply(modelData) }
                    }
                }

                // Empty state — shown while hyprshade ls is still running
                Text {
                    width:   parent.width
                    visible: root.filterList.length === 0
                    text:    "Loading…"
                    font.pixelSize: 11
                    color:   Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.25)
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 4
                }
            }
        }
    }

    // Tap outside the picker to close it
    TapHandler {
        enabled: root.filterPickerOpen
        onTapped: root.filterPickerOpen = false
    }
}
