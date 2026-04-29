import QtQuick
import Quickshell.Io
import "../"
import "../components"

// WifiTab
// Connect → attempt without password → if "secret" in stderr → expand field inline.
// Off overlay is a direct child of root Item (z:2), not inside Column — no overflow.

Item {
    id: root

    property var    _networks:      []
    property var    _needsPassword: ({})
    property bool   _scanning:      false
    property bool   _wifiEnabled:   true
    property string _connectingTo:  ""
    property string _forgetSsid:    ""
    property string _expandSsid:    ""

    readonly property var _current: {
        for (var i = 0; i < _networks.length; i++)
            if (_networks[i].inUse) return _networks[i]
        return null
    }
    readonly property var _available: {
        var r = []
        for (var i = 0; i < _networks.length; i++)
            if (!_networks[i].inUse) r.push(_networks[i])
        return r
    }

    Connections {
        target: Popups
        function onNetworkOpenChanged() {
            if (Popups.networkOpen) {
                root._forgetSsid    = ""
                root._expandSsid    = ""
                root._connectingTo  = ""
                root._needsPassword = ({})
                root._checkRadio()
                root._scan(false)
            }
        }
    }

    // ── Processes ─────────────────────────────────────────────────────────────

    Process {
        id: scanProc
        command: []
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim()
                if (t === "") return
                var lastC = t.lastIndexOf(":")
                if (lastC < 0) return
                var security  = t.substring(lastC + 1)
                var t2        = t.substring(0, lastC)
                var secC      = t2.lastIndexOf(":")
                if (secC < 0) return
                var signalStr = t2.substring(secC + 1)
                var t3        = t2.substring(0, secC)
                var firstC    = t3.indexOf(":")
                if (firstC < 0) return
                var inUseStr  = t3.substring(0, firstC)
                var ssid      = t3.substring(firstC + 1).replace(/\\:/g, ":")
                if (ssid === "" || ssid === "--") return
                var inUse   = inUseStr.trim() === "*"
                var signal  = parseInt(signalStr.trim()) || 0
                var secured = security.trim() !== "" && security.trim() !== "--"
                var nets = root._networks.slice()
                var found = false
                for (var i = 0; i < nets.length; i++) {
                    if (nets[i].ssid === ssid) {
                        if (inUse || signal > nets[i].signal)
                            nets[i] = { ssid: ssid, signal: signal, secured: secured, inUse: inUse }
                        found = true; break
                    }
                }
                if (!found) nets.push({ ssid: ssid, signal: signal, secured: secured, inUse: inUse })
                root._networks = nets
            }
        }
        onRunningChanged: if (!running) root._scanning = false
    }

    // First attempt — captures stderr to detect secret requirement
    Process {
        id: connectProc
        command: []
        running: false
        property string _ssid: ""
        stderr: StdioCollector { id: connectStderr }
        onExited: function(code, status) {
            if (code === 0) {
                // Success — clear password state and close the field
                var np = Object.assign({}, root._needsPassword)
                delete np[connectProc._ssid]
                root._needsPassword = np
                root._expandSsid    = ""
            } else {
                var err = connectStderr.text.toLowerCase()
                if (err.indexOf("secret") >= 0 || err.indexOf("password") >= 0
                        || err.indexOf("no network") < 0) {
                    var np2 = Object.assign({}, root._needsPassword)
                    np2[connectProc._ssid] = true
                    root._needsPassword = np2
                    root._expandSsid    = connectProc._ssid
                }
            }
            root._connectingTo = ""
            root._scan(false)
        }
    }

    Process {
        id: passProc
        command: []
        running: false
        onRunningChanged: if (!running) {
            root._connectingTo = ""
            root._expandSsid   = ""
            root._scan(false)
        }
    }

    Process {
        id: actionProc
        command: []
        running: false
        onRunningChanged: if (!running) {
            root._connectingTo  = ""
            root._forgetSsid    = ""
            root._expandSsid    = ""
            root._needsPassword = ({})
            root._scan(false)
        }
    }

    Process { id: nmtuiProc; command: ["kitty", "--title", "nmtui", "nmtui"]; running: false }

    Process {
        id: radioProc; command: []; running: false
        onRunningChanged: if (!running) root._checkRadio()
    }

    Process {
        id: radioCheckProc
        command: ["bash", "-c", "nmcli radio wifi"]
        running: false
        stdout: SplitParser {
            onRead: function(line) { root._wifiEnabled = line.trim() === "enabled" }
        }
    }

    function _checkRadio() { radioCheckProc.running = false; radioCheckProc.running = true }

    function _setWifiEnabled(on) {
        root._wifiEnabled = on
        radioProc.command = ["bash", "-c", "nmcli radio wifi " + (on ? "on" : "off")]
        radioProc.running = false; radioProc.running = true
    }

    function _scan(rescan) {
        if (_scanning || !root._wifiEnabled) return
        _scanning = true; _networks = []
        scanProc.command = ["bash", "-c",
            "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list " +
            (rescan ? "--rescan yes" : "--rescan no") + " 2>/dev/null"]
        scanProc.running = false; scanProc.running = true
    }

    function _disconnect() {
        actionProc.command = ["bash", "-c",
            "nmcli con down \"$(nmcli -t -f NAME,TYPE con show --active" +
            " | grep ':802-11-wireless' | head -1 | cut -d: -f1)\" 2>/dev/null"]
        actionProc.running = false; actionProc.running = true
    }

    function _forget(ssid) {
        if (actionProc.running) return
        _forgetSsid = ""
        actionProc.command = [
            "bash", "-c",
            "uuid=$(nmcli -g UUID,802-11-wireless.ssid con show 2>/dev/null" +
            " | awk -F: -v s=\"$1\" '$2==s{print $1;exit}');" +
            " [ -n \"$uuid\" ] && nmcli con delete uuid \"$uuid\" 2>/dev/null",
            "--", ssid
        ]
        actionProc.running = false; actionProc.running = true
    }

    function _connectFirst(ssid) {
        _connectingTo = ssid; _expandSsid = ""
        connectProc._ssid = ssid
        connectProc.command = ["bash", "-c",
            "nmcli con up id \"" + ssid + "\" 2>&1 ||" +
            " nmcli dev wifi connect \"" + ssid + "\" 2>&1"]
        connectProc.running = false; connectProc.running = true
    }

    function _connectWithPassword(ssid, password) {
        _connectingTo = ssid; _expandSsid = ""
        var np = Object.assign({}, root._needsPassword)
        delete np[ssid]
        root._needsPassword = np
        passProc.command = ["bash", "-c",
            "nmcli dev wifi connect \"" + ssid + "\" password \"" + password + "\" 2>/dev/null"]
        passProc.running = false; passProc.running = true
    }

    Component.onCompleted: { _checkRadio(); _scan(false) }

    // ── Components ────────────────────────────────────────────────────────────

    component ScanRings: Item {
        id: ringsRoot
        property string centerGlyph: "󰤨"
        property int    glyphSize:   18
        Repeater {
            model: 4
            delegate: Rectangle {
                required property int index
                anchors.centerIn: parent
                width: ringsRoot.width; height: ringsRoot.width; radius: ringsRoot.width / 2
                color: "transparent"
                border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.80)
                border.width: 1.5; opacity: 0; scale: 0.08
                SequentialAnimation {
                    running: root._scanning; loops: Animation.Infinite
                    PauseAnimation { duration: index * 650 }
                    ParallelAnimation {
                        NumberAnimation { property: "scale";   from: 0.08; to: 1.0; duration: 2200; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "opacity"; from: 0.80; to: 0.0; duration: 2200; easing.type: Easing.OutQuad  }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent; text: ringsRoot.centerGlyph; font.pixelSize: ringsRoot.glyphSize
            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
            SequentialAnimation on opacity {
                running: root._scanning; loops: Animation.Infinite
                NumberAnimation { to: 0.20; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.80; duration: 700; easing.type: Easing.InOutSine }
            }
        }
    }

    component SignalBars: Item {
        id: barsRoot
        required property int signal
        width: 18; height: 14
        Row {
            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; spacing: 2
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: 3; height: 4 + index * 3; radius: 1; anchors.bottom: parent?.bottom
                    readonly property bool lit: {
                        switch (index) {
                            case 0: return barsRoot.signal > 0
                            case 1: return barsRoot.signal > 25
                            case 2: return barsRoot.signal > 50
                            case 3: return barsRoot.signal > 75
                        }; return false
                    }
                    color: lit ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.85) : Qt.rgba(1,1,1,0.15)
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }
    }

    component NetworkRow: Item {
        id: netRow
        required property var  net
        required property bool isCurrent
        readonly property bool isForgetPending: root._forgetSsid   === net.ssid
        readonly property bool isExpanded:      root._expandSsid   === net.ssid
        readonly property bool isConnecting:    root._connectingTo === net.ssid
        readonly property bool needsPassword:   !!root._needsPassword[net.ssid]
        width: parent?.width ?? 0
        height: baseRow.height + expandArea.height

        Rectangle {
            anchors.fill: parent; radius: Theme.cornerRadius
            color: netRow.isCurrent
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.07)
                : rHov.hovered ? Qt.rgba(1,1,1,0.04) : "transparent"
            border.color: netRow.isCurrent
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                : netRow.needsPassword
                    ? Qt.rgba(245/255,196/255,122/255,0.30)
                    : Qt.rgba(1,1,1,0.06)
            border.width: 1
            Behavior on color        { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }

        Item {
            id: baseRow
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 48

            Column {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 3
                Text {
                    text: netRow.net.ssid; font.pixelSize: 13
                    font.weight: netRow.isCurrent ? Font.Medium : Font.Normal
                    color: netRow.isCurrent ? Theme.text : Qt.rgba(1,1,1,0.7)
                    width: 170; elide: Text.ElideRight
                }
                Text {
                    visible: netRow.needsPassword && !netRow.isCurrent
                    text: "Password required"; font.pixelSize: 10
                    color: Qt.rgba(245/255,196/255,122/255,0.80)
                }
                Text { visible: netRow.isCurrent; text: "Connected"; font.pixelSize: 10; color: Theme.active }
            }

            Row {
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 6

                Text {
                    visible: netRow.net.secured && !netRow.isCurrent
                    text: "󰌾"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.28)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item {
                    width: 22; height: 16; anchors.verticalCenter: parent.verticalCenter
                    SignalBars { anchors.centerIn: parent; signal: netRow.net.signal }
                }
                Item {
                    visible: netRow.isConnecting; width: 20; height: 20; anchors.verticalCenter: parent.verticalCenter
                    Text {
                        anchors.centerIn: parent; text: "○"; font.pixelSize: 14; color: Theme.active
                        SequentialAnimation on opacity {
                            running: netRow.isConnecting; loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }
                }
                // Disconnect
                Item {
                    visible: netRow.isCurrent; width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
                    Rectangle { anchors.fill: parent; radius: 6; color: dH.hovered ? Qt.rgba(1,1,1,0.10) : "transparent"; Behavior on color { ColorAnimation { duration: 100 } } }
                    Text { anchors.centerIn: parent; text: "󰖪"; font.pixelSize: 14; color: dH.hovered ? Qt.rgba(1,1,1,0.65) : Qt.rgba(1,1,1,0.35); Behavior on color { ColorAnimation { duration: 100 } } }
                    HoverHandler { id: dH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root._disconnect() }
                }
                // Forget
                Item {
                    visible: netRow.isCurrent; width: 28; height: 28; anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        anchors.fill: parent; radius: 6
                        color: fH.hovered ? Qt.rgba(248/255,113/255,113/255,0.15) : netRow.isForgetPending ? Qt.rgba(248/255,113/255,113/255,0.10) : "transparent"
                        Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Text { anchors.centerIn: parent; text: "󰗼"; font.pixelSize: 13; color: (fH.hovered || netRow.isForgetPending) ? "#f87171" : Qt.rgba(1,1,1,0.3); Behavior on color { ColorAnimation { duration: 100 } } }
                    HoverHandler { id: fH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root._forgetSsid = netRow.isForgetPending ? "" : netRow.net.ssid }
                }
                // Connect
                Rectangle {
                    visible: !netRow.isCurrent && !netRow.isConnecting
                    anchors.verticalCenter: parent.verticalCenter
                    width: connectLbl.implicitWidth + 20; height: 28; radius: 8
                    color: conH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.09)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35); border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { id: connectLbl; anchors.centerIn: parent; text: netRow.isExpanded ? "Retry" : "Connect"; font.pixelSize: 11; font.weight: Font.Medium; color: Theme.active }
                    HoverHandler { id: conH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            root._forgetSsid = ""
                            if (netRow.isExpanded && passInput.text !== "")
                                root._connectWithPassword(netRow.net.ssid, passInput.text)
                            else
                                root._connectFirst(netRow.net.ssid)
                        }
                    }
                }
            }
        }

        Item {
            id: expandArea
            anchors { top: baseRow.bottom; left: parent.left; right: parent.right }
            clip: true
            height: netRow.isForgetPending ? forgetRow.implicitHeight + 16 : netRow.isExpanded ? passRow.implicitHeight + 16 : 0
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Item {
                id: forgetRow
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                implicitHeight: 32
                opacity: netRow.isForgetPending ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Rectangle {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    radius: 8; color: Qt.rgba(248/255,113/255,113/255,0.07)
                    border.color: Qt.rgba(248/255,113/255,113/255,0.22); border.width: 1
                    Row {
                        anchors.centerIn: parent; spacing: 12
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Forget this network?"; font.pixelSize: 11; color: Qt.rgba(1,1,1,0.55) }
                        Rectangle {
                            width: 54; height: 24; radius: 6; color: cfH.hovered ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.04)
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "Cancel"; font.pixelSize: 10; color: Qt.rgba(1,1,1,0.45) }
                            HoverHandler { id: cfH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._forgetSsid = "" }
                        }
                        Rectangle {
                            width: 54; height: 24; radius: 6
                            color: ffH.hovered ? Qt.rgba(248/255,113/255,113/255,0.35) : Qt.rgba(248/255,113/255,113/255,0.18)
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text { anchors.centerIn: parent; text: "Forget"; font.pixelSize: 10; font.weight: Font.Medium; color: "#f87171" }
                            HoverHandler { id: ffH; cursorShape: Qt.PointingHandCursor }
                            MouseArea { anchors.fill: parent; onClicked: root._forget(netRow.net.ssid) }
                        }
                    }
                }
            }

            Item {
                id: passRow
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 8 }
                implicitHeight: 40
                opacity: netRow.isExpanded ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Row {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 8
                    Rectangle {
                        width: parent.width - parent.spacing; height: 32; radius: 8
                        color: Qt.rgba(1,1,1,0.06)
                        border.color: passInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55) : Qt.rgba(1,1,1,0.12)
                        border.width: 1; Behavior on border.color { ColorAnimation { duration: 120 } }
                        Text { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                        text: "Password…"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.22); visible: passInput.text === "" }
                        TextInput {
                            id: passInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter; color: Theme.text; font.pixelSize: 12
                            echoMode: TextInput.Password
                            selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35); clip: true
                            Keys.onReturnPressed: { if (text.length > 0) root._connectWithPassword(netRow.net.ssid, text) }
                        }
                    }
                }
            }

            onVisibleChanged: { if (visible && netRow.isExpanded) Qt.callLater(function() { passInput.forceActiveFocus() }) }
        }

        onIsExpandedChanged: {
            if (isExpanded) Qt.callLater(function() { passInput.forceActiveFocus() })
            else            passInput.text = ""
        }

        HoverHandler { id: rHov; enabled: !netRow.isCurrent }
    }

    // ── Layout — Column fills root, overlay is z:2 sibling ───────────────────
    Column {
        anchors.fill: parent; spacing: 0

        Item {
            width: parent.width; height: 40
            Text { anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
            text: "Wi-Fi"; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.text }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 8

                Rectangle {
                    width: 32; height: 32; radius: 8
                    color: wfPwrH.hovered ? (root._wifiEnabled ? Qt.rgba(248/255,113/255,113/255,0.18) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)) : Qt.rgba(1,1,1,0.04)
                    border.color: root._wifiEnabled ? Qt.rgba(1,1,1,0.10) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30)
                    border.width: 1
                    Behavior on color        { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: "⏻"; font.pixelSize: 14; color: root._wifiEnabled ? (wfPwrH.hovered ? "#f87171" : Qt.rgba(1,1,1,0.32)) : Theme.active; Behavior on color { ColorAnimation { duration: 120 } } }
                    HoverHandler { id: wfPwrH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root._setWifiEnabled(!root._wifiEnabled) }
                }

                Rectangle {
                    width: 32; height: 32; radius: 8
                    color: settH.hovered ? Qt.rgba(1,1,1,0.09) : Qt.rgba(1,1,1,0.03)
                    border.color: Qt.rgba(1,1,1,0.10); border.width: 1; Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "󰒓"; font.pixelSize: 14; color: settH.hovered ? Qt.rgba(1,1,1,0.75) : Qt.rgba(1,1,1,0.30); Behavior on color { ColorAnimation { duration: 100 } } }
                    HoverHandler { id: settH; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: { nmtuiProc.running = false; nmtuiProc.running = true } }
                }

                Rectangle {
                    width: 32; height: 32; radius: 8
                    color: rfH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.15) : Qt.rgba(1,1,1,0.05)
                    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28); border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        id: rfIcon; anchors.centerIn: parent; text: "󰑐"; font.pixelSize: 15
                        color: root._scanning ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4) : (root._wifiEnabled ? Theme.active : Qt.rgba(1,1,1,0.18))
                        Behavior on color { ColorAnimation { duration: 150 } }
                        RotationAnimator { target: rfIcon; from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root._scanning; easing.type: Easing.Linear }
                    }
                    HoverHandler { id: rfH; cursorShape: root._wifiEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    MouseArea { anchors.fill: parent; onClicked: if (!root._scanning && root._wifiEnabled) root._scan(true) }
                }
            }
        }

        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }
        Item      { width: parent.width; height: 8 }

        Flickable {
            id: flick; width: parent.width; height: parent.height - 49
            contentWidth: width; contentHeight: contentCol.height; clip: true; boundsBehavior: Flickable.StopAtBounds
            Column {
                id: contentCol; width: flick.width; height: implicitHeight; spacing: 4

                Item { width: parent.width; height: visible ? sLbl1.implicitHeight + 4 : 0; visible: root._current !== null
                    Text { id: sLbl1; text: "CONNECTED"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5) } }

                NetworkRow { visible: root._current !== null; width: parent.width - 2; x: 1; net: root._current ?? { ssid: "", signal: 0, secured: false, inUse: true }; isCurrent: true }

                Item { width: parent.width; height: 10; visible: root._current !== null && root._available.length > 0 }

                Item { width: parent.width; height: visible ? sLbl2.implicitHeight + 4 : 0; visible: root._available.length > 0
                    Text { id: sLbl2; text: "AVAILABLE"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Qt.rgba(1,1,1,0.25) } }

                Repeater {
                    model: root._available
                    delegate: NetworkRow { required property var modelData; width: contentCol.width - 2; x: 1; net: modelData; isCurrent: false }
                }

                Item {
                    width: parent.width; height: 160
                    visible: !root._scanning && root._networks.length === 0 && root._wifiEnabled
                    Column { anchors.centerIn: parent; spacing: 10
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰤭"; font.pixelSize: 34; color: Qt.rgba(1,1,1,0.08) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No networks found"; font.pixelSize: 12; color: Qt.rgba(1,1,1,0.2) } }
                }

                Item {
                    width: parent.width; height: 160
                    visible: root._scanning && root._networks.length === 0
                    ScanRings { anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 12 }
                    width: 96; height: 96; centerGlyph: "󰤨"; glyphSize: 18 }
                    Text { anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
                    text: "Scanning…"; font.pixelSize: 11; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.5) }
                }

                Item { width: parent.width; height: 8 }
            }
        }
    }

    // ── WiFi off overlay — covers list area only, stops at parent bounds ─────
    Item {
        anchors {
            fill:      parent
            topMargin: 49   // below header 40 + divider 1 + gap 8
        }
        visible: !root._wifiEnabled
        z: 2

        Rectangle { anchors.fill: parent; color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.95) }

        Column {
            anchors.centerIn: parent; spacing: 16
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰤭"; font.pixelSize: 42; color: Qt.rgba(1,1,1,0.12) }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Wi-Fi is off"; font.pixelSize: 14; font.weight: Font.Medium; color: Qt.rgba(1,1,1,0.30) }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: wfEnRow.implicitWidth + 24; height: 34; radius: 17
                color: wfEnH.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12)
                border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.40); border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                Row { id: wfEnRow; anchors.centerIn: parent; spacing: 8
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "󰤨"; font.pixelSize: 14; color: Theme.active }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Turn On"; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.active }
                }
                HoverHandler { id: wfEnH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root._setWifiEnabled(true) }
            }
        }
    }
}
