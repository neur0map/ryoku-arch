pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    readonly property string helper: Paths.toLocalFile(Quickshell.shellPath("scripts/ryoku-settings-about"))

    property bool loadingStatus: false
    property bool checkingUpdates: false
    property bool startingUpdate: false
    property bool runningDoctor: false
    property bool refreshingShell: false
    property var info: ({})
    property var lastUpdateReport: ({})
    property var lastDoctorReport: ({})
    property string lastError: ""

    signal updateCheckFinished(var report)
    signal updateStartFinished(var report)
    signal doctorFinished(var report)
    signal shellRefreshFinished(var report)

    function parseJson(text: string): var {
        if (!text || text.trim().length === 0)
            return {
                ok: false,
                error: qsTr("No output returned")
            };

        try {
            return JSON.parse(text);
        } catch (error) {
            return {
                ok: false,
                error: String(error),
                output: text
            };
        }
    }

    function refreshStatus(): void {
        if (loadingStatus)
            return;

        loadingStatus = true;
        statusProc.exec([helper, "status"]);
    }

    function checkUpdates(): void {
        if (checkingUpdates)
            return;

        checkingUpdates = true;
        checkProc.exec([helper, "check-updates"]);
    }

    function runDoctor(): void {
        if (runningDoctor)
            return;

        runningDoctor = true;
        doctorProc.exec([helper, "doctor"]);
    }

    function refreshShell(): void {
        if (refreshingShell)
            return;

        refreshingShell = true;
        refreshShellProc.exec([helper, "refresh-shell"]);
    }

    function startUpdate(branch: string): void {
        if (startingUpdate)
            return;

        startingUpdate = true;
        updateProc.exec([helper, "start-update", branch]);
    }

    function openUrl(url: string): void {
        openUrlProc.exec([helper, "open-url", url]);
    }

    Process {
        id: statusProc

        stdout: StdioCollector {
            id: statusOut
        }

        stderr: StdioCollector {
            id: statusErr
        }

        onExited: code => {
            const report = root.parseJson(statusOut.text);
            root.loadingStatus = false;
            if (report.ok) {
                root.info = report;
                root.lastError = "";
            } else {
                root.lastError = report.error || statusErr.text || qsTr("Unable to read Ryoku status");
            }
        }
    }

    Process {
        id: checkProc

        stdout: StdioCollector {
            id: checkOut
        }

        stderr: StdioCollector {
            id: checkErr
        }

        onExited: code => {
            const report = root.parseJson(checkOut.text);
            root.checkingUpdates = false;
            if (!report.ok && checkErr.text && !report.error)
                report.error = checkErr.text.trim();
            root.lastUpdateReport = report;
            root.updateCheckFinished(report);
            root.refreshStatus();
        }
    }

    Process {
        id: doctorProc

        stdout: StdioCollector {
            id: doctorOut
        }

        stderr: StdioCollector {
            id: doctorErr
        }

        onExited: code => {
            const report = root.parseJson(doctorOut.text);
            root.runningDoctor = false;
            if (!report.ok && doctorErr.text && !report.output)
                report.output = doctorErr.text.trim();
            root.lastDoctorReport = report;
            root.doctorFinished(report);
        }
    }

    Process {
        id: refreshShellProc

        stdout: StdioCollector {
            id: refreshShellOut
        }

        stderr: StdioCollector {
            id: refreshShellErr
        }

        onExited: code => {
            const report = root.parseJson(refreshShellOut.text);
            root.refreshingShell = false;
            if (!report.ok && refreshShellErr.text && !report.error)
                report.error = refreshShellErr.text.trim();
            root.shellRefreshFinished(report);
        }
    }

    Process {
        id: updateProc

        stdout: StdioCollector {
            id: updateOut
        }

        stderr: StdioCollector {
            id: updateErr
        }

        onExited: code => {
            const report = root.parseJson(updateOut.text);
            root.startingUpdate = false;
            if (!report.ok && updateErr.text && !report.error)
                report.error = updateErr.text.trim();
            root.updateStartFinished(report);
        }
    }

    Process {
        id: openUrlProc
    }
}
