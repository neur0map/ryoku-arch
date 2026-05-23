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
    property bool runningDoctor: false
    property bool switchingChannel: false
    property var info: ({})
    property var lastUpdateReport: ({})
    property var lastDoctorReport: ({})
    property string lastError: ""

    signal updateCheckFinished(var report)
    signal doctorFinished(var report)
    signal channelSwitchFinished(var report)

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

    function switchChannel(channel: string): void {
        if (switchingChannel)
            return;

        switchingChannel = true;
        switchProc.exec([helper, "switch-channel", channel]);
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

        onExited: code => { // qmllint disable signal-handler-parameters
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

        onExited: code => { // qmllint disable signal-handler-parameters
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

        onExited: code => { // qmllint disable signal-handler-parameters
            const report = root.parseJson(doctorOut.text);
            root.runningDoctor = false;
            if (!report.ok && doctorErr.text && !report.output)
                report.output = doctorErr.text.trim();
            root.lastDoctorReport = report;
            root.doctorFinished(report);
        }
    }

    Process {
        id: switchProc

        stdout: StdioCollector {
            id: switchOut
        }

        stderr: StdioCollector {
            id: switchErr
        }

        onExited: code => { // qmllint disable signal-handler-parameters
            const report = root.parseJson(switchOut.text);
            root.switchingChannel = false;
            if (!report.ok && switchErr.text && !report.error)
                report.error = switchErr.text.trim();
            root.channelSwitchFinished(report);
            root.refreshStatus();
        }
    }

    Process {
        id: openUrlProc
    }
}
