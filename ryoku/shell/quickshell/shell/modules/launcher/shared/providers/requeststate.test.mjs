import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const RequestState = require("./requeststate.js");

test("one key stays busy from debounce through process and settles once", () => {
  const idle = RequestState.initial();
  const debouncing = RequestState.begin(idle, "alpha");

  assert.equal(RequestState.isBusy(debouncing), true);
  assert.strictEqual(RequestState.begin(debouncing, "alpha"), debouncing);

  const running = RequestState.markRunning(
    debouncing, "alpha", debouncing.generation
  );
  assert.equal(RequestState.isBusy(running), true);

  const settled = RequestState.settle(
    running, "alpha", running.generation
  );
  assert.equal(RequestState.isBusy(settled), false);
  assert.strictEqual(RequestState.begin(settled, "alpha"), settled);
});

test("a superseding key invalidates every callback from the old generation", () => {
  const alpha = RequestState.begin(RequestState.initial(), "alpha");
  const beta = RequestState.begin(alpha, "beta");

  assert.equal(beta.generation, alpha.generation + 1);
  assert.equal(RequestState.isCurrent(
    beta, "alpha", alpha.generation
  ), false);
  assert.strictEqual(RequestState.markRunning(
    beta, "alpha", alpha.generation
  ), beta);
  assert.strictEqual(RequestState.settle(
    beta, "alpha", alpha.generation
  ), beta);
  assert.equal(RequestState.isBusy(beta), true);
});

test("a failed settled key only becomes requestable after a meaningful change", () => {
  const failed = RequestState.settle(
    RequestState.begin(RequestState.initial(), "alpha"),
    "alpha",
    1
  );

  assert.strictEqual(RequestState.begin(failed, "alpha"), failed);

  const changed = RequestState.begin(failed, "beta");
  assert.equal(RequestState.isBusy(changed), true);

  const alphaAgain = RequestState.begin(changed, "alpha");
  assert.equal(alphaAgain.generation, changed.generation + 1);
  assert.equal(RequestState.isBusy(alphaAgain), true);
});

test("adopting cached rows settles that key and cancels active identity", () => {
  const running = RequestState.markRunning(
    RequestState.begin(RequestState.initial(), "fresh"),
    "fresh",
    1
  );
  const cached = RequestState.adoptSettled(running, "cached");

  assert.equal(cached.key, "cached");
  assert.equal(RequestState.isBusy(cached), false);
  assert.equal(RequestState.isCurrent(running, "fresh", 1), true);
  assert.equal(RequestState.isCurrent(cached, "fresh", 1), false);
  assert.strictEqual(RequestState.adoptSettled(cached, "cached"), cached);
});

test("clearing invalidates active work and lets the same key start later", () => {
  const active = RequestState.begin(RequestState.initial(), "alpha");
  const cleared = RequestState.clear(active);

  assert.equal(cleared.phase, "idle");
  assert.equal(RequestState.isBusy(cleared), false);
  assert.equal(RequestState.isCurrent(
    cleared, "alpha", active.generation
  ), false);

  const restarted = RequestState.begin(cleared, "alpha");
  assert.equal(restarted.generation, cleared.generation + 1);
  assert.equal(RequestState.isBusy(restarted), true);
});
