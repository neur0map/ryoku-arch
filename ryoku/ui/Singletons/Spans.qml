pragma Singleton

import QtQuick
import Quickshell

// A cell's width and height come from what its control needs, never from a
// layout decision made by hand. This is the whole reason the design survives
// 27 pages: adding a setting is a data change, not a placement problem.
//
// The bands come from counting the real Hub: 14 controls have 2 options, 21
// have 3, 9 have 4-6, one has 7, the font catalogue has 25, and islandModules
// is a true set. Five or more options is never a segmented; nine or more is
// never inline.
Singleton {
    readonly property int cols: 12

    // options: how many choices the control offers (0 for sw/step/slid)
    function of(ctl, options) {
        var o = options || 0;
        switch (ctl) {
        case "sw":      return 4;
        case "step":    return 4;
        case "slid":    return 6;
        case "seg":     return o <= 2 ? 4 : (o === 3 ? 8 : 8);
        case "chips":   return 10;
        case "pick":    return 5;
        case "multi":   return 12;
        case "gallery": return 12;
        }
        return 4;
    }

    function rows(ctl) {
        switch (ctl) {
        case "gallery": return 3;
        case "chips":   return 2;
        case "multi":   return 2;
        }
        return 1;
    }

    // Bento packing: greedy-fill rows of `cols` columns, then stretch each row
    // to the full width, so a sheet never ends in a ragged right edge. Input is
    // the declared spans in order; output is the adjusted spans, same order.
    // `minSpan` lifts a span that would render below a usable width.
    function pack(declared, minSpan) {
        var out = [], row = [], used = 0;
        function close() {
            if (row.length === 0) return;
            var spare = cols - used, i;
            var each = Math.floor(spare / row.length);
            for (i = 0; i < row.length; i++) row[i].s += each;
            row[row.length - 1].s += spare - each * row.length;
            for (i = 0; i < row.length; i++) out.push(row[i].s);
            row = []; used = 0;
        }
        for (var i = 0; i < declared.length; i++) {
            var s = Math.min(cols, Math.max(declared[i], minSpan || 1));
            if (used + s > cols) close();
            row.push({ s: s });
            used += s;
        }
        close();
        return out;
    }

    // does the control get its own band under the text, or sit beside it?
    function isBlock(ctl) {
        return rows(ctl) > 1;
    }

    // width to reserve for an inline control so the text column stops short of
    // it. Overlap is prevented by reservation, not by tuning margins.
    function inlineWidth(ctl, options, cellWidth) {
        switch (ctl) {
        case "sw":   return 54;
        case "step": return 58;
        case "slid": return Math.round(cellWidth * 0.42);
        case "seg":  return Math.max(52, 52 * (options || 2));
        case "pick": return 0;    // pick owns the cell foot, not a side slot
        case "text": return 0;    // free entry owns the cell foot, like pick
        }
        return 0;
    }

    // the control taxonomy, chosen from the option set rather than by taste.
    // kind: bool | int | ratio | enum | set | catalogue | visual
    function controlFor(kind, options) {
        var o = options || 0;
        if (kind === "bool") return "sw";
        if (kind === "int") return "step";
        if (kind === "ratio") return "slid";
        if (kind === "set") return "multi";
        if (kind === "visual") return "gallery";
        if (kind === "enum" || kind === "catalogue") {
            if (o <= 4) return "seg";
            if (o <= 8) return "chips";
            return "pick";
        }
        return "sw";
    }
}
