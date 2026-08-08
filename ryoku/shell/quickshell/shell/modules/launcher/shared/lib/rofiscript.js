// Parse the rofi-script(5) / fuzzel dmenu protocol so existing launcher scripts
// work in Ryoku unchanged. Each output line is one row; a row may carry inline
// directives after a NUL, as key<US>value pairs separated by US (0x1f):
//   Firefox\0icon\x1ffirefox\x1finfo\x1ftab-3
// A leading-NUL line with no display text is a global directive (prompt, message,
// no-custom, markup-rows). Pure logic, node-tested.

var NUL = "\0";
var US = "\x1f";

// Parse full script stdout into { options, rows }. `options` holds global
// directives; `rows` is one entry per selectable line with its directives.
function parse(text) {
    var lines = String(text == null ? "" : text).split("\n");
    var options = {};
    var rows = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (line.length === 0)
            continue;
        var nul = line.indexOf(NUL);
        var display = nul === -1 ? line : line.slice(0, nul);
        var directives = nul === -1 ? {} : parseDirectives(line.slice(nul + 1));
        if (display.length === 0 && nul !== -1) {
            // global directive line: fold its pairs into options.
            for (var k in directives)
                options[k] = directives[k];
            continue;
        }
        rows.push({
            text: display,
            icon: directives.icon || "",
            meta: directives.meta || "",
            info: directives.info || "",
            nonselectable: directives.nonselectable === "true",
            urgent: directives.urgent === "true",
            active: directives.active === "true"
        });
    }
    return { options: options, rows: rows };
}

function parseDirectives(s) {
    var parts = s.split(US);
    var out = {};
    for (var i = 0; i + 1 < parts.length; i += 2)
        out[parts[i]] = parts[i + 1];
    return out;
}

// Build the environment a script is invoked with for a given pass and the chosen
// row's info, mirroring rofi's ROFI_RETV/ROFI_INFO contract. retv: 0 init, 1 a
// selection, 2 a custom entry.
function scriptEnv(retv, info) {
    var env = { ROFI_RETV: String(retv) };
    if (info != null && info.length)
        env.ROFI_INFO = info;
    return env;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parse, parseDirectives, scriptEnv };
}
