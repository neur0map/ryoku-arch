import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { glyphFor, labelFor, unitFor, tempSymbol, formatTemp, parseForecast, parseLoc, parseJson, hhmmToSec, sunFrac } = require("./weather.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }
function near(actual, expected, msg, eps) {
    if (eps === undefined) eps = 1e-6;
    if (typeof actual === "number" && isFinite(actual) && Math.abs(actual - expected) <= eps) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected ~" + expected + " (eps " + eps + ")\n  got      " + actual); }
}

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
eq(f.sunrise, -1, "sunrise -1 when daily.sunrise absent");
eq(f.sunset, -1, "sunset -1 when daily.sunset absent");

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

// parseForecast with daily.sunrise/sunset (Open-Meteo local ISO -> seconds of day)
const sampleSun = {
    current: { time: "2026-06-22T10:30", temperature_2m: 19.7, weather_code: 3, is_day: 1, relative_humidity_2m: 63 },
    daily: {
        time: ["2026-06-22"], weather_code: [63], temperature_2m_max: [20.9], temperature_2m_min: [9.5],
        sunrise: ["2026-06-22T05:12"], sunset: ["2026-06-22T20:48"]
    }
};
const fs = parseForecast(sampleSun, "celsius");
ok(fs.available, "parseForecast available with sunrise/sunset");
eq(fs.sunrise, 5 * 3600 + 12 * 60, "sunrise parsed to seconds of day");
eq(fs.sunset, 20 * 3600 + 48 * 60, "sunset parsed to seconds of day");

// hhmmToSec
eq(hhmmToSec("2026-07-01T05:24"), 5 * 3600 + 24 * 60, "hhmmToSec normal time");
eq(hhmmToSec("2026-07-01T00:00"), 0, "hhmmToSec midnight");
eq(hhmmToSec("2026-07-01T23:59"), 23 * 3600 + 59 * 60, "hhmmToSec 23:59");
eq(hhmmToSec(""), -1, "hhmmToSec empty string -> -1");
eq(hhmmToSec("2026-07-01"), -1, "hhmmToSec date-only string -> -1");
eq(hhmmToSec(null), -1, "hhmmToSec null -> -1");
eq(hhmmToSec("2026-07-01TXX:MM"), -1, "hhmmToSec non-numeric HH:MM -> -1");

// sunFrac: sunrise=05:12 (18720), sunset=20:48 (74880). Verified references.
const SR = 18720, SS = 74880, DAY = 86400;
const day = sunFrac(43200, SR, SS);
ok(day && day.isDay === true, "sunFrac noon isDay true");
near(day.frac, (43200 - SR) / (SS - SR), "sunFrac noon frac ~0.4359");
const atRise = sunFrac(SR, SR, SS);
ok(atRise && atRise.isDay === true, "sunFrac at sunrise isDay true");
eq(atRise.frac, 0, "sunFrac at sunrise frac 0");
const jbSunset = sunFrac(SS - 1, SR, SS);
ok(jbSunset && jbSunset.isDay === true, "sunFrac just before sunset isDay true");
near(jbSunset.frac, (SS - 1 - SR) / (SS - SR), "sunFrac just before sunset frac");
const atSet = sunFrac(SS, SR, SS);
ok(atSet && atSet.isDay === false, "sunFrac at sunset handoff isDay false");
eq(atSet.frac, 0, "sunFrac at sunset frac 0 (clean handoff)");
const afterSunset = sunFrac(22 * 3600, SR, SS);
ok(afterSunset && afterSunset.isDay === false, "sunFrac 22:00 isDay false");
near(afterSunset.frac, (22 * 3600 - SS) / ((SR + DAY) - SS), "sunFrac 22:00 frac ~0.1429");
const beforeSunrise = sunFrac(3 * 3600, SR, SS);
ok(beforeSunrise && beforeSunrise.isDay === false, "sunFrac 03:00 isDay false");
near(beforeSunrise.frac, (3 * 3600 - (SS - DAY)) / (SR - (SS - DAY)), "sunFrac 03:00 frac ~0.7381");
eq(sunFrac(43200, -1, SS), null, "sunFrac null on sunrise<0");
eq(sunFrac(43200, SR, -1), null, "sunFrac null on sunset<0");
eq(sunFrac(43200, SS, SR), null, "sunFrac null when sunset<=sunrise (swapped)");
eq(sunFrac(43200, SR, SR), null, "sunFrac null when sunset==sunrise");
eq(sunFrac(NaN, SR, SS), null, "sunFrac null on NaN nowSec");
eq(sunFrac(Infinity, SR, SS), null, "sunFrac null on Infinity nowSec");
eq(sunFrac(-Infinity, SR, SS), null, "sunFrac null on -Infinity nowSec");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
