import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const { filterExisting, parentUri, parseXbel, sortRecent } = require("./recent.js");

function document(bookmarks, root = "xbel") {
  return `<?xml version="1.0"?>
<${root} version="1.0" xmlns:b="urn:bookmarks">
${bookmarks}
</${root}>`;
}

function bookmark(href, options = {}) {
  const modified = options.modified ? ` modified="${options.modified}"` : "";
  const title = options.title === undefined ? "" : `<title>${options.title}</title>`;
  const metadata = options.metadata || "";
  return `<bookmark href="${href}"${modified}>${title}${metadata}</bookmark>`;
}

test("namespaced XBEL reads root bookmarks without mistaking application metadata for bookmarks", () => {
  const xml = document(`
    <b:bookmark href="file:///home/nero/one.txt" modified="2026-07-24T12:30:00Z">
      <b:title>One</b:title>
      <info><metadata>
        <b:applications>
          <b:application name="Editor" exec="editor %u" modified="2026-07-24T13:00:00Z"/>
        </b:applications>
      </metadata></info>
    </b:bookmark>
  `, "b:xbel");

  assert.deepEqual(parseXbel(xml), [{
    uri: "file:///home/nero/one.txt",
    path: "/home/nero/one.txt",
    title: "One",
    modified: Date.parse("2026-07-24T12:30:00Z")
  }]);
});

test("titles decode the five XML entities and decimal or hexadecimal Unicode entities", () => {
  const xml = document(bookmark(
    "file:///tmp/entities.txt",
    { title: "&lt;&gt;&amp;&quot;&apos; &#9731; &#x1F680;" }
  ));

  assert.equal(parseXbel(xml)[0].title, `<>&"' ☃ 🚀`);
});

test("file URLs decode percent escapes while raw and encoded plus signs remain plus signs", () => {
  const rows = parseXbel(document(
    bookmark("file:///home/nero/A%2BB%20C.txt")
    + bookmark("file:///home/nero/raw+plus.txt")
  ));

  assert.deepEqual(rows.map(row => row.path), [
    "/home/nero/A+B C.txt",
    "/home/nero/raw+plus.txt"
  ]);
  assert.deepEqual(rows.map(row => row.uri), [
    "file:///home/nero/A%2BB%20C.txt",
    "file:///home/nero/raw%2Bplus.txt"
  ]);
});

test("query and fragment are omitted from the canonical local file URI", () => {
  const [row] = parseXbel(document(
    bookmark("file:///home/nero/report%20draft.txt?download=1#section")
  ));

  assert.equal(row.path, "/home/nero/report draft.txt");
  assert.equal(row.uri, "file:///home/nero/report%20draft.txt");
});

test("localhost and empty file authorities canonicalize to the same URI and deduplicate", () => {
  const rows = parseXbel(document(
    bookmark("file://localhost/home/nero/same.txt", {
      title: "Older",
      modified: "2026-07-23T10:00:00Z"
    })
    + bookmark("file:///home/nero/same.txt", {
      title: "Newer",
      modified: "2026-07-24T10:00:00Z"
    })
  ));

  assert.deepEqual(rows, [{
    uri: "file:///home/nero/same.txt",
    path: "/home/nero/same.txt",
    title: "Newer",
    modified: Date.parse("2026-07-24T10:00:00Z")
  }]);
});

test("non-file, remote, relative, malformed percent, control, and NUL URLs are rejected", () => {
  const hrefs = [
    "https://example.com/file.txt",
    "file://server/home/nero/file.txt",
    "file:relative.txt",
    "file:///tmp/bad%ZZ.txt",
    "file:///tmp/control%0A.txt",
    "file:///tmp/nul%00.txt"
  ];
  const rows = parseXbel(document(hrefs.map(href => bookmark(href)).join("")));

  assert.deepEqual(rows, []);
});

test("an unencodable malformed Unicode path is rejected rather than escaping the parser", () => {
  const xml = document(bookmark("file:///tmp/\ud800.txt"));
  assert.doesNotThrow(() => parseXbel(xml));
  assert.deepEqual(parseXbel(xml), []);
});

test("malformed, unbalanced, DTD-bearing, and bad-entity XML is rejected as a whole", () => {
  const inputs = [
    "",
    "<xbel><bookmark href=\"file:///tmp/a\"></xbel>",
    "<xbel><bookmark href=\"file:///tmp/a\"></bookmark>",
    "<!DOCTYPE xbel [<!ENTITY nope \"bad\">]><xbel></xbel>",
    document(bookmark("file:///tmp/a", { title: "Bad &unknown;" })),
    document("<bookmark href=\"file:///tmp/a\"><title>Bad &#x110000;</title></bookmark>")
  ];

  for (const input of inputs)
    assert.deepEqual(parseXbel(input), []);
});

test("XML syntax errors do not become usable recent rows", () => {
  const row = bookmark("file:///tmp/should-not-parse.txt", { title: "Bad" });
  const malformed = [
    `<?xml version="1.0"?><xbel><bookmark href="file:///tmp/adjacent.txt"modified="2026-07-24T12:00:00Z"/></xbel>`,
    `<xbel><?xml version="1.0"?>${row}</xbel>`,
    `<xbel><??>${row}</xbel>`,
    `<xbel><bookmark href="file:///tmp/cdata-close.txt"><title>raw ]]&gt;</title></bookmark></xbel>`.replace("&gt;", ">"),
    `<xbel><!--foo--->${row}</xbel>`,
    `<xbel><bookmark href="file:///tmp/nul.txt"><title>raw \u0000 nul</title></bookmark></xbel>`,
    `<xbel><bookmark href="file:///tmp/surrogate.txt"><title>raw \ud800 surrogate</title></bookmark></xbel>`
  ];

  for (const input of malformed)
    assert.deepEqual(parseXbel(input), []);
});

test("valid XML declarations and non-XML processing instructions remain accepted", () => {
  const xml = `<?xml version="1.0"?><?xbel-tool refresh?>
<xbel><?inside value?>${bookmark("file:///tmp/valid-pi.txt", { title: "Valid" })}</xbel>`;

  assert.equal(parseXbel(xml)[0].title, "Valid");
});

test("one leading byte-order mark is accepted before an XML 1.0 declaration", () => {
  const xml = `\ufeff<?xml version="1.0"?><xbel>${
    bookmark("file:///tmp/bom.txt", { title: "BOM" })
  }</xbel>`;

  assert.equal(parseXbel(xml)[0].title, "BOM");
});

test("an XML 1.1 declaration is rejected because the parser implements XML 1.0", () => {
  const xml = `<?xml version="1.1"?><xbel>${
    bookmark("file:///tmp/xml-1.1.txt", { title: "Wrong version" })
  }</xbel>`;

  assert.deepEqual(parseXbel(xml), []);
});

test("the direct title wins and an absent title falls back to the decoded basename", () => {
  const rows = parseXbel(document(
    `<bookmark href="file:///tmp/direct.txt">
       <info><title>Nested metadata title</title></info>
       <title>Direct title</title>
     </bookmark>`
    + bookmark("file:///tmp/Fallback%20Name%2B.txt")
  ));

  assert.equal(rows[0].title, "Direct title");
  assert.equal(rows[1].title, "Fallback Name+.txt");
  assert.equal(rows[0].modified, 0);
});

test("root bookmark timestamps parse to milliseconds and invalid timestamps become zero", () => {
  const rows = parseXbel(document(
    bookmark("file:///tmp/new.txt", { modified: "2026-07-24T15:00:00.250Z" })
    + bookmark("file:///tmp/unknown.txt", { modified: "not-a-date" })
  ));

  assert.equal(rows[0].modified, Date.parse("2026-07-24T15:00:00.250Z"));
  assert.equal(rows[1].modified, 0);
});

test("sortRecent is non-mutating, stable for ties, newest-first, and applies its limit", () => {
  const source = [
    { uri: "file:///old", modified: 1 },
    { uri: "file:///tie-a", modified: 8 },
    { uri: "file:///new", modified: 12 },
    { uri: "file:///tie-b", modified: 8 }
  ];
  const snapshot = source.slice();

  assert.deepEqual(sortRecent(source, 3).map(row => row.uri), [
    "file:///new", "file:///tie-a", "file:///tie-b"
  ]);
  assert.deepEqual(source, snapshot);
});

test("sortRecent defaults to a 40-row cap after sorting the supplied source", () => {
  const source = Array.from({ length: 55 }, (_, index) => ({
    uri: `file:///${index}`,
    modified: index
  }));
  const rows = sortRecent(source);

  assert.equal(rows.length, 40);
  assert.equal(rows[0].modified, 54);
  assert.equal(rows[39].modified, 15);
});

test("the existence filter removes missing paths without trimming valid output records", () => {
  const source = [
    { path: "/tmp/exists with spaces" },
    { path: "/tmp/missing" },
    { path: "/tmp/line\nbreak" }
  ];

  assert.deepEqual(filterExisting(source, [
    "/tmp/line\nbreak",
    "/tmp/exists with spaces"
  ]), [source[0], source[2]]);
});

test("parentUri encodes spaces and plus signs and keeps root at the root", () => {
  assert.equal(parentUri("/home/nero/My File+One.txt"), "file:///home/nero");
  assert.equal(parentUri("/home/nero/My Folder+/item.txt"), "file:///home/nero/My%20Folder%2B");
  assert.equal(parentUri("/file.txt"), "file:///");
  assert.equal(parentUri("/"), "file:///");
});
