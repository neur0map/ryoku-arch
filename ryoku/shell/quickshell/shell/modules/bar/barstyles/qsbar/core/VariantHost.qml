import QtQuick

Item {
    id: host

    required property var stateService
    required property url v1Source
    required property url v2Source

    readonly property var activeItem: variantLoader.item
    readonly property bool ready: phase === "active"
        && activeItem !== null
        && activeItem.ready === true
    readonly property bool switching: phase !== "idle" && phase !== "active" && phase !== "failed"

    property string phase: "idle"
    property string runningVariant: ""
    property string targetVariant: ""
    property string previousVariant: ""
    property string queuedVariant: ""
    property string failedVariant: ""
    property string lastError: ""
    property bool rollbackMode: false
    property int prepareTicks: 0
    property int readyTicks: 0
    property int stableReadyTicks: 0

    signal switchCompleted(string variant)
    signal switchRolledBack(string failedVariant, string restoredVariant, string reason)
    signal switchFailed(string failedVariant, string reason)

    width: 0
    height: 0

    function normalize(value) {
        return String(value || "").trim().toLowerCase() === "v2" ? "v2" : "v1"
    }

    function sourceFor(variant) {
        return normalize(variant) === "v2" ? v2Source : v1Source
    }

    function startInitial() {
        if (phase !== "idle" || !stateService.initialized) return

        previousVariant = ""
        targetVariant = normalize(stateService.committedVariant)
        rollbackMode = false
        loadTarget()
    }

    function requestSwitch(variant) {
        var normalized = normalize(variant)

        if (switching) {
            queuedVariant = normalized
            return
        }
        if (ready && runningVariant === normalized) return

        previousVariant = runningVariant
        targetVariant = normalized
        rollbackMode = false
        lastError = ""

        if (activeItem === null) {
            loadTarget()
            return
        }

        phase = "preparing"
        prepareTicks = 0
        if (activeItem.prepareDeactivate) activeItem.prepareDeactivate()
        prepareTimer.start()
    }

    function beginUnload() {
        prepareTimer.stop()
        readyTimer.stop()
        phase = "unloading"
        variantLoader.source = ""
        if (variantLoader.item === null) destructionGrace.restart()
    }

    function loadTarget() {
        phase = rollbackMode ? "rollback-loading" : "loading"
        readyTicks = 0
        stableReadyTicks = 0
        variantLoader.setSource(sourceFor(targetVariant), { "variantHost": host })
    }

    function targetLoadFailed(reason) {
        var broken = targetVariant
        var fallback = previousVariant !== ""
            ? previousVariant
            : (broken === "v1" ? "v2" : "v1")

        if (rollbackMode) {
            phase = "failed"
            failedVariant = broken
            lastError = reason
            switchFailed(broken, reason)
            return
        }

        failedVariant = broken
        lastError = reason
        rollbackMode = true
        targetVariant = fallback
        beginUnload()
    }

    function finalizeAcceptedTarget() {
        readyTimer.stop()
        phase = "active"

        if (rollbackMode) {
            rollbackMode = false
            switchRolledBack(failedVariant, runningVariant, lastError)
        } else {
            switchCompleted(runningVariant)
        }

        queueDrain.restart()
    }

    function acceptTarget() {
        readyTimer.stop()
        runningVariant = targetVariant

        if (stateService.committedVariant !== runningVariant) {
            phase = "committing"
            stateService.commit(runningVariant)
            return
        }

        finalizeAcceptedTarget()
    }

    function commitTargetFailed(variant) {
        if (phase !== "committing" || variant !== runningVariant) return

        // Ryoku: a persistence miss must not revert the user's chosen variant.
        // Keep it for the session; it re-persists on the next successful write.
        lastError = "could not persist active variant"
        finalizeAcceptedTarget()
    }

    Loader {
        id: variantLoader
        asynchronous: true

        onItemChanged: {
            if (item === null && host.phase === "unloading")
                destructionGrace.restart()
        }

        onStatusChanged: {
            if (status === Loader.Ready
                    && (host.phase === "loading" || host.phase === "rollback-loading")) {
                host.phase = host.rollbackMode ? "rollback-ready" : "waiting-ready"
                host.readyTicks = 0
                host.stableReadyTicks = 0
                readyTimer.start()
            } else if (status === Loader.Error
                       && (host.phase === "loading" || host.phase === "rollback-loading")) {
                host.targetLoadFailed("QML loader error")
            }
        }
    }

    Timer {
        id: prepareTimer
        interval: 50
        repeat: true
        onTriggered: {
            host.prepareTicks++
            if (host.activeItem === null
                    || !host.activeItem.deactivationReady
                    || host.activeItem.deactivationReady()
                    || host.prepareTicks >= 20) {
                host.beginUnload()
            }
        }
    }

    Timer {
        id: destructionGrace
        interval: 150
        repeat: false
        onTriggered: host.loadTarget()
    }

    Timer {
        id: readyTimer
        interval: 200
        repeat: true
        onTriggered: {
            host.readyTicks++

            var itemMatches = host.activeItem !== null
                && host.activeItem.variantId === host.targetVariant
            if (itemMatches && host.activeItem.ready === true)
                host.stableReadyTicks++
            else
                host.stableReadyTicks = 0

            if (host.stableReadyTicks >= 10) {
                host.acceptTarget()
            } else if (host.readyTicks >= 50) {
                host.targetLoadFailed("variant did not become stably ready within 10 seconds")
            }
        }
    }

    Timer {
        id: queueDrain
        interval: 0
        repeat: false
        onTriggered: {
            if (host.queuedVariant === "") return
            var queued = host.queuedVariant
            host.queuedVariant = ""
            host.requestSwitch(queued)
        }
    }

    Connections {
        target: host.stateService
        function onInitializedChanged() { host.startInitial() }
        function onCommitSucceeded(variant) {
            if (host.phase === "committing" && variant === host.runningVariant)
                host.finalizeAcceptedTarget()
        }
        function onCommitFailed(variant) { host.commitTargetFailed(variant) }
    }

    Component.onCompleted: startInitial()
}
