import qs
import qs.modules.common
import QtQuick
import QtQuick.Layouts

// The toolkit content that lives INSIDE the center notch when tools mode
// is active. No background rectangle - the notch (drawn by RyokuTopFrame)
// is the visual container, so the buttons feel like they belong to the
// island itself, not a separate pill stacked on top.
//
// `progress` (0..1) drives a fan-out animation: icons closer to the row's
// center appear first, those further out appear later. The orchestrator
// binds it to its _contentProgress.
Item {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    property real progress: 1.0  // default 1 so the centerSizer (hidden)
                                  // reports the right implicitWidth.

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

    // Indices of non-DIVIDER entries in visibleOrder. Arrow keys cycle
    // through this list; DIVIDER positions are skipped.
    readonly property var navIndices: {
        const out = [];
        for (let i = 0; i < visibleOrder.length; i++) {
            if (visibleOrder[i] !== "DIVIDER") out.push(i);
        }
        return out;
    }

    // Index in visibleOrder of the keyboard-focused button. -1 means no
    // keyboard selection yet. The first arrow press selects the first
    // button (or last, depending on direction).
    property int focusedIndex: -1

    function _moveFocus(direction) {
        const navs = navIndices;
        if (navs.length === 0) return;
        if (focusedIndex < 0) {
            focusedIndex = direction > 0 ? navs[0] : navs[navs.length - 1];
            return;
        }
        const currentNavIdx = navs.indexOf(focusedIndex);
        if (currentNavIdx < 0) {
            focusedIndex = navs[0];
            return;
        }
        const nextNavIdx = (currentNavIdx + direction + navs.length) % navs.length;
        focusedIndex = navs[nextNavIdx];
    }

    function _activateFocused() {
        if (focusedIndex < 0) return;
        // Find the button delegate by walking the row's children.
        for (let i = 0; i < row.children.length; i++) {
            const ldr = row.children[i];
            if (ldr && ldr.index === focusedIndex && ldr.item && ldr.item.activate) {
                ldr.item.activate();
                return;
            }
        }
    }

    Component.onCompleted: root.forceActiveFocus()
    onVisibleOrderChanged: focusedIndex = -1

    Keys.onLeftPressed:  _moveFocus(-1)
    Keys.onRightPressed: _moveFocus(+1)
    Keys.onReturnPressed:    _activateFocused()
    Keys.onEnterPressed:     _activateFocused()

    // Per-icon stage helper. Returns 0..1 for the given index based on
    // distance from the row's horizontal center. Items closer to center
    // unlock faster.
    //   spread: how much of the master progress is spent staggering
    //           (0.0 = all icons together, 0.6 = strong fan-out).
    function _stageFor(index) {
        const n = visibleOrder.length;
        if (n <= 1) return root.progress;
        const center = (n - 1) / 2;
        const dist = Math.abs(index - center);
        const maxDist = Math.max(1, center);
        const norm = dist / maxDist;             // 0 at center, 1 at edges
        const spread = 0.6;
        // Each icon ramps from 0 to 1 over the window
        // [norm * spread, norm * spread + (1 - spread)] of master progress.
        const start = norm * spread;
        const window = 1 - spread;
        return Math.max(0, Math.min(1, (root.progress - start) / Math.max(0.0001, window)));
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: root.visibleOrder
            delegate: Loader {
                id: btnLoader
                required property string modelData
                required property int index
                sourceComponent: modelData === "DIVIDER" ? dividerComp : buttonComp

                readonly property real stage: root._stageFor(index)
                // Stagger via scale (0.55 to 1.0) instead of opacity so
                // icons "spawn and grow" from the row center without any
                // fade. Combined with the small outward slide below, the
                // ensemble reads as a fan-out from the pill's heart.
                scale: 0.55 + 0.45 * stage
                transformOrigin: Item.Center
                // Subtle horizontal slide outward: items > center slide
                // in from the right, items < center from the left.
                readonly property real _slidePx: {
                    const n = root.visibleOrder.length;
                    if (n <= 1) return 0;
                    const center = (n - 1) / 2;
                    return (index - center) * (1 - stage) * 1.4;
                }
                Layout.alignment: Qt.AlignVCenter

                transform: Translate { x: btnLoader._slidePx }

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
                        keyboardFocused: root.focusedIndex === btnLoader.index
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onPressed: GlobalStates.toolsModeOpen = false
    }

    Keys.onEscapePressed: {
        if (root.closeOnEsc) GlobalStates.toolsModeOpen = false
    }

    // IpcHandler lives in services/ToolsModeService.qml so it registers
    // exactly once across all bar instances and stays alive even before the
    // tools row mounts (chicken-and-egg fix).
}
