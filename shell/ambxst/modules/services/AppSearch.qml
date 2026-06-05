pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.ambxst.modules.services

Singleton {
    id: root

    property var iconCache: ({})
    
    function getCachedIcon(str) {
        if (!str) return "image-missing";
        if (iconCache[str]) return iconCache[str];
        
        const result = guessIcon(str);
        iconCache[str] = result;
        return result;
    }

    function iconExists(iconName) {
        return (Quickshell.iconPath(iconName, true).length > 0) 
            && !iconName.includes("image-missing");
    }

    function validateIcon(iconName) {
        if (!iconName || iconName.length === 0) {
            return "image-missing";
        }
        
        if (iconName.startsWith("/")) {
            const resolvedPath = Quickshell.iconPath(iconName, true);
            if (resolvedPath.length === 0) {
                return "image-missing";
            }
            return iconName;
        }
        
        if (iconExists(iconName)) {
            return iconName;
        }
        
        return "image-missing";
    }

    function getIconFromDesktopEntry(className) {
        if (!className || className.length === 0) return null;

        const normalizedClassName = className.toLowerCase();

        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            if (app.command && app.command.length > 0) {
                const executableLower = app.command[0].toLowerCase();
                if (executableLower === normalizedClassName) {
                    return app.icon || "application-x-executable";
                }
            }
            if (app.name && app.name.toLowerCase() === normalizedClassName) {
                return app.icon || "application-x-executable";
            }
            if (app.keywords && app.keywords.length > 0) {
                for (let j = 0; j < app.keywords.length; j++) {
                    if (app.keywords[j].toLowerCase() === normalizedClassName) {
                        return app.icon || "application-x-executable";
                    }
                }
            }
        }
        return null;
    }

    function guessIcon(str) {
        if (!str || str.length == 0) return "image-missing";

        const desktopIcon = getIconFromDesktopEntry(str);
        if (desktopIcon) return desktopIcon;

        if (substitutions[str])
            return substitutions[str];

        for (let i = 0; i < regexSubstitutions.length; i++) {
            const substitution = regexSubstitutions[i];
            const replacedName = str.replace(
                substitution.regex,
                substitution.replace,
            );
            if (replacedName != str) return replacedName;
        }

        if (iconExists(str)) return str;

        const extensionGuess = str.split('.').pop().toLowerCase();
        if (iconExists(extensionGuess)) return extensionGuess;

        const dashedGuess = str.toLowerCase().replace(/\s+/g, "-");
        if (iconExists(dashedGuess)) return dashedGuess;

        return str;
    }

    property var substitutions: ({
        "code-url-handler": "visual-studio-code",
        "Code": "visual-studio-code",
        "gnome-tweaks": "org.gnome.tweaks",
        "pavucontrol-qt": "pavucontrol",
        "wps": "wps-office2019-kprometheus",
        "wpsoffice": "wps-office2019-kprometheus",
        "footclient": "foot",
        "zen": "zen-browser",
    })
    property list<var> regexSubstitutions: [
        {
            "regex": /^steam_app_(\d+)$/,
            "replace": "steam_icon_$1"
        },
        {
            "regex": /Minecraft.*/,
            "replace": "minecraft"
        },
        {
            "regex": /.*polkit.*/,
            "replace": "system-lock-screen"
        },
        {
            "regex": /gcr.prompter/,
            "replace": "system-lock-screen"
        }
    ]




    
    readonly property list<DesktopEntry> list: Array.from(DesktopEntries.applications.values)
        .sort((a, b) => a.name.localeCompare(b.name))
    
    property var searchIndex: []
    
    function buildIndex() {
        const newIndex = [];
        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            newIndex.push({
                name: app.name.toLowerCase(),
                command: (app.command && app.command.length > 0) ? app.command.join(' ').toLowerCase() : "",
                executable: (app.command && app.command.length > 0) ? app.command[0].toLowerCase() : "",
                comment: (app.comment || "").toLowerCase(),
                genericName: (app.genericName || "").toLowerCase(),
                keywords: (app.keywords || []).map(k => k.toLowerCase()),
                original: app
            });
        }
        searchIndex = newIndex;
    }
    
    property var allAppsCache: null

    function invalidateCache() {
        allAppsCache = null;
    }

    onListChanged: {
        allAppsCache = null;
        buildIndex();
    }
    
    Component.onCompleted: {
        buildIndex();
    }
    

    function launchApp(app) {
        const path = app.fileName || app.path || app.filePath;
        
        if (path && path.toString().endsWith('.desktop')) {
            const escapedPath = path.toString().replace(/'/g, "'\\''");
            runInActiveWorkspace("gio launch '" + escapedPath + "'");
            return;
        }

        if (app.command && app.command.length > 0) {
            const safeArgs = [];
            for (let i = 0; i < app.command.length; i++) {
                const arg = app.command[i];
                if (/^%[fFuUijkc]$/.test(arg)) continue;
                safeArgs.push("'" + arg.replace(/'/g, "'\\''") + "'");
            }

            if (safeArgs.length > 0) {
                runInActiveWorkspace(safeArgs.join(" "));
                return;
            }
        }

        app.execute();
    }

    function runInActiveWorkspace(command) {
        const p = Qt.createQmlObject('import Quickshell.Io; Process { }', root);
        p.command = ["bash", "-c", "cd ~ && env -u HL_INITIAL_WORKSPACE_TOKEN setsid " + command + " < /dev/null > /dev/null 2>&1 &"];
        p.onExited.connect(() => p.destroy());
        p.running = true;
    }

    function getAllApps() {
        if (allAppsCache) return allAppsCache;

        const results = [];
        
        for (let i = 0; i < list.length; i++) {
            const app = list[i];
            const usageScore = UsageTracker.getUsageScore(app.id);
            
            let iconToUse = app.icon || "application-x-executable";
            if (iconCache[iconToUse]) {
                iconToUse = iconCache[iconToUse];
            } else {
                let validated = validateIcon(iconToUse);
                iconCache[iconToUse] = validated;
                iconToUse = validated;
            }

            results.push({
                name: app.name,
                icon: iconToUse,
                id: app.id,
                execString: app.execString,
                comment: app.comment || "",
                categories: app.categories || [],
                runInTerminal: app.runInTerminal || false,
                usageScore: usageScore,
                execute: () => {
                    launchApp(app);
                }
            });
        }
        
        results.sort((a, b) => {
            if (a.usageScore !== b.usageScore) {
                return b.usageScore - a.usageScore;
            }
            return a.name.localeCompare(b.name);
        });
        
        allAppsCache = results;
        return results;
    }
    
    function fuzzyQuery(search) {
        if (!search || search.length === 0) return [];
        
        const searchLower = search.toLowerCase();
        const results = [];
        
        if (searchIndex.length === 0 && list.length > 0) buildIndex();
        
        for (let i = 0; i < searchIndex.length; i++) {
            const entry = searchIndex[i];
            let score = 0;
            let matchFound = false;
            
            if (entry.name === searchLower) {
                score += 100;
                matchFound = true;
            } else if (entry.name.startsWith(searchLower)) {
                score += 80;
                matchFound = true;
            } else if (entry.name.includes(searchLower)) {
                score += 60;
                matchFound = true;
            }
            
            if (entry.command) {
                if (entry.command.includes(searchLower)) {
                    score += 40;
                    matchFound = true;
                }
                if (entry.executable.includes(searchLower)) {
                    score += 50;
                    matchFound = true;
                }
            }
            
            if (entry.comment && entry.comment.includes(searchLower)) {
                score += 30;
                matchFound = true;
            }
            
            if (entry.genericName && entry.genericName.includes(searchLower)) {
                score += 25;
                matchFound = true;
            }
            
            if (entry.keywords.length > 0) {
                for (let j = 0; j < entry.keywords.length; j++) {
                    if (entry.keywords[j].includes(searchLower)) {
                        score += 20;
                        matchFound = true;
                        break;
                    }
                }
            }
            
            if (matchFound) {
                const app = entry.original;
                const usageScore = UsageTracker.getUsageScore(app.id);
                let iconToUse = app.icon || "application-x-executable";
                if (iconCache[iconToUse]) {
                    iconToUse = iconCache[iconToUse];
                } else {
                    let validated = validateIcon(iconToUse);
                    iconCache[iconToUse] = validated;
                    iconToUse = validated;
                }
                
                results.push({
                    name: app.name,
                    icon: iconToUse,
                    score: score,
                    id: app.id,
                    execString: app.execString,
                    comment: app.comment || "",
                    categories: app.categories || [],
                    runInTerminal: app.runInTerminal || false,
                    usageScore: usageScore,
                    execute: () => {
                        launchApp(app);
                    }
                });
            }
        }
        
        results.sort((a, b) => {
            const totalScoreA = a.score + a.usageScore;
            const totalScoreB = b.score + b.usageScore;
            
            if (totalScoreA !== totalScoreB) {
                return totalScoreB - totalScoreA;
            }
            return (a.name || "").localeCompare(b.name || "");
        });
        
        return results.slice(0, 10);
    }
}
