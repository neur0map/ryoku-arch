// Pure weather model: parses Open-Meteo + ip-api responses, maps WMO weather
// codes to the shell's glyph names, and picks/formats the temperature unit. No
// QML and no network here, so the Weather singleton can stay a thin fetch wrapper
// and node can exercise the parsing against a captured real response. Avoids
// Date.now()/Math.random() (both throw in the Quickshell JS engine); Math.round
// and the Date constructor are fine (the Calendar already uses them).

// WMO weather code -> one of the shell's existing weather glyph names
// (sun | cloud | fog | rain | snow | storm), matching what GlyphIcon ships.
function glyphFor(code) {
    if (code === 0) return "sun";
    if (code <= 3) return "cloud";
    if (code === 45 || code === 48) return "fog";
    if (code >= 95) return "storm";
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "snow";
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "rain";
    return "cloud";
}

// Short condition word for a WMO code (the display text, replacing wttr.in's %C).
function labelFor(code) {
    if (code === 0) return "Clear";
    if (code <= 3) return "Cloudy";
    if (code === 45 || code === 48) return "Fog";
    if (code >= 95) return "Thunder";
    if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "Snow";
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return "Rain";
    return "Cloudy";
}

// Imperial vs metric from the locale env, so a US locale keeps Fahrenheit (as the
// previous IP-located provider implicitly did) and the rest of the world gets
// Celsius. US, Liberia and Myanmar are the Fahrenheit holdouts.
function unitFor(localeEnv) {
    var l = String(localeEnv || "");
    return /(^|[_.@-])(US|LR|MM)([_.@-]|$)/.test(l) ? "fahrenheit" : "celsius";
}

function tempSymbol(unit) { return unit === "fahrenheit" ? "\u00b0F" : "\u00b0C"; }

// "27°C" / "81°F". The temperature is already in `unit` (it is what we request
// from Open-Meteo), so this only rounds and appends the symbol.
function formatTemp(temp, unit) {
    return Math.round(temp) + tempSymbol(unit);
}

// Parse an Open-Meteo forecast into the shell's weather state. Guards every
// field: a missing/!numeric current block yields available:false so the caller
// hides the readout and keeps its last good values.
function parseForecast(json, unit) {
    var out = {
        available: false, tempNow: 0, temp: "", condition: "", glyph: "cloud",
        humidity: 0, isDay: true, hourly: [], daily: []
    };
    var cur = json && json.current;
    if (!cur || typeof cur.temperature_2m !== "number" || typeof cur.weather_code !== "number")
        return out;

    var h = json.hourly;
    if (h && h.time && h.temperature_2m && h.weather_code) {
        var n = Math.min(h.time.length, h.temperature_2m.length, h.weather_code.length);
        for (var i = 0; i < n; i++)
            out.hourly.push({ hour: String(h.time[i]).slice(11, 13), temp: Math.round(h.temperature_2m[i]), code: h.weather_code[i] });
    }

    var d = json.daily;
    if (d && d.time && d.weather_code && d.temperature_2m_max && d.temperature_2m_min) {
        var dn = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        var m = Math.min(d.time.length, d.weather_code.length, d.temperature_2m_max.length, d.temperature_2m_min.length);
        for (var j = 0; j < m; j++) {
            var p = String(d.time[j]).split("-");
            var dow = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])).getDay();
            out.daily.push({ day: dn[dow], code: d.weather_code[j], hi: Math.round(d.temperature_2m_max[j]), lo: Math.round(d.temperature_2m_min[j]) });
        }
    }

    out.tempNow = Math.round(cur.temperature_2m);
    out.temp = formatTemp(cur.temperature_2m, unit);
    out.condition = labelFor(cur.weather_code);
    out.glyph = glyphFor(cur.weather_code);
    out.humidity = typeof cur.relative_humidity_2m === "number" ? Math.round(cur.relative_humidity_2m) : 0;
    out.isDay = cur.is_day === 1;
    out.available = true;
    return out;
}

// Parse ip-api's response to { city, lat, lon }, or null when it failed.
function parseLoc(json) {
    if (json && (json.status === "success" || json.status === undefined)
        && typeof json.lat === "number" && typeof json.lon === "number")
        return { city: json.city || "", lat: json.lat, lon: json.lon };
    return null;
}

// Guarded JSON.parse: null on any empty or malformed body.
function parseJson(text) {
    try {
        if (text && text.trim().length > 0) return JSON.parse(text);
    } catch (e) {}
    return null;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { glyphFor, labelFor, unitFor, tempSymbol, formatTemp, parseForecast, parseLoc, parseJson };
}
