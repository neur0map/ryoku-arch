import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import "calc.js" as Calc
import ".."

// Calculator provider: evaluates the query with qalc. Routed by the "=" prefix,
// and offered in the default fan-out when the query looks numeric. qalc runs
// async, so query() returns the cached row for the current text and starts a
// fresh evaluation (debounced) when the text changes; the cached row repaints via
// Dispatcher.notifyAsync once qalc resolves.
Provider {
    id: calc

    providerId: "calc"
    prefix: "="
    defaultProvider: false
    numericFallback: true

    property string cachedText: ""
    property string cachedResult: ""
    property string pendingText: ""

    function rowFor(expr, result) {
        return {
            id: "calc:" + expr,
            title: result,
            subtitle: expr,
            icon: "",
            type: "Calc",
            score: -10,   // a valid calc result outranks app matches
            actions: [{
                name: "Copy",
                icon: "",
                execute: function () { Quickshell.clipboardText = result; }
            }]
        };
    }

    function query(text) {
        var t = (text || "").trim();
        if (t.length === 0)
            return [];
        if (t === calc.cachedText)
            return calc.cachedResult.length ? [rowFor(t, calc.cachedResult)] : [];
        // New expression: schedule an evaluation without touching state inside
        // the binding, and show nothing until it resolves. Guard the restart on
        // pendingText too, so a re-query for the same in-flight expression (any
        // other provider bumping Dispatcher.revision re-runs results()) does
        // not keep pushing the debounce forward and starve the calc process.
        if (t !== calc.pendingText) {
            calc.pendingText = t;
            debounce.restart();
        }
        return [];
    }

    Timer {
        id: debounce
        interval: 60
        repeat: false
        onTriggered: {
            proc.expr = calc.pendingText;
            proc.running = false;
            proc.running = true;
        }
    }

    Process {
        id: proc
        onRunningChanged: Dispatcher.setBusy("calc", running)
        property string expr: ""
        property string out: ""
        command: [Config.scriptsDir + "ryoku-cmd-calc", expr]
        stdout: SplitParser {
            onRead: data => proc.out += data + "\n"
        }
        onStarted: proc.out = ""
        onExited: (code, status) => {
            // a killed (superseded) eval must not cache its partial output
            // under the newer expression's key.
            if (status !== 0)
                return;
            var result = Calc.parseResult(proc.out);
            calc.cachedText = proc.expr;
            calc.cachedResult = result ? result : "";
            Dispatcher.notifyAsync();
        }
    }

    Component.onCompleted: Dispatcher.register(calc);
}
