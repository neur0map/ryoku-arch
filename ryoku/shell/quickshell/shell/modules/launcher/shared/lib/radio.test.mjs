import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { isRadioTitle, isRadioPlayer, isWallpaperTitle, countsAsMusic, stationRows } = require("./radio.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

// ---- radio player signature -------------------------------------------------
eq(isRadioTitle("LIVE · Lofi Girl"), true, "engine title carries the prefix");
eq(isRadioTitle("lofi hip hop radio"), false, "an ordinary stream title is not the radio");
eq(isRadioTitle(""), false, "empty title is not the radio");
eq(isRadioPlayer("org.mpris.MediaPlayer2.mpv", "LIVE · Lofi Girl"), true, "mpv bus + prefix is the radio");
eq(isRadioPlayer("org.mpris.MediaPlayer2.mpv.instance12345", "LIVE · SomaFM Groove Salad"), true, "suffixed mpv instance still matches");
eq(isRadioPlayer("org.mpris.MediaPlayer2.spotify", "LIVE · Lofi Girl"), false, "a non-mpv player never matches even with the title");
eq(isRadioPlayer("org.mpris.MediaPlayer2.mpv", "some song.mp3"), false, "plain mpv use is not the radio");

// ---- wallpaper immunity -----------------------------------------------------
eq(isWallpaperTitle("moewalls-20717.webm"), true, "live wallpaper webm is a wallpaper");
eq(isWallpaperTitle("clip.mp4"), true, "mp4 wallpaper is a wallpaper");
eq(isWallpaperTitle("LIVE · Lofi Girl"), false, "the radio is not a wallpaper");
eq(isWallpaperTitle("Song Title"), false, "a song is not a wallpaper");

// ---- what counts as music (the collision watcher's verdict) ------------------
eq(countsAsMusic("MEMPHIS PHONK MIX IV"), true, "a real track is music");
eq(countsAsMusic("LIVE · Lofi Girl"), false, "the radio itself is not a rival");
eq(countsAsMusic("moewalls-20717.webm"), false, "wallpaper scenery is not music");
eq(countsAsMusic(""), false, "a titleless registering player is not music yet");
eq(countsAsMusic(null), false, "no title at all is not music");
eq(countsAsMusic("https://manifest.googlevideo.com/x"), false, "a URL title is a stream still resolving");
eq(countsAsMusic("www.example.com/stream"), false, "www titles are still resolving too");

// ---- station rows -----------------------------------------------------------
const stations = [
    { id: "lofi", label: "Lofi Girl", kind: "youtube", fallback: "groove" },
    { id: "groove", label: "SomaFM Groove Salad", kind: "direct", fallback: "" }
];
const offStatus = { on: false, station: "", aside: null, fellBack: false };

let rows = stationRows(stations, "", offStatus);
eq(rows.length, 2, "empty query lists every station");
eq(rows[0].id, "lofi", "catalog order holds when nothing plays");
eq(rows[0].verb, "start", "silent station starts");
eq(rows[0].note, "live radio · falls back to groove", "the fallback is said up front");
eq(rows[1].note, "live radio", "a station with no fallback says just that");

rows = stationRows(stations, "lofi", offStatus);
eq(rows.length, 1, "query narrows by substring");
eq(rows[0].id, "lofi", "lofi matches lofi");

rows = stationRows(stations, "SOMA", offStatus);
eq(rows.map(r => r.id), ["groove"], "label match is case-insensitive");

rows = stationRows(stations, "", { on: true, station: "lofi", aside: null, fellBack: false });
eq(rows[0].id, "lofi", "the playing station ranks first");
eq(rows[0].verb, "stop", "a playing station's primary verb is stop");
eq(rows[0].on, true, "the playing station is marked on");
eq(rows[0].note, "on air", "on air without fallback note");
eq(rows[1].verb, "start", "the other station still starts");

rows = stationRows(stations, "", { on: true, station: "lofi", aside: null, fellBack: true });
eq(rows[0].note, "on air · fallback station", "a fallen-back station says so");

rows = stationRows(stations, "", { on: true, station: "lofi", aside: null, fellBack: false, tuning: true });
eq(rows[0].note, "tuning in — a few quiet seconds is normal", "resolving silence reads as tuning");
eq(rows[0].verb, "stop", "a tuning station can still be stopped");

rows = stationRows(stations, "", { on: false, station: "", aside: { station: "lofi", label: "Lofi Girl" }, fellBack: false });
eq(rows[0].id, "lofi", "an aside station ranks first when nothing plays");
eq(rows[0].verb, "resume", "an aside station resumes");

eq(stationRows([], "anything", offStatus), [], "no stations, no rows");
eq(stationRows(stations, "zzz", offStatus), [], "no match, no rows");

process.exit(failed > 0 ? 1 : 0);
