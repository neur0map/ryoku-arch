import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { glyphFor, labelFor, unitFor, tempSymbol, formatTemp, parseForecast, parseLoc, parseJson } = require("./weather.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }

// WMO code -> glyph (only the six names the shell's GlyphIcon ships)
eq(glyphFor(0), "sun", "code 0 clear -> sun");
eq(glyphFor(2), "cloud", "code 2 -> cloud");
eq(glyphFor(45), "fog", "code 45 -> fog");
eq(glyphFor(48), "fog", "code 48 -> fog");
eq(glyphFor(61), "rain", "code 61 -> rain");
eq(glyphFor(80), "rain", "code 80 showers -> rain");
eq(glyphFor(71), "snow", "code 71 -> snow");
eq(glyphFor(86), "snow", "code 86 -> snow");
eq(glyphFor(95), "storm", "code 95 -> storm");
eq(glyphFor(99), "storm", "code 99 -> storm");
const glyphs = new Set(["sun", "cloud", "fog", "rain", "snow", "storm"]);
ok([0, 1, 2, 3, 45, 48, 51, 61, 71, 80, 85, 95, 99, 1234].every(c => glyphs.has(glyphFor(c))), "every glyph is a shipped name");

eq(labelFor(0), "Clear", "label clear");
eq(labelFor(3), "Cloudy", "label cloudy");
eq(labelFor(61), "Rain", "label rain");
eq(labelFor(95), "Thunder", "label thunder");

eq(unitFor("en_US.UTF-8"), "fahrenheit", "US locale -> fahrenheit");
eq(unitFor("en_US"), "fahrenheit", "bare US locale -> fahrenheit");
eq(unitFor("en_GB.UTF-8"), "celsius", "GB locale -> celsius");
eq(unitFor("de_DE.UTF-8"), "celsius", "DE locale -> celsius");
eq(unitFor(""), "celsius", "empty locale -> celsius");
eq(unitFor("C.UTF-8"), "celsius", "C locale -> celsius");
eq(unitFor("es_CU"), "celsius", "Cuba locale is not US -> celsius");

eq(tempSymbol("celsius"), "\u00b0C", "celsius symbol");
eq(tempSymbol("fahrenheit"), "\u00b0F", "fahrenheit symbol");
eq(formatTemp(19.7, "celsius"), "20\u00b0C", "formatTemp rounds and appends C");
eq(formatTemp(67.5, "fahrenheit"), "68\u00b0F", "formatTemp rounds half-up and appends F");

const sample = {
    current: { time: "2026-06-22T10:30", temperature_2m: 19.7, weather_code: 3, is_day: 1, relative_humidity_2m: 63 },
    hourly: { time: ["2026-06-22T10:00", "2026-06-22T11:00", "2026-06-22T12:00"], temperature_2m: [18.1, 19.9, 20.9], weather_code: [3, 3, 61] },
    daily: { time: ["2026-06-22", "2026-06-23"], weather_code: [63, 55], temperature_2m_max: [20.9, 22.1], temperature_2m_min: [9.5, 15.5] }
};
const f = parseForecast(sample, "celsius");
ok(f.available, "parseForecast available on a good body");
eq(f.tempNow, 20, "tempNow rounded");
eq(f.temp, "20\u00b0C", "temp formatted");
eq(f.condition, "Cloudy", "condition from code 3");
eq(f.glyph, "cloud", "glyph from code 3");
eq(f.humidity, 63, "humidity parsed");
eq(f.isDay, true, "isDay from is_day 1");
eq(f.hourly.length, 3, "hourly length");
eq(f.hourly[0], { hour: "10", temp: 18, code: 3 }, "hourly[0] hour/temp/code");
eq(f.hourly[2], { hour: "12", temp: 21, code: 61 }, "hourly[2] parsed");
eq(f.daily.length, 2, "daily length");
eq(f.daily[0].code, 63, "daily[0] code");
eq(f.daily[0].hi, 21, "daily[0] hi rounded");
eq(f.daily[0].lo, 10, "daily[0] lo rounded");
ok(glyphs.size && ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].includes(f.daily[0].day), "daily[0] day is a weekday name");

eq(parseForecast({}, "celsius").available, false, "no current -> unavailable");
eq(parseForecast({ current: {} }, "celsius").available, false, "current without temp -> unavailable");
eq(parseForecast(null, "celsius").available, false, "null json -> unavailable");

eq(parseLoc({ status: "success", city: "Pittsfield", lat: 42.45, lon: -73.25 }), { city: "Pittsfield", lat: 42.45, lon: -73.25 }, "parseLoc reads a success body");
eq(parseLoc({ lat: 1, lon: 2 }), { city: "", lat: 1, lon: 2 }, "parseLoc tolerates a missing status/city");
eq(parseLoc({ status: "fail" }), null, "parseLoc null on failure");
eq(parseLoc(null), null, "parseLoc null on null");

eq(parseJson('{"a":1}'), { a: 1 }, "parseJson reads valid json");
eq(parseJson(""), null, "parseJson null on empty");
eq(parseJson("nope"), null, "parseJson null on garbage");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
