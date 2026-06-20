pragma Singleton
import QtQuick
import Quickshell

/**
 * App/window icon resolution for Hyprland toplevels. A window's class often
 * differs from its icon-theme name, so match the class against a desktop entry
 * id first and fall back to a direct icon-theme lookup. Shared by every surface
 * that paints a window's icon (the minimized tray, the workspace switcher).
 */
Singleton {
    function iconFor(t) {
        var cls = (t && t.lastIpcObject && t.lastIpcObject.class) ? t.lastIpcObject.class
            : (t && t.wayland && t.wayland.appId ? t.wayland.appId : "");
        if (!cls)
            return "";
        var apps = DesktopEntries.applications.values;
        for (var i = 0; i < apps.length; i++) {
            var e = apps[i];
            if (e && e.id && e.id.toLowerCase() === cls.toLowerCase() && e.icon)
                return Quickshell.iconPath(e.icon, "application-x-executable");
        }
        return Quickshell.iconPath(cls, "application-x-executable");
    }
}
