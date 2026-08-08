import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const {
  dedupeRows,
  quicklinkRowId,
  scriptRowId,
  snippetRowId
} = require("./providerids.js");

test("script identity includes keyword, info, and activation text", () => {
  const first = scriptRowId("emoji", { info: "shared", text: "One" });
  const second = scriptRowId("emoji", { info: "shared", text: "Two" });

  assert.notEqual(first, second);
  assert.notEqual(first, scriptRowId("symbols", {
    info: "shared",
    text: "One"
  }));
});

test("script identities survive reorder and insertion without positions", () => {
  const before = [
    { info: "alpha", text: "Alpha" },
    { info: "beta", text: "Beta" }
  ];
  const after = [
    { info: "inserted", text: "Inserted" },
    before[1],
    before[0]
  ];
  const byText = rows => Object.fromEntries(rows.map(row => [
    row.text,
    scriptRowId("picker", row)
  ]));

  assert.equal(byText(after).Alpha, byText(before).Alpha);
  assert.equal(byText(after).Beta, byText(before).Beta);
});

test("exact duplicate script rows dedupe by computed identity", () => {
  const id = scriptRowId("picker", { info: "same", text: "Same" });
  assert.deepEqual(dedupeRows([
    { id, title: "Same" },
    { id, title: "Same duplicate" }
  ]).map(row => row.title), ["Same"]);
});

test("snippet explicit ids are stable namespaced tuples", () => {
  assert.equal(
    snippetRowId({ id: "signature", name: "Before" }),
    snippetRowId({ id: "signature", name: "After" })
  );
  assert.notEqual(
    snippetRowId({ id: "a:b", name: "One" }),
    snippetRowId({ id: "a", name: "b:One" })
  );
});

test("snippet fallback ids survive reorder and unrelated insertion", () => {
  const entry = {
    name: "Signature",
    keyword: "sig",
    body: "Regards, {date}",
    keywords: ["mail", "closing"]
  };
  const before = [entry, { name: "Other", body: "Other" }];
  const after = [{ name: "Inserted", body: "New" }, before[1], before[0]];

  assert.equal(snippetRowId(before[0]), snippetRowId(after[2]));
});

test("quicklink fallback uses stable URL and keyword content", () => {
  const entry = {
    name: "Arch Wiki",
    keyword: "wiki",
    url: "https://wiki.archlinux.org/?search={query}",
    keywords: ["docs", "arch"]
  };
  const before = [entry, { name: "Other", url: "https://other.example" }];
  const after = [
    { name: "Inserted", url: "https://inserted.example" },
    before[1],
    before[0]
  ];

  assert.equal(quicklinkRowId(before[0]), quicklinkRowId(after[2]));
  assert.notEqual(quicklinkRowId(entry), quicklinkRowId(Object.assign(
    {}, entry, { url: "https://example.org/?q={query}" }
  )));
});

test("duplicate explicit and identical fallback identities dedupe", () => {
  const explicit = snippetRowId({ id: "same", name: "First" });
  const fallback = quicklinkRowId({
    name: "Wiki",
    keyword: "wiki",
    url: "https://wiki.example/{query}"
  });
  const rows = dedupeRows([
    { id: explicit, title: "Explicit first" },
    { id: explicit, title: "Explicit duplicate" },
    { id: fallback, title: "Fallback first" },
    { id: fallback, title: "Fallback duplicate" }
  ]);

  assert.deepEqual(rows.map(row => row.title), [
    "Explicit first", "Fallback first"
  ]);
});

test("snippet and quicklink identities occupy separate namespaces", () => {
  const shared = {
    id: "shared",
    name: "Shared",
    keyword: "same",
    body: "same",
    url: "same",
    keywords: ["same"]
  };

  assert.notEqual(snippetRowId(shared), quicklinkRowId(shared));
  assert.equal(dedupeRows([
    { id: snippetRowId(shared), title: "Snippet" },
    { id: quicklinkRowId(shared), title: "Quicklink" }
  ]).length, 2);
});
