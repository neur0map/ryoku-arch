import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.ambxst.modules.globals
import qs.ambxst.modules.theme
import qs.ambxst.config
import "MpvShaderGenerator.js" as ShaderGenerator

PanelWindow {
    id: wallpaper

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ambxst:wallpaper"
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"

    property string wallpaperDir: wallpaperConfig.adapter.wallPath
    property string fallbackDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/wallpapers_example").toString().replace("file://", ""))
    property var wallpaperPaths: []
    property var subfolderFilters: []
    property var allSubdirs: []
    property int currentIndex: 0
    property string currentWallpaper: initialLoadCompleted && wallpaperPaths.length > 0 ? wallpaperPaths[currentIndex] : ""
    property bool initialLoadCompleted: false
    property bool usingFallback: false
    property bool _wallpaperDirInitialized: false
    property string currentMatugenScheme: wallpaperConfig.adapter.matugenScheme
    property var perScreenWallpapers: wallpaperConfig.adapter.perScreenWallpapers || {}
    property string effectiveWallpaper: perScreenWallpapers[currentScreenName] || currentWallpaper
    property string currentScreenName: wallpaper.screen ? wallpaper.screen.name : ""
    property alias tintEnabled: wallpaperAdapter.tintEnabled
    property int thumbnailsVersion: 0

    // QUICKSHELL-GIT: property string mpvShaderDir: Quickshell.cacheDir + "/mpv_shaders_" + (currentScreenName ? currentScreenName : "ALL")
    property string mpvShaderDir: Quickshell.env("HOME") + "/.cache/ambxst/mpv_shaders_" + (currentScreenName ? currentScreenName : "ALL")
    property string mpvShaderPath: ""
    property bool mpvShaderReady: false

    readonly property var optimizedPalette: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

    Binding {
        target: wallpaper
        property: "wallpaperPaths"
        value: GlobalStates.wallpaperManager.wallpaperPaths
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    Binding {
        target: wallpaper
        property: "currentIndex"
        value: GlobalStates.wallpaperManager.currentIndex
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    Binding {
        target: wallpaper
        property: "subfolderFilters"
        value: GlobalStates.wallpaperManager.subfolderFilters
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    Binding {
        target: wallpaper
        property: "initialLoadCompleted"
        value: GlobalStates.wallpaperManager.initialLoadCompleted
        when: GlobalStates.wallpaperManager !== null && GlobalStates.wallpaperManager !== wallpaper
    }

    property string colorPresetsDir: Quickshell.env("HOME") + "/.config/ambxst/colors"
    property string officialColorPresetsDir: decodeURIComponent(Qt.resolvedUrl("../../../../assets/colors").toString().replace("file://", ""))
    onColorPresetsDirChanged: console.log("Color Presets Directory:", colorPresetsDir)
    property list<string> colorPresets: []
    onColorPresetsChanged: console.log("Color Presets Updated:", colorPresets)
    property string activeColorPreset: wallpaperConfig.adapter.activeColorPreset || ""

    property bool isLightMode: Config.theme.lightMode
    onIsLightModeChanged: {
        if (activeColorPreset) {
            applyColorPreset();
        } else {
            runMatugenForCurrentWallpaper();
        }
    }

    onActiveColorPresetChanged: {
        if (activeColorPreset) {
            applyColorPreset();
        } else {
            runMatugenForCurrentWallpaper();
        }
    }

    function scanColorPresets() {
        scanPresetsProcess.running = true;
    }

    function applyColorPreset() {
        if (!activeColorPreset)
            return;

        var mode = Config.theme.lightMode ? "light.json" : "dark.json";

        var officialFile = officialColorPresetsDir + "/" + activeColorPreset + "/" + mode;
        var userFile = colorPresetsDir + "/" + activeColorPreset + "/" + mode;
        // QUICKSHELL-GIT: var dest = Quickshell.cachePath("colors.json");
        var dest = Quickshell.env("HOME") + "/.cache/ambxst/colors.json";

        var cmd = "if [ -f '" + officialFile + "' ]; then cp '" + officialFile + "' '" + dest + "'; else cp '" + userFile + "' '" + dest + "'; fi";

        console.log("Applying color preset:", activeColorPreset);
        applyPresetProcess.command = ["bash", "-c", cmd];
        applyPresetProcess.running = true;
    }

    function setColorPreset(name) {
        wallpaperConfig.adapter.activeColorPreset = name;
    }

    function getFileType(path) {
        var extension = path.toLowerCase().split('.').pop();
        if (['jpg', 'jpeg', 'png', 'webp', 'tif', 'tiff', 'bmp'].includes(extension)) {
            return 'image';
        } else if (['gif'].includes(extension)) {
            return 'gif';
        } else if (['mp4', 'webm', 'mov', 'avi', 'mkv'].includes(extension)) {
            return 'video';
        }
        return 'unknown';
    }

    function getThumbnailPath(filePath) {
        var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";
        var relativePath = filePath.replace(basePath, "");

        var pathParts = relativePath.split('/');
        var fileName = pathParts.pop();
        var thumbnailName = fileName + ".jpg";
        var relativeDir = pathParts.join('/');

        // Build the proxy path
        // QUICKSHELL-GIT: var thumbnailPath = Quickshell.cacheDir + "/thumbnails/" + relativeDir + "/" + thumbnailName;
        var thumbnailPath = Quickshell.env("HOME") + "/.cache/ambxst" + "/thumbnails/" + relativeDir + "/" + thumbnailName;
        return thumbnailPath;
    }

    function getDisplaySource(filePath) {
        var fileType = getFileType(filePath);

        if (fileType === 'video' || fileType === 'image' || fileType === 'gif') {
            var thumbnailPath = getThumbnailPath(filePath);
            return thumbnailPath;
        }

        return filePath;
    }

    function getColorSource(filePath) {
        var fileType = getFileType(filePath);

        if (fileType === 'video') {
            return getThumbnailPath(filePath);
        }

        return filePath;
    }

    function getLockscreenFramePath(filePath) {
        if (!filePath) {
            return "";
        }

        var fileType = getFileType(filePath);

        if (fileType === 'image') {
            return filePath;
        }

        if (fileType === 'video' || fileType === 'gif') {
            var fileName = filePath.split('/').pop();
            // QUICKSHELL-GIT: var cachePath = Quickshell.cacheDir + "/lockscreen/" + fileName + ".jpg";
            var cachePath = Quickshell.env("HOME") + "/.cache/ambxst" + "/lockscreen/" + fileName + ".jpg";
            return cachePath;
        }

        return filePath;
    }

    function generateLockscreenFrame(filePath) {
        if (!filePath) {
            console.warn("generateLockscreenFrame: empty filePath");
            return;
        }

        console.log("Generating lockscreen frame for:", filePath);

        var scriptPath = decodeURIComponent(Qt.resolvedUrl("../../../../scripts/lockwall.py").toString().replace("file://", ""));
        // QUICKSHELL-GIT: var dataPath = Quickshell.cacheDir;
        var dataPath = Quickshell.env("HOME") + "/.cache/ambxst";

        lockscreenWallpaperScript.command = ["python3", scriptPath, filePath, dataPath];

        lockscreenWallpaperScript.running = true;
    }

    function getSubfolderFromPath(filePath) {
        var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";
        var relativePath = filePath.replace(basePath, "");
        var parts = relativePath.split("/");
        if (parts.length > 1) {
            return parts[0];
        }
        return "";
    }

    function scanSubfolders() {
        if (!wallpaperDir)
            return;
        var cmd = ["find", wallpaperDir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "d", "-print"];
        scanSubfoldersProcess.command = cmd;
        scanSubfoldersProcess.running = true;
    }

    onWallpaperDirChanged: {
        // Skip initial spurious changes before config is loaded
        if (!_wallpaperDirInitialized)
            return;

        if (GlobalStates.wallpaperManager !== wallpaper)
            return;

        console.log("Wallpaper directory changed to:", wallpaperDir);
        usingFallback = false;

        wallpaperPaths = [];
        subfolderFilters = [];

        directoryWatcher.path = wallpaperDir;

        var cmd = ["find", wallpaperDir, "-name", ".*", "-prune", "-o", "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"];
        scanWallpapers.command = cmd;
        scanWallpapers.running = true;

        scanSubfolders();

        if (delayedThumbnailGen.running)
            delayedThumbnailGen.restart();
        else
            delayedThumbnailGen.start();
    }

    onCurrentWallpaperChanged:
    {}

    function setWallpaper(path, targetScreen = null) {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.setWallpaper(path, targetScreen);
            return;
        }

        console.log("setWallpaper called with:", path, "for screen:", targetScreen);
        initialLoadCompleted = true;
        var pathIndex = wallpaperPaths.indexOf(path);
        if (pathIndex !== -1) {
            if (targetScreen) {
                let perScreen = Object.assign({}, wallpaperConfig.adapter.perScreenWallpapers || {});
                perScreen[targetScreen] = path;
                wallpaperConfig.adapter.perScreenWallpapers = perScreen;
                
                // If this targetScreen is the primary screen, it must update currentWall
                // because currentWall is exactly the primary monitor fallback.
                let isPrimary = false;
                if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager.screen) {
                    isPrimary = (targetScreen === GlobalStates.wallpaperManager.screen.name);
                }

                if (isPrimary || !wallpaperConfig.adapter.currentWall) {
                    currentIndex = pathIndex;
                    wallpaperConfig.adapter.currentWall = path;
                    currentWallpaper = path;
                    runMatugenForCurrentWallpaper();
                }
            } else {
                currentIndex = pathIndex;
                wallpaperConfig.adapter.currentWall = path;
                currentWallpaper = path;
                runMatugenForCurrentWallpaper();
            }
            generateLockscreenFrame(path);
        } else {
            console.warn("Wallpaper path not found in current list:", path);
        }
    }

    function clearPerScreenWallpaper(targetScreen) {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.clearPerScreenWallpaper(targetScreen);
            return;
        }
        
        console.log("Clearing per-screen wallpaper for:", targetScreen);
        let perScreen = Object.assign({}, wallpaperConfig.adapter.perScreenWallpapers || {});
        if (perScreen[targetScreen]) {
            delete perScreen[targetScreen];
            wallpaperConfig.adapter.perScreenWallpapers = perScreen;
        }
    }

    function nextWallpaper() {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.nextWallpaper();
            return;
        }

        if (wallpaperPaths.length === 0)
            return;
        initialLoadCompleted = true;
        currentIndex = (currentIndex + 1) % wallpaperPaths.length;
        currentWallpaper = wallpaperPaths[currentIndex];
        wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
        runMatugenForCurrentWallpaper();
        generateLockscreenFrame(wallpaperPaths[currentIndex]);
    }

    function previousWallpaper() {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.previousWallpaper();
            return;
        }

        if (wallpaperPaths.length === 0)
            return;
        initialLoadCompleted = true;
        currentIndex = currentIndex === 0 ? wallpaperPaths.length - 1 : currentIndex - 1;
        currentWallpaper = wallpaperPaths[currentIndex];
        wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
        runMatugenForCurrentWallpaper();
        generateLockscreenFrame(wallpaperPaths[currentIndex]);
    }

    function setWallpaperByIndex(index) {
        if (GlobalStates.wallpaperManager && GlobalStates.wallpaperManager !== wallpaper) {
            GlobalStates.wallpaperManager.setWallpaperByIndex(index);
            return;
        }

        if (index >= 0 && index < wallpaperPaths.length) {
            initialLoadCompleted = true;
            currentIndex = index;
            currentWallpaper = wallpaperPaths[currentIndex];
            wallpaperConfig.adapter.currentWall = wallpaperPaths[currentIndex];
            runMatugenForCurrentWallpaper();
            generateLockscreenFrame(wallpaperPaths[currentIndex]);
        }
    }

    function setMatugenScheme(scheme) {
        wallpaperConfig.adapter.matugenScheme = scheme;

        if (wallpaperConfig.adapter.activeColorPreset) {
            console.log("Switching to Matugen scheme, clearing preset");
            wallpaperConfig.adapter.activeColorPreset = "";
        } else {
            runMatugenForCurrentWallpaper();
        }
    }

    // property string mpvSocket: "/tmp/ambxst_mpv_socket"
    property string mpvSocket: "/tmp/ambxst_mpv_socket_" + (currentScreenName ? currentScreenName : "ALL")

    function runMatugenForCurrentWallpaper() {
        if (activeColorPreset) {
            console.log("Skipping Matugen because color preset is active:", activeColorPreset);
            return;
        }

        if (currentWallpaper && initialLoadCompleted) {
            console.log("Running Matugen for current wallpaper:", currentWallpaper);

            var fileType = getFileType(currentWallpaper);
            var matugenSource = getColorSource(currentWallpaper);

            console.log("Using source for matugen:", matugenSource, "(type:", fileType + ")");

            // Stop existing processes if running to prioritize new request
            if (matugenProcessWithConfig.running) {
                matugenProcessWithConfig.running = false;
            }
            if (matugenProcessNormal.running) {
                matugenProcessNormal.running = false;
            }

            var commandWithConfig = ["matugen", "image", matugenSource, "--source-color-index", "0", "-c", decodeURIComponent(Qt.resolvedUrl("../../../../assets/matugen/config.toml").toString().replace("file://", "")), "-t", wallpaperConfig.adapter.matugenScheme];
            if (Config.theme.lightMode) {
                commandWithConfig.push("-m", "light");
            }
            matugenProcessWithConfig.command = commandWithConfig;
            matugenProcessWithConfig.running = true;

            var commandNormal = ["matugen", "image", matugenSource, "--source-color-index", "0", "-t", wallpaperConfig.adapter.matugenScheme];
            if (Config.theme.lightMode) {
                commandNormal.push("-m", "light");
            }
            matugenProcessNormal.command = commandNormal;
            matugenProcessNormal.running = true;
        }
    }

    function updateMpvRuntime(enable) {
        var cmdString;
        if (enable) {
            // Since we are using unique filenames, we can just set the new path.
            // MPV will handle the switch smoothly and won't use cached versions.
            var setCmd = JSON.stringify({
                "command": ["set_property", "glsl-shaders", mpvShaderPath]
            });
            cmdString = "echo '" + setCmd + "' | socat - " + mpvSocket;
        } else {
            var jsonCmd = JSON.stringify({
                "command": ["set_property", "glsl-shaders", ""]
            });
            cmdString = "echo '" + jsonCmd + "' | socat - " + mpvSocket;
        }

        mpvIpcProcess.command = ["bash", "-c", cmdString];
        mpvIpcProcess.running = true;
    }

    function requestVideoSync() {
        if (GlobalStates.wallpaperManager !== wallpaper) {
            if (GlobalStates.wallpaperManager) {
                GlobalStates.wallpaperManager.requestVideoSync();
            }
            return;
        }
        videoSyncTimer.restart();
    }

    Timer {
        id: videoSyncTimer
        interval: 1200 // give mpvpaper processes time to spawn and initialize
        repeat: false
        onTriggered: {
            console.log("Broadcasting video sync to all mpvpaper sockets...");
            mpvSyncProcess.running = true;
        }
    }

    Process {
        id: mpvSyncProcess
        running: false
        command: ["bash", "-c", "for sock in /tmp/ambxst_mpv_socket_*; do echo '{ \"command\": [\"set_property\", \"time-pos\", 0] }' | socat - \"$sock\" 2>/dev/null; done"]
        onExited: code => {
            console.log("Video sync broadcast completed with code:", code);
        }
    }

    function updateMpvShader() {
        if (getFileType(effectiveWallpaper) !== "video") {
            return;
        }
        if (!wallpaperAdapter.tintEnabled) {
            updateMpvRuntime(false);
            return;
        }

        var colors = [];
        var firstColorRaw = Colors[optimizedPalette[0]];
        console.log("Generating MPV shader. First palette color (" + optimizedPalette[0] + "):", firstColorRaw);

        for (var i = 0; i < optimizedPalette.length; i++) {
            var rawColor = Colors[optimizedPalette[i]];
            if (rawColor) {
                var c = Qt.darker(rawColor, 1.0);
                if (c && !isNaN(c.r) && !isNaN(c.g) && !isNaN(c.b)) {
                    colors.push({
                        r: c.r,
                        g: c.g,
                        b: c.b
                    });
                }
            }
        }

        if (colors.length === 0) {
            console.warn("MpvShaderGenerator: No valid colors found for palette! Aborting.");
            return;
        }

        var shaderContent = ShaderGenerator.generate(colors);

        var timestamp = Date.now();
        var currentShaderPath = mpvShaderDir + "/tint_" + timestamp + ".glsl";

        wallpaper.mpvShaderPath = currentShaderPath;

        var cmd = ["python3", "-c", "import sys, os, pathlib; " + "d = pathlib.Path(sys.argv[1]); " + "d.mkdir(parents=True, exist_ok=True); " + "[f.unlink() for f in d.iterdir() if f.is_file()]; " + "pathlib.Path(sys.argv[2]).write_text(sys.argv[3]); " + "print('Wrote shader to ' + sys.argv[2]); " + "legacy_dir = os.path.dirname(sys.argv[1]); " + "[pathlib.Path(legacy_dir, f).unlink(missing_ok=True) for f in ['mpv_tint_0.glsl', 'mpv_tint_1.glsl', 'mpv_tint.glsl']]", mpvShaderDir, currentShaderPath, shaderContent];

        mpvShaderWriter.command = cmd;
        mpvShaderWriter.running = true;
    }

    property int ipcRetryCount: 0

    Timer {
        id: ipcRetryTimer
        interval: 200
        repeat: false
        onTriggered: {
            // Retry the last command (which is currently set in mpvIpcProcess)
            mpvIpcProcess.running = true;
        }
    }

    Process {
        id: mpvIpcProcess
        running: false
        onExited: code => {
            if (code !== 0) {
                console.warn("MPV IPC failed (is mpvpaper running?) Code:", code);
                if (ipcRetryCount < 10) {
                    ipcRetryCount++;
                    console.log("Retrying IPC (" + ipcRetryCount + "/10)...");
                    ipcRetryTimer.restart();
                }
            } else {
                ipcRetryCount = 0;
            }
        }
    }

    Process {
        id: mpvShaderWriter
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("mpvShaderWriter stdout:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("mpvShaderWriter stderr:", text);
                }
            }
        }

        onExited: code => {
            if (code === 0) {
                console.log("MPV tint shader generated at:", mpvShaderPath);
                mpvShaderReady = true;
                // Apply immediately via IPC
                updateMpvRuntime(true);
            } else {
                console.warn("Failed to generate MPV shader");
            }
        }
    }

    Timer {
        id: shaderUpdateDebounce
        interval: 500
        onTriggered: {
            console.log("Shader debounce triggered, updating MPV...");
            updateMpvShader();
        }
    }

    Connections {
        target: Colors
        function onFileChanged() {
            console.log("Colors file changed, scheduling update...");
            shaderUpdateDebounce.restart();
        }
        function onBackgroundChanged() {
            console.log("Colors background changed, scheduling update...");
            shaderUpdateDebounce.restart();
        }
        function onPrimaryChanged() {
            console.log("Colors primary changed, scheduling update...");
            shaderUpdateDebounce.restart();
        }
    }

    Connections {
        target: Config
        function onOledModeChanged() {
            console.log("Config OLED mode changed, scheduling update...");
            shaderUpdateDebounce.restart();
        }
    }

    onTintEnabledChanged: {
        console.log("Tint enabled changed to", tintEnabled);
        updateMpvShader();
    }

    onEffectiveWallpaperChanged: {
        if (getFileType(effectiveWallpaper) === "video") {
            shaderUpdateDebounce.restart();
        }
    }

    Component.onCompleted: {
        if (GlobalStates.wallpaperManager !== null) {
            _wallpaperDirInitialized = true;
            return;
        }

        GlobalStates.wallpaperManager = wallpaper;

        checkWallpapersJson.running = true;

        scanColorPresets();
        presetsWatcher.reload();
        officialPresetsWatcher.reload();
        wallpaperConfig.reload();

        Qt.callLater(function () {
            if (currentWallpaper) {
                generateLockscreenFrame(currentWallpaper);
            }
            if (tintEnabled) {
                updateMpvShader();
            }
        });
    }

    FileView {
        id: wallpaperConfig
        // QUICKSHELL-GIT: path: Quickshell.cachePath("wallpapers.json")
        path: Quickshell.env("HOME") + "/.cache/ambxst/wallpapers.json"
        watchChanges: true

        onLoaded: {
            if (!wallpaperConfig.adapter.wallPath) {
                console.log("Loaded config but wallPath is empty, using fallback");
                wallpaperConfig.adapter.wallPath = fallbackDir;
            }
        }

        onFileChanged: reload()
        onAdapterUpdated: {
            if (!wallpaperConfig.adapter.matugenScheme) {
                wallpaperConfig.adapter.matugenScheme = "scheme-tonal-spot";
            }
            currentMatugenScheme = Qt.binding(function () {
                return wallpaperConfig.adapter.matugenScheme;
            });
            writeAdapter();
        }

        JsonAdapter {
            id: wallpaperAdapter
            property string currentWall: ""
            property string wallPath: ""
            property string matugenScheme: "scheme-tonal-spot"
            property string activeColorPreset: ""
            property bool tintEnabled: false
            property var perScreenWallpapers: ({})

            onActiveColorPresetChanged: {
                if (wallpaperConfig.adapter.activeColorPreset !== wallpaper.activeColorPreset) {
                    wallpaper.activeColorPreset = wallpaperConfig.adapter.activeColorPreset || "";
                }
            }

            onCurrentWallChanged: {
                if (!wallpaper._wallpaperDirInitialized)
                    return;

                if (currentWall && currentWall !== wallpaper.currentWallpaper) {
                    if (wallpaper.wallpaperPaths.length === 0) {
                        return;
                    }

                    var pathIndex = wallpaper.wallpaperPaths.indexOf(currentWall);
                    if (pathIndex !== -1) {
                        wallpaper.currentIndex = pathIndex;
                        if (!wallpaper.initialLoadCompleted) {
                            wallpaper.initialLoadCompleted = true;
                        }
                        wallpaper.runMatugenForCurrentWallpaper();
                    } else {
                        console.warn("Saved wallpaper not found in current list:", currentWall);
                    }
                }
            }

            onWallPathChanged: {
                if (wallPath) {
                    console.log("Config wallPath updated:", wallPath);

                    if (!wallpaper._wallpaperDirInitialized && GlobalStates.wallpaperManager === wallpaper) {
                        wallpaper._wallpaperDirInitialized = true;

                        directoryWatcher.path = wallPath;
                        directoryWatcher.reload();

                        var cmd = ["find", wallPath, "-name", ".*", "-prune", "-o", "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"];
                        scanWallpapers.command = cmd;
                        scanWallpapers.running = true;
                        wallpaper.scanSubfolders();

                        delayedThumbnailGen.start();
                    }
                }
            }
        }
    }

    Process {
        id: checkWallpapersJson
        running: false
        // QUICKSHELL-GIT: command: ["test", "-f", Quickshell.cachePath("wallpapers.json")]
        command: ["test", "-f", Quickshell.env("HOME") + "/.cache/ambxst/wallpapers.json"]

        onExited: function (exitCode) {
            if (exitCode !== 0) {
                console.log("wallpapers.json does not exist, creating with fallbackDir");
                wallpaperConfig.adapter.wallPath = fallbackDir;
            } else {
                console.log("wallpapers.json exists");
            }
        }
    }

    Process {
        id: matugenProcessWithConfig
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Matugen (with config) output:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Matugen (with config) error:", text);
                }
            }
        }

        onExited: {
            console.log("Matugen with config finished");
        }
    }

    Process {
        id: matugenProcessNormal
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Matugen (normal) output:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Matugen (normal) error:", text);
                }
            }
        }

        onExited: {
            console.log("Matugen normal finished");
        }
    }

    Process {
        id: thumbnailGeneratorScript
        running: false
        // QUICKSHELL-GIT: command: ["python3", decodeURIComponent(Qt.resolvedUrl("../../../../scripts/thumbgen.py").toString().replace("file://", "")), Quickshell.cacheDir + "/wallpapers.json", Quickshell.cacheDir, fallbackDir]
        command: ["python3", decodeURIComponent(Qt.resolvedUrl("../../../../scripts/thumbgen.py").toString().replace("file://", "")), Quickshell.env("HOME") + "/.cache/ambxst" + "/wallpapers.json", Quickshell.env("HOME") + "/.cache/ambxst", fallbackDir]

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Thumbnail Generator:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Thumbnail Generator Error:", text);
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                console.log("✅ Video thumbnails generated successfully");
                thumbnailsVersion++;
            } else {
                console.warn("⚠️ Thumbnail generation failed with code:", exitCode);
            }
        }
    }

    Timer {
        id: delayedThumbnailGen
        interval: 2000
        repeat: false
        onTriggered: thumbnailGeneratorScript.running = true
    }

    Process {
        id: lockscreenWallpaperScript
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.log("Lockscreen Wallpaper Generator:", text);
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Lockscreen Wallpaper Generator Error:", text);
                }
            }
        }

        onExited: function (exitCode) {
            if (exitCode === 0) {
                console.log("✅ Lockscreen wallpaper ready");
            } else {
                console.warn("⚠️ Lockscreen wallpaper generation failed with code:", exitCode);
            }
        }
    }

    Process {
        id: scanSubfoldersProcess
        running: false
        command: wallpaperDir ? ["find", wallpaperDir, "-mindepth", "1", "-name", ".*", "-prune", "-o", "-type", "d", "-print"] : []

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("scanSubfolders stdout:", text);
                var rawPaths = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                });

                allSubdirs = rawPaths;

                var basePath = wallpaperDir.endsWith("/") ? wallpaperDir : wallpaperDir + "/";

                var topLevelFolders = rawPaths.filter(function (path) {
                    var relative = path.replace(basePath, "");
                    return relative.indexOf("/") === -1;
                }).map(function (path) {
                    return path.split("/").pop();
                }).filter(function (name) {
                    return name.length > 0 && !name.startsWith(".");
                });

                topLevelFolders.sort();
                subfolderFilters = topLevelFolders;
                subfolderFiltersChanged();
                console.log("Updated subfolderFilters:", subfolderFilters);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Error scanning subfolders:", text);
                }
            }
        }

        onRunningChanged: {
            if (running) {
                console.log("Starting scanSubfolders for directory:", wallpaperDir);
            } else {
                console.log("Finished scanSubfolders");
            }
        }
    }

    FileView {
        id: directoryWatcher
        path: wallpaperDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            if (wallpaperDir === "")
                return;
            console.log("Wallpaper directory changed, rescanning...");
            scanWallpapers.running = true;
            scanSubfoldersProcess.running = true;
            if (delayedThumbnailGen.running)
                delayedThumbnailGen.restart();
            else
                delayedThumbnailGen.start();
        }

        // Remove onLoadFailed to prevent premature fallback activation
    }

    Instantiator {
        model: allSubdirs

        delegate: FileView {
            path: modelData
            watchChanges: true
            printErrors: false
            onFileChanged: {
                console.log("Subdirectory content changed (" + path + "), rescanning...");
                scanWallpapers.running = true;
                scanSubfoldersProcess.running = true;

                if (delayedThumbnailGen.running)
                    delayedThumbnailGen.restart();
                else
                    delayedThumbnailGen.start();
            }
        }
    }

    FileView {
        id: presetsWatcher
        path: colorPresetsDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            console.log("User color presets directory changed, rescanning...");
            scanPresetsProcess.running = true;
        }
    }

    FileView {
        id: officialPresetsWatcher
        path: officialColorPresetsDir
        watchChanges: true
        printErrors: false

        onFileChanged: {
            console.log("Official color presets directory changed, rescanning...");
            scanPresetsProcess.running = true;
        }
    }

    Process {
        id: scanWallpapers
        running: false
        command: wallpaperDir ? ["find", wallpaperDir, "-name", ".*", "-prune", "-o", "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"] : []

        onRunningChanged: {
            if (running && wallpaperDir === "") {
                console.log("Blocking scanWallpapers because wallpaperDir is empty");
                running = false;
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                var files = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                });
                if (files.length === 0) {
                    console.log("No wallpapers found in main directory, using fallback");
                    usingFallback = true;
                    scanFallback.running = true;
                } else {
                    usingFallback = false;
                    var newFiles = files.sort();
                    var listChanged = JSON.stringify(newFiles) !== JSON.stringify(wallpaperPaths);
                    if (listChanged) {
                        console.log("Wallpaper directory updated. Found", newFiles.length, "images");
                        wallpaperPaths = newFiles;

                        if (wallpaperPaths.length > 0) {
                            if (delayedThumbnailGen.running)
                                delayedThumbnailGen.restart();
                            else
                                delayedThumbnailGen.start();

                            if (wallpaperConfig.adapter.currentWall) {
                                var savedIndex = wallpaperPaths.indexOf(wallpaperConfig.adapter.currentWall);
                                if (savedIndex !== -1) {
                                    currentIndex = savedIndex;
                                    console.log("Loaded saved wallpaper at index:", savedIndex);
                                } else {
                                    currentIndex = 0;
                                    console.log("Saved wallpaper not found, using first");
                                }
                            } else {
                                currentIndex = 0;
                            }

                            if (!initialLoadCompleted) {
                                if (!wallpaperConfig.adapter.currentWall) {
                                    wallpaperConfig.adapter.currentWall = wallpaperPaths[0];
                                }
                                initialLoadCompleted = true;
                            }
                        }
                    }
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.length > 0) {
                    console.warn("Error scanning wallpaper directory:", text);
                    if (wallpaperPaths.length === 0 && wallpaperDir !== "") {
                        console.log("Directory scan failed for " + wallpaperDir + ", using fallback");
                        usingFallback = true;
                        scanFallback.running = true;
                    }
                }
            }
        }
    }

    Process {
        id: scanFallback
        running: false
        command: ["find", fallbackDir, "-name", ".*", "-prune", "-o", "-type", "f", "(", "-name", "*.jpg", "-o", "-name", "*.jpeg", "-o", "-name", "*.png", "-o", "-name", "*.webp", "-o", "-name", "*.tif", "-o", "-name", "*.tiff", "-o", "-name", "*.gif", "-o", "-name", "*.mp4", "-o", "-name", "*.webm", "-o", "-name", "*.mov", "-o", "-name", "*.avi", "-o", "-name", "*.mkv", ")", "-print"]

        stdout: StdioCollector {
            onStreamFinished: {
                var files = text.trim().split("\n").filter(function (f) {
                    return f.length > 0;
                });
                console.log("Using fallback wallpapers. Found", files.length, "images");

                if (usingFallback) {
                    wallpaperPaths = files.sort();

                    if (wallpaperPaths.length > 0) {
                        if (wallpaperConfig.adapter.currentWall) {
                            var savedIndex = wallpaperPaths.indexOf(wallpaperConfig.adapter.currentWall);
                            if (savedIndex !== -1) {
                                currentIndex = savedIndex;
                            } else {
                                currentIndex = 0;
                            }
                        } else {
                            currentIndex = 0;
                        }

                        if (!initialLoadCompleted) {
                            if (!wallpaperConfig.adapter.currentWall) {
                                wallpaperConfig.adapter.currentWall = wallpaperPaths[0];
                            }
                            initialLoadCompleted = true;
                        }
                    }
                }
            }
        }
    }

    Process {
        id: scanPresetsProcess
        running: false
        command: ["find", officialColorPresetsDir, colorPresetsDir, "-mindepth", "1", "-maxdepth", "1", "-type", "d"]

        stdout: StdioCollector {
            onStreamFinished: {
                console.log("Scan Presets Output:", text);
                var rawLines = text.trim().split("\n");
                var uniqueNames = [];
                for (var i = 0; i < rawLines.length; i++) {
                    var line = rawLines[i].trim();
                    if (line.length === 0)
                        continue;
                    var name = line.split('/').pop();
                    if (uniqueNames.indexOf(name) === -1) {
                        uniqueNames.push(name);
                    }
                }
                uniqueNames.sort();
                console.log("Found color presets:", uniqueNames);
                colorPresets = uniqueNames;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                // Suppress common "No such file or directory" if one dir is missing
                // console.warn("Scan Presets Error:", text);
            }
        }
    }

    Process {
        id: applyPresetProcess
        running: false
        command: []

        onExited: code => {
            if (code === 0)
                console.log("Color preset applied successfully");
            else
                console.warn("Failed to apply color preset, code:", code);
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color: "black"
        focus: true

        Keys.onLeftPressed: {
            if (wallpaper.wallpaperPaths.length > 0) {
                wallpaper.previousWallpaper();
            }
        }

        Keys.onRightPressed: {
            if (wallpaper.wallpaperPaths.length > 0) {
                wallpaper.nextWallpaper();
            }
        }

        WallpaperImage {
            id: wallImage
            anchors.fill: parent
            source: wallpaper.effectiveWallpaper
        }
    }

    component WallpaperImage: Item {
        property string source
        property string previousSource

        Process {
            id: killMpvpaperProcess
            running: false
            command: ["pkill", "-f", wallpaper.mpvSocket]

            onExited: function (exitCode) {
                console.log("Killed mpvpaper processes on socket", wallpaper.mpvSocket, ", exit code:", exitCode);
            }
        }

        onSourceChanged: {
            if (previousSource !== "" && source !== previousSource) {
                if (Config.animDuration > 0) {
                    transitionAnimation.restart();
                }
            }
            previousSource = source;

            if (source) {
                var fileType = getFileType(source);
                if (fileType === 'image') {
                    killMpvpaperProcess.running = true;
                }
            }
        }

        SequentialAnimation {
            id: transitionAnimation

            ParallelAnimation {
                NumberAnimation {
                    target: wallImage
                    property: "scale"
                    to: 1.01
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: wallImage
                    property: "opacity"
                    to: 0.5
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                NumberAnimation {
                    target: wallImage
                    property: "scale"
                    to: 1.0
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: wallImage
                    property: "opacity"
                    to: 1.0
                    duration: Config.animDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (!parent.source)
                    return null;

                var fileType = getFileType(parent.source);
                if (fileType === 'image') {
                    return staticImageComponent;
                } else if (fileType === 'gif' || fileType === 'video') {
                    return mpvpaperComponent;
                }
                return staticImageComponent;
            }

            property string sourceFile: parent.source
        }

        Component {
            id: staticImageComponent
            Item {
                id: staticImageRoot
                width: parent.width
                height: parent.height
                property string sourceFile: parent.sourceFile
                property bool tint: wallpaper.tintEnabled

                readonly property var optimizedPalette: ["background", "overBackground", "shadow", "surface", "surfaceBright", "surfaceDim", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest", "primary", "secondary", "tertiary", "red", "lightRed", "green", "lightGreen", "blue", "lightBlue", "yellow", "lightYellow", "cyan", "lightCyan", "magenta", "lightMagenta"]

                Item {
                    id: paletteSourceItem
                    // Must be visible for ShaderEffectSource to capture it,
                    // but we hide it visually by placing it behind or expecting ShaderEffectSource hideSource behavior.
                    visible: true
                    width: staticImageRoot.optimizedPalette.length
                    height: 1
                    opacity: 0 // Make invisible to eye but maintain presence for capture if needed (though hideSource usually handles this)

                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: staticImageRoot.optimizedPalette
                            Rectangle {
                                width: 1
                                height: 1
                                color: Colors[modelData]
                            }
                        }
                    }
                }

                ShaderEffectSource {
                    id: paletteTextureSource
                    sourceItem: paletteSourceItem
                    hideSource: true
                    visible: false
                    smooth: false
                    recursive: false
                }

                Image {
                    mipmap: true
                    id: rawImage
                    anchors.fill: parent
                    source: parent.sourceFile ? "file://" + parent.sourceFile : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    sourceSize.width: wallpaper.width
                    sourceSize.height: wallpaper.height
                    layer.enabled: parent.tint
                    layer.effect: ShaderEffect {
                        property var paletteTexture: paletteTextureSource
                        property real paletteSize: staticImageRoot.optimizedPalette.length
                        property real texWidth: rawImage.width
                        property real texHeight: rawImage.height

                        vertexShader: "palette.vert.qsb"
                        fragmentShader: "palette.frag.qsb"
                    }
                }
            }
        }

        Component {
            id: mpvpaperComponent
            Item {
                property string sourceFile: parent.sourceFile
                property string scriptPath: decodeURIComponent(Qt.resolvedUrl("mpvpaper.sh").toString().replace("file://", ""))

                Timer {
                    id: mpvpaperRestartTimer
                    interval: 100
                    onTriggered: {
                        if (sourceFile) {
                            console.log("Restarting mpvpaper for:", sourceFile);
                            mpvpaperProcess.running = true;
                            wallpaper.requestVideoSync();
                        }
                    }
                }

                onSourceFileChanged: {
                    if (sourceFile) {
                        console.log("Source file changed to:", sourceFile);
                        mpvpaperProcess.running = false;
                        mpvpaperRestartTimer.restart();
                    }
                }

                Component.onCompleted: {
                    if (sourceFile) {
                        console.log("Initial mpvpaper run for:", sourceFile);
                        mpvpaperProcess.running = true;
                        wallpaper.requestVideoSync();
                    }
                }

                Component.onDestruction:
                {}

                Process {
                    id: mpvpaperProcess
                    running: false
                    command: sourceFile && wallpaper.currentScreenName ? ["bash", scriptPath, sourceFile, (wallpaper.tintEnabled ? wallpaper.mpvShaderPath : ""), wallpaper.currentScreenName] : []

                    stdout: StdioCollector {
                        onStreamFinished: {
                            if (text.length > 0) {
                                console.log("mpvpaper output:", text);
                            }
                        }
                    }

                    stderr: StdioCollector {
                        onStreamFinished: {
                            if (text.length > 0) {
                                console.warn("mpvpaper error:", text);
                            }
                        }
                    }

                    onExited: function (exitCode) {
                        console.log("mpvpaper process exited with code:", exitCode);
                    }
                }
            }
        }
    }
}
