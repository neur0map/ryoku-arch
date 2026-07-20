pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// audio graph for the mixer: classifies Pipewire nodes into output devices,
// input devices, and per-app playback streams; switches the default sink/source
// through the writable preferred-default properties; resolves a stream's app
// name + icon; and reads/sets a Bluetooth sink's codec + profile. Devices.qml
// stays the owner of display (brightness/vibrance); this owns sound. tracks the
// sink, source, and every node it lists so volumes and metadata read live.
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var nodes: (Pipewire.nodes && Pipewire.ready) ? Pipewire.nodes.values : []

    // node type flags as a string, e.g. "AudioSink" / "AudioSource" /
    // "AudioOutStream". constant, so it reads without tracking, unlike
    // properties and live audio which only populate once a node is tracked.
    function typeOf(n) {
        return (n && typeof PwNodeType !== "undefined") ? PwNodeType.toString(n.type) : "";
    }

    // a real, switchable output/input device (not a stream). the ryoku-eq
    // filter-chain sink is internal plumbing, not a user-pickable output:
    // picking it while the chain is down routes @DEFAULT into silence.
    function isOutput(n) { return !!(n && n.isSink && !n.isStream && n.audio && n.name !== "ryoku.eq.sink"); }
    function isInput(n) { return !!(n && !n.isSink && !n.isStream && n.audio); }
    // an application feeding the graph (playback, not capture). per-app here.
    // the ryoku.eq.out node is the equalizer's own output leg, not an app:
    // muting or dropping it in the mixer silences everything routed through the EQ.
    function isPlayStream(n) {
        return !!(n && n.isStream && n.audio && root.typeOf(n).indexOf("In") < 0 && n.name !== "ryoku.eq.out");
    }

    readonly property var outputs: root.nodes.filter(root.isOutput)
    readonly property var inputs: root.nodes.filter(root.isInput)
    readonly property var streams: root.nodes.filter(root.isPlayStream)

    function setOutput(n) { if (n) Pipewire.preferredDefaultAudioSink = n; }
    function setInput(n) { if (n) Pipewire.preferredDefaultAudioSource = n; }

    // track every node we show so its properties (media/app/codec metadata) and
    // live audio (volume, mute) populate. classification above reads only the
    // node's constant flags, so this never deadlocks on untracked properties.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(Boolean)
            .concat(root.outputs).concat(root.inputs).concat(root.streams)
    }

    // --- device presentation ------------------------------------------------

    function nodeLabel(n) {
        if (!n)
            return "";
        var p = n.properties || ({});
        return n.description || n.nickname || p["node.description"] || n.name || "Audio device";
    }

    // a GlyphIcon name for a device, from its bluez-ness / icon hint / port.
    function nodeIcon(n) {
        if (!n)
            return "speaker";
        if (isBluez(n))
            return "headphones";
        var p = n.properties || ({});
        var hint = ((p["device.icon-name"] || "") + " " + (n.name || "")).toLowerCase();
        if (hint.indexOf("headphone") >= 0 || hint.indexOf("headset") >= 0)
            return "headphones";
        if (hint.indexOf("hdmi") >= 0 || hint.indexOf("displayport") >= 0 || hint.indexOf("dp-") >= 0)
            return "monitor";
        if (!n.isSink)
            return "mic";
        return "speaker";
    }

    // --- bluetooth sink: codec, profile, matching device --------------------

    function isBluez(n) {
        if (!n)
            return false;
        var p = n.properties || ({});
        return (p["device.api"] || "") === "bluez5"
            || ((p["factory.name"] || "").indexOf("bluez5") >= 0)
            || ((n.name || "").indexOf("bluez") >= 0);
    }

    // bluez sinks: codec + active profile live on the bluez CARD, not the sink
    // node, so they are scanned from `pactl list cards` whenever the default
    // sink becomes bluez or a profile is toggled. all degrade to empty (chip
    // hidden) without a bluez card.
    property string btCard: ""
    property string btProfile: ""
    property string btCodec: ""

    readonly property bool sinkIsBluez: root.isBluez(root.sink)
    onSinkIsBluezChanged: root.refreshBtCard()
    onSinkChanged: if (root.sinkIsBluez) root.refreshBtCard()

    // MAC from a bluez node name (bluez_output.<MAC>.<profile>), colon-formatted.
    function btMac(n) {
        var m = ((n && n.name) ? n.name : "").match(/bluez_(?:output|input)\.([0-9A-Fa-f_]+)/);
        return m ? m[1].toUpperCase().replace(/_/g, ":") : "";
    }

    function refreshBtCard() {
        if (!root.sinkIsBluez) {
            root.btCard = ""; root.btProfile = ""; root.btCodec = "";
            return;
        }
        cardScan.running = false;
        cardScan.running = true;
    }

    function parseCards(text) {
        var blocks = ("\n" + text).split(/\nCard #\d+/);
        var mac = root.btMac(root.sink).replace(/:/g, "_");
        var card = "", prof = "", codec = "";
        for (var i = 0; i < blocks.length; i++) {
            var nm = /Name:\s*(bluez_card\.\S+)/.exec(blocks[i]);
            if (!nm)
                continue;
            var match = mac.length > 0 && nm[1].toUpperCase().indexOf(mac) >= 0;
            if (match || card.length === 0) {
                var pr = /Active Profile:\s*(\S+)/.exec(blocks[i]);
                var cd = /api\.bluez5\.codec\s*=\s*"?([A-Za-z0-9._-]+)"?/.exec(blocks[i]);
                card = nm[1];
                prof = pr ? pr[1] : "";
                codec = cd ? cd[1] : "";
                if (match)
                    break;
            }
        }
        root.btCard = card;
        root.btProfile = prof.toLowerCase();
        root.btCodec = codec.toUpperCase();
    }

    function isHeadset() {
        var p = root.btProfile;
        return p.indexOf("headset") >= 0 || p.indexOf("hfp") >= 0 || p.indexOf("hsp") >= 0;
    }

    // headset (HSP/HFP) trades fidelity for a mic; a2dp is high-fidelity playback.
    function profileLabel() {
        if (!root.btProfile.length)
            return "";
        if (root.isHeadset())
            return "Headset";
        return root.btProfile.indexOf("a2dp") >= 0 ? "Hi-Fi" : root.btProfile;
    }

    // flip the active bluez card between a2dp playback and headset mode.
    function toggleProfile() {
        if (!root.btCard.length)
            return;
        var target = root.isHeadset() ? "a2dp-sink" : "headset-head-unit";
        profileProc.command = ["pactl", "set-card-profile", root.btCard, target];
        profileProc.running = false;
        profileProc.running = true;
    }

    // the BlueZ device backing the active bluez sink, for its battery: matched
    // by MAC from the node name, else the first connected audio device.
    function btDeviceFor(n) {
        if (!root.isBluez(n) || typeof Bluetooth === "undefined" || !Bluetooth || !Bluetooth.devices)
            return null;
        var devs = Bluetooth.devices.values;
        var mac = root.btMac(n);
        for (var i = 0; i < devs.length; i++)
            if (devs[i] && ((devs[i].address || "") + "").toUpperCase() === mac)
                return devs[i];
        for (var j = 0; j < devs.length; j++)
            if (devs[j] && devs[j].connected && devs[j].batteryAvailable)
                return devs[j];
        return null;
    }

    function batteryOf(n) {
        var d = btDeviceFor(n);
        if (!d || !d.batteryAvailable)
            return -1;
        var b = d.battery;
        if (b === undefined || b === null || b <= 0)
            return -1;
        if (b <= 1)
            b = b * 100;
        return Math.round(b);
    }

    // --- per-app stream presentation ----------------------------------------

    function streamName(n) {
        var p = (n && n.properties) ? n.properties : ({});
        return p["application.name"] || p["media.name"] || (n ? n.description : "") || "Application";
    }

    function streamIcon(n) {
        var p = (n && n.properties) ? n.properties : ({});
        var named = (p["application.icon-name"] || "") + "";
        if (named.length) {
            var direct = Quickshell.iconPath(named, true);
            if (direct.length)
                return direct;
        }
        var bin = ((p["application.process.binary"] || p["application.name"] || "") + "").toLowerCase();
        if (bin.length) {
            var e = (typeof DesktopEntries !== "undefined" && DesktopEntries.heuristicLookup)
                ? DesktopEntries.heuristicLookup(bin) : null;
            if (e && e.icon)
                return Quickshell.iconPath(e.icon, "application-x-executable");
            var byBin = Quickshell.iconPath(bin, true);
            if (byBin.length)
                return byBin;
        }
        return Quickshell.iconPath("application-x-executable", true);
    }

    Process {
        id: profileProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: root.refreshBtCard()
    }

    Process {
        id: cardScan
        command: ["pactl", "list", "cards"]
        stdout: StdioCollector { onStreamFinished: root.parseCards(this.text) }
    }
}
