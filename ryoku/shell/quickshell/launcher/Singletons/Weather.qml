pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/weather.js" as Model

// live weather for the pill's hover glance + the calendar footer. Open-Meteo,
// no API key. location resolves once via a keyless IP lookup, cached at
// ~/.local/state/ryoku/weather-loc.json so a restart skips the coord round-trip.
// replaced the old wttr.in scrape (rate-limited, re-located on every poll).
// public contract = temp / condition / glyph / available, unchanged. hourly /
// daily / humidity / city for richer panes. all parsing + the WMO-code ->
// glyph/label map live in lib/weather.js (unit-tested under node); this
// singleton just fetches and assigns. unit follows the locale (F for US/LR/MM,
// C elsewhere), matching the old IP-located feel.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"
    readonly property string unit: Model.unitFor(Quickshell.env("LC_MEASUREMENT") || Quickshell.env("LANG") || "")

    // public contract, identical to the old wttr.in version.
    property string temp: ""
    property string condition: ""
    property string glyph: "cloud"
    property bool available: false

    // richer data, ready for an hourly / 5-day pane.
    property int tempNow: 0
    property int humidity: 0
    property bool isDay: true
    property int sunrise: -1
    property int sunset: -1
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
        root.sunrise = f.sunrise;
        root.sunset = f.sunset;
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

    // fresh profile may not have the state dir; mkdir before writeLoc touches it.
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
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset&forecast_days=5"
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
