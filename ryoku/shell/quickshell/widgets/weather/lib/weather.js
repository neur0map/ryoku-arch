// pure weather model for the desktop weather widget. parses Open-Meteo +
// ip-api responses and maps WMO codes to an *animation category*
// (clear | clouds | rain | snow | storm | fog) the animated Sky knows how to
// draw. sibling of the pill's lib/weather.js, not a copy: the pill maps codes
// to font glyphs and pulls its unit from the locale, while the widget maps
// codes to live animations and reads its unit (C/F) out of Ryoku Settings.
// no QML and no network here, so node can run the parser against captured
// JSON. avoids Date.now() / Math.random() (both throw in the Quickshell JS
// engine); the Date ctor and Math.round are fine.

// WMO code -> animation category the Sky knows how to draw.
function categoryFor(code) {
    if (code === 0 || code === 1) return "clear";
    if (code <= 3) return "clouds";
    if (code === 45 || code === 48) return "fog";
    if (code >= 95) return "storm";
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "rain";
    return "clouds";
}

// short condition word for a WMO code (display label).
function labelFor(code) {
    if (code === 0 || code === 1) return "Clear";
    if (code <= 3) return "Cloudy";
    if (code === 45 || code === 48) return "Fog";
    if (code >= 95) return "Thunder";
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "Snow";
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "Rain";
    return "Cloudy";
}

// user unit ("C"/"F") -> Open-Meteo request param + display symbol.
function unitParam(unit) { return unit === "F" ? "fahrenheit" : "celsius"; }
// widget shows the bare degree; the unit letter lives in the caption.
function tempSymbol(unit) { return "\u00b0"; }

// "27°": round + append the bare degree. temp is already in the requested
// unit (it's what we ask Open-Meteo for).
function formatTemp(temp, unit) {
    return Math.round(temp) + tempSymbol(unit);
}

// Open-Meteo forecast -> the widget's weather state. guards every field: a
// missing/non-numeric current block gives back available:false so the caller
// keeps its last good values instead of flashing zeros.
function parseForecast(json, unit) {
    var out = {
        available: false, tempNow: 0, temp: "", condition: "", category: "clouds",
        code: 3, humidity: 0, wind: 0, isDay: true, daily: []
    };
    var cur = json && json.current;
    if (!cur || typeof cur.temperature_2m !== "number" || typeof cur.weather_code !== "number")
        return out;

    var d = json.daily;
    if (d && d.time && d.weather_code && d.temperature_2m_max && d.temperature_2m_min) {
        var dn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var m = Math.min(d.time.length, d.weather_code.length, d.temperature_2m_max.length, d.temperature_2m_min.length);
        for (var j = 0; j < m; j++) {
            var p = String(d.time[j]).split("-");
            var dow = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])).getDay();
            out.daily.push({
                day: dn[dow],
                code: d.weather_code[j],
                category: categoryFor(d.weather_code[j]),
                hi: Math.round(d.temperature_2m_max[j]),
                lo: Math.round(d.temperature_2m_min[j])
            });
        }
    }

    out.tempNow = Math.round(cur.temperature_2m);
    out.temp = formatTemp(cur.temperature_2m, unit);
    out.code = cur.weather_code;
    out.condition = labelFor(cur.weather_code);
    out.category = categoryFor(cur.weather_code);
    out.humidity = typeof cur.relative_humidity_2m === "number" ? Math.round(cur.relative_humidity_2m) : 0;
    out.wind = typeof cur.wind_speed_10m === "number" ? Math.round(cur.wind_speed_10m) : 0;
    out.isDay = cur.is_day === 1;
    out.available = true;
    return out;
}

// ip-api response -> { city, lat, lon }, or null if the lookup failed.
function parseLoc(json) {
    if (json && (json.status === "success" || json.status === undefined)
        && typeof json.lat === "number" && typeof json.lon === "number")
        return { city: json.city || "", lat: json.lat, lon: json.lon };
    return null;
}

// guarded JSON.parse. null on empty or malformed body.
function parseJson(text) {
    try {
        if (text && text.trim().length > 0) return JSON.parse(text);
    } catch (e) {}
    return null;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { categoryFor, labelFor, unitParam, tempSymbol, formatTemp, parseForecast, parseLoc, parseJson };
}
