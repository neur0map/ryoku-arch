import QtQuick
import Quickshell
import "hub/quickshell/barstudio" as BarStudio

ShellRoot {
    id: root

    property var staged: null
    property var labelFor: id => id === "activeWindow" ? "Active window"
        : id === "connectivity" ? "Connections"
        : id === "utils" ? "Recording" : id

    BarStudio.NacreEditor {
        id: editor
        width: 900
        config: ({
            islands: {
                left: ["brand", "media", "activeWindow"],
                center: ["clock", "workspaces", "resources"],
                right: ["connectivity", "audio", "battery", "notifications", "tray"]
            },
            height: 40,
            opacity: 0.82,
            padding: 12,
            spacing: 8,
            islandGap: 14,
            frameSize: 9,
            frameRoundness: 9,
            edgeMelt: 8,
            islandScale: 1,
            osdScale: 1,
            frame: true,
            occupiedWorkspaces: true,
            workspaceStyle: "dots"
        })
        onStaged: value => root.staged = value
    }

    BarStudio.NacreIslandLane {
        id: sparseLane
        width: 260
        islandId: "left"
        items: ["brand"]
        labelFor: root.labelFor
    }

    BarStudio.NacreIslandLane {
        id: crowdedLane
        width: 260
        islandId: "right"
        items: ["media", "brand", "utils", "weather", "activeWindow"]
        labelFor: root.labelFor
    }

    BarStudio.NacreIslandLane {
        id: emptyLane
        width: 260
        islandId: "center"
        items: []
        labelFor: root.labelFor
    }

    BarStudio.NacreWidgetChip {
        id: longChip
        widgetId: "activeWindow"
        label: "An extremely long widget name"
        sourceIsland: "left"
        sourceIndex: 0
    }

    function require(condition, label) {
        if (!condition)
            throw new Error("NACRE-EDITOR-PROBE-FAIL " + label);
    }

    function findObject(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        const children = item.children || [];
        for (const child of children) {
            const found = root.findObject(child, name);
            if (found)
                return found;
        }
        return null;
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            require(editor.islandIds.length === 3, "three islands");
            require(editor.placedCount === 11, "default placed widgets");
            require(editor.unusedCount === 2, "default unused widgets");
            const left = root.findObject(editor, "nacre-island-left");
            const center = root.findObject(editor, "nacre-island-center");
            const right = root.findObject(editor, "nacre-island-right");
            require(left && center && right, "island lanes");
            require(left.width === editor.width && center.width === editor.width
                && right.width === editor.width, "full width lanes");
            require(left.y < center.y && center.y < right.y, "stacked lanes");
            require(crowdedLane.height > sparseLane.height, "wrapped lane grows");
            require(root.findObject(emptyLane, "nacre-empty-drop-center"), "empty lane drop affordance");
            crowdedLane.showDropPreview(12, 44);
            require(crowdedLane.dragPreview && crowdedLane.dropIndex >= 0, "lane tracks insertion preview");
            const marker = root.findObject(crowdedLane, "nacre-drop-marker-right");
            require(marker && marker.visible && marker.x >= 0
                && marker.x <= crowdedLane.width && marker.color.a > 0,
                "insertion marker stays inside lane");
            crowdedLane.hideDropPreview();
            require(!crowdedLane.dragPreview && crowdedLane.dropIndex === -1, "lane clears insertion preview");
            const palette = root.findObject(editor, "nacre-palette");
            palette.showRemovalPreview();
            require(palette.removalPreview, "palette exposes removal preview");
            palette.hideRemovalPreview();
            require(longChip.width <= 144, "long chip capped");
            const dragVisual = root.findObject(longChip, "nacre-widget-visual-activeWindow");
            require(dragVisual, "separate drag visual");
            const slotX = longChip.x;
            dragVisual.x = 80;
            require(longChip.x === slotX, "drag visual preserves flow slot");
            dragVisual.x = 0;
            editor.moveWidget("brand", "left", "right", 1);
            require(root.staged.islands.left.length === 2, "drag removes source");
            require(root.staged.islands.right[1] === "brand", "drag inserts target");
            editor.config = root.staged;
            editor.setAppearance("height", 48);
            require(root.staged.height === 48, "appearance stages");
            editor.config = root.staged;
            editor.setAppearance("frame", false);
            require(root.staged.frame === false, "frame stages");
            require(root.findObject(editor, "nacre-frame"), "frame control");
            editor.config = root.staged;
            editor.setAppearance("frameRoundness", 18);
            require(root.staged.frameRoundness === 18, "frame roundness stages");
            editor.config = root.staged;
            editor.setAppearance("frameSize", 14);
            require(root.staged.frameSize === 14, "frame size stages");
            editor.config = root.staged;
            editor.setAppearance("edgeMelt", 20);
            require(root.staged.edgeMelt === 20, "edge melt stages");
            require(root.findObject(editor, "nacre-frame-roundness"), "frame roundness control");
            require(root.findObject(editor, "nacre-frame-size"), "frame size control");
            require(root.findObject(editor, "nacre-edge-melt"), "edge melt control");
            editor.config = root.staged;
            editor.setAppearance("islandScale", 0.8);
            require(root.staged.islandScale === 0.8, "island size stages");
            editor.config = root.staged;
            editor.setAppearance("osdScale", 0.75);
            require(root.staged.osdScale === 0.75, "OSD size stages");
            require(root.findObject(editor, "nacre-island-size"), "island size control");
            require(root.findObject(editor, "nacre-osd-size"), "OSD size control");
            require(root.findObject(editor, "nacre-workspace-style"), "workspace style control");
            editor.config = root.staged;
            editor.setAppearance("workspaceStyle", "kanji");
            require(root.staged.workspaceStyle === "kanji", "workspace style stages");
            console.log("NACRE-EDITOR-PROBE-PASS");
            Qt.quit();
        }
    }
}
