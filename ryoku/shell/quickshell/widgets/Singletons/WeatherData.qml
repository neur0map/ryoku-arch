pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../weather/lib/weather.js" as Model

// live weather for the desktop weather widget, via Open-Meteo (no API key).
// thin fetch wrapper, all the parsing and the WMO-code -> animation-category
// map live in weather/lib/weather.js (node-tested).
//
// location: resolved once via a keyless IP lookup and cached at the same
// ~/.local/state/ryoku/weather-loc.json the pill uses, so the two share one
// lookup. unit follows Ryoku Settings (`unit` = C|F), set by the host;
// changing it refetches so the temperature flips at once.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"

    // set by the host from Config.weatherUnit. refetch on change.
    property string unit: "C"

    // public state for the designs.
    property bool available: false
    property int tempNow: 0
    property string temp: ""
    property int code: 3
    property string condition: ""
    property string category: "clouds"
    property int humidity: 0
    property int wind: 0
    property bool isDay: true
    property string city: ""
    property var daily: []

    property real lat: 0
    property real lon: 0
    property bool located: false
    // set true once construction finishes; the cache FileView's initial
    // blockLoading load fires before ipProc/wxProc exist, so loadLoc must wait.
    property bool ready: false

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
        root.code = f.code;
        root.condition = f.condition;
        root.category = f.category;
        root.humidity = f.humidity;
        root.wind = f.wind;
        root.isDay = f.isDay;
        root.daily = f.daily;
        root.available = true;
    }

    // load the resolved location from the shared cache the pill authoritatively
    // writes (keyed by the explicit weatherLocation), so a location change in
    // Settings reaches the desktop weather widget live and across restarts.
    function loadLoc() {
        if (!root.ready)
            return;
        var c = Model.parseJson(locCache.text());
        if (!c || typeof c.lat !== "number" || typeof c.lon !== "number")
            return;
        if (root.located && c.lat === root.lat && c.lon === root.lon)
            return;
        root.city = c.city || "";
        root.lat = c.lat;
        root.lon = c.lon;
        root.located = true;
        root.fetchWeather();
    }

    onUnitChanged: fetchWeather();

    Component.onCompleted: {
        root.ready = true;
        root.loadLoc();
        // no cache yet (fresh profile): locate by IP for this session. The pill
        // owns the shared cache and is its only writer, so the widget never
        // clobbers the explicit-location resolution.
        if (!root.located)
            ipProc.running = true;
    }

    // ensure the shared state dir exists (the pill writes weather-loc.json here).
    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: locCache
        path: root.stateDir + "/weather-loc.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loadLoc()
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
            + "&current=temperature_2m,weather_code,is_day,relative_humidity_2m,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=7"
            + "&timezone=auto&temperature_unit=" + Model.unitParam(root.unit)]
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
