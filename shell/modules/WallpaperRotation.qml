pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import qs.services
import qs.settingsgui.Commons

// Ryoku: scheduled wallpaper rotation for the Wallpaper settings' Automation
// subtab. Always loaded from shell.qml so rotation runs whether or not settings
// are open. Config persists in settings.json (GlobalConfig.wallpaper.*); the
// wallpaper is applied through Ryoku's own Wallpapers service (the `ryoku
// wallpaper` CLI), not the dormant WallpaperService.
Item {
    id: root

    function pickNext(): string {
        const entries = Wallpapers.list;
        if (!entries || entries.length === 0)
            return "";

        const paths = [];
        for (let i = 0; i < entries.length; i++) {
            const p = entries[i].path;
            if (p)
                paths.push(p);
        }
        if (paths.length === 0)
            return "";
        if (paths.length === 1)
            return paths[0];

        const current = Wallpapers.actualCurrent;

        if ((GlobalConfig.wallpaper.wallpaperChangeMode || "random") === "alphabetical") {
            paths.sort((a, b) => a.localeCompare(b));
            const idx = paths.indexOf(current);
            return paths[(idx + 1) % paths.length];
        }

        // random — avoid immediately repeating the current wallpaper
        let next = current;
        let guard = 0;
        while (next === current && guard < 25) {
            next = paths[Math.floor(Math.random() * paths.length)];
            guard++;
        }
        return next;
    }

    Timer {
        interval: Math.max(60, GlobalConfig.wallpaper.randomIntervalSec) * 1000
        running: GlobalConfig.wallpaper.automationEnabled && GlobalConfig.background.wallpaperEnabled
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            const next = root.pickNext();
            if (next)
                Wallpapers.setWallpaper(next);
        }
    }
}
