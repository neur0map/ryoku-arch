function clamp(value) {
  return Math.max(0, Math.min(1, Number(value)));
}

function color(value) {
  if (typeof value === "string") {
    var hex = value.replace("#", "");
    var alpha = 1;
    if (hex.length === 3)
      hex = hex[0] + hex[0] + hex[1] + hex[1] + hex[2] + hex[2];
    if (hex.length === 8) {
      alpha = parseInt(hex.slice(0, 2), 16) / 255;
      hex = hex.slice(2);
    }
    if (hex.length !== 6)
      return { r: 0, g: 0, b: 0, a: 1 };
    return {
      r: parseInt(hex.slice(0, 2), 16) / 255,
      g: parseInt(hex.slice(2, 4), 16) / 255,
      b: parseInt(hex.slice(4, 6), 16) / 255,
      a: alpha
    };
  }

  return {
    r: clamp(value && value.r),
    g: clamp(value && value.g),
    b: clamp(value && value.b),
    a: value && value.a !== undefined ? clamp(value.a) : 1
  };
}

function composite(foreground, background) {
  var top = color(foreground);
  var bottom = color(background);
  return {
    r: top.r * top.a + bottom.r * (1 - top.a),
    g: top.g * top.a + bottom.g * (1 - top.a),
    b: top.b * top.a + bottom.b * (1 - top.a),
    a: 1
  };
}

function channelLuminance(channel) {
  return channel <= 0.04045
    ? channel / 12.92
    : Math.pow((channel + 0.055) / 1.055, 2.4);
}

function relativeLuminance(value) {
  var current = color(value);
  return 0.2126 * channelLuminance(current.r)
    + 0.7152 * channelLuminance(current.g)
    + 0.0722 * channelLuminance(current.b);
}

function contrastRatio(foreground, background) {
  var backdrop = composite(background, { r: 0, g: 0, b: 0, a: 1 });
  var painted = composite(foreground, backdrop);
  var foregroundLuminance = relativeLuminance(painted);
  var backgroundLuminance = relativeLuminance(backdrop);
  return (Math.max(foregroundLuminance, backgroundLuminance) + 0.05)
    / (Math.min(foregroundLuminance, backgroundLuminance) + 0.05);
}

function mix(from, to, amount) {
  var start = color(from);
  var end = color(to);
  var progress = clamp(amount);
  return {
    r: start.r + (end.r - start.r) * progress,
    g: start.g + (end.g - start.g) * progress,
    b: start.b + (end.b - start.b) * progress,
    a: 1
  };
}

function adjustToward(foreground, destination, background, target) {
  var source = color(foreground);
  var endpoint = color(destination);
  if (contrastRatio(source, background) >= target)
    return source;
  if (contrastRatio(endpoint, background) < target)
    return endpoint;

  var failing = 0;
  var passing = 1;
  for (var index = 0; index < 24; index++) {
    var midpoint = (failing + passing) / 2;
    if (contrastRatio(mix(source, endpoint, midpoint), background) >= target)
      passing = midpoint;
    else
      failing = midpoint;
  }
  return mix(source, endpoint, passing);
}

function readableForeground(background, dark, light, minimumRatio) {
  var target = Math.max(1, Number(minimumRatio) || 4.5);
  var darkCandidate = color(dark);
  var lightCandidate = color(light);
  var darkRatio = contrastRatio(darkCandidate, background);
  var lightRatio = contrastRatio(lightCandidate, background);
  var chosen = darkRatio >= lightRatio ? darkCandidate : lightCandidate;
  if (Math.max(darkRatio, lightRatio) >= target)
    return chosen;

  var black = { r: 0, g: 0, b: 0, a: 1 };
  var white = { r: 1, g: 1, b: 1, a: 1 };
  var destination = contrastRatio(black, background)
    >= contrastRatio(white, background) ? black : white;
  return adjustToward(chosen, destination, background, target + 0.02);
}

function mutedForeground(foreground, background, minimumRatio) {
  var target = Math.max(1, Number(minimumRatio) || 4.5);
  var safeTarget = target + 0.02;
  var source = color(foreground);
  if (contrastRatio(source, background) < safeTarget)
    source = readableForeground(background, source, source, safeTarget);

  var passing = 0;
  var failing = 1;
  for (var index = 0; index < 24; index++) {
    var midpoint = (passing + failing) / 2;
    if (contrastRatio(mix(source, background, midpoint), background) >= safeTarget)
      passing = midpoint;
    else
      failing = midpoint;
  }
  return mix(source, background, passing);
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    contrastRatio,
    mutedForeground,
    readableForeground
  };
}
