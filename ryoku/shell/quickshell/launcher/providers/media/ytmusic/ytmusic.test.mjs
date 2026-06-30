import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { parse, fmtDuration } = require("./ytmusic.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, msg) { eq(!!cond, true, msg); }

const ndjson = [
    JSON.stringify({ id: "aaa", title: "Song A", uploader: "Artist A", duration: 200 }),
    JSON.stringify({ id: "bbb", title: "Clip", uploader: "X", duration: 10 }),       // too short
    JSON.stringify({ id: "ccc", title: "Podcast", uploader: "Y", duration: 3600 }),  // too long
    JSON.stringify({ id: "ddd", title: "Song D", channel: "Artist D", duration: 245 }),
    "not json",                                                                       // skipped
    JSON.stringify({ title: "No ID", duration: 100 })                                // no id, skipped
].join("\n");

eq(parse(ndjson).length, 2, "keeps only the two valid songs");
eq(parse(ndjson)[0], { id: "aaa", title: "Song A", artist: "Artist A", duration: 200, durationLabel: "3:20" }, "first track parsed with uploader as artist");
eq(parse(ndjson)[1].artist, "Artist D", "channel used as artist fallback");

eq(fmtDuration(200), "3:20", "duration formatted mm:ss");
eq(fmtDuration(5), "0:05", "seconds zero-padded");
eq(fmtDuration(0), "", "zero duration is blank");

eq(parse(""), [], "empty text yields no tracks");
ok(parse(JSON.stringify({ id: "z", title: "T" })).length === 1, "missing duration is kept (unknown length)");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
