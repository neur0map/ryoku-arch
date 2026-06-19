pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Current-conditions poll from wttr.in (auto-located by IP). Exposes a short
 * temperature string, the condition text, and a `glyph` key that maps onto the
 * weather glyphs in GlyphIcon. `available` gates the UI: a failed or offline
 * fetch leaves it false so callers can hide the readout rather than show stale
 * or empty values.
 */
Singleton {
    id: root

    property string temp: ""
    property string condition: ""
    property string glyph: "cloud"
    property bool available: false

    Process {
        id: poll
        command: ["sh", "-c", "curl -s --max-time 10 'https://wttr.in/?format=%t|%C' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = text.trim();
                var bar = out.indexOf("|");
                if (bar < 0) {
                    root.available = false;
                    return;
                }
                var t = out.substring(0, bar).trim().replace("+", "");
                var c = out.substring(bar + 1).trim();
                if (!/-?\d/.test(t) || t.toLowerCase().indexOf("unknown") >= 0 || c.length === 0) {
                    root.available = false;
                    return;
                }
                root.temp = t;
                root.condition = c;
                root.glyph = root.glyphFor(c);
                root.available = true;
            }
        }
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    function glyphFor(c) {
        var s = c.toLowerCase();
        if (s.indexOf("thunder") >= 0 || s.indexOf("storm") >= 0)
            return "storm";
        if (s.indexOf("snow") >= 0 || s.indexOf("sleet") >= 0 || s.indexOf("blizzard") >= 0 || s.indexOf("ice") >= 0)
            return "snow";
        if (s.indexOf("rain") >= 0 || s.indexOf("drizzle") >= 0 || s.indexOf("shower") >= 0)
            return "rain";
        if (s.indexOf("fog") >= 0 || s.indexOf("mist") >= 0 || s.indexOf("haze") >= 0)
            return "fog";
        if (s.indexOf("clear") >= 0 || s.indexOf("sunny") >= 0)
            return "sun";
        return "cloud";
    }
}
