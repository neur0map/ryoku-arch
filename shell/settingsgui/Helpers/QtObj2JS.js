// Only used when generating settings-default.json
function qtObjectToPlainObject(obj) {
  if (obj === null || obj === undefined) {
    return obj;
  }

  if (typeof obj !== "object") {
    return obj;
  }

  if (Array.isArray(obj)) {
    return obj.map((item) => qtObjectToPlainObject(item));
  }

  // Detect QML arrays FIRST (before color detection)
  // QML arrays have a numeric length property and indexed properties
  if (typeof obj.length === "number" && obj.length >= 0) {
    var hasIndexedProps = true;
    var hasNumericKeys = false;

    for (var i = 0; i < obj.length; i++) {
      if (obj.hasOwnProperty(i) || obj[i] !== undefined) {
        hasNumericKeys = true;
        break;
      }
    }

    if (obj.length > 0 && hasNumericKeys) {
      var arr = [];
      for (var i = 0; i < obj.length; i++) {
        var item = obj[i];
        if (item !== undefined) {
          arr.push(qtObjectToPlainObject(item));
        }
      }
      return arr; // Return here to avoid processing as object
    }

    if (obj.length === 0) {
      return [];
    }
  }

  if (
    typeof obj.r === "number" &&
    typeof obj.g === "number" &&
    typeof obj.b === "number" &&
    typeof obj.a === "number" &&
    typeof obj.valid === "boolean"
  ) {
    try {
      if (typeof obj.toString === "function") {
        return obj.toString();
      } else {
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

  var plainObj = {};

  var propertyNames = Object.getOwnPropertyNames(obj);

  for (var i = 0; i < propertyNames.length; i++) {
    var propName = propertyNames[i];

    if (
      propName === "objectName" ||
      propName === "objectNameChanged" ||
      propName === "length" ||
      /^\d+$/.test(propName) ||
      propName.endsWith("Changed") ||
      typeof obj[propName] === "function"
    ) {
      continue;
    }

    try {
      var value = obj[propName];
      plainObj[propName] = qtObjectToPlainObject(value);
    } catch (e) {
      continue;
    }
  }

  return plainObj;
}
