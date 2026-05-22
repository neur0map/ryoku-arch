    pragma Singleton
    import Quickshell
    import Quickshell.Io
    import QtQuick

    Singleton {
        id: root

        readonly property list<Connection> connections: []
        readonly property list<string> savedNetworks: []
        readonly property Connection active: connections.find(c => c.active) ?? null

        property bool wifiEnabled: true
        readonly property bool scanning: rescanProc.running
        readonly property bool connecting: connectProc.running

        property string lastNetworkAttempt: ""
        property string lastErrorMessage: ""
        property string message: ""

        readonly property string icon: {
            if (!active) return "󰤭";
            if (active.type === "ethernet") return "󰈀";

            if (active.strength >= 75) return "󰤨";
            else if (active.strength >= 50) return "󰤥";
            else if (active.strength >= 25) return "󰤢";
            else return "󰤟";
        }

        readonly property string wifiLabel: {
            const activeWifi = connections.find(c => c.active && c.type === "wifi");
            if (activeWifi) return activeWifi.name;
            return "Wi-Fi";
        }

        readonly property string wifiStatus: {
            const activeWifi = connections.find(c => c.active && c.type === "wifi");
            if (activeWifi) return "Connected";
            if (wifiEnabled) return "On";
            return "Off";
        }

        readonly property string label: {
            if (active) return active.name;
            if (wifiEnabled) return "Wi-Fi";
            return "Wi-Fi";
        }

        readonly property string status: {
            if (active) return "Connected";
            if (wifiEnabled) return "On";
            return "Off";
        }

        function enableWifi(enabled: bool): void {
            enableWifiProc.exec(["nmcli", "radio", "wifi", enabled ? "on" : "off"]);
        }

        function toggleWifi(): void {
            enableWifi(!wifiEnabled);
        }

        function rescan(): void {
            rescanProc.running = true;
        }

        function connect(connection: Connection, password: string): void {
            if (connection.type === "wifi") {
                root.lastNetworkAttempt = connection.name;
                root.lastErrorMessage = "";
                root.message = "";

                if (password && password.length > 0) {
                    connectProc.exec(["nmcli", "dev", "wifi", "connect", connection.name, "password", password]);
                } else {
                    connectProc.exec(["nmcli", "dev", "wifi", "connect", connection.name]);
                }
            } else if (connection.type === "ethernet") {
                ethConnectProc.exec(["nmcli", "connection", "up", connection.uuid]);
            }
        }

        function forget(name: string): void {
            forgetProc.exec(["nmcli", "connection", "delete", name])
        }

        function disconnect():void {
            if (!active) return;

            if (active.type === "wifi") {
                disconnectProc.exec(["nmcli", "connection", "down", active.name]);
            } else {
                ethDisconnectProc.exec(["nmcli", "connection", "down", active.uuid]);
            }
        }

        function getWifiStatus(): void {
            wifiStatusProc.running = true;
        }

        function updateConnections(): void {
            getSavedNetworks.running = true;
        }

        function mergeConnections(newConns: var, connType: string): void {
            const rConns = root.connections;
            const destroyed = rConns.filter(rc => rc.type === connType && !newConns.find(nc =>
                    connType === "wifi" ? (nc.frequency === rc.frequency && nc.name === rc.name && nc.bssid === rc.bssid)
                    : nc.uuid === rc.uuid
            ));

            for (const conn of destroyed)
        rConns.splice(rConns.indexOf(conn), 1).forEach(c => c.destroy());

        for (const conn of newConns) {
            const match = rConns.find(c =>
                    connType === "wifi" ? (c.frequency === conn.frequency && c.name === conn.name && c.bssid === conn.bssid)
                    : c.uuid === conn.uuid
            );
            if (match) {
                match.lastIpcObject = conn;
            } else {
                rConns.push(connComp.createObject(root, { lastIpcObject: conn }));
            }
        }
    }


    Process {
            id: wifiStatusProc
            running: true
            command: ["nmcli", "radio", "wifi"]
            environment: ({LANG: "C.UTF-8", LC_ALL: "C.UTF-8"})
            stdout: StdioCollector {
                onStreamFinished: {
                    root.wifiEnabled = text.trim() === "enabled"
                    if (!root.wifiEnabled) {
                        root.lastErrorMessage = "";
                        root.message = "";
                        root.lastNetworkAttempt = "";
                    }
                }
            }
        }

        Process {
            id: enableWifiProc;
            onExited: {
                getWifiStatus();
                updateConnections();
            }
        }

        Process {
            id: rescanProc
            command: ["nmcli", "dev", "wifi", "list", "--rescan", "yes"]
            onExited: updateConnections()
        }

        Process {
            id: connectProc
            stdout: StdioCollector { }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.includes("Error") || text.includes("incorrect")) {
                        root.lastErrorMessage = "Incorrect password";
                    }
                }
            }
            onExited: {
                if (exitCode === 0) {
                    root.message = "ok";
                    root.lastErrorMessage = "";
                } else {
                    root.message = root.lastErrorMessage !== "" ? root.lastErrorMessage : "Connection failed";
                }
                updateConnections();
            }
        }

        Process {
            id: forgetProc
            onExited: updateConnections()
        }

        Process {
            id: disconnectProc;
            onExited: updateConnections();
        }

        Process {
            id: ethConnectProc;
            onExited: updateConnections();
        }

        Process {
            id: ethDisconnectProc;
            onExited: updateConnections();
        }

        Process {
            id: getSavedNetworks;
            running: true;
            command: ["nmcli", "-g", "NAME,TYPE", "connection", "show"]
            environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\n")
                    const wifiConnections = lines
                        .map(line =>  line.split(":"))
                        .filter(parts => parts[1] === "802-11-wireless")
                        .map(parts => parts[0]);
                    root.savedNetworks = wifiConnections;
                }
            }
            onExited: {
                getWifiNetworks.running = true;
                getEthConnections.running = true;
            }
        }

        Process {
            id: getWifiNetworks
            running: true
            command: ["nmcli", "-g", "ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY", "d", "w"]
            environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
            stdout: StdioCollector {
                onStreamFinished: {
                    const PLACEHOLDER = "STRINGWHICHHOPEFULLYWONTBEUSED";
                    const rep = new RegExp("\\\\:", "g");
                    const rep2 = new RegExp(PLACEHOLDER, "g");

                    const allNetworks = text.trim().split("\n").map(n => {
                        const net = n.replace(rep, PLACEHOLDER).split(":");
                        return {
                            type: "wifi",
                            active: net[0] === "yes",
                            strength: parseInt(net[1]),
                            frequency: parseInt(net[2]),
                            name: net[3]?.replace(rep2, ":") ?? "",
                            bssid: net[4]?.replace(rep2, ":") ?? "",
                            security: net[5] ?? "",
                            saved: root.savedNetworks.includes(net[3] ?? ""),
                            uuid: "",
                            device: ""
                        };
                    }).filter(n => n.name && n.name.length > 0);

                    const networkMap = new Map();
                    for (const network of allNetworks) {
                        const existing = networkMap.get(network.name);
                        if (!existing) {
                            networkMap.set(network.name, network);
                        } else {
                            if (network.active && !existing.active) {
                                networkMap.set(network.name, network);
                            } else if (!network.active && !existing.active && network.strength > existing.strength) {
                                networkMap.set(network.name, network);
                            }
                        }
                    }

                    mergeConnections(Array.from(networkMap.values()), "wifi");
                }
            }
        }

        Process {
            id: getEthConnections
            running: true
            command: ["nmcli", "-g", "NAME,UUID,TYPE,DEVICE,STATE", "connection", "show"]
            environment: ({ LANG: "C.UTF-8", LC_ALL: "C.UTF-8" })
            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\n");
                    const ethConns = lines
                        .map(line => line.split(":"))
                        .filter(parts => parts[2] === "802-3-ethernet" || parts[2] === "gsm" || parts[2] === "bluetooth")
                        .map(parts => ({
                        type: "ethernet",
                        name: parts[0],
                        uuid: parts[1],
                        device: parts[3],
                        active: parts[4] === "activated",
                        strength: 100,
                        frequency: 0,
                        bssid: "",
                        security: "",
                        saved: true
                    }));

                    mergeConnections(ethConns, "ethernet");
                }
            }
        }

        component Connection: QtObject {
            required property var lastIpcObject
            readonly property string type: lastIpcObject.type
            readonly property string name: lastIpcObject.name
            readonly property string uuid: lastIpcObject.uuid
            readonly property string device: lastIpcObject.device
            readonly property bool active: lastIpcObject.active
            readonly property int strength: lastIpcObject.strength
            readonly property int frequency: lastIpcObject.frequency
            readonly property string bssid: lastIpcObject.bssid
            readonly property string security: lastIpcObject.security
            readonly property bool isSecure: security.length > 0
            readonly property bool saved: lastIpcObject.saved
        }

        Component { id: connComp; Connection { } }

    }