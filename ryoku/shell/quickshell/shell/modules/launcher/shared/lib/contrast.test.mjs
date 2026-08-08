import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { createRequire } from "node:module";
import test from "node:test";

const require = createRequire(import.meta.url);
const helperPath = new URL("./contrast.js", import.meta.url);
const Contrast = existsSync(helperPath) ? require("./contrast.js") : {};

test("classic contrast helper exposes its QML-safe API", () => {
  assert.equal(typeof Contrast.contrastRatio, "function");
  assert.equal(typeof Contrast.readableForeground, "function");
  assert.equal(typeof Contrast.mutedForeground, "function");
});

test("lead foreground clears 4.5:1 on representative and adversarial containers", () => {
  assert.equal(typeof Contrast.readableForeground, "function");
  assert.equal(typeof Contrast.contrastRatio, "function");

  const backgrounds = [
    "#cdc4ba",
    "#16110b",
    "#6f6f6f",
    "#767676",
    "#00aaff",
    "#ff00ff",
    "#00ff00",
    "#ffff00",
    "#000000",
    "#ffffff"
  ];

  for (const background of backgrounds) {
    const foreground = Contrast.readableForeground(
      background,
      "#040404",
      "#f3ede1",
      4.5
    );
    assert.ok(
      Contrast.contrastRatio(foreground, background) >= 4.5,
      `${background} foreground misses 4.5:1`
    );
  }
});

test("tiny metadata remains muted without dropping below 4.5:1", () => {
  assert.equal(typeof Contrast.mutedForeground, "function");
  assert.equal(typeof Contrast.contrastRatio, "function");

  const backgrounds = [
    "#cdc4ba",
    "#16110b",
    "#6f6f6f",
    "#00aaff",
    "#ff00ff"
  ];

  for (const background of backgrounds) {
    const foreground = Contrast.readableForeground(
      background,
      "#040404",
      "#f3ede1",
      4.5
    );
    const metadata = Contrast.mutedForeground(foreground, background, 4.5);
    const foregroundRatio = Contrast.contrastRatio(foreground, background);
    const metadataRatio = Contrast.contrastRatio(metadata, background);

    assert.ok(metadataRatio >= 4.5, `${background} metadata misses 4.5:1`);
    assert.ok(metadataRatio <= foregroundRatio + 0.0001);
  }
});

test("contrast accounts for alpha compositing instead of treating alpha as opaque", () => {
  assert.equal(typeof Contrast.contrastRatio, "function");

  const translucent = Contrast.contrastRatio(
    { r: 1, g: 1, b: 1, a: 0.62 },
    "#6f6f6f"
  );
  const opaque = Contrast.contrastRatio("#ffffff", "#6f6f6f");

  assert.ok(translucent < opaque);
  assert.ok(translucent < 4.5);
});

test("Qt alpha-first color strings preserve their RGB and alpha channels", () => {
  const qtOpaqueRatio = Contrast.contrastRatio("#ff6f6f6f", "#ff000000");
  const rgbRatio = Contrast.contrastRatio("#6f6f6f", "#000000");
  assert.ok(Math.abs(qtOpaqueRatio - rgbRatio) < 0.0001);

  const qtTranslucent = Contrast.contrastRatio("#9effffff", "#ff6f6f6f");
  const objectTranslucent = Contrast.contrastRatio(
    { r: 1, g: 1, b: 1, a: 158 / 255 },
    "#6f6f6f"
  );
  assert.ok(Math.abs(qtTranslucent - objectTranslucent) < 0.0001);
});
