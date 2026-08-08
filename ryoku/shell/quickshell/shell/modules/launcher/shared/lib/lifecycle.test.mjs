import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const {
  CAPTURE,
  PHASES,
  frostBackdropOpacity,
  frostPresentation,
  initialState,
  mapsMonitor,
  recoveryMonitor,
  reduce,
  shadowEnvelope,
  surfaceBudget
} = require("./lifecycle.js");

function openPrelude(options = {}) {
  return reduce(initialState(), {
    type: "show",
    monitor: options.monitor || "DP-1",
    height: options.height || 250,
    frostEligible: options.frostEligible !== false
  });
}

function transition(state, type, details = {}) {
  return reduce(state, {
    ...details,
    type,
    generation: state.generation
  });
}

function passPrelude(state) {
  state = transition(state, "captureReady");
  state = transition(state, "frameTick");
  return transition(state, "frameTick");
}

test("show maps one transparent Prelude and starts a fresh frost generation", () => {
  const state = openPrelude();

  assert.equal(state.phase, PHASES.PRELUDE);
  assert.equal(state.generation, 1);
  assert.equal(state.monitor, "DP-1");
  assert.equal(state.mapped, true);
  assert.equal(state.focusHeld, true);
  assert.equal(state.visualTransparent, true);
  assert.equal(state.capture, CAPTURE.PENDING);
  assert.equal(state.captureDeadlineMs, 50);
  assert.equal(mapsMonitor(state, "DP-1"), true);
  assert.equal(mapsMonitor(state, "HDMI-A-1"), false);
});

test("Prelude requires exactly two render ticks and a terminal frost gate", () => {
  let state = openPrelude();

  state = transition(state, "frameTick");
  assert.equal(state.preludeTicks, 1);
  assert.equal(state.phase, PHASES.PRELUDE);

  state = transition(state, "frameTick");
  assert.equal(state.preludeTicks, 2);
  assert.equal(state.phase, PHASES.PRELUDE);

  state = reduce(state, {
    type: "captureReady",
    generation: state.generation
  });
  assert.equal(state.phase, PHASES.OPENING);
  assert.equal(state.visualTransparent, false);
});

test("frost timeout opens after the two ticks and rejects a late frame", () => {
  let state = openPrelude();
  const generation = state.generation;

  state = transition(state, "frameTick");
  state = transition(state, "frameTick");
  state = reduce(state, { type: "captureTimeout", generation });
  assert.equal(state.capture, CAPTURE.TIMED_OUT);
  assert.equal(state.phase, PHASES.OPENING);

  const late = reduce(state, { type: "captureReady", generation });
  assert.deepEqual(late, state);
});

test("skipped frost still waits for both Prelude ticks", () => {
  let state = openPrelude({ frostEligible: false });
  assert.equal(state.capture, CAPTURE.SKIPPED);

  state = transition(state, "frameTick");
  assert.equal(state.phase, PHASES.PRELUDE);
  state = transition(state, "frameTick");
  assert.equal(state.phase, PHASES.OPENING);
});

test("failed and unavailable capture take the solid-drawer path", () => {
  for (const eventType of ["captureFailed", "captureUnavailable"]) {
    let state = openPrelude();
    state = transition(state, "frameTick");
    state = transition(state, "frameTick");
    state = reduce(state, {
      type: eventType,
      generation: state.generation
    });
    assert.equal(state.capture, CAPTURE.FAILED);
    assert.equal(state.phase, PHASES.OPENING);
    assert.equal(state.visualTransparent, false);
  }
});

test("stale capture and timeout callbacks cannot cross an invocation", () => {
  const state = openPrelude();
  assert.deepEqual(reduce(state, {
    type: "captureReady",
    generation: state.generation + 1
  }), state);
  assert.deepEqual(reduce(state, {
    type: "captureTimeout",
    generation: state.generation - 1
  }), state);
});

test("render ticks and close completion require the active generation", () => {
  let state = openPrelude();
  const generation = state.generation;

  assert.deepEqual(reduce(state, { type: "frameTick" }), state);
  assert.deepEqual(reduce(state, {
    type: "frameTick",
    generation: generation - 1
  }), state);

  state = reduce(state, { type: "frameTick", generation });
  assert.equal(state.preludeTicks, 1);

  state = reduce(state, { type: "hide" });
  assert.deepEqual(reduce(state, { type: "closeComplete" }), state);
  assert.deepEqual(reduce(state, {
    type: "closeComplete",
    generation: generation - 1
  }), state);
});

test("input growth waits for both a render tick and the configured outer height", () => {
  let state = openPrelude({ height: 250 });
  state = transition(state, "grow", { height: 430, duration: 280 });

  assert.equal(state.phase, PHASES.PRELUDE);
  assert.equal(state.targetHeight, 430);
  assert.equal(state.outerHeight, 430);
  assert.equal(state.maskHeight, 250);
  assert.equal(state.geometryStage, "grow-outer");

  state = transition(state, "frameTick");
  assert.equal(state.growTickReady, true);
  assert.equal(state.maskHeight, 250);
  assert.equal(state.geometryStage, "grow-outer");

  state = reduce(state, {
    type: "outerConfigured",
    generation: state.generation,
    height: 430
  });
  assert.equal(state.maskHeight, 430);
  assert.equal(state.visibleHeight, 430);
  assert.equal(state.geometryStage, "stable");
});

test("outer configure before the grow tick still waits for that tick", () => {
  let state = openPrelude({ height: 250 });
  state = transition(state, "grow", { height: 430 });
  state = reduce(state, {
    type: "outerConfigured",
    generation: state.generation,
    height: 430
  });

  assert.equal(state.outerConfigured, true);
  assert.equal(state.maskHeight, 250);
  state = transition(state, "frameTick");
  assert.equal(state.maskHeight, 430);
});

test("a bounded grow fallback reveals no more than the configured safe capacity", () => {
  let state = openPrelude({ height: 250 });
  state = transition(state, "grow", { height: 430 });
  state = transition(state, "frameTick");
  state = reduce(state, {
    type: "growFallback",
    generation: state.generation,
    height: 310
  });

  assert.equal(state.visibleHeight, 310);
  assert.equal(state.maskHeight, 310);
  // Keep the already-submitted outer request alive. A later real geometry
  // change may safely trigger one fresh grow request without a frame loop.
  assert.equal(state.outerHeight, 430);
  assert.equal(state.geometryStage, "stable");
  assert.equal(state.growTickReady, false);

  const lateConfigure = reduce(state, {
    type: "outerConfigured",
    generation: state.generation,
    height: 430
  });
  assert.deepEqual(lateConfigure, state);

  const retried = transition(state, "grow", {
    height: 430
  });
  assert.equal(retried.geometryStage, "grow-outer");
  assert.equal(retried.outerHeight, 430);
});

test("shrink waits for the visible animation and one render tick before the outer window", () => {
  let state = openPrelude({ height: 430 });
  state = passPrelude(state);
  state = transition(state, "openComplete");
  state = transition(state, "shrink", { height: 250, duration: 280 });

  assert.equal(state.phase, PHASES.OPEN);
  assert.equal(state.targetHeight, 250);
  assert.equal(state.visibleHeight, 250);
  assert.equal(state.maskHeight, 250);
  assert.equal(state.outerHeight, 430);
  assert.equal(state.geometryStage, "shrink-card");
  assert.equal(state.geometryDuration, 280);

  state = transition(state, "frameTick");
  assert.equal(state.outerHeight, 430);
  assert.equal(state.geometryStage, "shrink-card");

  state = reduce(state, {
    type: "shrinkVisualComplete",
    generation: state.generation
  });
  assert.equal(state.outerHeight, 430);
  assert.equal(state.geometryStage, "shrink-wait-tick");

  state = transition(state, "frameTick");
  assert.equal(state.outerHeight, 250);
  assert.equal(state.geometryStage, "stable");
});

test("a stale shrink completion cannot collapse a newer geometry generation", () => {
  let state = passPrelude(openPrelude({ height: 430 }));
  state = transition(state, "shrink", { height: 250, duration: 280 });
  const generation = state.generation;
  state = transition(state, "grow", { height: 520, duration: 180 });

  const stale = reduce(state, {
    type: "shrinkVisualComplete",
    generation: generation - 1
  });
  assert.deepEqual(stale, state);
  assert.equal(stale.geometryStage, "grow-outer");
});

test("interrupted shrink settles the replacement grow at its pending outer height", () => {
  let state = passPrelude(openPrelude({ height: 430 }));
  state = reduce(state, {
    type: "shrink",
    generation: state.generation,
    height: 200,
    duration: 280
  });
  state = reduce(state, {
    type: "grow",
    generation: state.generation,
    height: 300,
    duration: 180
  });

  assert.equal(state.outerHeight, 430);
  assert.equal(state.pendingOuterHeight, 300);
  assert.equal(state.geometryStage, "grow-outer");

  state = reduce(state, {
    type: "frameTick",
    generation: state.generation
  });
  state = reduce(state, {
    type: "outerConfigured",
    generation: state.generation,
    height: 430
  });

  assert.equal(state.visibleHeight, 300);
  assert.equal(state.maskHeight, 300);
  assert.equal(state.outerHeight, 300);
  assert.equal(state.geometryStage, "stable");
});

test("visible close finishes visually before transparent ticks and unmap", () => {
  let state = passPrelude(openPrelude());
  state = transition(state, "openComplete");
  state = reduce(state, { type: "hide" });

  assert.equal(state.phase, PHASES.CLOSING);
  assert.equal(state.closeStage, "visual");
  assert.equal(state.focusHeld, true);
  assert.equal(state.unmapRequested, false);

  state = reduce(state, {
    type: "visualHidden",
    generation: state.generation
  });
  assert.equal(state.closeStage, "transparent");
  assert.equal(state.visualTransparent, true);
  assert.equal(state.closeDeadlineMs, 50);

  state = transition(state, "frameTick");
  assert.equal(state.closeTicks, 1);
  assert.equal(state.unmapRequested, false);
  state = transition(state, "frameTick");
  assert.equal(state.closeTicks, 2);
  assert.equal(state.unmapRequested, true);
  assert.equal(state.phase, PHASES.CLOSING);
  assert.equal(state.focusHeld, true);

  state = reduce(state, {
    type: "unmapped",
    generation: state.generation
  });
  assert.equal(state.phase, PHASES.CLOSED);
  assert.equal(state.mapped, false);
  assert.equal(state.focusHeld, false);
});

test("close render fallback requests unmap after the bounded deadline", () => {
  let state = passPrelude(openPrelude());
  state = reduce(state, { type: "hide" });
  state = reduce(state, {
    type: "visualHidden",
    generation: state.generation
  });
  state = reduce(state, {
    type: "closeFallback",
    generation: state.generation
  });

  assert.equal(state.closeTicks, 0);
  assert.equal(state.unmapRequested, true);
  assert.equal(state.visualTransparent, true);
});

test("Prelude Escape cancels capture and closes without a visible exit", () => {
  let state = openPrelude();
  state = reduce(state, { type: "hide" });

  assert.equal(state.phase, PHASES.CLOSING);
  assert.equal(state.capture, CAPTURE.CANCELLED);
  assert.equal(state.closeStage, "transparent");
  assert.equal(state.visualTransparent, true);
  assert.equal(state.unmapRequested, false);
});

test("rapid reopen before unmap reuses the current frost generation", () => {
  let state = openPrelude();
  state = passPrelude(state);
  state = reduce(state, { type: "hide" });
  const reopened = reduce(state, {
    type: "show",
    monitor: "DP-1",
    height: 250,
    frostEligible: true
  });

  assert.equal(reopened.generation, 1);
  assert.equal(reopened.capture, CAPTURE.READY);
  assert.equal(reopened.phase, PHASES.OPENING);
  assert.equal(reopened.unmapRequested, false);
  assert.equal(reopened.focusHeld, true);
});

test("rapid reopen preserves the current query geometry instead of flashing Rest", () => {
  let state = passPrelude(openPrelude({ height: 250 }));
  state = transition(state, "grow", { height: 430 });
  state = transition(state, "frameTick");
  state = reduce(state, {
    type: "outerConfigured",
    generation: state.generation,
    height: 430
  });
  state = reduce(state, { type: "hide" });

  const reopened = reduce(state, {
    type: "show",
    monitor: "DP-1",
    height: 250,
    frostEligible: true
  });
  assert.equal(reopened.targetHeight, 430);
  assert.equal(reopened.outerHeight, 430);
  assert.equal(reopened.visibleHeight, 430);
});

test("reverse reuses the same invocation in both directions", () => {
  let state = passPrelude(openPrelude());
  state = reduce(state, { type: "reverse" });
  assert.equal(state.phase, PHASES.CLOSING);
  const generation = state.generation;
  state = reduce(state, { type: "reverse" });
  assert.equal(state.phase, PHASES.OPENING);
  assert.equal(state.generation, generation);
});

test("a closed reopen creates a fresh generation", () => {
  let state = openPrelude();
  state = reduce(state, { type: "hide" });
  state = transition(state, "closeComplete");
  const reopened = reduce(state, {
    type: "show",
    monitor: "DP-1",
    height: 250,
    frostEligible: true
  });

  assert.equal(reopened.generation, 2);
  assert.equal(reopened.phase, PHASES.PRELUDE);
});

test("monitor transfer closes and unmaps the old output before mapping the new one", () => {
  let state = passPrelude(openPrelude({ monitor: "DP-1" }));
  state = transition(state, "openComplete");
  state = reduce(state, {
    type: "show",
    monitor: "HDMI-A-1",
    height: 300,
    frostEligible: true
  });

  assert.equal(state.phase, PHASES.CLOSING);
  assert.equal(state.monitor, "DP-1");
  assert.equal(state.pendingMonitor, "HDMI-A-1");
  assert.equal(mapsMonitor(state, "DP-1"), true);
  assert.equal(mapsMonitor(state, "HDMI-A-1"), false);

  state = reduce(state, {
    type: "visualHidden",
    generation: state.generation
  });
  state = reduce(state, {
    type: "closeFallback",
    generation: state.generation
  });
  state = reduce(state, {
    type: "unmapped",
    generation: state.generation
  });

  assert.equal(state.phase, PHASES.PRELUDE);
  assert.equal(state.generation, 2);
  assert.equal(state.monitor, "HDMI-A-1");
  assert.equal(mapsMonitor(state, "DP-1"), false);
  assert.equal(mapsMonitor(state, "HDMI-A-1"), true);
});

test("hide during monitor transfer cancels the pending output", () => {
  let state = passPrelude(openPrelude({ monitor: "DP-1" }));
  state = reduce(state, {
    type: "show",
    monitor: "HDMI-A-1",
    height: 300,
    frostEligible: true
  });
  state = reduce(state, { type: "hide" });

  assert.equal(state.phase, PHASES.CLOSING);
  assert.equal(state.pendingMonitor, "");
  state = transition(state, "closeComplete");
  assert.equal(state.phase, PHASES.CLOSED);
});

test("stale unmap from the old monitor cannot close the transferred generation", () => {
  let state = passPrelude(openPrelude({ monitor: "DP-1" }));
  state = reduce(state, {
    type: "show",
    monitor: "HDMI-A-1",
    height: 250,
    frostEligible: false
  });
  state = transition(state, "closeComplete");
  assert.equal(state.generation, 2);
  assert.equal(state.monitor, "HDMI-A-1");

  const stale = reduce(state, { type: "unmapped", generation: 1 });
  assert.deepEqual(stale, state);
});

test("stale animation and geometry callbacks cannot mutate a new invocation", () => {
  let state = openPrelude({ height: 250 });
  state = reduce(state, { type: "hide" });
  state = transition(state, "closeComplete");
  state = reduce(state, {
    type: "show",
    monitor: "DP-1",
    height: 250,
    frostEligible: true
  });

  for (const event of [
    { type: "openComplete", generation: state.generation - 1 },
    { type: "grow", generation: state.generation - 1, height: 500 },
    { type: "shrink", generation: state.generation - 1, height: 100 },
    { type: "visualHidden", generation: state.generation - 1 }
  ]) {
    assert.deepEqual(reduce(state, event), state);
  }
});

test("active surface loss is monitor and generation qualified", () => {
  const state = passPrelude(openPrelude({ monitor: "DP-1", height: 430 }));

  for (const event of [
    {
      type: "surfaceLost",
      generation: state.generation - 1,
      monitor: "DP-1"
    },
    {
      type: "surfaceLost",
      generation: state.generation,
      monitor: "HDMI-A-1"
    }
  ]) {
    assert.deepEqual(reduce(state, event), state);
  }

  const lost = reduce(state, {
    type: "surfaceLost",
    generation: state.generation,
    monitor: "DP-1"
  });
  assert.equal(lost.phase, PHASES.CLOSED);
  assert.equal(lost.mapped, false);
  assert.equal(lost.focusHeld, false);
  assert.equal(lost.generation, state.generation);
});

test("surface loss releases focus before a shell-revalidated fresh show", () => {
  let state = passPrelude(openPrelude({ monitor: "DP-1", height: 430 }));
  state = reduce(state, {
    type: "show",
    monitor: "HDMI-A-1",
    height: 300,
    frostEligible: true
  });

  state = reduce(state, {
    type: "surfaceLost",
    generation: state.generation,
    monitor: "DP-1",
    replacementMonitor: "eDP-1",
    replacementHeight: 250,
    replacementFrostEligible: false
  });

  assert.equal(state.phase, PHASES.CLOSED);
  assert.equal(state.generation, 1);
  assert.equal(state.focusHeld, false);
  assert.equal(state.mapped, false);

  state = reduce(state, {
    type: "show",
    monitor: "eDP-1",
    height: 250,
    frostEligible: false
  });
  assert.equal(state.phase, PHASES.PRELUDE);
  assert.equal(state.generation, 2);
  assert.equal(state.monitor, "eDP-1");
  assert.equal(state.outerHeight, 250);
  assert.equal(state.capture, CAPTURE.SKIPPED);
  assert.equal(state.pendingMonitor, "");
  assert.equal(state.focusHeld, true);
});

test("recovery monitor uses only a currently available shell target", () => {
  assert.equal(recoveryMonitor({
    availableMonitors: ["eDP-1", "DP-2"],
    pendingMonitor: "HDMI-A-1",
    requestedMonitor: "DP-2",
    focusedMonitor: "eDP-1",
    currentMonitor: "HDMI-A-1"
  }), "DP-2");

  assert.equal(recoveryMonitor({
    availableMonitors: ["eDP-1"],
    pendingMonitor: "DP-2",
    requestedMonitor: "DP-2",
    focusedMonitor: "DP-2",
    currentMonitor: "DP-2"
  }), "eDP-1");

  assert.equal(recoveryMonitor({
    availableMonitors: [],
    pendingMonitor: "DP-2",
    requestedMonitor: "DP-2",
    focusedMonitor: "DP-2",
    currentMonitor: "DP-2"
  }), "");
});

test("non-invocation outputs remain unmapped in every active phase", () => {
  let state = openPrelude({ monitor: "eDP-1" });
  for (const next of [
    state,
    transition(state, "frameTick"),
    passPrelude(state),
    reduce(passPrelude(state), { type: "hide" })
  ]) {
    assert.equal(mapsMonitor(next, "eDP-1"), true);
    assert.equal(mapsMonitor(next, "DP-3"), false);
  }
  assert.equal(mapsMonitor(initialState(), "eDP-1"), false);
});

test("surface budget reserves top placement, shadow envelope, and screen edges", () => {
  const budget = surfaceBudget({
    screenWidth: 800,
    screenHeight: 600,
    topMargin: 150,
    shadowPadX: 52,
    shadowPadTop: 38,
    shadowPadBottom: 68,
    bottomSafeMargin: 16,
    compressedHeroHeight: 126
  });

  assert.deepEqual(budget, {
    workAreaWidth: 696,
    workAreaHeight: 360,
    maxCardHeight: 328,
    maxDrawerHeight: 202
  });
  assert.ok((budget.workAreaWidth - 32) + 52 * 2 <= 800);
  assert.ok(150 + 38 + budget.maxCardHeight + 68 + 16 <= 600);
  assert.ok(150 + 38 + 126 + budget.maxDrawerHeight <= 600);
});

test("shadow envelope covers broad blur at both animation extrema", () => {
  const envelope = shadowEnvelope({
    blur: 36,
    spread: 2,
    shadowOffsetY: 24,
    openTranslateUp: 13,
    closeTranslateDown: 8
  });

  assert.deepEqual(envelope, {
    top: 51,
    bottom: 70,
    side: 38
  });
  assert.ok(54 >= envelope.top);
  assert.ok(76 >= envelope.bottom);
  assert.ok(52 >= envelope.side);
});

test("frost presentation is dormant at Rest and bounded to the visible drawer", () => {
  assert.deepEqual(frostPresentation({
    frostActive: true,
    drawerHeight: 0,
    drawerOpacity: 0,
    maxDrawerHeight: 500,
    sourceHeight: 540,
    bleedTop: 24,
    bleedBottom: 16
  }), {
    active: false,
    drawerHeight: 0,
    textureHeight: 0
  });

  assert.deepEqual(frostPresentation({
    frostActive: true,
    drawerHeight: 300,
    drawerOpacity: 0.42,
    maxDrawerHeight: 500,
    sourceHeight: 540,
    bleedTop: 24,
    bleedBottom: 16
  }), {
    active: true,
    drawerHeight: 300,
    textureHeight: 340,
    opacity: 0.42
  });

  assert.deepEqual(frostPresentation({
    frostActive: true,
    drawerHeight: 900,
    drawerOpacity: 1,
    maxDrawerHeight: 500,
    sourceHeight: 540,
    bleedTop: 24,
    bleedBottom: 16
  }), {
    active: true,
    drawerHeight: 500,
    textureHeight: 540,
    opacity: 1
  });
});

test("an active frost keeps the captured backdrop visibly present", () => {
  assert.equal(frostBackdropOpacity(false), 1);
  assert.equal(frostBackdropOpacity(true), 0.72);
});
