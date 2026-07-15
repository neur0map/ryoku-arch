import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import "../../lib/radio.js" as RadioLib
import ".."

// Live-radio provider on the "@" prefix: "@" lists the stations, "@lofi" tunes
// Lofi Girl in, "@stop" tunes out. Rows come from the engine's station catalog
// crossed with the Radio singleton's live status, so the playing station leads
// with Stop, an aside one leads with Resume, and the fallback promise is
// spelled out before the first note plays. Enter runs the row's primary verb.
Provider {
    id: tuner

    providerId: "radio"
    prefix: "@"
    defaultProvider: false

    property var stations: []

    function rowFor(r) {
        var acts = [];
        if (r.verb === "stop")
            acts.push({ name: "Stop", icon: "", execute: function () { Radio.stop(); } });
        else if (r.verb === "resume")
            acts.push({ name: "Resume", icon: "", execute: function () { Radio.resume(); } });
        else
            acts.push({ name: "Tune in", icon: "", execute: (function (id) {
                return function () { Radio.start(id); };
            })(r.id) });
        return {
            id: "radio:" + r.id,
            title: r.on ? "LIVE · " + r.label : r.label,
            subtitle: r.note,
            icon: "",
            type: "Radio",
            score: r.score,
            actions: acts
        };
    }

    function query(text) {
        var t = (text || "").trim();
        // "@stop" / "@off" tunes out — or lets a parked station go — from
        // anywhere, no list browsing needed; "@resume" picks a parked one up.
        if (t === "stop" || t === "off") {
            if (Radio.on)
                return [{
                    id: "radio:stop",
                    title: "Stop the radio",
                    subtitle: Radio.tuning ? Radio.label + " is tuning in" : "LIVE · " + Radio.label + " is on air",
                    icon: "",
                    type: "Radio",
                    score: -30,
                    actions: [{ name: "Stop", icon: "", execute: function () { Radio.stop(); } }]
                }];
            if (Radio.aside)
                return [{
                    id: "radio:dismiss",
                    title: "Let the parked radio go",
                    subtitle: (Radio.aside.label || "the radio") + " is set aside",
                    icon: "",
                    type: "Radio",
                    score: -30,
                    actions: [{ name: "Dismiss", icon: "", execute: function () { Radio.stop(); } }]
                }];
        }
        if (t === "resume" && Radio.aside && !Radio.on)
            return [{
                id: "radio:resume",
                title: "Resume " + (Radio.aside.label || "the radio"),
                subtitle: "set aside for your music",
                icon: "",
                type: "Radio",
                score: -30,
                actions: [{ name: "Resume", icon: "", execute: function () { Radio.resume(); } }]
            }];
        var status = {
            on: Radio.on,
            station: Radio.station,
            fellBack: Radio.fellBack,
            tuning: Radio.tuning,
            aside: Radio.aside
        };
        var rows = RadioLib.stationRows(tuner.stations, t, status);
        var out = [];
        for (var i = 0; i < rows.length; i++)
            out.push(rowFor(rows[i]));
        return out;
    }

    // the station catalog never changes at runtime; one read at load.
    Process {
        id: stationsProc
        running: true
        command: ["ryoku-cmd-radio", "stations"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = text.split("\n").filter(l => l.trim().length > 0);
                try {
                    for (const l of lines)
                        rows.push(JSON.parse(l));
                    tuner.stations = rows;
                    Dispatcher.notifyAsync();
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: Dispatcher.register(tuner)
}
