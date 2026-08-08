import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { cover, dragFocal, selectSource } = require("./hero.js");

test("cover fills a landscape frame and positions its vertical overflow", () => {
    assert.deepEqual(cover(720, 250, 1600, 900, 0.25, 0.75), {
        width: 720,
        height: 405,
        x: 0,
        y: -116.25
    });
});

test("cover keeps a portrait image full width and moves vertical overflow", () => {
    assert.deepEqual(cover(720, 250, 1000, 1600, 0.5, 1), {
        width: 720,
        height: 1152,
        x: 0,
        y: -902
    });
});

test("cover leaves an equal-aspect image flush with the frame", () => {
    assert.deepEqual(cover(720, 250, 1440, 500, 0, 1), {
        width: 720,
        height: 250,
        x: 0,
        y: 0
    });
});

test("cover honors both focal endpoints without replacing zero", () => {
    assert.deepEqual(cover(250, 250, 500, 250, 0, 0), {
        width: 500,
        height: 250,
        x: 0,
        y: 0
    });
    assert.deepEqual(cover(250, 250, 500, 250, 1, 1), {
        width: 500,
        height: 250,
        x: -250,
        y: 0
    });
});

test("cover returns empty geometry while image dimensions are unavailable", () => {
    assert.deepEqual(cover(720, 250, 0, 0, 0.5, 0.5), {
        width: 0,
        height: 0,
        x: 0,
        y: 0
    });
});

test("dragging right moves the stored focal point left", () => {
    assert.equal(dragFocal(0.5, 100, 400), 0.25);
});

test("drag focal clamps at both ends", () => {
    assert.equal(dragFocal(0.2, 200, 100), 0);
    assert.equal(dragFocal(0.8, -200, 100), 1);
});

test("zero overflow preserves the starting focal point including zero", () => {
    assert.equal(dragFocal(0, 500, 0), 0);
    assert.equal(dragFocal(0.7, -500, 0), 0.7);
});

test("source selection falls back only when the requested source is missing", () => {
    assert.equal(selectSource("", "file:///shipped.png"), "file:///shipped.png");
    assert.equal(selectSource(undefined, "file:///shipped.png"), "file:///shipped.png");
    assert.equal(selectSource(null, "file:///shipped.png"), "file:///shipped.png");
    assert.equal(selectSource("file:///custom.png", "file:///shipped.png"), "file:///custom.png");
});
