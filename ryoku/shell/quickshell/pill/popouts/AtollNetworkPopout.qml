pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import ".."
import "../Singletons"

// atoll network popout content: a faithful port of ilyamiro's radial network /
// bluetooth orbit. a large centre core shows the connected device (icon, name,
// status) as a bone chip with dark ink; satellite info chips (signal, security,
// battery, audio profile, mac, "Scan Devices") orbit on a slowly rotating
// ellipse, tethered to the core by curved Canvas bezier connectors. a bottom
// Wi-Fi | Bluetooth segmented toggle (active = bone chip) and a power button
// that morphs from a big centred disc (radio off) to a small corner button
// (radio on). tapping "Scan Devices" flips the orbit to a scan view whose
// networks / devices orbit as connectable chips.
//
// this is transparent content: the frame blob behind it IS the surface, so
// there is no window background here, only the inner orbit sized via implicit
// dimensions. every raw ilyamiro pixel is multiplied by root.s (their
// scaler.s(v) becomes v * root.s). data comes from Ryoku: Quickshell.Networking
// for wifi (the same surface Link/LinkWifi read), Quickshell.Bluetooth for the
// adapter and devices, and the Network singleton for ethernet presence.
Item {
    id: root

    property real s: 1
    // popout open: gates the wifi scanner, bt discovery and the orbit spin so a
    // closed panel spins no radios and burns no frames.
    property bool open: false

    anchors.fill: parent
    // canvas scaled down from ilyamiro's fullscreen layer to a popout footprint
    // while preserving every ratio: their s(360) tab bar and s(200) core shrink
    // proportionally so the whole orbit fits a bar popout.
    implicitWidth: 440 * s
    implicitHeight: 464 * s
    clip: true

    // "wifi" | "bt". the bottom segmented toggle drives this (ilyamiro's
    // activeMode, minus the separate ethernet tab: ethernet folds into the wifi
    // side as the connected core when a cable is present).
    property string mode: "wifi"

    // ---- geometry (ilyamiro raw px in comments, scaled here) ----
    readonly property real coreW: 128 * s          // src s(200) connected
    readonly property real chipW: 138 * s          // src s(170)
    readonly property real chipH: 50 * s           // src s(60)
    readonly property real pwrBig: 128 * s         // src s(160)
    readonly property real pwrSmall: 44 * s        // src s(48)

    // orbit ellipse radii. info nodes ride a tight ellipse (src s(280)/s(180));
    // scan chips ride a wider one with a two-ring alternation (src s(320)/s(200)
    // + (index%2)*s(40)).
    function orbitRadX(i) { return (infoMode ? 132 : 138 + (i % 2) * 24) * root.s; }
    function orbitRadY(i) { return (infoMode ? 112 : 122 + (i % 2) * 24) * root.s; }

    // shared angle for a chip: even spread around the ellipse plus the global
    // slow spin, offset by -90deg so index 0 starts at the top. used by both the
    // chip delegates and the connector Canvas so the two never disagree.
    function orbitAngle(i, count) {
        return root.globalOrbitAngle * 1.5 + (count > 0 ? (i / count) * 2 * Math.PI : 0) - Math.PI / 2;
    }

    // ---- networking (wifi + ethernet), guarded like Link.qml ----
    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var wifiDev: netDevices.find(function (d) { return d && d.type === DeviceType.Wifi; }) || null
    readonly property var wiredDev: netDevices.find(function (d) { return d && d.type === DeviceType.Wired && d.connected; }) || null
    readonly property bool wired: Network.kind === "ethernet" || wiredDev !== null
    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(function (n) { return n && n.connected; }) || null
    readonly property var wifiSorted: wifiNets.slice().sort(function (a, b) {
        return ((b ? b.signalStrength : 0) || 0) - ((a ? a.signalStrength : 0) || 0);
    })
    // strongest known-or-open network: the scan chip we breathe as the suggested
    // tap target when nothing is connected (ilyamiro's targetWifiSsid).
    readonly property string targetSsid: wifiSorted.length > 0 ? (wifiSorted[0].name || "") : ""
    readonly property real ethSpeed: (wiredDev && wiredDev.linkSpeed) ? wiredDev.linkSpeed : 0
    readonly property string ethSpeedText: ethSpeed > 0
        ? (ethSpeed >= 1000 ? (ethSpeed / 1000).toFixed(ethSpeed % 1000 === 0 ? 0 : 1) + " Gb/s" : ethSpeed + " Mb/s")
        : ""
    property string ethIp: ""

    // ---- bluetooth, guarded like LinkBt.qml ----
    readonly property var btAdapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
    readonly property var btDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []
    readonly property bool btOn: btAdapter ? btAdapter.enabled === true : false
    readonly property var btConnectedList: btDevices.filter(function (d) { return d && d.connected; })
    readonly property var btPrimary: btConnectedList.length > 0 ? btConnectedList[0] : null
    // connected first, then paired, then named, nameless MACs last (LinkBt order).
    readonly property var btSorted: btDevices.slice().sort(function (a, b) {
        function rank(d) {
            if (!d) return 3;
            if (d.connected) return 0;
            if (d.paired) return 1;
            return (d.name && d.name.length) ? 2 : 3;
        }
        var r = rank(a) - rank(b);
        if (r !== 0) return r;
        return String((a && a.name) || "").localeCompare(String((b && b.name) || ""));
    })

    // ---- per-mode power / connection roll-up (ilyamiro currentPower/currentConn) ----
    readonly property bool currentPower: mode === "wifi" ? (wifiOn || wired) : btOn
    readonly property bool currentConn: mode === "wifi" ? (wired || wifiActive !== null) : btConnectedList.length > 0

    // the device shown in the centre core, or null when scanning.
    readonly property var coreDevice: {
        if (mode === "wifi")
            return wired ? { name: "Ethernet", icon: "lan" } : wifiActive;
        return btPrimary;
    }
    readonly property string coreName: {
        if (!coreDevice) return "";
        if (mode === "wifi") return wired ? "Ethernet" : (coreDevice.name || "Wi-Fi");
        return coreDevice.deviceName || coreDevice.name || "Device";
    }
    readonly property string coreIcon: {
        if (mode === "wifi") return wired ? "lan" : "wifi";
        return "bluetooth";
    }

    // scan vs info: when connected we orbit the info chips, and the user flips to
    // the scan list via the "Scan Devices" chip (ilyamiro showInfoView).
    property bool showInfoView: true
    readonly property bool infoMode: currentConn && showInfoView

    // ---- connect / disconnect state (ilyamiro busyTasks/connectingId/failedId) ----
    property string connectingId: ""
    property string failedId: ""
    property string pendingSsid: ""   // secured, unknown wifi awaiting a password
    property string pendingPw: ""
    property string attemptSsid: ""

    Timer { id: failClear; interval: 4000; onTriggered: root.failedId = "" }

    // nmcli-derived security + known-profile maps (LinkWifi pattern), used to
    // decide whether a wifi tap connects straight away or drops the password
    // layer, and to label the connected network's security chip.
    property var securityMap: ({})
    property var knownProfiles: ({})
    function isSecured(ssid) {
        var sec = securityMap[ssid];
        return sec !== undefined && sec !== "" && sec !== "--";
    }
    // last unescaped colon split for `nmcli -t` lines (LinkWifi.splitTerse).
    function splitTerse(line) {
        for (var k = line.length - 1; k >= 0; k--) {
            if (line[k] === ":" && (k === 0 || line[k - 1] !== "\\"))
                return { head: line.slice(0, k).replace(/\\:/g, ":"), tail: line.slice(k + 1) };
        }
        return null;
    }

    function batteryLevel(d) {
        if (!d || d.battery === undefined || d.battery === null) return -1;
        var b = d.battery;
        if (b <= 0) return -1;
        if (b <= 1) b = b * 100;
        return Math.round(b);
    }

    // ---- the orbit model: info chips when connected, scan chips otherwise ----
    // each node is a flat record the chip delegate renders directly; live device
    // refs ride along in `ref` so a tap can act on them.
    readonly property var orbitItems: {
        // touch the reactive inputs so the array rebuilds when they change.
        void mode; void infoMode; void wifiActive; void btPrimary; void wired;
        void ethIp; void ethSpeedText; void securityMap; void wifiSorted; void btSorted;

        var out = [];
        if (infoMode) {
            if (mode === "wifi") {
                if (wired) {
                    if (ethSpeedText.length) out.push({ kind: "info", icon: "speed", title: ethSpeedText, sub: "Link Speed", id: "spd", ref: null });
                    if (ethIp.length) out.push({ kind: "info", icon: "lan", title: ethIp, sub: "IP Address", id: "ip", ref: null });
                } else if (wifiActive) {
                    var sig = wifiActive.signalStrength;
                    out.push({ kind: "info", icon: "network_wifi", title: (sig !== undefined ? sig + "%" : "Signal"), sub: "Signal Strength", id: "sig", ref: null });
                    var sec = securityMap[wifiActive.name || ""];
                    out.push({ kind: "info", icon: isSecured(wifiActive.name || "") ? "lock" : "lock_open", title: (sec && sec !== "--" ? sec : "Open"), sub: "Security", id: "sec", ref: null });
                }
            } else if (btPrimary) {
                var bat = batteryLevel(btPrimary);
                if (bat >= 0) out.push({ kind: "info", icon: "battery_full", title: bat + "%", sub: "Battery", id: "bat", ref: null });
                out.push({ kind: "info", icon: "graphic_eq", title: "Hi-Fi", sub: "Audio Profile", id: "prof", ref: null });
                out.push({ kind: "info", icon: "tag", title: btPrimary.address || "Unknown", sub: "MAC Address", id: "mac", ref: null });
            }
            // the pivot chip back to the scan list (ilyamiro action_scan).
            out.push({ kind: "action", icon: "radar", title: "Scan Devices", sub: "Switch View", id: "action_scan", ref: null });
        } else if (mode === "wifi") {
            for (var i = 0; i < wifiSorted.length && i < 8; i++) {
                var n = wifiSorted[i];
                out.push({ kind: "net", icon: "wifi", title: n.name || "Hidden", sub: (n.connected ? "Connected" : "Connect"), id: (n.name || "net" + i), ref: n });
            }
        } else {
            for (var j = 0; j < btSorted.length && j < 8; j++) {
                var d = btSorted[j];
                out.push({ kind: "bt", icon: "bluetooth", title: d.deviceName || d.name || "Unknown", sub: (d.connected ? "Connected" : (d.paired ? "Connect" : "Pair")), id: (d.address || "bt" + j), ref: d });
            }
        }
        return out;
    }

    // ---- actions ----
    function activateNode(node) {
        if (!node) return;
        if (node.kind === "action") {
            root.showInfoView = !root.showInfoView;
            if (!root.showInfoView) root.startScan();
            return;
        }
        if (node.kind === "net") {
            var net = node.ref;
            if (!net) return;
            if (net.connected) { if (typeof net.disconnect === "function") net.disconnect(); return; }
            var ssid = net.name || "";
            if (root.knownProfiles[ssid] === true || !root.isSecured(ssid)) {
                root.connectingId = node.id;
                if (typeof net.connect === "function") net.connect();
                root.refreshNmcli();
                return;
            }
            // secured and unknown: raise the in-core password layer.
            root.pendingSsid = ssid;
            return;
        }
        if (node.kind === "bt") {
            var dev = node.ref;
            if (!dev) return;
            if (dev.connected) { if (typeof dev.disconnect === "function") dev.disconnect(); return; }
            if (dev.paired) { root.connectingId = node.id; if (typeof dev.connect === "function") dev.connect(); return; }
            root.pairDevice(dev);
        }
    }

    // secure connect: nmcli --ask reads the secret from stdin so it never lands
    // in a world-readable /proc cmdline (LinkWifi.connectWithPassword).
    function connectWithPassword(ssid, pw) {
        if (connProc.running || !pw.length) return;
        root.connectingId = ssid;
        root.attemptSsid = ssid;
        root.pendingPw = pw;
        connProc.command = ["nmcli", "--ask", "dev", "wifi", "connect", ssid];
        connProc.running = true;
    }

    function pairDevice(d) {
        if (!d || !d.address || pairProc.running) return;
        root.attemptSsid = d.address;
        root.connectingId = d.address;
        pairProc.command = ["sh", "-c",
            'timeout 30 bluetoothctl pair "$1" && bluetoothctl trust "$1" && timeout 30 bluetoothctl connect "$1"',
            "sh", d.address];
        pairProc.running = true;
    }

    function disconnectCore() {
        if (mode === "wifi") {
            if (wired && wiredDev) { if (typeof wiredDev.disconnect === "function") wiredDev.disconnect(); return; }
            if (wifiActive && typeof wifiActive.disconnect === "function") wifiActive.disconnect();
        } else if (btPrimary && typeof btPrimary.disconnect === "function") {
            btPrimary.disconnect();
        }
    }

    function togglePower() {
        root.pendingSsid = "";
        if (mode === "wifi") {
            if (typeof Networking !== "undefined" && Networking)
                Networking.wifiEnabled = !root.wifiOn;
        } else if (btAdapter) {
            btAdapter.enabled = !root.btOn;
        }
    }

    property bool scanning: false
    function startScan() {
        if (mode === "wifi") {
            if (!wifiOn) return;
            root.scanning = true;
            rescanProc.running = true;
            scanTimer.restart();
        } else if (btAdapter) {
            btAdapter.discovering = true;
            btScanTimer.restart();
        }
    }

    function refreshNmcli() {
        secProc.running = true;
        profProc.running = true;
    }

    onModeChanged: {
        root.pendingSsid = "";
        root.showInfoView = true;
        if (btAdapter && btAdapter.discovering) btAdapter.discovering = false;
        root.scanning = false;
    }
    onOpenChanged: {
        if (open) {
            refreshNmcli();
            ipProc.running = true;
        } else {
            root.pendingSsid = "";
            root.scanning = false;
            if (btAdapter && btAdapter.discovering) btAdapter.discovering = false;
        }
    }

    // keep the live wifi scanner running only while open on the wifi tab, exactly
    // like LinkWifi, so nmcli never rescans behind a closed panel.
    Binding {
        target: root.wifiDev
        property: "scannerEnabled"
        value: root.open && root.mode === "wifi" && root.wifiOn
        when: root.wifiDev !== null
    }

    Timer { id: scanTimer; interval: 10000; onTriggered: root.scanning = false }
    Timer { id: btScanTimer; interval: 25000; onTriggered: if (root.btAdapter) root.btAdapter.discovering = false }

    // ---- processes ----
    Process { id: rescanProc; command: ["nmcli", "dev", "wifi", "rescan"] }

    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 -o addr show scope global up | awk '{for(i=1;i<=NF;i++) if($i==\"inet\"){print $(i+1); exit}}' | cut -d/ -f1"]
        stdout: StdioCollector { onStreamFinished: root.ethIp = this.text.trim() }
    }

    Process {
        id: secProc
        command: ["nmcli", "-t", "-f", "SSID,SECURITY", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i].length) continue;
                    var parts = root.splitTerse(lines[i]);
                    if (parts && parts.head.length) map[parts.head] = parts.tail;
                }
                root.securityMap = map;
            }
        }
    }

    Process {
        id: profProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                var set = {};
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var parts = root.splitTerse(lines[i]);
                    if (parts && parts.head.length && parts.tail === "802-11-wireless") set[parts.head] = true;
                }
                root.knownProfiles = set;
            }
        }
    }

    Process {
        id: connProc
        stdinEnabled: true
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onStarted: {
            // feed the secret once, then close the pipe so nmcli stops waiting.
            write(root.pendingPw + "\n");
            root.pendingPw = "";
        }
        onExited: function (exitCode) {
            root.connectingId = "";
            if (exitCode !== 0) { root.failedId = root.attemptSsid; failClear.restart(); }
            root.refreshNmcli();
        }
    }

    Process {
        id: pairProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function (exitCode) {
            root.connectingId = "";
            if (exitCode !== 0) { root.failedId = root.attemptSsid; failClear.restart(); }
        }
    }

    // ---- animation drivers (ilyamiro globalOrbitAngle + introState) ----
    property real globalOrbitAngle: 0
    NumberAnimation on globalOrbitAngle {
        // src loops 2*pi over 200s; kept slow so the orbit drifts, not spins.
        from: 0; to: Math.PI * 2; duration: 200000; loops: Animation.Infinite; running: root.open
    }

    // entrance reveal: chips and connectors bloom outward from the core.
    property real intro: open ? 1 : 0
    Behavior on intro { NumberAnimation { duration: 1500; easing.type: Easing.OutCubic } }
    // combined gate: nothing orbits until the radio is on and the intro has run.
    readonly property real orbitReveal: currentPower ? intro : 0

    // ---- the orbit region (everything above the toggle bar) ----
    Item {
        id: region
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 84 * root.s   // src s(80): clears the tab bar + power

        readonly property real cx: width / 2
        readonly property real cy: height / 2

        // faint concentric radar rings behind the core (ilyamiro radarItem).
        Repeater {
            model: 3
            Rectangle {
                required property int index
                anchors.centerIn: parent
                width: (150 + index * 92) * root.s * (0.6 + 0.4 * root.orbitReveal)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Theme.bright
                opacity: (root.currentConn ? 0.10 - index * 0.025 : 0.05) * root.orbitReveal
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 600 } }
            }
        }

        // curved bezier connectors from the core edge to each orbiting chip.
        // ported from ilyamiro nodeLinesCanvas: a start offset past the core
        // radius, a perpendicular control point with a breathing wobble, drawn
        // as a soft glow stroke under a brighter core stroke. monochrome bone,
        // vermillion only when the pending attempt failed.
        Canvas {
            id: connectors
            anchors.fill: parent
            z: 0
            opacity: root.orbitReveal
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 400 } }

            property real repaintTrigger: root.globalOrbitAngle + root.orbitReveal
            onRepaintTriggerChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections { target: root; function onOrbitItemsChanged() { connectors.requestPaint(); } }

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (root.orbitReveal < 0.01) return;

                var cx = width / 2;
                var cy = height / 2;
                var coreR = root.coreW / 2;
                var count = root.orbitItems.length;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";

                for (var i = 0; i < count; i++) {
                    var a = root.orbitAngle(i, count);
                    var tx = cx + Math.cos(a) * root.orbitRadX(i) * root.orbitReveal;
                    var ty = cy + Math.sin(a) * root.orbitRadY(i) * root.orbitReveal;

                    var dx = tx - cx;
                    var dy = ty - cy;
                    var dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist < coreR + root.s * 10) continue;

                    var ux = dx / dist;
                    var uy = dy / dist;
                    var sx = cx + ux * (coreR + root.s * 5);          // src coreR + s(5)
                    var sy = cy + uy * (coreR + root.s * 5);
                    var ex = tx - ux * (root.chipW * 0.42);           // stop short of the chip
                    var ey = ty - uy * (root.chipH * 0.42);

                    var mx = (sx + ex) / 2;
                    var my = (sy + ey) / 2;
                    var perpX = -uy;
                    var perpY = ux;
                    // breathing perpendicular bow gives the curve its living arc.
                    var wob = Math.sin(root.globalOrbitAngle * 6 + i) * root.s * 8;
                    var cpx = mx + perpX * (root.s * 20 + wob);
                    var cpy = my + perpY * (root.s * 20 + wob);

                    var failed = root.failedId !== "" && root.failedId === root.orbitItems[i].id;
                    var stroke = failed ? Theme.vermLit : Theme.bright;

                    ctx.beginPath();
                    ctx.moveTo(sx, sy);
                    ctx.quadraticCurveTo(cpx, cpy, ex, ey);
                    ctx.lineWidth = root.s * 3.4;
                    ctx.strokeStyle = stroke;
                    ctx.globalAlpha = 0.10 * root.orbitReveal;
                    ctx.stroke();

                    ctx.lineWidth = root.s * 1.2;
                    ctx.strokeStyle = stroke;
                    ctx.globalAlpha = 0.5 * root.orbitReveal;
                    ctx.stroke();
                }
            }
        }

        // ---- the satellite chips ----
        Repeater {
            id: orbitRepeater
            model: root.orbitItems

            delegate: Item {
                id: chip
                required property int index
                required property var modelData
                width: root.chipW
                height: root.chipH
                z: 1

                readonly property int count: orbitRepeater.count
                readonly property bool isConnected: {
                    if (modelData.kind === "net") return modelData.ref && modelData.ref.connected === true;
                    if (modelData.kind === "bt") return modelData.ref && modelData.ref.connected === true;
                    return false;
                }
                readonly property bool isBusy: root.connectingId !== "" && root.connectingId === modelData.id
                readonly property bool isFailed: root.failedId !== "" && root.failedId === modelData.id
                readonly property bool isHighlight: modelData.kind === "action"
                    || (modelData.kind === "net" && !root.currentConn && modelData.id === root.targetSsid)
                    || (modelData.kind === "bt" && modelData.ref && modelData.ref.paired && !isConnected)
                readonly property bool interactive: modelData.kind !== "info"
                // bone fill for a connected or highlighted chip, dim tile otherwise.
                readonly property bool bone: isConnected || isHighlight || isBusy

                // staggered entrance, ilyamiro 40 + index*30 with an OutBack pop.
                property bool loaded: false
                Timer { running: true; interval: 40 + chip.index * 30; onTriggered: chip.loaded = true }

                readonly property real a: root.orbitAngle(index, count)
                x: region.cx - width / 2 + Math.cos(a) * root.orbitRadX(index) * root.orbitReveal
                y: region.cy - height / 2 + Math.sin(a) * root.orbitRadY(index) * root.orbitReveal

                opacity: loaded ? root.orbitReveal : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                scale: loaded ? (chipMa.pressed ? 0.96 : (chipMa.containsMouse ? 1.06 : 1)) : 0
                Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }

                Rectangle {
                    anchors.fill: parent
                    radius: 12 * root.s     // src s(14)
                    color: chip.isFailed ? Theme.vermDeep
                         : chip.bone ? Theme.bright
                         : (chipMa.containsMouse ? Theme.tileBg : Theme.cardTop)
                    border.width: 1
                    border.color: chip.isFailed ? Theme.vermLit
                        : chip.bone ? "transparent" : Theme.border
                    Behavior on color { ColorAnimation { duration: 200 } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 11 * root.s
                        anchors.rightMargin: 11 * root.s
                        spacing: 9 * root.s

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.icon
                            fill: chip.bone ? 1 : 0
                            color: chip.isFailed ? Theme.bright : chip.bone ? Theme.cardBot : Theme.cream
                            font.pixelSize: 18 * root.s
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 27 * root.s
                            spacing: 1 * root.s
                            Text {
                                width: parent.width
                                text: chip.modelData.title
                                color: chip.isFailed ? Theme.bright : chip.bone ? Theme.cardBot : Theme.cream
                                font.family: Theme.mono
                                font.pixelSize: 12 * root.s
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: chip.isFailed ? "Failed" : chip.isBusy ? "Connecting..." : chip.modelData.sub
                                color: chip.isFailed ? Theme.vermLit
                                     : chip.bone ? Qt.alpha(Theme.cardBot, 0.7) : Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: 9 * root.s
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    hoverEnabled: chip.interactive
                    enabled: chip.interactive && !chip.isBusy
                    cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.activateNode(chip.modelData)
                }
            }
        }

        // ---- the centre core (connected device / scanning / password) ----
        Item {
            id: core
            width: root.coreW
            height: root.coreW
            anchors.centerIn: parent
            z: 2
            opacity: root.currentPower ? root.intro : 0
            visible: opacity > 0.01
            scale: 0.85 + 0.15 * root.intro
            Behavior on opacity { NumberAnimation { duration: 500 } }

            property real disconnectFill: 0

            Rectangle {
                id: coreDisc
                anchors.fill: parent
                radius: width / 2
                readonly property bool danger: coreMa.containsMouse && root.currentConn
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0
                        color: root.currentConn ? (coreDisc.danger ? Theme.vermLit : Theme.bright) : Theme.tileBg
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                    GradientStop {
                        position: 1
                        color: root.currentConn ? (coreDisc.danger ? Theme.verm : Theme.cream) : Theme.cardBot
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }
                }
                border.width: 2 * root.s
                border.color: root.currentConn ? (coreDisc.danger ? Theme.vermLit : Theme.bright) : Theme.border
                Behavior on border.color { ColorAnimation { duration: 300 } }

                // hold-to-disconnect progress ring (ilyamiro's press-and-hold
                // water fill, distilled to a sweeping arc so the interaction and
                // its "Hold..." feedback survive without the heavy wave canvas).
                Canvas {
                    id: holdRing
                    anchors.fill: parent
                    visible: core.disconnectFill > 0.001
                    property real fillTrigger: core.disconnectFill
                    onFillTriggerChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (core.disconnectFill <= 0.001) return;
                        var r = width / 2 - root.s * 4;
                        ctx.beginPath();
                        ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + core.disconnectFill * 2 * Math.PI);
                        ctx.lineWidth = root.s * 4;
                        ctx.strokeStyle = Theme.verm;
                        ctx.lineCap = "round";
                        ctx.stroke();
                    }
                }

                // scanning pulse rings, shown when the radio is on but nothing is
                // connected (ilyamiro showScanning).
                Repeater {
                    model: 3
                    Rectangle {
                        id: pulseRing
                        required property int index
                        anchors.centerIn: parent
                        width: parent.width * 0.4
                        height: width
                        radius: width / 2
                        color: "transparent"
                        border.width: 2 * root.s
                        border.color: Theme.bright
                        visible: root.currentPower && !root.currentConn && root.pendingSsid === ""
                        SequentialAnimation on scale {
                            running: pulseRing.visible; loops: Animation.Infinite
                            PauseAnimation { duration: pulseRing.index * 400 }
                            NumberAnimation { from: 1; to: 2.4; duration: 2000; easing.type: Easing.OutSine }
                        }
                        SequentialAnimation on opacity {
                            running: pulseRing.visible; loops: Animation.Infinite
                            PauseAnimation { duration: pulseRing.index * 400 }
                            NumberAnimation { from: 0.7; to: 0; duration: 2000; easing.type: Easing.OutSine }
                        }
                    }
                }

                // connected / scanning content
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 30 * root.s
                    spacing: 4 * root.s
                    visible: root.pendingSsid === ""
                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentConn ? root.coreIcon : (root.mode === "wifi" ? "wifi_find" : "bluetooth_searching")
                        fill: root.currentConn ? 1 : 0
                        color: root.currentConn ? Theme.cardBot : Theme.cream
                        font.pixelSize: 40 * root.s   // src s(48)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.currentConn ? root.coreName : "Scanning"
                        color: root.currentConn ? Theme.cardBot : Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 14 * root.s   // src s(16)
                        font.weight: Font.Black
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.currentConn ? (core.disconnectFill > 0.01 ? "Hold..." : (coreDisc.danger ? "Disconnect" : "Connected")) : "Tap to scan"
                        color: root.currentConn ? Qt.alpha(Theme.cardBot, 0.75) : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Bold
                    }
                }

                // in-core password entry for a secured, unknown wifi network.
                Column {
                    id: pwdLayer
                    anchors.centerIn: parent
                    width: parent.width - 26 * root.s
                    spacing: 7 * root.s
                    visible: root.pendingSsid !== "" && root.mode === "wifi"
                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "lock"; fill: 1; color: Theme.cardBot
                        font.pixelSize: 26 * root.s
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.pendingSsid
                        color: Theme.cardBot
                        font.family: Theme.mono
                        font.pixelSize: 12 * root.s
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: 30 * root.s
                        radius: 15 * root.s
                        color: Theme.cardBot
                        border.width: 1
                        border.color: pwdField.activeFocus ? Theme.bright : "transparent"
                        TextInput {
                            id: pwdField
                            anchors.fill: parent
                            anchors.leftMargin: 12 * root.s
                            anchors.rightMargin: 12 * root.s
                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.mono
                            font.pixelSize: 12 * root.s
                            color: Theme.cream
                            echoMode: TextInput.Password
                            clip: true
                            onAccepted: {
                                if (text.trim() !== "") {
                                    root.connectWithPassword(root.pendingSsid, text);
                                    root.pendingSsid = "";
                                    text = "";
                                }
                            }
                            Keys.onEscapePressed: { root.pendingSsid = ""; text = ""; }
                        }
                    }
                    // grab focus when the layer appears so the user can type.
                    Timer { id: pwdFocus; interval: 60; onTriggered: pwdField.forceActiveFocus() }
                    onVisibleChanged: if (visible) { pwdField.text = ""; pwdFocus.start(); }
                }

                MouseArea {
                    id: coreMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.pendingSsid === ""
                    cursorShape: root.currentConn ? Qt.PointingHandCursor : Qt.ArrowCursor
                    // connected: press and hold to disconnect. not connected: tap
                    // kicks a fresh scan.
                    onPressed: {
                        if (root.currentConn) { coreDrain.stop(); coreFill.start(); }
                    }
                    onReleased: { coreFill.stop(); coreDrain.start(); }
                    onCanceled: { coreFill.stop(); coreDrain.start(); }
                    onClicked: { if (!root.currentConn) root.startScan(); }
                }

                NumberAnimation {
                    id: coreFill
                    target: core; property: "disconnectFill"; to: 1
                    duration: 700 * (1 - core.disconnectFill); easing.type: Easing.InSine
                    onFinished: {
                        if (!coreMa.pressed) { core.disconnectFill = 0; return; }
                        root.disconnectCore();
                        core.disconnectFill = 0;
                    }
                }
                NumberAnimation {
                    id: coreDrain
                    target: core; property: "disconnectFill"; to: 0
                    duration: 400 * core.disconnectFill; easing.type: Easing.OutQuad
                }
            }
        }

        // ---- power button: big centred disc (off) morphing to a corner button (on) ----
        Item {
            id: power
            z: 3
            // src pwrMorph: InOutQuint 800ms drives both size and position.
            property real pwrMorph: root.currentPower ? 1 : 0
            Behavior on pwrMorph { NumberAnimation { duration: 800; easing.type: Easing.InOutQuint } }

            width: root.pwrBig + (root.pwrSmall - root.pwrBig) * pwrMorph
            height: width
            x: {
                var startX = region.width / 2 - root.pwrBig / 2;
                var endX = region.width - 18 * root.s - root.pwrSmall;
                return startX + (endX - startX) * pwrMorph;
            }
            y: {
                var startY = region.height / 2 - root.pwrBig / 2;
                var endY = region.height - 6 * root.s - root.pwrSmall;
                return startY + (endY - startY) * pwrMorph;
            }

            Rectangle {
                id: powerDisc
                anchors.fill: parent
                radius: width / 2
                scale: pwrMa.pressed ? 0.95 : (pwrMa.containsMouse ? 1.05 : 1)
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0; color: root.currentPower ? Theme.bright : Theme.tileBg }
                    GradientStop { position: 1; color: root.currentPower ? Theme.cream : Theme.cardBot }
                }
                border.width: 2 * root.s
                border.color: root.currentPower ? "transparent" : Theme.border

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "power_settings_new"
                    fill: root.currentPower ? 1 : 0
                    color: root.currentPower ? Theme.cardBot : Theme.cream
                    font.pixelSize: (root.currentPower ? 22 : 52) * root.s
                    Behavior on font.pixelSize { NumberAnimation { duration: 800; easing.type: Easing.InOutQuint } }
                }

                MouseArea {
                    id: pwrMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.togglePower()
                }
            }
        }
    }

    // ---- bottom Wi-Fi | Bluetooth segmented toggle (active = bone chip) ----
    Rectangle {
        id: tabs
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 18 * root.s     // src s(25)
        width: 260 * root.s                    // src s(360)
        height: 46 * root.s                    // src s(54)
        radius: 12 * root.s                    // src s(14)
        color: Qt.alpha(Theme.bright, 0.06)
        border.width: 1
        border.color: Theme.border

        // the morphing highlight pill slides between the two segments, its two
        // edges chasing at slightly different speeds (ilyamiro actualLeft/Right).
        Rectangle {
            id: highlight
            y: 5 * root.s
            height: parent.height - 10 * root.s
            radius: 9 * root.s
            property Item activeItem: root.mode === "wifi" ? wifiTab : btTab
            property real targetLeft: activeItem ? activeItem.x : 0
            property real actualLeft: targetLeft
            property real actualRight: (activeItem ? activeItem.x + activeItem.width : 0)
            Behavior on actualLeft { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
            Behavior on actualRight { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
            x: 5 * root.s + actualLeft
            width: Math.max(0, actualRight - actualLeft)
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0; color: Theme.bright }
                GradientStop { position: 1; color: Theme.cream }
            }
        }

        Row {
            id: tabRow
            anchors.fill: parent
            anchors.margins: 5 * root.s
            spacing: 4 * root.s

            component Tab: Item {
                id: tab
                property string tabMode
                property string glyph
                property string label
                width: (tabRow.width - tabRow.spacing) / 2
                height: tabRow.height
                readonly property bool activeTab: root.mode === tabMode
                Row {
                    anchors.centerIn: parent
                    spacing: 7 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.glyph
                        fill: tab.activeTab ? 1 : 0
                        color: tab.activeTab ? Theme.cardBot : Theme.cream
                        font.pixelSize: 17 * root.s
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.label
                        color: tab.activeTab ? Theme.cardBot : Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 12 * root.s
                        font.weight: Font.Black
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.mode !== tab.tabMode) root.mode = tab.tabMode
                }
            }

            Tab { id: wifiTab; tabMode: "wifi"; glyph: "wifi"; label: "Wi-Fi" }
            Tab { id: btTab; tabMode: "bt"; glyph: "bluetooth"; label: "Bluetooth" }
        }
    }
}
