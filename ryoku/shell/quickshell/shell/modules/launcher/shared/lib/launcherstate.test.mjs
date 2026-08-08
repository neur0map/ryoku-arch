import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";
import { packActions } from "./results.js";

const require = createRequire(import.meta.url);
const {
  MODES,
  acceptEvaluationSnapshot,
  acceptOuterShrink,
  activationTarget,
  compositionKeyDisposition,
  moveResultIndex,
  escape,
  moveActionFocus,
  planOuterGeometry,
  resolveTypedPrefix,
  routeForMode,
  snapshotMatchesToken,
  selectMode,
  synchronizeOuterGeometry,
  toggleFocusRegion
} = require("./launcherstate.js");

const prefixes = {
  "=": "calc",
  "/": "actions",
  "/file": "find",
  "/image": "find",
  "?": "web"
};

test("mode routes are internal and never inject text into the visible query", () => {
  assert.deepEqual(routeForMode(MODES.REST, ""), {
    providerId: null, prefix: "", query: ""
  });
  assert.deepEqual(routeForMode(MODES.FEDERATED, "fire"), {
    providerId: null, prefix: "", query: "fire"
  });
  assert.deepEqual(routeForMode(MODES.ALL, "fire"), {
    providerId: "apps", prefix: "", query: "fire"
  });
  assert.deepEqual(routeForMode(MODES.IMAGE, "cats"), {
    providerId: "find", prefix: "/image", query: "cats"
  });
  assert.deepEqual(routeForMode(MODES.FILE, "notes"), {
    providerId: "find", prefix: "/file", query: "notes"
  });
  assert.deepEqual(routeForMode(MODES.RECENT, "report"), {
    providerId: "recent", prefix: "", query: "report"
  });
  assert.deepEqual(routeForMode(MODES.HELP, ""), {
    providerId: "help", prefix: "", query: ""
  });
  assert.deepEqual(routeForMode(MODES.SPECIAL, "? weather"), {
    providerId: null, prefix: "", query: "? weather"
  });
});

test("selecting a mode strips one recognized prefix and preserves its payload", () => {
  assert.deepEqual(selectMode(MODES.IMAGE, "? cats", prefixes), {
    mode: MODES.IMAGE, query: "cats"
  });
  assert.deepEqual(selectMode(MODES.FILE, "? /image cats", prefixes), {
    mode: MODES.FILE, query: "/image cats"
  });
  assert.deepEqual(selectMode(MODES.ALL, "fire fox", prefixes), {
    mode: MODES.ALL, query: "fire fox"
  });
  assert.deepEqual(selectMode(MODES.RECENT, "/file", prefixes), {
    mode: MODES.RECENT, query: ""
  });
});

test("typed complete provider prefixes override button modes and stay visible", () => {
  assert.deepEqual(resolveTypedPrefix(MODES.ALL, "? weather", prefixes), {
    mode: MODES.SPECIAL, query: "? weather"
  });
  assert.deepEqual(resolveTypedPrefix(MODES.FILE, "/image cats", prefixes), {
    mode: MODES.SPECIAL, query: "/image cats"
  });
  assert.deepEqual(resolveTypedPrefix(MODES.IMAGE, "/ima", {
    "?": "web",
    "/image": "find"
  }), {
    mode: MODES.IMAGE, query: "/ima"
  });
});

test("an incomplete longer slash prefix is not stolen by the bare action prefix", () => {
  assert.deepEqual(resolveTypedPrefix(MODES.IMAGE, "/ima", prefixes), {
    mode: MODES.IMAGE, query: "/ima"
  });
  assert.deepEqual(resolveTypedPrefix(MODES.FILE, "/", prefixes), {
    mode: MODES.SPECIAL, query: "/"
  });
  assert.deepEqual(resolveTypedPrefix(MODES.FILE, "/image", prefixes), {
    mode: MODES.SPECIAL, query: "/image"
  });
  assert.deepEqual(resolveTypedPrefix(MODES.FILE, "/x", prefixes), {
    mode: MODES.SPECIAL, query: "/x"
  });
  assert.deepEqual(selectMode(MODES.RECENT, "/ima", prefixes), {
    mode: MODES.RECENT, query: "/ima"
  });
  assert.deepEqual(selectMode(MODES.ALL, "/image cats", prefixes), {
    mode: MODES.ALL, query: "cats"
  });
});

test("ordinary input enters federated mode while scoped empty modes stay scoped", () => {
  assert.deepEqual(resolveTypedPrefix(MODES.REST, "fire", prefixes), {
    mode: MODES.FEDERATED, query: "fire"
  });
  assert.deepEqual(resolveTypedPrefix(MODES.FEDERATED, "", prefixes), {
    mode: MODES.REST, query: ""
  });
  for (const mode of [MODES.ALL, MODES.IMAGE, MODES.FILE, MODES.RECENT]) {
    assert.deepEqual(resolveTypedPrefix(mode, "", prefixes), {
      mode, query: ""
    });
    assert.deepEqual(resolveTypedPrefix(mode, "plain", prefixes), {
      mode, query: "plain"
    });
  }
});

test("imperative result snapshots publish only for the current generation and route", () => {
  assert.equal(acceptEvaluationSnapshot(12, 12, "apps\u001ffire", "apps\u001ffire"), true);
  assert.equal(acceptEvaluationSnapshot(11, 12, "apps\u001ffire", "apps\u001ffire"), false);
  assert.equal(acceptEvaluationSnapshot(13, 12, "apps\u001ffire", "apps\u001ffire"), false);
  assert.equal(acceptEvaluationSnapshot(12, 12, "apps\u001ffire", "find\u001ffire"), false);
  assert.equal(acceptEvaluationSnapshot(12, 12, "apps\u001ffire", "apps\u001ffirefox"), false);
});

test("a stored snapshot cannot cross a provider or query boundary", () => {
  assert.equal(snapshotMatchesToken("apps\u0000fire", "apps\u0000fire"), true);
  assert.equal(snapshotMatchesToken("apps\u0000fire", "find\u0000fire"), false);
  assert.equal(snapshotMatchesToken("apps\u0000fire", "apps\u0000firefox"), false);
  assert.equal(snapshotMatchesToken("", "apps\u0000fire"), false);
});

test("drawer close then reopen cancels the stale outer shrink", () => {
  const closing = planOuterGeometry(520, 360, 4);
  assert.deepEqual(closing, {
    generation: 5,
    pendingHeight: 360,
    cancelShrink: false,
    armShrink: true,
    requestHeight: 0,
    growing: false
  });
  assert.equal(acceptOuterShrink(
    closing.generation,
    closing.generation,
    closing.pendingHeight,
    360,
    520
  ), true);

  const reopened = planOuterGeometry(520, 520, closing.generation);
  assert.equal(reopened.cancelShrink, true);
  assert.equal(reopened.armShrink, false);
  assert.equal(acceptOuterShrink(
    closing.generation,
    reopened.generation,
    closing.pendingHeight,
    520,
    520
  ), false);
});

test("shelf close then reopen rejects an armed timer even at the old generation", () => {
  const collapsed = planOuterGeometry(468, 354, 20);
  const reopened = planOuterGeometry(468, 468, collapsed.generation);
  assert.equal(reopened.cancelShrink, true);
  assert.equal(acceptOuterShrink(
    collapsed.generation,
    collapsed.generation,
    collapsed.pendingHeight,
    reopened.pendingHeight,
    468
  ), false);
});

test("outer growth cancels pending shrink and requests the larger surface immediately", () => {
  assert.deepEqual(planOuterGeometry(400, 540, 8), {
    generation: 9,
    pendingHeight: 540,
    cancelShrink: true,
    armShrink: false,
    requestHeight: 540,
    growing: true
  });
});

test("a fresh lifecycle generation resets persistent outer-height bookkeeping", () => {
  const fresh = synchronizeOuterGeometry({
    observedGeneration: 8,
    lifecycleGeneration: 9,
    lifecycleOuterHeight: 250,
    outerGeometryGeneration: 17,
    bodyOpen: false,
    shelfOpen: false
  });

  assert.deepEqual(fresh, {
    observedGeneration: 9,
    outerGeometryGeneration: 18,
    lastOuterHeight: 250,
    pendingOuterHeight: 250,
    lastBodyOpenForGeometry: false,
    lastShelfOpenForGeometry: false
  });

  const typed = planOuterGeometry(
    fresh.lastOuterHeight, 430, fresh.outerGeometryGeneration);
  assert.equal(typed.growing, true);
  assert.equal(typed.requestHeight, 430);
  assert.equal(typed.armShrink, false);
});

test("same-generation close reversal preserves outer-height bookkeeping", () => {
  assert.equal(synchronizeOuterGeometry({
    observedGeneration: 9,
    lifecycleGeneration: 9,
    lifecycleOuterHeight: 250,
    outerGeometryGeneration: 18,
    bodyOpen: false,
    shelfOpen: false
  }), null);
});

test("IME composition owns every key except preedit cancellation", () => {
  assert.equal(compositionKeyDisposition(false, false), "launcher");
  assert.equal(compositionKeyDisposition(true, false), "input");
  assert.equal(compositionKeyDisposition(true, true), "cancel");
});

test("Escape consumes preedit before touching shelf, query, or mode", () => {
  const state = {
    mode: MODES.FILE,
    query: "notes",
    shelfOpen: true,
    actionFocusId: "reveal",
    preeditActive: true
  };
  assert.deepEqual(escape(state), {
    ...state,
    consumed: true,
    cancelPreedit: true
  });
});

test("Escape collapses the shelf before leaving its parent state", () => {
  const first = escape({
    mode: MODES.FILE,
    query: "notes",
    shelfOpen: true,
    actionFocusId: "reveal"
  });
  assert.deepEqual(first, {
    mode: MODES.FILE,
    query: "notes",
    shelfOpen: false,
    actionFocusId: "",
    consumed: true,
    focusQuery: true
  });

  assert.deepEqual(escape(first), {
    mode: MODES.REST,
    query: "",
    shelfOpen: false,
    actionFocusId: "",
    consumed: true,
    focusQuery: true
  });
});

test("Escape clears every body mode to Rest", () => {
  for (const mode of [
    MODES.FEDERATED,
    MODES.ALL,
    MODES.IMAGE,
    MODES.FILE,
    MODES.RECENT,
    MODES.HELP,
    MODES.SPECIAL
  ]) {
    const state = escape({ mode, query: "payload", shelfOpen: false });
    assert.equal(state.mode, MODES.REST);
    assert.equal(state.query, "");
    assert.equal(state.consumed, true);
    assert.equal(state.focusQuery, true);
  }
});

test("Escape closes Rest, cancels Prelude capture, and ignores Closed", () => {
  assert.deepEqual(escape({ mode: MODES.REST, query: "", phase: "open" }), {
    mode: MODES.REST,
    query: "",
    phase: "open",
    consumed: true,
    closeRequested: true
  });
  assert.deepEqual(escape({ mode: MODES.REST, query: "", phase: "prelude" }), {
    mode: MODES.REST,
    query: "",
    phase: "prelude",
    consumed: true,
    closeRequested: true,
    cancelCapture: true
  });
  assert.deepEqual(escape({ mode: MODES.REST, query: "", phase: "closed" }), {
    mode: MODES.REST,
    query: "",
    phase: "closed",
    consumed: false
  });
});

test("Prelude closes capture before clearing a buffered body mode", () => {
  assert.deepEqual(escape({
    mode: MODES.FEDERATED,
    query: "buffered",
    shelfOpen: false,
    phase: "prelude"
  }), {
    mode: MODES.FEDERATED,
    query: "buffered",
    shelfOpen: false,
    phase: "prelude",
    consumed: true,
    closeRequested: true,
    cancelCapture: true
  });
});

test("Prelude still lets preedit and shelf consume Escape first", () => {
  const preedit = escape({
    mode: MODES.FEDERATED,
    query: "buffered",
    shelfOpen: true,
    preeditActive: true,
    phase: "prelude"
  });
  assert.equal(preedit.cancelPreedit, true);
  assert.equal(preedit.closeRequested, undefined);

  const shelf = escape({
    mode: MODES.FEDERATED,
    query: "buffered",
    shelfOpen: true,
    preeditActive: false,
    phase: "prelude"
  });
  assert.equal(shelf.shelfOpen, false);
  assert.equal(shelf.closeRequested, undefined);
});

function actionLayout(count) {
  return packActions(Array.from({ length: count }, (_, index) => ({
    id: `action-${index}`
  })));
}

test("action focus opens on the first secondary for counts one through seven", () => {
  for (let count = 1; count <= 7; count += 1) {
    assert.equal(moveActionFocus(actionLayout(count), "", "Open"), "action-0");
  }
  assert.equal(moveActionFocus([], "", "Open"), "");
});

test("Tab and Shift+Tab wrap linearly for every packed action count", () => {
  for (let count = 1; count <= 7; count += 1) {
    const layout = actionLayout(count);
    assert.equal(moveActionFocus(layout, `action-${count - 1}`, "Tab"), "action-0");
    assert.equal(moveActionFocus(layout, "action-0", "Shift+Tab"), `action-${count - 1}`);
    assert.equal(moveActionFocus(layout, "action-0", "Backtab"), `action-${count - 1}`);
  }
});

test("horizontal action focus stays within its visual row", () => {
  const three = actionLayout(3);
  assert.equal(moveActionFocus(three, "action-0", "Left"), "action-0");
  assert.equal(moveActionFocus(three, "action-0", "Right"), "action-1");
  assert.equal(moveActionFocus(three, "action-2", "Right"), "action-2");

  const six = actionLayout(6);
  assert.equal(moveActionFocus(six, "action-2", "Left"), "action-2");
  assert.equal(moveActionFocus(six, "action-2", "Right"), "action-3");
  assert.equal(moveActionFocus(six, "action-3", "Right"), "action-3");
});

test("vertical action focus does not wrap and keeps the nearest column", () => {
  const six = actionLayout(6);
  assert.equal(moveActionFocus(six, "action-0", "Up"), "action-0");
  assert.equal(moveActionFocus(six, "action-0", "Down"), "action-2");
  assert.equal(moveActionFocus(six, "action-1", "Down"), "action-3");
  assert.equal(moveActionFocus(six, "action-4", "Down"), "action-4");
  assert.equal(moveActionFocus(six, "action-5", "Down"), "action-5");
});

test("a full-width odd final action returns to the source column", () => {
  for (const count of [5, 7]) {
    const fromLeft = actionLayout(count);
    const last = `action-${count - 1}`;
    const left = `action-${count - 3}`;
    assert.equal(moveActionFocus(fromLeft, left, "Down"), last);
    assert.equal(moveActionFocus(fromLeft, last, "Up"), left);

    const fromRight = actionLayout(count);
    const right = `action-${count - 2}`;
    assert.equal(moveActionFocus(fromRight, right, "Down"), last);
    assert.equal(moveActionFocus(fromRight, last, "Up"), right);
    assert.equal(moveActionFocus(fromRight, last, "Down"), last);
  }
});

test("recreating a packed layout intentionally resets odd-row return memory", () => {
  const stableLayout = actionLayout(5);
  assert.equal(moveActionFocus(stableLayout, "action-3", "Down"), "action-4");
  assert.equal(moveActionFocus(stableLayout, "action-4", "Up"), "action-3");

  const recreatedLayout = actionLayout(5);
  assert.equal(moveActionFocus(recreatedLayout, "action-4", "Up"), "action-2");
});

test("unknown keys and stale action ids are stable", () => {
  const layout = actionLayout(4);
  assert.equal(moveActionFocus(layout, "action-1", "Home"), "action-1");
  assert.equal(moveActionFocus(layout, "missing", "Right"), "action-0");
});

test("window focus is an explicit Tab destination and Enter otherwise launches", () => {
  assert.equal(toggleFocusRegion("results", true, false), "windows");
  assert.equal(toggleFocusRegion("windows", true, false), "results");
  assert.equal(toggleFocusRegion("results", true, true), "windows");
  assert.equal(toggleFocusRegion("windows", true, true), "results");
  assert.equal(toggleFocusRegion("results", false, false), "results");

  assert.equal(activationTarget("results", true), "result");
  assert.equal(activationTarget("windows", true), "window");
  assert.equal(activationTarget("windows", false), "result");
});

test("result arrows move through the visible two-column grid", () => {
  assert.equal(moveResultIndex(0, 6, "Right"), 1);
  assert.equal(moveResultIndex(1, 6, "Right"), 1);
  assert.equal(moveResultIndex(1, 6, "Left"), 0);
  assert.equal(moveResultIndex(1, 6, "Down"), 3);
  assert.equal(moveResultIndex(4, 6, "Up"), 2);
  assert.equal(moveResultIndex(4, 5, "Down"), 4);
  assert.equal(moveResultIndex(-1, 6, "Down"), 0);
});
