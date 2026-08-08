import QtQuick
import Quickshell
import Quickshell.Io
import "../modules"

Column {
    id: tab
    required property var root

    spacing: 8

    readonly property string applyScript: Quickshell.env("HOME") + "/.config/quickshell/bin/qs-shell-apply-update.sh"
    readonly property bool progressMode: root.shellUpdateProgressVisible
    readonly property bool progressRunning: root.shellProgressRunning
    readonly property bool progressFailed: root.shellProgressFailed || root.shellProgressInterrupted
    readonly property bool progressCompleted: root.shellProgressCompleted
    readonly property int progressStep: Math.max(1, Math.min(root.shellProgressStep || 1, root.shellProgressTotalSteps || 5))
    readonly property int totalSteps: root.shellProgressTotalSteps || 5
    readonly property bool canApply: root.shellUpdateBehind > 0
        && root.shellUpdateRepository !== ""
        && root.shellUpdateUpstreamRef !== ""
        && root.shellUpdateBaseCommit !== ""
        && root.shellUpdateTargetCommit !== ""
        && !root.shellUpdateChecking
        && !progressRunning
    readonly property var phaseLabels: [
        "Check for updates",
        "Validate payload",
        "Test shell",
        "Install",
        "Restart"
    ]
    readonly property var spinnerFrames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    property int spinnerFrame: 0

    Process {
        id: shellCheckProc
        command: ["systemctl", "--user", "start", "--wait", "qs-shell-update-check.service"]
        running: false
        onExited: {
            tab.root.shellUpdateChecking = false
            shellCheckWatchdog.stop()
            tab.root.reloadShellUpdateState()
        }
    }

    Process {
        id: shellApplyProc
        command: ["true"]
    }

    Timer {
        id: shellCheckWatchdog
        interval: 190000
        onTriggered: {
            tab.root.shellUpdateChecking = false
            shellCheckProc.running = false
            tab.root.reloadShellUpdateState()
        }
    }

    Timer {
        interval: 120
        running: tab.progressMode && tab.progressRunning && tab.root.archVisible && tab.visible
        repeat: true
        onTriggered: tab.spinnerFrame = (tab.spinnerFrame + 1) % tab.spinnerFrames.length
    }

    function shortSha(s) {
        if (!s) return "—"
        return String(s).substring(0, 12)
    }

    function checkedLabel() {
        if (!root.shellUpdateChecked) return "never checked"
        var d = new Date(root.shellUpdateChecked)
        if (isNaN(d.getTime())) return root.shellUpdateChecked
        return Qt.formatDateTime(d, "yyyy-MM-dd HH:mm")
    }

    function screenNameForProgress() {
        if (root.activePopupScreenName) return root.activePopupScreenName
        if (root.activePopupScreen && root.activePopupScreen.name) return root.activePopupScreen.name
        return ""
    }

    function appendSetenv(args, name, value) {
        if (value !== undefined && value !== null && String(value).length > 0)
            args.push("--setenv=" + name + "=" + value)
    }

    function applyUnitName() {
        return "qs-shell-apply-" + Date.now()
    }

    function checkShell() {
        if (root.shellUpdateChecking || progressRunning) return
        root.shellUpdateChecking = true
        shellCheckWatchdog.restart()
        shellCheckProc.running = false
        shellCheckProc.running = true
    }

    function startApply() {
        if (!canApply) return
        root.setShellProgressPanelOpen(true)
        var cmd = [
            "systemd-run",
            "--user",
            "--collect",
            "--quiet",
            "--unit=" + applyUnitName(),
            "--property=Type=exec"
        ]
        appendSetenv(cmd, "QS_SHELL_PROGRESS_SCREEN", screenNameForProgress())
        appendSetenv(cmd, "DISPLAY", Quickshell.env("DISPLAY"))
        appendSetenv(cmd, "WAYLAND_DISPLAY", Quickshell.env("WAYLAND_DISPLAY"))
        appendSetenv(cmd, "XDG_RUNTIME_DIR", Quickshell.env("XDG_RUNTIME_DIR"))
        appendSetenv(cmd, "XDG_SESSION_ID", Quickshell.env("XDG_SESSION_ID"))
        appendSetenv(cmd, "XDG_SESSION_TYPE", Quickshell.env("XDG_SESSION_TYPE"))
        appendSetenv(cmd, "XDG_CURRENT_DESKTOP", Quickshell.env("XDG_CURRENT_DESKTOP"))
        appendSetenv(cmd, "QT_QPA_PLATFORM", Quickshell.env("QT_QPA_PLATFORM"))
        appendSetenv(cmd, "QT_QUICK_CONTROLS_STYLE", Quickshell.env("QT_QUICK_CONTROLS_STYLE"))
        appendSetenv(cmd, "HYPRLAND_INSTANCE_SIGNATURE", Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE"))
        appendSetenv(cmd, "RYOKU_PATH", Quickshell.env("RYOKU_PATH"))
        appendSetenv(cmd, "PATH", Quickshell.env("PATH"))
        cmd.push("bash", applyScript)
        shellApplyProc.command = cmd
        shellApplyProc.running = false
        shellApplyProc.running = true
    }

    function phaseKind(step) {
        if (!progressMode) return "pending"
        if (progressCompleted) return "done"
        if (progressFailed) {
            if (step < progressStep) return "done"
            if (step === progressStep) return "failed"
            return "pending"
        }
        if (step < progressStep) return "done"
        if (step === progressStep) return "active"
        return "pending"
    }

    function phaseIcon(step) {
        var kind = phaseKind(step)
        if (kind === "done") return "✓"
        if (kind === "failed") return "!"
        if (kind === "active") return spinnerFrames[spinnerFrame]
        return "•"
    }

    function phaseColor(step) {
        var kind = phaseKind(step)
        if (kind === "done") return root.green
        if (kind === "failed") return root.seal
        if (kind === "active") return root.ink
        return Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.32)
    }

    function phaseOpacity(step) {
        return phaseKind(step) === "pending" ? 0.55 : 1.0
    }

    readonly property string progressHeader: {
        if (root.shellProgressInterrupted) return "Interrupted"
        if (root.shellProgressFailed) return "Failed · Step " + progressStep + " of " + totalSteps
        if (root.shellProgressCompleted) return "Completed"
        return "Step " + progressStep + " of " + totalSteps
    }

    readonly property string progressErrorText: {
        if (root.shellProgressInterrupted)
            return "Update interrupted: no progress update for more than ten minutes."
        return root.shellProgressError || "Shell update failed."
    }

    component ActionButton: Rectangle {
        id: btn
        required property string label
        property bool primary: false
        property bool buttonEnabled: true
        signal clicked()

        height: 28
        radius: tab.root.panelButtonRadius
        opacity: buttonEnabled ? 1.0 : 0.45
        color: primary
            ? (ma.containsMouse && buttonEnabled ? tab.root.fillPrimaryHover : tab.root.seal)
            : (ma.containsMouse && buttonEnabled ? tab.root.fillHover : tab.root.fillIdle)
        border.color: primary ? "transparent" : (ma.containsMouse && buttonEnabled ? tab.root.seal : tab.root.sep)
        border.width: primary ? 0 : 1
        Behavior on color { ColorAnimation { duration: 120 } }
        UiText {
            anchors.centerIn: parent
            text: btn.label
            color: btn.primary ? tab.root.paper : (ma.containsMouse && btn.buttonEnabled ? tab.root.seal : tab.root.ink)
            font.family: tab.root.mono
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            enabled: btn.buttonEnabled
            hoverEnabled: true
            cursorShape: btn.buttonEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: btn.clicked()
        }
    }

    Text {
        width: parent.width
        textFormat: Text.RichText
        renderType: Text.NativeRendering
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
        font.family: root.mono
        font.pixelSize: 10
        text: {
            function hx(c) { function h(v){var x=Math.round(v*255).toString(16); return x.length<2?"0"+x:x} return "#"+h(c.r)+h(c.g)+h(c.b) }
            function seg(t,c){ return '<font color="'+hx(c)+'">'+t+'</font>' }
            var p = []
            if (progressMode) p.push(seg(progressHeader, progressFailed ? root.seal : root.ink))
            else if (root.shellUpdateBehind > 0) p.push(seg(root.shellUpdateBehind + (root.shellUpdateBehind === 1 ? " commit available" : " commits available"), root.ink))
            else p.push(seg("up to date", root.sumi))
            p.push(seg("checked " + checkedLabel(), root.sumi))
            return p.join(' <font color="'+hx(root.sumi)+'">·</font> ')
        }
    }

    Row {
        width: parent.width
        spacing: 8
        UiText {
            width: (parent.width - 8) / 2
            text: "Installed: " + shortSha(root.shellInstalledCommit || root.shellUpdateBaseCommit)
            color: root.sumi
            font.family: root.mono
            font.pixelSize: 10
            elide: Text.ElideRight
        }
        UiText {
            width: (parent.width - 8) / 2
            text: "Target: " + shortSha(root.shellUpdateTargetCommit || root.shellProgressTargetCommit)
            color: root.sumi
            font.family: root.mono
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    Column {
        id: progressCol
        visible: progressMode
        width: parent.width
        height: visible ? implicitHeight : 0
        spacing: 6

        Repeater {
            model: tab.phaseLabels.length

            delegate: Row {
                width: progressCol.width
                height: 24
                spacing: 8
                opacity: tab.phaseOpacity(index + 1)

                UiText {
                    width: 18
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: tab.phaseIcon(index + 1)
                    color: tab.phaseColor(index + 1)
                    font.family: root.mono
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
                UiText {
                    width: progressCol.width - 26
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.phaseLabels[index]
                    color: tab.phaseColor(index + 1)
                    font.family: root.mono
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }

        UiText {
            width: parent.width
            visible: progressFailed
            text: progressErrorText
            color: root.seal
            font.family: root.mono
            font.pixelSize: 10
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
    }

    Item {
        visible: !progressMode
        width: parent.width
        height: visible ? Math.min(commitsCol.implicitHeight, 190) : 0

        Flickable {
            id: commitsFlick
            anchors.fill: parent
            contentHeight: commitsCol.implicitHeight
            clip: true
            interactive: visible && commitsCol.implicitHeight > height

            Column {
                id: commitsCol
                width: parent.width
                spacing: 4

                Repeater {
                    model: root.shellUpdateSummary

                    delegate: Row {
                        required property var modelData
                        width: commitsCol.width
                        spacing: 6
                        UiText {
                            text: "•"
                            color: root.seal
                            font.family: root.mono
                            font.pixelSize: 11
                        }
                        UiText {
                            width: commitsCol.width - 14
                            text: modelData
                            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.85)
                            font.family: root.mono
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                    }
                }

                UiText {
                    width: parent.width
                    visible: root.shellUpdateSummary.length === 0
                    text: root.shellUpdateBehind > 0 ? "No changelog available" : "No shell update available"
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
                    font.family: root.mono
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 20
                }
            }
        }
    }

    UiText {
        width: parent.width
        text: progressRunning
            ? "You can hide this panel; the update continues in the background."
            : "Shell updates are applied separately from packages and themes."
        color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.45)
        font.family: root.mono
        font.pixelSize: 9
        font.letterSpacing: 0.5
        wrapMode: Text.Wrap
    }

    Rectangle { width: parent.width; height: 1; color: root.sep }

    Row {
        visible: !progressMode
        width: parent.width
        height: visible ? 28 : 0
        spacing: 8

        ActionButton {
            width: (parent.width - 8) / 2
            label: root.shellUpdateChecking ? "Checking…" : "Check shell"
            buttonEnabled: !root.shellUpdateChecking && !progressRunning
            onClicked: tab.checkShell()
        }

        ActionButton {
            width: (parent.width - 8) / 2
            label: "Update & restart"
            primary: true
            buttonEnabled: tab.canApply
            onClicked: tab.startApply()
        }
    }

    Row {
        visible: progressRunning
        width: parent.width
        height: visible ? 28 : 0
        spacing: 8
        ActionButton {
            width: parent.width
            label: "Hide"
            onClicked: root.closeArchUpdatesPanel()
        }
    }

    Row {
        visible: progressFailed
        width: parent.width
        height: visible ? 28 : 0
        spacing: 8
        ActionButton {
            width: (parent.width - 8) / 2
            label: "Dismiss"
            onClicked: {
                root.ackShellProgress()
                root.archVisible = false
            }
        }
        ActionButton {
            width: (parent.width - 8) / 2
            label: "Retry"
            primary: true
            buttonEnabled: tab.canApply
            onClicked: tab.startApply()
        }
    }

    Row {
        visible: progressCompleted
        width: parent.width
        height: visible ? 28 : 0
        spacing: 8
        ActionButton {
            width: parent.width
            label: "Done"
            primary: true
            onClicked: root.ackShellProgress()
        }
    }
}
