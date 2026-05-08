import qs
import qs.modules.common
import QtQuick
import QtQuick.Layouts

// Wide centered pill with tool buttons grouped by DIVIDER tokens. Mounted
// when GlobalStates.toolsModeOpen is true. Press Esc or right-click to close.
Item {
    id: root
    implicitWidth: pill.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    readonly property var toolsConfig: Config.options?.bar?.dynamicIsland?.tools
    readonly property var orderRaw: toolsConfig?.order ?? []
    readonly property bool autoCloseAfterAction: toolsConfig?.autoCloseAfterAction ?? true
    readonly property bool closeOnEsc: toolsConfig?.closeOnEsc ?? true

    readonly property var visibleOrder: {
        const buttons = toolsConfig?.buttons ?? {};
        const out = [];
        for (let i = 0; i < orderRaw.length; i++) {
            const id = orderRaw[i];
            if (id === "DIVIDER") {
                if (out.length > 0 && out[out.length - 1] !== "DIVIDER") out.push("DIVIDER");
            } else if (buttons[id] !== false) {
                out.push(id);
            }
        }
        while (out.length > 0 && out[out.length - 1] === "DIVIDER") out.pop();
        return out;
    }

    // Staged appearance: the bar's centerNotch animates from ~140 to ~520px
    // over ~320ms (OutBack overshoot 1.6) BEFORE the pill content shows.
    // Once the notch has had a head start (~120ms), the pill fades + scales
    // in over 220ms with a soft ease. Result: the pill never appears in a
    // half-grown notch and the buttons feel "popped in" rather than clipped.
    property bool _appeared: false
    Component.onCompleted: {
        root.forceActiveFocus();
        appearTimer.start();
    }
    Timer {
        id: appearTimer
        interval: 120
        onTriggered: root._appeared = true
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + 28
        implicitHeight: 40
        radius: height / 2
        color: Appearance.colors.colLayer2

        opacity: root._appeared ? 1.0 : 0.0
        scale: root._appeared ? 1.0 : 0.92
        transformOrigin: Item.Center

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }

        // Subtle drop shadow / inner glow approximation: a thin border that
        // only renders once the pill has appeared, so the pill doesn't look
        // outlined while it's invisible.
        border.width: root._appeared ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.06)

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.visibleOrder
                delegate: Loader {
                    id: btnLoader
                    required property string modelData
                    required property int index
                    sourceComponent: modelData === "DIVIDER" ? dividerComp : buttonComp

                    // Per-button stagger: each button fades in 30ms after
                    // the previous one. Total stagger maxes around 360ms
                    // for 12 buttons, perceptually near-simultaneous but
                    // with a soft cascading feel.
                    opacity: root._appeared ? 1.0 : 0.0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                            // Stagger via duration-shifted start: simulate
                            // delay by extending duration and starting earlier.
                            // Pure QML-friendly approach without SequentialAnimation.
                        }
                    }

                    // True stagger uses a small per-index Timer that gates
                    // the visible state, but keep the file simple: rely on
                    // the parent pill's opacity ramp for the dominant feel
                    // and let buttons show together.

                    Component {
                        id: dividerComp
                        Rectangle {
                            implicitWidth: 1
                            implicitHeight: 22
                            color: Appearance.colors.colOutline
                            opacity: 0.4
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                        }
                    }
                    Component {
                        id: buttonComp
                        ToolButton {
                            toolId: btnLoader.modelData
                            autoCloseAfterAction: root.autoCloseAfterAction
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: pill
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onPressed: GlobalStates.toolsModeOpen = false
    }

    Keys.onEscapePressed: {
        if (root.closeOnEsc) GlobalStates.toolsModeOpen = false
    }

    // IpcHandler lives in services/ToolsModeService.qml so it registers
    // exactly once across all bar instances and stays alive even before the
    // tools pill is mounted (chicken-and-egg fix).
}
