import assert from "node:assert/strict";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const { describeDesktopActions } = require("./appactions.js");
const { normalizeRows } = require("../../lib/results.js");
const execute = () => {};

function ids(actions) {
  return describeDesktopActions(actions).map(action => action.id);
}

test("zero desktop actions produce no descriptors", () => {
  assert.deepEqual(describeDesktopActions([]), []);
  assert.deepEqual(describeDesktopActions(null), []);
});

test("one, two, and three desktop actions preserve declaration order", () => {
  assert.deepEqual(ids([
    { id: "new-window", name: "New Window", icon: "window-new" }
  ]), ["desktop:new-window"]);

  assert.deepEqual(ids([
    { id: "new-window", name: "New Window", icon: "window-new" },
    { id: "private", name: "New Incognito Window", icon: "" }
  ]), ["desktop:new-window", "desktop:private"]);

  assert.deepEqual(ids([
    { id: "home", name: "Home" },
    { id: "computer", name: "Computer" },
    { id: "trash", name: "Trash" }
  ]), ["desktop:home", "desktop:computer", "desktop:trash"]);
});

test("a missing icon becomes an empty primitive string", () => {
  assert.deepEqual(describeDesktopActions([
    { id: "new-window", name: "New Window" }
  ]), [{
    id: "desktop:new-window",
    desktopId: "new-window",
    name: "New Window",
    icon: "",
    sourceIndex: 0
  }]);
});

test("malformed and duplicate ids are discarded deterministically", () => {
  assert.deepEqual(describeDesktopActions([
    null,
    { id: "", name: "Blank" },
    { id: "   ", name: "Whitespace" },
    { id: "open", name: "First" },
    { id: "open", name: "Duplicate" },
    { id: 7, name: "Numeric" },
    { id: "private", name: "Private" },
    { id: "constructor", name: "Prototype-shaped but valid" }
  ]), [
    {
      id: "desktop:open",
      desktopId: "open",
      name: "First",
      icon: "",
      sourceIndex: 3
    },
    {
      id: "desktop:private",
      desktopId: "private",
      name: "Private",
      icon: "",
      sourceIndex: 6
    },
    {
      id: "desktop:constructor",
      desktopId: "constructor",
      name: "Prototype-shaped but valid",
      icon: "",
      sourceIndex: 7
    }
  ]);
});

test("descriptors retain primitives and source indexes, never source objects", () => {
  const desktopAction = {
    id: "new-window",
    name: "New Window",
    icon: "window-new",
    execute
  };
  const [descriptor] = describeDesktopActions([desktopAction]);

  assert.deepEqual(Object.values(descriptor).map(value => typeof value), [
    "string", "string", "string", "string", "number"
  ]);
  assert.equal(Object.values(descriptor).includes(desktopAction), false);
  assert.equal("execute" in descriptor, false);
});

test("a model revision builds a fresh primitive snapshot", () => {
  const firstModel = [{ id: "new-window", name: "New Window", icon: "old" }];
  const first = describeDesktopActions(firstModel);
  const secondModel = [
    { id: "new-window", name: "Open a New Window", icon: "new" },
    { id: "private", name: "Private", icon: "" }
  ];
  const second = describeDesktopActions(secondModel);

  assert.notEqual(second, first);
  assert.notEqual(second[0], first[0]);
  assert.deepEqual(first.map(action => action.name), ["New Window"]);
  assert.deepEqual(second.map(action => action.name), [
    "Open a New Window", "Private"
  ]);
});

test("desktop action ids remain stable through result normalization", () => {
  const descriptors = describeDesktopActions([
    { id: "new-window", name: "New Window" },
    { id: "private", name: "Private" }
  ]);
  const actions = [{ id: "launch", name: "Launch", execute }].concat(
    descriptors.map(action => ({
      id: action.id,
      name: action.name,
      icon: action.icon,
      execute
    }))
  );
  const [row] = normalizeRows("apps", [{ id: "browser.desktop", actions }]);

  assert.equal(row.primaryAction.id, "launch");
  assert.deepEqual(row.secondaryActions.map(action => action.id), [
    "desktop:new-window", "desktop:private"
  ]);
  assert.equal(row.disabled, false);
});
