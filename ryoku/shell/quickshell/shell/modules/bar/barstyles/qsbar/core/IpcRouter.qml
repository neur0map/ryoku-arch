import QtQuick
import Quickshell.Io

Item {
    id: router

    required property var variantHost

    property var pendingThemePayload: undefined
    property var pendingLauncherPayload: undefined
    property bool pendingThemeReload: false
    property string pendingPickerMode: ""
    property bool pendingSystemRefresh: false

    width: 0
    height: 0

    function canDispatch() {
        return variantHost.ready && variantHost.activeItem !== null
    }

    function invoke(method, first, second) {
        if (!canDispatch()) return false
        var fn = variantHost.activeItem[method]
        if (!fn) return false

        if (second !== undefined) fn(first, second)
        else if (first !== undefined) fn(first)
        else fn()
        return true
    }

    function applyTheme(payload) {
        if (!invoke("applyTheme", payload)) pendingThemePayload = payload
    }

    function applyLauncher(payload) {
        if (!invoke("applyLauncher", payload)) pendingLauncherPayload = payload
    }

    function reloadTheme() {
        if (!invoke("reloadTheme")) pendingThemeReload = true
    }

    function openPicker(mode) {
        if (!invoke("openPicker", mode)) pendingPickerMode = mode
    }

    function systemRefresh() {
        if (!invoke("systemUpdateRefresh")) pendingSystemRefresh = true
    }

    function flush() {
        if (!canDispatch()) return

        if (pendingThemePayload !== undefined) {
            invoke("applyTheme", pendingThemePayload)
            pendingThemePayload = undefined
        }
        if (pendingLauncherPayload !== undefined) {
            invoke("applyLauncher", pendingLauncherPayload)
            pendingLauncherPayload = undefined
        }
        if (pendingThemeReload) {
            invoke("reloadTheme")
            pendingThemeReload = false
        }
        if (pendingSystemRefresh) {
            invoke("systemUpdateRefresh")
            pendingSystemRefresh = false
        }
        if (pendingPickerMode !== "") {
            invoke("openPicker", pendingPickerMode)
            pendingPickerMode = ""
        }
    }

    IpcHandler {
        target: "lifecycle"
        function version(): string {
            return router.variantHost.runningVariant === "v2" ? "V2" : "V1"
        }
        function ready(): bool { return router.variantHost.ready }
    }

    IpcHandler {
        target: "variant"
        function current(): string { return router.variantHost.runningVariant }
        function state(): string { return router.variantHost.phase }
        function error(): string { return router.variantHost.lastError }
        function activate(version: string): void { router.variantHost.requestSwitch(version) }
    }

    IpcHandler {
        target: "layout"
        function lock(): void { router.invoke("layoutLock") }
        function unlock(): void { router.invoke("layoutUnlock") }
    }

    IpcHandler {
        target: "ryoku.system-update"
        function refresh(): void { router.systemRefresh() }
    }

    IpcHandler {
        target: "reactor"
        function test(kind: string, arg: string): void { router.invoke("runReactor", kind, arg) }
        function monsweep(): void { router.invoke("runReactor", "monsweep", "") }
        function clear(): void { router.invoke("runReactor", "clear", "") }
    }

    IpcHandler {
        target: "theme"
        function apply(payload: string): void { router.applyTheme(payload) }
        function applyLauncher(payload: string): void { router.applyLauncher(payload) }
        function reload(): void { router.reloadTheme() }
    }

    IpcHandler {
        target: "picker"
        function theme(): void { router.openPicker("theme") }
        function wallpaper(): void { router.openPicker("wallpaper") }
        function screenshots(): void { router.openPicker("screenshots") }
        function videos(): void { router.openPicker("videos") }
    }

    Connections {
        target: router.variantHost
        function onPhaseChanged() {
            if (router.variantHost.ready) router.flush()
        }
    }
}
