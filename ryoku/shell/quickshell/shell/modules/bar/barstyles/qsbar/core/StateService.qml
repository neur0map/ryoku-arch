import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: service

    readonly property string stateBase: {
        var x = Quickshell.env("XDG_STATE_HOME")
        return (x && x !== "") ? x : (Quickshell.env("HOME") + "/.local/state")
    }
    readonly property string stateRoot: stateBase + "/quickshell-rise"
    readonly property string statePath: stateRoot + "/active-variant"
    readonly property string legacyStatePath: stateRoot + "/active-version"

    property string committedVariant: "v1"
    property string pendingVariant: ""
    property bool initialized: false
    property bool persistenceAvailable: false

    signal commitSucceeded(string variant)
    signal commitFailed(string variant)

    width: 0
    height: 0

    function normalize(value) {
        var candidate = String(value || "").trim().toLowerCase()
        return candidate === "v2" ? "v2" : "v1"
    }

    function loadState() {
        var current = String(activeVariantFile.text() || "").trim().toLowerCase()
        var legacy = String(legacyVersionFile.text() || "").trim().toLowerCase()

        if (current === "v1" || current === "v2")
            committedVariant = current
        else if (legacy === "v1" || legacy === "v2")
            committedVariant = legacy
        else
            committedVariant = "v1"

        initialized = true
    }

    function commit(variant) {
        var normalized = normalize(variant)
        pendingVariant = normalized
        activeVariantFile.setText(normalized + "\n")
    }

    Process {
        id: stateDirectoryCreator
        command: ["bash", "-c", "mkdir -p '" + service.stateRoot + "'"]
        running: true
        onExited: (exitCode) => {
            service.persistenceAvailable = exitCode === 0
            service.loadState()
        }
    }

    FileView {
        id: activeVariantFile
        path: service.statePath
        atomicWrites: true
        blockWrites: true
        printErrors: false
        onSaved: {
            if (service.pendingVariant === "") return
            var saved = service.pendingVariant
            service.pendingVariant = ""
            service.committedVariant = saved
            service.commitSucceeded(saved)
        }
        onSaveFailed: {
            var failed = service.pendingVariant
            service.pendingVariant = ""
            service.commitFailed(failed)
        }
    }

    FileView {
        id: legacyVersionFile
        path: service.legacyStatePath
        printErrors: false
    }
}
