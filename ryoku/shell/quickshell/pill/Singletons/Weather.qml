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
// daily / humidity / wind / feels / city for richer panes. all parsing + WMO-code ->
// glyph/label map live in lib/weather.js (unit-tested under node); this
// singleton just fetches and assigns. unit follows the locale (F for US/LR/MM,
// C elsewhere), matching the old IP-located feel.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"
    readonly property string unit: {
        var u = Config.weatherUnit;
        return (u === "celsius" || u === "fahrenheit") ? u
            : Model.unitFor(Quickshell.env("LC_MEASUREMENT") || Quickshell.env("LANG") || "");
    }

    // public contract, identical to the old wttr.in version.
    property string temp: ""
    property string condition: ""
    property string glyph: "cloud"
    property bool available: false

    // richer data, ready for an hourly / 5-day pane.
    property int tempNow: 0
    property int humidity: 0
    property int wind: 0
    property int feels: 0
    property bool isDay: true
    property string city: ""
    property var hourly: []
    property var daily: []

    property real lat: 0
    property real lon: 0
    property bool located: false
    // the unit a fetch was requested in, so applyForecast formats with the SAME
    // unit the data came back in even if the setting changed mid-request; a unit
    // change while a fetch is in flight queues one more via pendingFetch.
    property string fetchUnit: ""
    property bool pendingFetch: false

    function fetchWeather() {
        if (!root.located)
            return;
        if (wxProc.running) {
            root.pendingFetch = true;
            return;
        }
        root.fetchUnit = root.unit;
        wxProc.running = true;
    }

    function applyForecast(text) {
        var f = Model.parseForecast(Model.parseJson(text), root.fetchUnit);
        if (!f.available)
            return;
        root.tempNow = f.tempNow;
        root.temp = f.temp;
        root.condition = f.condition;
        root.glyph = f.glyph;
        root.humidity = f.humidity;
        root.wind = f.wind;
        root.feels = f.feels;
        root.isDay = f.isDay;
        root.hourly = f.hourly;
        root.daily = f.daily;
        root.available = true;
    }

    function writeLoc() {
        locCache.setText(JSON.stringify({ query: Config.weatherLocation, city: root.city, lat: root.lat, lon: root.lon }));
    }

    // resolve coords: an explicit Config.weatherLocation wins (geocoded), else the
    // cached coords for the same query, else an IP lookup. the cache is keyed by
    // the query, so a restart skips the round-trip only while the location is
    // unchanged.
    function resolveLocation() {
        var target = Config.weatherLocation.trim();
        var c = Model.parseJson(locCache.text());
        if (c && c.query === target && typeof c.lat === "number" && typeof c.lon === "number") {
            root.city = c.city || "";
            root.lat = c.lat;
            root.lon = c.lon;
            root.located = true;
            root.fetchWeather();
            return;
        }
        if (target.length > 0)
            geoProc.running = true;
        else
            ipProc.running = true;
    }

    Component.onCompleted: root.resolveLocation()
    // a unit change needs a re-fetch: Open-Meteo returns the temperature already
    // in the requested unit, so the value, not just the symbol, changes.
    onUnitChanged: if (root.located) root.fetchWeather()

    Connections {
        target: Config
        function onWeatherLocationChanged() { root.located = false; root.resolveLocation(); }
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

    // geocode an explicit location via Open-Meteo's keyless geocoding API.
    Process {
        id: geoProc
        command: ["curl", "-s", "--max-time", "8",
            "https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name="
            + encodeURIComponent(Config.weatherLocation.trim())]
        stdout: StdioCollector {
            onStreamFinished: {
                var g = Model.parseGeo(Model.parseJson(this.text));
                if (g) {
                    root.city = g.city;
                    root.lat = g.lat;
                    root.lon = g.lon;
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
            + "&current=temperature_2m,weather_code,is_day,relative_humidity_2m,apparent_temperature,wind_speed_10m"
            + "&hourly=temperature_2m,weather_code,precipitation_probability&forecast_hours=24"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=5"
            + "&timezone=auto&temperature_unit=" + root.fetchUnit + "&wind_speed_unit=" + (root.fetchUnit === "fahrenheit" ? "mph" : "kmh")]
        stdout: StdioCollector {
            onStreamFinished: {
                root.applyForecast(this.text);
                if (root.pendingFetch) {
                    root.pendingFetch = false;
                    root.fetchWeather();
                }
            }
        }
    }

    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: root.fetchWeather()
    }
}
