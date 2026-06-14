// AdvancedMath.js - Lightweight math library for Ryoku Calculator

function toRadians(degrees) {
    return degrees * (Math.PI / 180);
}

function toDegrees(radians) {
    return radians * (180 / Math.PI);
}

var constants = {
    PI: Math.PI,
    E: Math.E,
    LN2: Math.LN2,
    LN10: Math.LN10,
    LOG2E: Math.LOG2E,
    LOG10E: Math.LOG10E,
    SQRT1_2: Math.SQRT1_2,
    SQRT2: Math.SQRT2
};

function evaluate(expression) {
    try {
        var cleanExpr = expression.replace(/\s+/g, '').toLowerCase();
        
        // Allows numbers (including decimals), basic operators, and explicitly permitted math terms only
        var safeRegex = /^(\d*\.?\d+|[+\-*/()^%,]|sin|cos|tan|asin|acos|atan|atan2|sinh|cosh|tanh|asinh|acosh|atanh|log|ln|exp|pow|sqrt|cbrt|abs|floor|ceil|round|trunc|min|max|random|pi|e|sind|cosd|tand)+$/;

        if (!safeRegex.test(cleanExpr)) {
            throw new Error("Invalid characters or unauthorized functions in expression");
        }

        var processed = cleanExpr
            .replace(/\bpi\b/gi, Math.PI)
            .replace(/\be\b/gi, Math.E);

        processed = processed
            .replace(/\bsin\s*\(/g, 'Math.sin(')
            .replace(/\bcos\s*\(/g, 'Math.cos(')
            .replace(/\btan\s*\(/g, 'Math.tan(')
            .replace(/\basin\s*\(/g, 'Math.asin(')
            .replace(/\bacos\s*\(/g, 'Math.acos(')
            .replace(/\batan\s*\(/g, 'Math.atan(')
            .replace(/\batan2\s*\(/g, 'Math.atan2(')

            .replace(/\bsinh\s*\(/g, 'Math.sinh(')
            .replace(/\bcosh\s*\(/g, 'Math.cosh(')
            .replace(/\btanh\s*\(/g, 'Math.tanh(')
            .replace(/\basinh\s*\(/g, 'Math.asinh(')
            .replace(/\bacosh\s*\(/g, 'Math.acosh(')
            .replace(/\batanh\s*\(/g, 'Math.atanh(')

            .replace(/\blog\s*\(/g, 'Math.log10(')
            .replace(/\bln\s*\(/g, 'Math.log(')
            .replace(/\bexp\s*\(/g, 'Math.exp(')
            .replace(/\bpow\s*\(/g, 'Math.pow(')

            .replace(/\bsqrt\s*\(/g, 'Math.sqrt(')
            .replace(/\bcbrt\s*\(/g, 'Math.cbrt(')

            .replace(/\babs\s*\(/g, 'Math.abs(')
            .replace(/\bfloor\s*\(/g, 'Math.floor(')
            .replace(/\bceil\s*\(/g, 'Math.ceil(')
            .replace(/\bround\s*\(/g, 'Math.round(')
            .replace(/\btrunc\s*\(/g, 'Math.trunc(')

            .replace(/\bmin\s*\(/g, 'Math.min(')
            .replace(/\bmax\s*\(/g, 'Math.max(')

            .replace(/\brandom\s*\(\s*\)/g, 'Math.random()');

        processed = processed
            .replace(/\bsind\s*\(/g, '(function(x) { return Math.sin(' + (Math.PI / 180) + ' * x); })(')
            .replace(/\bcosd\s*\(/g, '(function(x) { return Math.cos(' + (Math.PI / 180) + ' * x); })(')
            .replace(/\btand\s*\(/g, '(function(x) { return Math.tan(' + (Math.PI / 180) + ' * x); })(');

        // Handle ^ for exponentiation: convert 2^3 to Math.pow(2,3)
        processed = processed.replace(/([\d.]+|\))\^([\d.]+|\([^)]*\))/g, 'Math.pow($1,$2)');

        // Replacing eval() with a scoped function constructor
        // This is safe because the strict whitelist guarantees only math reaches this point
        var result = new Function('return ' + processed)();

        if (!isFinite(result) || isNaN(result)) {
            throw new Error("Invalid result");
        }

        return result;
    } catch (error) {
        throw new Error("Evaluation failed: " + error.message);
    }
}

function formatResult(result) {
    if (Number.isInteger(result)) {
        return result.toString();
    }

    // Handle very large or very small numbers
    if (Math.abs(result) >= 1e15 || (Math.abs(result) < 1e-6 && result !== 0)) {
        return result.toExponential(6);
    }

    return parseFloat(result.toFixed(10)).toString();
}

function getAvailableFunctions() {
    return [
        // Basic arithmetic: +, -, *, /, %, ^, ()

        "sin(x), cos(x), tan(x) - trigonometric functions (radians)",
        "sind(x), cosd(x), tand(x) - trigonometric functions (degrees)",
        "asin(x), acos(x), atan(x) - inverse trigonometric",
        "atan2(y, x) - two-argument arctangent",

        "sinh(x), cosh(x), tanh(x) - hyperbolic functions",
        "asinh(x), acosh(x), atanh(x) - inverse hyperbolic",

        "log(x) - base 10 logarithm",
        "ln(x) - natural logarithm",
        "exp(x) - e^x",
        "pow(x, y) - x^y",

        "sqrt(x) - square root",
        "cbrt(x) - cube root",

        "abs(x) - absolute value",
        "floor(x), ceil(x), round(x), trunc(x)",

        "min(a, b, ...), max(a, b, ...)",
        "random() - random number 0-1",

        "pi, e - mathematical constants"
    ];
}
