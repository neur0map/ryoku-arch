import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules/bar/barstyles/nacre/popouts" as Popouts
import "modules/bar/barstyles/obi/widgets" as Obi
import "modules/bar/barstyles/nacre/components" as NacreComponents
import "modules/bar/barstyles/nacre/widgets" as NacreWidgets

// External half of the nacre popup probe: exercises the nacre and obi barstyle
// PRODUCTS shipped by ryoku-extras, copied into the built-in barstyle dir
// (modules/bar/barstyles) of the scaffold. These products still import the
// RETIRED pill.* namespace (pill.Singletons, pill as Pill, pill.popouts,
// pill.framebars.menus), so until they are migrated to the consolidated tree
// they cannot load and nacre-popup-probe.sh SKIPs this half (see that file's
// header). Every assertion below is preserved so this runs for real once a
// pill.* compat / product migration lands.
ShellRoot {
    id: root

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

    function visibleText(item) {
        if (!item)
            return [];
        let values = item.visible && typeof item.text === "string" ? [item.text] : [];
        const children = item.children || [];
        for (const child of children)
            values = values.concat(root.visibleText(child));
        return values;
    }

    function findWidgetHost(item, widgetId) {
        if (!item)
            return null;
        if (item.widgetId === widgetId && item.status !== undefined)
            return item;
        const children = item.children || [];
        for (const child of children) {
            const found = root.findWidgetHost(child, widgetId);
            if (found)
                return found;
        }
        return null;
    }

    Component { id: audio; Popouts.AudioPopout {} }
    Component { id: battery; Popouts.BatteryPopout {} }
    Component { id: calendar; Popouts.CalendarPopout {} }
    Component { id: connectivity; Popouts.ConnectivityPopout {} }
    Component { id: media; Popouts.MediaPopout {} }
    Component { id: resources; Popouts.ResourcesPopout {} }
    Component { id: weather; Popouts.WeatherPopout {} }
    Component { id: obiAudio; Obi.Audio {} }
    Component { id: obiBattery; Obi.Battery {} }
    Component { id: obiClock; Obi.Clock {} }
    Component { id: obiConnectivity; Obi.Connectivity {} }
    Component { id: obiMedia; Obi.Media {} }
    Component { id: obiResources; Obi.Resources {} }
    Component { id: obiWeather; Obi.Weather {} }
    Component {
        id: nacreScene
        Loader {
            source: "modules/bar/barstyles/nacre/Scene.qml"
            onLoaded: item.modelData = Quickshell.screens[0]
        }
    }
    Component { id: nacreActiveWindow; NacreWidgets.ActiveWindow {} }
    Component { id: nacreAudio; NacreWidgets.Audio {} }
    Component { id: nacreBattery; NacreWidgets.Battery {} }
    Component { id: nacreBrand; NacreWidgets.Brand {} }
    Component { id: nacreClock; NacreWidgets.Clock {} }
    Component { id: nacreConnectivity; NacreWidgets.Connectivity {} }
    Component { id: nacreMedia; NacreWidgets.Media {} }
    Component { id: nacreNotifications; NacreWidgets.Notifications {} }
    Component { id: nacreResources; NacreWidgets.Resources {} }
    Component { id: nacreTray; NacreWidgets.Tray {} }
    Component { id: nacreUtils; NacreWidgets.Utils {} }
    Component { id: nacreWeather; NacreWidgets.Weather {} }
    Component { id: nacreWorkspaces; NacreWidgets.Workspaces {} }
    Component {
        id: nacreIsland
        NacreComponents.Island {}
    }
    Component {
        id: nacreConnectivityUrl
        Loader { source: "modules/bar/barstyles/nacre/widgets/Connectivity.qml" }
    }
    Component {
        id: connectivityPopupUrl
        Loader { source: "modules/bar/barstyles/nacre/popouts/ConnectivityPopout.qml" }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            const components = [
                audio, battery, calendar, connectivity, media, resources, weather,
                obiAudio, obiBattery, obiClock, obiConnectivity, obiMedia, obiResources, obiWeather,
                nacreActiveWindow, nacreAudio, nacreBattery, nacreBrand, nacreClock,
                nacreConnectivity, nacreMedia, nacreNotifications, nacreResources, nacreTray, nacreUtils, nacreWeather,
                nacreWorkspaces
            ];
            for (const component of components) {
                const item = component.createObject(root);
                if (!item)
                    throw new Error("NACRE-POPUP-PROBE-FAIL");
                item.destroy();
            }
            const workspaceFace = nacreWorkspaces.createObject(root, {
                workspaceStyle: "dots"
            });
            if (!workspaceFace || workspaceFace.label(1) !== "")
                throw new Error("NACRE-WORKSPACE-DOTS-PROBE-FAIL");
            workspaceFace.workspaceStyle = "numbers";
            if (workspaceFace.label(3) !== "3")
                throw new Error("NACRE-WORKSPACE-NUMBERS-PROBE-FAIL");
            workspaceFace.workspaceStyle = "kanji";
            if (workspaceFace.label(3) !== "三" || workspaceFace.label(11) !== "11")
                throw new Error("NACRE-WORKSPACE-KANJI-PROBE-FAIL");
            workspaceFace.destroy();
            const scene = nacreScene.createObject(root);
            if (!scene || scene.status !== Loader.Ready)
                throw new Error("NACRE-SCENE-PROBE-FAIL");
            if (!scene.item || !scene.item.unifiedBlobFrame || scene.item.frameInset <= 0
                    || scene.item.barSpan !== scene.item.settings.height
                        * scene.item.settings.islandScale + scene.item.frameInset)
                throw new Error("NACRE-FRAME-INSET-PROBE-FAIL");
            if (scene.item.mediaPresent === undefined
                    || scene.item.mediaPopupEnabled === undefined)
                throw new Error("NACRE-MEDIA-POPUP-PRESENCE-PROBE-FAIL");
            scene.item.mediaPresent = false;
            if (scene.item.mediaPopupEnabled)
                throw new Error("NACRE-IDLE-MEDIA-POPUP-PROBE-FAIL");
            scene.item.mediaPresent = true;
            if (!scene.item.mediaPopupEnabled)
                throw new Error("NACRE-PRESENT-MEDIA-POPUP-PROBE-FAIL");
            if (scene.item.overlayKeyboardMode !== WlrKeyboardFocus.None)
                throw new Error("NACRE-CLOSED-KEYBOARD-PROBE-FAIL");
            scene.item.selectedCenter = 900;
            scene.item.selectedPopup = "connectivity";
            if (scene.item.centerFor("connectivity") !== 900
                    || scene.item.overlayKeyboardMode !== WlrKeyboardFocus.OnDemand)
                throw new Error("NACRE-OPEN-POPUP-STATE-PROBE-FAIL");
            const popupBounds = scene.item.selectedPopupBounds();
            if (!scene.item.popupBackdropActive
                    || popupBounds.width <= 0 || popupBounds.height <= 0)
                throw new Error("NACRE-POPUP-BACKDROP-PROBE-FAIL");
            if (scene.item.dismissPopupAt(
                    popupBounds.x + popupBounds.width / 2,
                    popupBounds.y + popupBounds.height / 2)
                    || scene.item.selectedPopup !== "connectivity")
                throw new Error("NACRE-POPUP-INSIDE-PRESS-PROBE-FAIL");
            if (!scene.item.dismissPopupAt(0, scene.item.barSpan + 100)
                    || scene.item.selectedPopup !== ""
                    || scene.item.popupBackdropActive)
                throw new Error("NACRE-POPUP-OUTSIDE-PRESS-PROBE-FAIL");
            if (scene.item.centerFor("connectivity") !== 900
                    || scene.item.overlayKeyboardMode !== WlrKeyboardFocus.None)
                throw new Error("NACRE-CLOSE-ANCHOR-PROBE-FAIL");
            scene.destroy();
            const connectivityUrl = nacreConnectivityUrl.createObject(root);
            if (!connectivityUrl || connectivityUrl.status !== Loader.Ready)
                throw new Error("NACRE-CONNECTIVITY-PROBE-FAIL");
            connectivityUrl.destroy();
            const connectivityPopup = connectivityPopupUrl.createObject(root);
            if (!connectivityPopup || connectivityPopup.status !== Loader.Ready)
                throw new Error("CONNECTIVITY-POPUP-PROBE-FAIL");
            connectivityPopup.destroy();
            const emptyIsland = nacreIsland.createObject(root, { widgetIds: [] });
            if (!emptyIsland || emptyIsland.visible || emptyIsland.width !== 0 || emptyIsland.height !== 0)
                throw new Error("NACRE-EMPTY-ISLAND-PROBE-FAIL");
            const populatedIsland = nacreIsland.createObject(root, { widgetIds: ["brand"] });
            if (!populatedIsland || !populatedIsland.visible || !populatedIsland.hasWidgets
                    || populatedIsland.naturalWidth <= 0 || populatedIsland.height <= 0)
                throw new Error("NACRE-POPULATED-ISLAND-PROBE-FAIL");
            const constrainedIsland = nacreIsland.createObject(root, {
                widgetIds: ["brand"], maxWidth: 0
            });
            if (!constrainedIsland || constrainedIsland.width <= 0)
                throw new Error("NACRE-CONSTRAINED-ISLAND-PROBE-FAIL");
            const unifiedIsland = nacreIsland.createObject(root, {
                widgetIds: ["brand"], unifiedFrame: true
            });
            if (!unifiedIsland || unifiedIsland.border.width !== 0 || unifiedIsland.color.a !== 0)
                throw new Error("NACRE-UNIFIED-ISLAND-PROBE-FAIL");
            const scaledIsland = nacreIsland.createObject(root, {
                widgetIds: ["brand"], islandScale: 0.75
            });
            if (!scaledIsland || scaledIsland.width >= populatedIsland.width
                    || scaledIsland.height >= populatedIsland.height)
                throw new Error("NACRE-ISLAND-SCALE-PROBE-FAIL");
            populatedIsland.widgetIds = [];
            populatedIsland.destroy();
            constrainedIsland.destroy();
            unifiedIsland.destroy();
            scaledIsland.destroy();
            emptyIsland.destroy();
            const resourcesFace = nacreResources.createObject(root);
            if (!resourcesFace
                    || !root.findObject(resourcesFace, "nacre-health-cpu")
                    || !root.findObject(resourcesFace, "nacre-health-memory")
                    || !root.findObject(resourcesFace, "nacre-health-temperature"))
                throw new Error("NACRE-HEALTH-ICONS-PROBE-FAIL");
            const healthText = root.visibleText(resourcesFace);
            if (healthText.some(value => value.startsWith("CPU ") || value.startsWith("RAM ")))
                throw new Error("NACRE-HEALTH-WORDS-PROBE-FAIL");
            resourcesFace.destroy();
            const mediaHarness = nacreIsland.createObject(root, {
                widgetIds: ["brand"]
            });
            const mediaFace = nacreMedia.createObject(mediaHarness);
            if (!mediaFace || mediaFace.visible
                    || root.visibleText(mediaFace).includes("No music"))
                throw new Error("NACRE-IDLE-MEDIA-PROBE-FAIL");
            if (mediaFace.mediaPresent === undefined)
                throw new Error("NACRE-MEDIA-PRESENCE-STATE-PROBE-FAIL");
            mediaFace.mediaPresent = true;
            if (!mediaFace.visible)
                throw new Error("NACRE-PAUSED-MEDIA-PROBE-FAIL");
            mediaFace.destroy();
            mediaHarness.destroy();
            const dormantMediaIsland = nacreIsland.createObject(root, {
                widgetIds: ["media"]
            });
            const dormantMediaHost = root.findWidgetHost(dormantMediaIsland, "media");
            if (!dormantMediaHost || dormantMediaHost.status !== Loader.Ready
                    || !dormantMediaHost.visible || dormantMediaHost.width !== 0)
                throw new Error("NACRE-DORMANT-WIDGET-HOST-PROBE-FAIL");
            dormantMediaIsland.destroy();
            const seekPlayer = {
                position: 10,
                length: 100,
                canSeek: true
            };
            const seekPopup = media.createObject(root);
            if (!seekPopup || typeof seekPopup.seekToFraction !== "function"
                    || seekPopup.mediaService === undefined)
                throw new Error("NACRE-MEDIA-SEEK-API-PROBE-FAIL");
            seekPopup.mediaService = { player: seekPlayer };
            if (!seekPopup.seekToFraction(0.75) || seekPlayer.position !== 75)
                throw new Error("NACRE-MEDIA-SEEK-PROBE-FAIL");
            seekPopup.destroy();
            console.log("NACRE-BARSTYLE-PROBE-PASS");
            Qt.quit();
        }
    }
}
