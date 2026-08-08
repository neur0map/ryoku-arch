import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";
const require = createRequire(import.meta.url);
const {
  LAYOUT,
  actionSignature,
  cardGeometry,
  hideDuplicateWindowRows,
  normalizeRows,
  packActions,
  reconcileSelection,
  resultKey,
  shelfGeometry,
  secondaryActions
} = require("./results.js");

const execute = () => {};

test("provider-local ids cannot collide", () => {
  assert.notEqual(resultKey("apps", "same"), resultKey("find", "same"));
});

test("an app result owns its matching-open-window presentation", () => {
  const app = { providerId: "apps", title: "kitty" };
  const window = { providerId: "windows", title: "kitty terminal" };
  const web = { providerId: "web", title: "kitty" };
  assert.deepEqual(hideDuplicateWindowRows([app, window, web]), [app, web]);
  assert.deepEqual(hideDuplicateWindowRows([window, web]), [window, web]);
});

test("a malformed primary disables the row without promoting a secondary", () => {
  const [row] = normalizeRows("find", [{
    id: "one",
    actions: [
      { id: "", name: "broken" },
      { id: "reveal", name: "Reveal", execute }
    ]
  }]);

  assert.equal(row.disabled, true);
  assert.equal(row.primaryAction, null);
  assert.deepEqual(secondaryActions(row), []);
});

test("disabled secondaries are neither counted nor focusable", () => {
  const [row] = normalizeRows("mpris", [{
    id: "now",
    actions: [
      { id: "toggle", name: "Play", execute },
      { id: "next", name: "Next", execute, enabled: false },
      { id: "previous", name: "Previous", execute }
    ]
  }]);

  assert.deepEqual(secondaryActions(row).map(action => action.id), ["previous"]);
});

test("closeOnExecute defaults true but preserves an explicit false", () => {
  const [row] = normalizeRows("test", [{
    id: "one",
    actions: [
      { id: "open", name: "Open", execute },
      { id: "stay", name: "Stay", execute, closeOnExecute: false }
    ]
  }]);

  assert.equal(row.primaryAction.closeOnExecute, true);
  assert.equal(row.secondaryActions[0].closeOnExecute, false);
});

test("normalization tolerates missing arrays and preserves actions without icons", () => {
  assert.deepEqual(normalizeRows("test", null), []);
  assert.deepEqual(normalizeRows("test", [{ id: "" }]), []);

  const [row] = normalizeRows("test", [{
    id: "iconless",
    actions: [{ id: "open", name: "Open", execute }]
  }]);
  assert.equal(row.primaryAction.icon, undefined);
  assert.equal(row.resultKey, resultKey("test", "iconless"));
});

test("action signatures use ordered displayable ids, not refreshed callbacks", () => {
  const first = normalizeRows("apps", [{
    id: "terminal",
    actions: [
      { id: "launch", name: "Launch", execute },
      { id: "desktop:new-window", name: "New Window", execute }
    ]
  }])[0];
  const refreshed = normalizeRows("apps", [{
    id: "terminal",
    actions: [
      { id: "launch", name: "Launch", execute: () => {} },
      { id: "desktop:new-window", name: "New Window", execute: () => {} }
    ]
  }])[0];
  const changed = normalizeRows("apps", [{
    id: "terminal",
    actions: [
      { id: "launch", name: "Launch", execute },
      { id: "desktop:private", name: "Private Window", execute }
    ]
  }])[0];

  assert.equal(actionSignature(first), '["desktop:new-window"]');
  assert.equal(actionSignature(refreshed), actionSignature(first));
  assert.notEqual(actionSignature(changed), actionSignature(first));
});

test("a label-only secondary refresh preserves action signature and focus identity", () => {
  const [first] = normalizeRows("apps", [{
    id: "terminal",
    actions: [
      { id: "launch", name: "Launch", execute },
      { id: "desktop:new-window", name: "New Window", execute }
    ]
  }]);
  const [refreshed] = normalizeRows("apps", [{
    id: "terminal",
    actions: [
      { id: "launch", name: "Launch", execute },
      { id: "desktop:new-window", name: "Open a New Window", execute }
    ]
  }]);
  const focusedActionId = secondaryActions(first)[0].id;

  assert.equal(actionSignature(refreshed), actionSignature(first));
  assert.equal(secondaryActions(refreshed)[0].id, focusedActionId);
});

test("packActions produces the expected rows for zero through seven actions", () => {
  for (let count = 0; count <= 7; count += 1) {
    const packed = packActions(Array.from({ length: count }, (_, index) => ({ id: String(index) })));
    const lengths = packed.map(row => row.actions.length);
    const fullWidths = packed.map(row => row.fullWidth);

    const expected = [
      { lengths: [], fullWidths: [] },
      { lengths: [1], fullWidths: [true] },
      { lengths: [2], fullWidths: [false] },
      { lengths: [3], fullWidths: [false] },
      { lengths: [2, 2], fullWidths: [false, false] },
      { lengths: [2, 2, 1], fullWidths: [false, false, true] },
      { lengths: [2, 2, 2], fullWidths: [false, false, false] },
      { lengths: [2, 2, 2, 1], fullWidths: [false, false, false, true] }
    ][count];

    assert.deepEqual({ lengths, fullWidths }, expected, "count " + count);
  }
});

test("Shutter geometry keeps the approved dense dimensions", () => {
  assert.deepEqual(LAYOUT, {
    baseWidth: 720,
    workMargin: 32,
    heroRest: 250,
    heroCompressed: 126,
    leadHeight: 82,
    ledgerRowHeight: 44,
    actionRowHeight: 38,
    shelfMaxHeight: 114
  });
});

test("card width is 720px at base scale and caps inside the work area", () => {
  assert.equal(cardGeometry(1920, 1080, 1, 0).width, 720);
  assert.equal(cardGeometry(700, 1080, 1, 0).width, 668);
  assert.equal(cardGeometry(960, 1080, 1.2, 0).width, 864);
  assert.equal(cardGeometry(820, 1080, 1.2, 0).width, 788);
});

test("card height keeps fixed hero and lead while capping the scrollable drawer", () => {
  assert.deepEqual(cardGeometry(1920, 1080, 1, 874), {
    width: 720,
    height: 1000,
    heroHeight: 126,
    bodyHeight: 874
  });
  assert.deepEqual(cardGeometry(1920, 620, 1, 1000), {
    width: 720,
    height: 588,
    heroHeight: 126,
    bodyHeight: 462
  });
  assert.deepEqual(cardGeometry(1920, 620, 1, 0), {
    width: 720,
    height: 250,
    heroHeight: 250,
    bodyHeight: 0
  });
});

test("action shelf uses exact rows, never leaves an odd blank, and caps after three rows", () => {
  for (let count = 1; count <= 7; count += 1) {
    const geometry = shelfGeometry(count, 1);
    const packed = packActions(Array.from({ length: count }, (_, index) => ({ id: String(index) })));
    assert.equal(geometry.rowCount, packed.length, "row count " + count);
    assert.equal(geometry.contentHeight, packed.length * LAYOUT.actionRowHeight, "content " + count);
    assert.equal(geometry.viewportHeight, Math.min(geometry.contentHeight, LAYOUT.shelfMaxHeight), "viewport " + count);
    assert.equal(packed.flatMap(row => row.actions).length, count, "no blank cell " + count);
    if (count >= 4 && count % 2 === 1)
      assert.equal(packed.at(-1).fullWidth, true, "odd final action spans " + count);
  }
});

test("selection follows its key through async insertions and reordering", () => {
  const rows = ids => normalizeRows("apps", ids.map(id => ({
    id,
    actions: [{ id: "launch", execute }]
  })));
  const selected = resultKey("apps", "beta");

  assert.deepEqual(reconcileSelection(rows(["alpha", "beta", "gamma"]), selected, 1), {
    key: selected,
    index: 1
  });
  assert.deepEqual(reconcileSelection(rows(["alpha", "inserted", "beta", "gamma"]), selected, 1), {
    key: selected,
    index: 2
  });
  assert.deepEqual(reconcileSelection(rows(["gamma", "beta", "alpha"]), selected, 2), {
    key: selected,
    index: 1
  });
});

test("composite result keys retain selection for provider-local duplicate ids", () => {
  const [app] = normalizeRows("apps", [{
    id: "same",
    actions: [{ id: "launch", execute }]
  }]);
  const [file] = normalizeRows("find", [{
    id: "same",
    actions: [{ id: "open", execute }]
  }]);

  assert.deepEqual(reconcileSelection([app, file], file.resultKey, 0), {
    key: file.resultKey,
    index: 1
  });
});

test("selection removal falls back to the nearest available rank", () => {
  const rows = normalizeRows("apps", ["alpha", "gamma"].map(id => ({
    id,
    actions: [{ id: "launch", execute }]
  })));

  assert.deepEqual(reconcileSelection(rows, resultKey("apps", "beta"), 1), {
    key: resultKey("apps", "gamma"),
    index: 1
  });
  assert.deepEqual(reconcileSelection(rows, "missing", 99), {
    key: resultKey("apps", "gamma"),
    index: 1
  });
  assert.deepEqual(reconcileSelection([], "missing", 0), { key: "", index: -1 });
});
