import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { apiUrl, parseAnswer } = require("./ddg.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const EMPTY = { available: false, heading: "", text: "", source: "", url: "" };

eq(apiUrl("nmap"),
   "https://api.duckduckgo.com/?q=nmap&format=json&no_html=1&skip_disambig=1",
   "url encodes a plain query");
eq(apiUrl("a b&c"),
   "https://api.duckduckgo.com/?q=" + encodeURIComponent("a b&c") + "&format=json&no_html=1&skip_disambig=1",
   "url percent-encodes reserved chars");
eq(apiUrl(""),
   "https://api.duckduckgo.com/?q=&format=json&no_html=1&skip_disambig=1",
   "empty query still yields a valid url");
eq(apiUrl(null),
   "https://api.duckduckgo.com/?q=&format=json&no_html=1&skip_disambig=1",
   "null query is coerced to empty");

// Wikipedia-style abstract: what an `?what is nmap` returns.
const nmapBody = JSON.stringify({
    Abstract: "Nmap is a network scanner.",
    AbstractText: "Nmap is a network scanner created by Gordon Lyon.",
    AbstractSource: "Wikipedia",
    AbstractURL: "https://en.wikipedia.org/wiki/Nmap",
    Heading: "Nmap",
    Answer: "",
    AnswerType: ""
});
eq(parseAnswer(nmapBody), {
    available: true,
    heading: "Nmap",
    text: "Nmap is a network scanner created by Gordon Lyon.",
    source: "Wikipedia",
    url: "https://en.wikipedia.org/wiki/Nmap"
}, "abstract body yields available answer with Wikipedia source");

// Instant-answer slot with a type set: e.g. `random number 1..100` -> "rand".
const answerBody = JSON.stringify({
    Abstract: "", AbstractText: "", AbstractSource: "", AbstractURL: "",
    Heading: "", Answer: "1 (random number)", AnswerType: "rand"
});
eq(parseAnswer(answerBody), {
    available: true,
    heading: "",
    text: "1 (random number)",
    source: "",
    url: ""
}, "Answer with AnswerType is preferred over an empty abstract");

// Answer preferred over AbstractText when both are present (the direct reply
// wins over the encyclopedic paragraph).
const bothBody = JSON.stringify({
    AbstractText: "long abstract paragraph",
    AbstractSource: "Wikipedia",
    Heading: "H",
    Answer: "42",
    AnswerType: "calc"
});
eq(parseAnswer(bothBody), {
    available: true, heading: "H", text: "42",
    source: "Wikipedia", url: ""
}, "Answer wins when both slots are filled");

// A raw Answer with no AnswerType is skipped; DDG sometimes echoes debug or
// meta content there. We prefer no answer over a misleading one.
const answerNoType = JSON.stringify({ Answer: "some junk", AnswerType: "", AbstractText: "" });
eq(parseAnswer(answerNoType), EMPTY, "Answer without AnswerType is skipped");

const emptyBody = JSON.stringify({
    Abstract: "", AbstractText: "", AbstractSource: "", AbstractURL: "",
    Heading: "", Answer: "", AnswerType: ""
});
eq(parseAnswer(emptyBody), EMPTY, "empty body is unavailable");

eq(parseAnswer(""), EMPTY, "empty string is unavailable");
eq(parseAnswer("not json"), EMPTY, "garbage text is unavailable");
eq(parseAnswer("{"), EMPTY, "malformed json is unavailable");
eq(parseAnswer(null), EMPTY, "null is unavailable");
eq(parseAnswer(undefined), EMPTY, "undefined is unavailable");
eq(parseAnswer(42), EMPTY, "non-object non-string is unavailable");

// Non-string field values (numbers/nulls) must not throw and must not leak
// into the normalized answer as arbitrary types.
const weirdTypes = JSON.stringify({
    AbstractText: "text",
    AbstractSource: null,
    AbstractURL: 7,
    Heading: null
});
eq(parseAnswer(weirdTypes), {
    available: true, heading: "", text: "text", source: "", url: ""
}, "non-string fields are coerced to empty");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
