pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/weather.js" as Model

/**
 * Live weather for the pill's hover glance and the calendar footer, served by
 * Open-Meteo (no API key). The location resolves once via a keyless IP lookup and
 * is cached at ~/.local/state/ryoku/weather-loc.json, so a restart skips the
 * round-trip for coordinates. This replaces the previous wttr.in scrape, which
 * was rate-limited and re-located on every poll. The public contract is
 * unchanged: `temp`, `condition`, `glyph`, `available`; `hourly`/`daily`/
 * `humidity`/`city` are exposed for richer panes. All parsing and the WMO-code ->
 * glyph/label mapping live in lib/weather.js (unit-tested under node); this
 * singleton only fetches and assigns. The temperature unit follows the locale
 * (Fahrenheit for US/LR/MM, Celsius elsewhere), matching the old IP-located feel.
 */
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"
    readonly property string unit: Model.unitFor(Quickshell.env("LC_MEASUREMENT") || Quickshell.env("LANG") || "")

    // Public contract, identical to the previous wttr.in version.
    property string temp: ""
    property string condition: ""
    property string glyph: "cloud"
    property bool available: false

    // Richer data, ready for an hourly/5-day pane.
    property int tempNow: 0
    property int humidity: 0
    property bool isDay: true
    property string city: ""
    property var hourly: []
    property var daily: []

    property real lat: 0
    property real lon: 0
    property bool located: false

    function fetchWeather() {
        if (!root.located || wxProc.running)
            return;
        wxProc.running = true;
    }

    function applyForecast(text) {
        var f = Model.parseForecast(Model.parseJson(text), root.unit);
        if (!f.available)
            return;
        root.tempNow = f.tempNow;
        root.temp = f.temp;
        root.condition = f.condition;
        root.glyph = f.glyph;
        root.humidity = f.humidity;
        root.isDay = f.isDay;
        root.hourly = f.hourly;
        root.daily = f.daily;
        root.available = true;
    }

    function writeLoc() {
        locCache.setText(JSON.stringify({ city: root.city, lat: root.lat, lon: root.lon }));
    }

    Component.onCompleted: {
        var c = Model.parseJson(locCache.text());
        if (c && typeof c.lat === "number" && typeof c.lon === "number") {
            root.city = c.city || "";
            root.lat = c.lat;
            root.lon = c.lon;
            root.located = true;
            root.fetchWeather();
        } else {
            ipProc.running = true;
        }
    }

    // The state dir may not exist on a fresh profile; create it before writeLoc.
    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: locCache
        path: root.stateDir + "/weather-loc.json"
        blockLoading: true
        printErrors: false
    }

    Process {
        id: ipProc
        command: ["curl", "-s", "--max-time", "8", "http://ip-api.com/json/?fields=status,city,lat,lon"]
        stdout: StdioCollector {
            onStreamFinished: {
                var loc = Model.parseLoc(Model.parseJson(this.text));
                if (loc) {
                    root.city = loc.city;
                    root.lat = loc.lat;
                    root.lon = loc.lon;
                    root.located = true;
                    root.writeLoc();
                    root.fetchWeather();
                }
            }
        }
    }

    Process {
        id: wxProc
        command: ["curl", "-s", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.lat
            + "&longitude=" + root.lon
            + "&current=temperature_2m,weather_code,is_day,relative_humidity_2m"
            + "&hourly=temperature_2m,weather_code&forecast_hours=24"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=5"
            + "&timezone=auto&temperature_unit=" + root.unit]
        stdout: StdioCollector {
            onStreamFinished: root.applyForecast(this.text)
        }
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }
}
