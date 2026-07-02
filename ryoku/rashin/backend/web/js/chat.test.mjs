import { test } from "node:test";
import assert from "node:assert/strict";
import { applyEvent, initialState } from "./chat.js";

function reduce(events) {
  return events.reduce(applyEvent, initialState());
}

test("agent_text appends to a single open message", () => {
  const s = reduce([
    { type: "agent_text", text: "Hel" },
    { type: "agent_text", text: "lo" },
  ]);
  const msgs = s.items.filter((i) => i.kind === "msg" && i.role === "agent");
  assert.equal(msgs.length, 1);
  assert.equal(msgs[0].text, "Hello");
  assert.equal(msgs[0].open, true);
});

test("turn_end closes the open message and clears busy", () => {
  const s = reduce([
    { type: "state", state: "busy" },
    { type: "agent_text", text: "hi" },
    { type: "turn_end", stopReason: "end_turn" },
  ]);
  const msg = s.items.find((i) => i.role === "agent");
  assert.equal(msg.open, false);
  assert.equal(s.busy, false);
});

test("text after turn_end starts a fresh message", () => {
  const s = reduce([
    { type: "agent_text", text: "one" },
    { type: "turn_end" },
    { type: "agent_text", text: "two" },
  ]);
  const msgs = s.items.filter((i) => i.role === "agent");
  assert.equal(msgs.length, 2);
  assert.deepEqual(msgs.map((m) => m.text), ["one", "two"]);
});

test("agent_thought accumulates on the open message", () => {
  const s = reduce([
    { type: "agent_thought", text: "plan " },
    { type: "agent_thought", text: "steps" },
    { type: "agent_text", text: "answer" },
  ]);
  const msg = s.items.find((i) => i.role === "agent");
  assert.equal(msg.thought, "plan steps");
  assert.equal(msg.text, "answer");
});

test("tool status transitions update the same card by id", () => {
  const s = reduce([
    { type: "tool", id: "t1", title: "Running ls", kind: "execute", status: "pending" },
    { type: "tool", id: "t1", status: "in_progress" },
    { type: "tool", id: "t1", status: "completed" },
  ]);
  const tools = s.items.filter((i) => i.kind === "tool");
  assert.equal(tools.length, 1);
  assert.equal(tools[0].status, "completed");
  assert.equal(tools[0].title, "Running ls", "title preserved across updates");
  assert.equal(tools[0].kind2, "execute", "kind preserved across updates");
});

test("distinct tool ids create distinct cards", () => {
  const s = reduce([
    { type: "tool", id: "t1", status: "pending" },
    { type: "tool", id: "t2", status: "pending" },
  ]);
  assert.equal(s.items.filter((i) => i.kind === "tool").length, 2);
});

test("permission queues then reply removes it", () => {
  let s = reduce([
    { type: "permission", requestId: "r1", title: "Run?", options: [{ id: "allow", name: "Allow", kind: "allow_once" }] },
  ]);
  assert.equal(s.permissions.length, 1);
  assert.equal(s.permissions[0].requestId, "r1");
  s = applyEvent(s, { type: "permission_reply", requestId: "r1" });
  assert.equal(s.permissions.length, 0);
});

test("state event sets banner and busy flag", () => {
  let s = applyEvent(initialState(), { type: "state", state: "busy", model: "hermes-1" });
  assert.equal(s.banner.state, "busy");
  assert.equal(s.banner.model, "hermes-1");
  assert.equal(s.busy, true);
  s = applyEvent(s, { type: "state", state: "dead", error: "no hermes" });
  assert.equal(s.banner.state, "dead");
  assert.equal(s.banner.error, "no hermes");
  assert.equal(s.busy, false);
});

test("user event appends a right-aligned user message", () => {
  const s = applyEvent(initialState(), { type: "user", text: "hey" });
  assert.equal(s.items.length, 1);
  assert.equal(s.items[0].role, "user");
  assert.equal(s.items[0].text, "hey");
});

test("applyEvent does not mutate the input state", () => {
  const s0 = initialState();
  const s1 = applyEvent(s0, { type: "user", text: "x" });
  assert.equal(s0.items.length, 0, "original items untouched");
  assert.notEqual(s0, s1);
});

test("unknown event returns state unchanged", () => {
  const s0 = initialState();
  const s1 = applyEvent(s0, { type: "mystery" });
  assert.equal(s0, s1);
});
