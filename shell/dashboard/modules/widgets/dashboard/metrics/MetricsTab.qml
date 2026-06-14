pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.dashboard.config
import qs.dashboard.modules.theme
import qs.dashboard.modules.components
import qs.services

// System-stats dashboard tab, rebuilt on top of ryoku's own working services
// (qs.services SystemUsage + NetworkUsage). Styling re-uses the dashboard's Colors /
// Styling / Icons singletons so it matches the rest of the island dashboard.
//
// The services only sample while their refCount > 0, so this tab registers /
// unregisters on completion / destruction (see Component.onCompleted below).
Rectangle {
    id: root

    color: "transparent"
    implicitWidth: 400
    implicitHeight: 400

    readonly property bool hasGpu: SystemUsage.gpuType !== "NONE"
    readonly property bool hasBattery: UPower.displayDevice.isLaptopBattery
    readonly property var primaryDisk: SystemUsage.disks.length > 0 ? SystemUsage.disks[0] : null

    Component.onCompleted: {
        SystemUsage.refCount++;
        NetworkUsage.refCount++;
    }
    Component.onDestruction: {
        SystemUsage.refCount--;
        NetworkUsage.refCount--;
    }

    function fmtKib(kib) {
        const f = SystemUsage.formatKib(kib);
        const v = f.value >= 100 ? Math.round(f.value) : f.value.toFixed(1);
        return `${v} ${f.unit}`;
    }

    function fmtSpeed(bytes) {
        const f = NetworkUsage.formatBytes(bytes);
        return `${f.value.toFixed(f.value >= 100 ? 0 : 1)} ${f.unit}`;
    }

    function fmtTotal(bytes) {
        const f = NetworkUsage.formatBytesTotal(bytes);
        return `${f.value.toFixed(f.value >= 100 ? 0 : 1)} ${f.unit}`;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            RingCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                glyph: Icons.cpu
                heading: "CPU"
                subheading: SystemUsage.cpuName || "Processor"
                value: SystemUsage.cpuPerc
                accent: Colors.primary
                footer: SystemUsage.cpuTemp > 0 ? `${Math.round(SystemUsage.cpuTemp)}°C` : ""
            }

            RingCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.hasGpu
                glyph: Icons.gpu
                heading: "GPU"
                subheading: SystemUsage.gpuName || SystemUsage.gpuType
                value: SystemUsage.gpuPerc
                accent: Colors.green
                footer: SystemUsage.gpuTemp > 0 ? `${Math.round(SystemUsage.gpuTemp)}°C` : ""
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            BarCard {
                Layout.fillWidth: true
                glyph: Icons.ram
                heading: "Memory"
                value: SystemUsage.memPerc
                accent: Colors.cyan
                detail: `${root.fmtKib(SystemUsage.memUsed)} / ${root.fmtKib(SystemUsage.memTotal)}`
            }

            BarCard {
                Layout.fillWidth: true
                glyph: Icons.ssd
                heading: root.primaryDisk ? root.primaryDisk.mount : "Disk"
                value: root.primaryDisk ? root.primaryDisk.perc : 0
                accent: Colors.yellow
                detail: root.primaryDisk ? `${root.fmtKib(root.primaryDisk.used)} / ${root.fmtKib(root.primaryDisk.total)}` : "—"
            }
        }

        Repeater {
            model: SystemUsage.disks.length > 1 ? SystemUsage.disks.slice(1) : []

            BarCard {
                required property var modelData
                Layout.fillWidth: true
                glyph: Icons.disk
                heading: modelData.mount
                value: modelData.perc
                accent: Colors.yellow
                detail: `${root.fmtKib(modelData.used)} / ${root.fmtKib(modelData.total)}`
            }
        }

        StyledRect {
            id: netCard

            Layout.fillWidth: true
            Layout.preferredHeight: 132
            variant: "pane"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: Icons.globe
                        font.family: Icons.font
                        font.pixelSize: Styling.fontSize(2)
                        color: Colors.primary
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Network"
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.Medium
                        color: Colors.overBackground
                    }
                    Text {
                        text: `Σ ↓${root.fmtTotal(NetworkUsage.downloadTotal)}  ↑${root.fmtTotal(NetworkUsage.uploadTotal)}`
                        font.pixelSize: Styling.fontSize(-3)
                        color: Colors.overSurfaceVariant
                    }
                }

                Item {
                    id: graphArea

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Canvas {
                        id: netCanvas

                        anchors.fill: parent

                        function drawSeries(ctx, vals, maxV, col, w, h) {
                            const n = vals.length;
                            if (n < 2)
                                return;
                            const step = w / (NetworkUsage.historyLength - 1);
                            const x0 = w - (n - 1) * step;
                            ctx.beginPath();
                            ctx.moveTo(x0, h);
                            for (let i = 0; i < n; i++) {
                                const x = x0 + i * step;
                                const y = h - Math.max(0, Math.min(1, vals[i] / maxV)) * h;
                                ctx.lineTo(x, y);
                            }
                            ctx.lineTo(x0 + (n - 1) * step, h);
                            ctx.closePath();
                            const grad = ctx.createLinearGradient(0, 0, 0, h);
                            grad.addColorStop(0, Qt.rgba(col.r, col.g, col.b, 0.35));
                            grad.addColorStop(1, Qt.rgba(col.r, col.g, col.b, 0.0));
                            ctx.fillStyle = grad;
                            ctx.fill();

                            ctx.beginPath();
                            for (let i = 0; i < n; i++) {
                                const x = x0 + i * step;
                                const y = h - Math.max(0, Math.min(1, vals[i] / maxV)) * h;
                                if (i === 0)
                                    ctx.moveTo(x, y);
                                else
                                    ctx.lineTo(x, y);
                            }
                            ctx.strokeStyle = col;
                            ctx.lineWidth = 2;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.stroke();
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            const dl = NetworkUsage.downloadBuffer.values;
                            const ul = NetworkUsage.uploadBuffer.values;
                            const maxV = Math.max(NetworkUsage.downloadBuffer.maximum, NetworkUsage.uploadBuffer.maximum, 1024);

                            ctx.strokeStyle = Qt.rgba(Colors.overSurfaceVariant.r, Colors.overSurfaceVariant.g, Colors.overSurfaceVariant.b, 0.12);
                            ctx.lineWidth = 1;
                            for (let i = 1; i < 4; i++) {
                                const y = height * i / 4;
                                ctx.beginPath();
                                ctx.moveTo(0, y);
                                ctx.lineTo(width, y);
                                ctx.stroke();
                            }

                            drawSeries(ctx, dl, maxV, Colors.cyan, width, height);
                            drawSeries(ctx, ul, maxV, Colors.magenta, width, height);
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: NetworkUsage.downloadBuffer.count < 2
                        text: "Collecting data…"
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                        opacity: 0.7
                    }

                    Connections {
                        target: NetworkUsage.downloadBuffer
                        function onValuesChanged() {
                            netCanvas.requestPaint();
                        }
                    }
                    Connections {
                        target: Colors
                        function onSurfaceChanged() {
                            netCanvas.requestPaint();
                        }
                    }
                    onWidthChanged: netCanvas.requestPaint()
                    onHeightChanged: netCanvas.requestPaint()
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    RowLayout {
                        spacing: 4
                        Text {
                            text: Icons.arrowDown
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.cyan
                        }
                        Text {
                            text: root.fmtSpeed(NetworkUsage.downloadSpeed)
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                        }
                    }

                    RowLayout {
                        spacing: 4
                        Text {
                            text: Icons.arrowUp
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.magenta
                        }
                        Text {
                            text: root.fmtSpeed(NetworkUsage.uploadSpeed)
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 4
                        visible: root.hasBattery
                        Text {
                            text: {
                                const p = UPower.displayDevice.percentage;
                                if (UPower.displayDevice.state === UPowerDeviceState.Charging)
                                    return Icons.batteryCharging;
                                if (p >= 0.8)
                                    return Icons.batteryFull;
                                if (p >= 0.55)
                                    return Icons.batteryHigh;
                                if (p >= 0.3)
                                    return Icons.batteryMedium;
                                if (p >= 0.1)
                                    return Icons.batteryLow;
                                return Icons.batteryEmpty;
                            }
                            font.family: Icons.font
                            font.pixelSize: Styling.fontSize(2)
                            color: UPower.displayDevice.percentage <= 0.15 && UPower.displayDevice.state !== UPowerDeviceState.Charging ? Colors.red : Colors.green
                        }
                        Text {
                            text: `${Math.round(UPower.displayDevice.percentage * 100)}%`
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                        }
                    }
                }
            }
        }
    }


    component RingCard: StyledRect {
        id: ringCard

        property string glyph
        property string heading
        property string subheading
        property string footer
        property real value: 0
        property color accent: Colors.primary
        property real animatedValue: 0

        variant: "pane"
        Component.onCompleted: animatedValue = value
        onValueChanged: animatedValue = value

        Behavior on animatedValue {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: ringCard.glyph
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(2)
                    color: ringCard.accent
                }
                Text {
                    Layout.fillWidth: true
                    text: ringCard.heading
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Medium
                    color: Colors.overBackground
                    elide: Text.ElideRight
                }
                Text {
                    visible: ringCard.footer.length > 0
                    text: ringCard.footer
                    font.pixelSize: Styling.fontSize(-2)
                    color: ringCard.accent
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 90

                Canvas {
                    id: ring

                    readonly property real arcStart: 0.75 * Math.PI
                    readonly property real arcSweep: 1.5 * Math.PI

                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height)
                    height: width

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        const cx = width / 2;
                        const cy = height / 2;
                        const lw = Math.max(6, width * 0.1);
                        const r = width / 2 - lw / 2 - 2;

                        ctx.lineCap = "round";
                        ctx.lineWidth = lw;

                        ctx.strokeStyle = Qt.rgba(ringCard.accent.r, ringCard.accent.g, ringCard.accent.b, 0.18);
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, arcStart, arcStart + arcSweep);
                        ctx.stroke();

                        ctx.strokeStyle = ringCard.accent;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, arcStart, arcStart + arcSweep * Math.max(0, Math.min(1, ringCard.animatedValue)));
                        ctx.stroke();
                    }

                    Connections {
                        target: ringCard
                        function onAnimatedValueChanged() {
                            ring.requestPaint();
                        }
                    }
                    Connections {
                        target: Colors
                        function onSurfaceChanged() {
                            ring.requestPaint();
                        }
                    }
                    onWidthChanged: requestPaint()
                }

                Text {
                    anchors.centerIn: parent
                    text: `${Math.round(ringCard.value * 100)}%`
                    font.pixelSize: Styling.fontSize(8)
                    font.weight: Font.Medium
                    color: ringCard.accent
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                text: ringCard.subheading
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.overSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }

    component BarCard: StyledRect {
        id: barCard

        property string glyph
        property string heading
        property string detail
        property real value: 0
        property color accent: Colors.primary
        property real animatedValue: 0

        variant: "pane"
        implicitHeight: 64
        Component.onCompleted: animatedValue = value
        onValueChanged: animatedValue = value

        Behavior on animatedValue {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: barCard.glyph
                    font.family: Icons.font
                    font.pixelSize: Styling.fontSize(0)
                    color: barCard.accent
                }
                Text {
                    Layout.fillWidth: true
                    text: barCard.heading
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: Colors.overBackground
                    elide: Text.ElideRight
                }
                Text {
                    text: `${Math.round(barCard.value * 100)}%`
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: barCard.accent
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: height / 2
                color: Qt.rgba(barCard.accent.r, barCard.accent.g, barCard.accent.b, 0.18)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, barCard.animatedValue))
                    height: parent.height
                    radius: height / 2
                    color: barCard.accent
                }
            }

            Text {
                Layout.fillWidth: true
                text: barCard.detail
                font.pixelSize: Styling.fontSize(-3)
                color: Colors.overSurfaceVariant
                elide: Text.ElideRight
            }
        }
    }
}
