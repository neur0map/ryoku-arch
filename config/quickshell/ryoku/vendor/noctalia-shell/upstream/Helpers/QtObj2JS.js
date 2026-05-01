// -----------------------------------------------------
// Helper function to convert Qt objects to plain JavaScript objects
// Only used when generating settings-default.json
function qtObjectToPlainObject(obj) {
  if (obj === null || obj === undefined) {
    return obj;
  }

  // Handle primitive types
  if (typeof obj !== "object") {
    return obj;
  }

  // Handle native JavaScript arrays
  if (Array.isArray(obj)) {
    return obj.map((item) => qtObjectToPlainObject(item));
  }

  // Detect QML arrays FIRST (before color detection)
  // QML arrays have a numeric length property and indexed properties
  if (typeof obj.length === "number" && obj.length >= 0) {
    // Check if it has indexed properties - be more flexible about detection
    var hasIndexedProps = true;
    var hasNumericKeys = false;

    // Check if we have at least some numeric properties
    for (var i = 0; i < obj.length; i++) {
      if (obj.hasOwnProperty(i) || obj[i] !== undefined) {
        hasNumericKeys = true;
        break;
      }
    }

    // If we have length > 0 and some numeric keys, treat as array
    if (obj.length > 0 && hasNumericKeys) {
      var arr = [];
      for (var i = 0; i < obj.length; i++) {
        // Use direct property access, handle undefined gracefully
        var item = obj[i];
        if (item !== undefined) {
          arr.push(qtObjectToPlainObject(item));
        }
      }
      return arr; // Return here to avoid processing as object
    }

    // Handle empty arrays (length = 0)
    if (obj.length === 0) {
      return [];
    }
  }

  // Detect and convert QML color objects to hex strings
  if (
    typeof obj.r === "number" &&
    typeof obj.g === "number" &&
    typeof obj.b === "number" &&
    typeof obj.a === "number" &&
    typeof obj.valid === "boolean"
  ) {
    // This looks like a QML color object
    try {
      // Try to get the string representation (should be hex like "#000000")
      if (typeof obj.toString === "function") {
        return obj.toString();
      } else {
        // Fallback: convert RGBA to hex manually
        var r = Math.round(obj.r * 255);
        var g = Math.round(obj.g * 255);
        var b = Math.round(obj.b * 255);
        var hex =
          "#" +
          r.toString(16).padStart(2, "0") +
          g.toString(16).padStart(2, "0") +
          b.toString(16).padStart(2, "0");
        return hex;
      }
    } catch (e) {
      // If conversion fails, fall through to regular object handling
    }
  }

  // Handle regular objects
  var plainObj = {};

  // Get all property names, but filter out Qt-specific ones
  var propertyNames = Object.getOwnPropertyNames(obj);

  for (var i = 0; i < propertyNames.length; i++) {
    var propName = propertyNames[i];

    // Skip Qt-specific properties, functions, and array-like properties
    if (
      propName === "objectName" ||
      propName === "objectNameChanged" ||
      propName === "length" || // Skip length property
      /^\d+$/.test(propName) || // Skip numeric keys (0, 1, 2, etc.)
      propName.endsWith("Changed") ||
      typeof obj[propName] === "function"
    ) {
      continue;
    }

    try {
      var value = obj[propName];
      plainObj[propName] = qtObjectToPlainObject(value);
    } catch (e) {
      // Skip properties that can't be accessed
      continue;
    }
  }

  return plainObj;
}
