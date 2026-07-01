// DuckDuckGo Instant Answer helpers: build the API URL and normalize the raw
// response. Kept pure so the Web provider stays a thin fetch + render layer,
// and so the parse contract is node-tested without a running shell. Consumed
// by Web.qml (QML import) and ddg.test.mjs.

function apiUrl(query) {
    var q = String(query == null ? "" : query);
    return "https://api.duckduckgo.com/?q=" + encodeURIComponent(q)
        + "&format=json&no_html=1&skip_disambig=1";
}

function pick(value) {
    return typeof value === "string" ? value : "";
}

var EMPTY = { available: false, heading: "", text: "", source: "", url: "" };

// Normalize DDG's raw JSON into { available, heading, text, source, url }.
// Prefer the "Answer" slot (calc, conversions, random numbers, IP lookups; the
// key is that AnswerType names the answer kind) because it is the short, direct
// reply. Fall back to AbstractText for encyclopedic hits (Wikipedia). A missing
// AnswerType demotes Answer to noise (DDG sometimes echoes junk there), so we
// prefer the empty state over a mystery string in the UI.
function parseAnswer(rawJson) {
    if (rawJson == null)
        return EMPTY;
    var data;
    try {
        data = typeof rawJson === "string" ? JSON.parse(rawJson) : rawJson;
    } catch (e) {
        return EMPTY;
    }
    if (!data || typeof data !== "object")
        return EMPTY;
    var answer = pick(data.Answer);
    var answerType = pick(data.AnswerType);
    var abstractText = pick(data.AbstractText);
    var text = "";
    if (answer.length > 0 && answerType.length > 0)
        text = answer;
    else if (abstractText.length > 0)
        text = abstractText;
    if (text.length === 0)
        return EMPTY;
    return {
        available: true,
        heading: pick(data.Heading),
        text: text,
        source: pick(data.AbstractSource),
        url: pick(data.AbstractURL)
    };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { apiUrl, parseAnswer };
}
