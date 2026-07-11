pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The app's state: browse results, the preview palette, the apply pipeline and
// persisted settings, driven through the ryowalls engine and ryoku-shell.
Singleton {
    id: root

    // ---- browse state -------------------------------------------------------
    property string query
    property string topRange            // "" (latest) | "1w" | "1M"
    property string ratios              // "" | "16x9" ... (Fit screen)
    property int page: 1
    property var results: []
    property bool searching
    property string error
    property string _searchErr

    // ---- selection + live preview palette -----------------------------------
    property var selected: null
    property var palette: []            // 16 wallust colours for the picked image
    property bool paletteLoading

    // ---- apply --------------------------------------------------------------
    property bool busy
    property string status
    property string _dlPath

    // ---- source: which library the grid browses -----------------------------
    // wallhaven (images) | live (local ~/Pictures/livewalls videos) | moewalls
    // (anime/aesthetic video from moewalls.com). The one app-state singleton
    // drives all three so the grid, preview and tune keep their bindings.
    property string source: "wallhaven"

    // ---- settings (persisted to ~/.config/ryoku/ryowalls.json) -------------
    readonly property string apiKey: cfg.apiKey || ""
    // only wallhaven takes a key; moewalls is keyless, live is local.
    readonly property var keyPrefix: source === "wallhaven" && apiKey.length > 0
        ? ["env", "WALLHAVEN_API_KEY=" + apiKey] : []

    // what this machine can enhance: vulkan = capable GPU, upscaler = the ncnn tool
    property bool upscaleSupported: false
    property bool upscaler: false
    Process {
        id: capsProc
        running: true
        command: ["ryowalls", "caps"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var c = JSON.parse(text);
                    root.upscaleSupported = !!c.vulkan;
                    root.upscaler = !!c.upscaler;
                } catch (e) {}
            }
        }
    }
    function refreshCaps() { capsProc.running = false; capsProc.running = true; }
    // one official-repo upscaler (waifu2x) now sharpens both images and, frame by
    // frame, video, so Install pulls just that. gpk needs a tty for its confirm and
    // sudo prompts (--manager pins the official build); --hold keeps errors readable.
    function installUpscaler() {
        Quickshell.execDetached(["kitty", "--hold", "-e", "gpk", "install", "waifu2x-ncnn-vulkan", "--manager", "pacman"]);
    }

    function cmd(args) {
        return keyPrefix.concat(["ryowalls"]).concat(args);
    }

    // download command for the current source; shared by apply() and enhance().
    function _downloadCmd(it) {
        if (source === "moewalls") return cmd(["moewalls-download", it.id, it.dl]);
        if (source === "motionbgs") return cmd(["motionbgs-download", it.id, it.dl]);
        if (source === "ryoku") return cmd(["extras-download", it.id, it.dl]);
        if (source === "lib") return cmd(["library-download", it.id, it.dl]);
        return cmd(["download", it.id, it.path]);
    }

    // ---- enhance: on-demand AI upscale of the picked wallpaper (image or video)
    // on the GPU. The engine writes progress to a state file we watch; the video
    // path guards its desktop swap so a slow finish never yanks an old wallpaper
    // back. No tool installed -> the action offers Install instead.
    property bool enhancing: false
    property string enhancePhase: ""     // probe|extract|enhance|assemble|done|error|unsupported
    property real enhanceFrac: 0
    property bool _enhanceAfterDl: false

    readonly property bool selectedVideo: !!(selected && selected.video && ("" + selected.video).length > 0)
    function localPathOf(it) {
        if (!it) return "";
        if (source === "live" || source === "local")
            return ("" + (it.video || it.path || "")).replace(/^file:\/\//, "");
        return "";
    }
    function enhance() {
        var it = selected;
        if (!it || busy || enhancing) return;
        if (!upscaler) { installUpscaler(); return; }
        var local = localPathOf(it);
        if (local.length > 0) { _startEnhance(local); return; }
        // remote: fetch the full file first, then enhance the saved copy.
        busy = true;
        status = "Downloading";
        _dlPath = "";
        _setAfter = false;
        _enhanceAfterDl = true;
        dlProc.command = _downloadCmd(it);
        dlProc.running = true;
    }
    function _startEnhance(path) {
        enhancing = true;
        enhancePhase = "probe";
        enhanceFrac = 0;
        enhProc.command = ["ryowalls", "enhance", path];
        enhProc.running = true;
    }
    Process {
        id: enhProc
        onExited: code => {
            root.enhancing = false;
            // the exit code is authoritative for the final state; the watched file
            // drives only the live progress while it runs.
            root.enhancePhase = code === 3 ? "unsupported" : (code !== 0 ? "error" : "done");
            root._enhClear.restart();
        }
    }
    Timer { id: _enhClear; interval: 3500; onTriggered: { root.enhancePhase = ""; root.enhanceFrac = 0; } }
    FileView {
        id: enhView
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku-ryowalls-enhance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (!root.enhancing) return;   // ignore a stale file left by a past run
            try {
                var s = JSON.parse(enhView.text());
                root.enhancePhase = s.phase || "";
                root.enhanceFrac = (s.total > 0) ? Math.max(0, Math.min(1, s.done / s.total)) : 0;
            } catch (e) {}
        }
    }

    // ---- adjust: grade the picked image (brightness/contrast/saturation/warmth,
    // vignette) live, then bake it on Set. Session-only, reset when the pick
    // changes. The graded preview drives both the rice mock and its palette, so
    // what you see is what Set writes. Videos can't be graded (canAdjust=false).
    property var adjust: ({ brightness: 0, contrast: 0, saturation: 0, warmth: 0, vignette: false })
    property string adjustPreview: ""     // graded temp image url for the live preview
    property int adjustRev: 0
    readonly property bool adjustActive: adjust.brightness !== 0 || adjust.contrast !== 0
        || adjust.saturation !== 0 || adjust.warmth !== 0 || adjust.vignette
    readonly property bool canAdjust: !!selected && !selectedVideo

    readonly property string _adjDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku"
    function _adjSlot(rev) { return _adjDir + "/ryowalls-adjust-" + (rev % 2) + ".png"; }
    function _adjFlags() {
        var f = ["--brightness", "" + adjust.brightness, "--contrast", "" + adjust.contrast,
                 "--saturation", "" + adjust.saturation, "--warmth", "" + adjust.warmth];
        if (adjust.vignette) f.push("--vignette");
        return f;
    }
    function setAdjust(key, val) {
        var a = { brightness: adjust.brightness, contrast: adjust.contrast,
                  saturation: adjust.saturation, warmth: adjust.warmth, vignette: adjust.vignette };
        a[key] = val;
        adjust = a;
        _adjDebounce.restart();
    }
    function applyLook(look) {
        adjust = { brightness: look.brightness || 0, contrast: look.contrast || 0,
                   saturation: look.saturation || 0, warmth: look.warmth || 0, vignette: !!look.vignette };
        _adjDebounce.restart();
    }
    function resetAdjust() {
        adjust = { brightness: 0, contrast: 0, saturation: 0, warmth: 0, vignette: false };
        adjustPreview = "";
        _preview();
    }
    Timer {
        id: _adjDebounce
        interval: 200
        onTriggered: {
            if (!root.adjustActive || !root.canAdjust) { root.adjustPreview = ""; root._preview(); return; }
            var src = root.selected.large || root.selected.path || root.selected.thumb || "";
            if (("" + src).length === 0) return;
            adjProc.running = false;
            adjProc.command = ["ryowalls", "adjust", src, root._adjSlot(root.adjustRev + 1), "--size", "1100"].concat(root._adjFlags());
            adjProc.running = true;
        }
    }
    Process {
        id: adjProc
        onExited: code => {
            if (code !== 0) return;
            root.adjustRev++;
            root.adjustPreview = "file://" + root._adjSlot(root.adjustRev);
            root._previewFrom(root._adjSlot(root.adjustRev));
        }
    }

    // ---- user-added libraries (any GitHub repo of wallpapers) ---------------
    // Ryoku hosts nothing: the user points ryowalls at repos at their discretion.
    property string libraryRepo: ""
    property string libraryBranch: ""
    property string libraryPath: ""
    property string libraryName: ""
    property string libraryType: "all"      // all | images | live
    readonly property var libraries: cfg.libraries || []

    function setLibrary(lib) {
        if (!lib || !lib.repo) return;
        source = "lib";
        libraryName = lib.name || lib.repo;
        libraryRepo = lib.repo;
        libraryBranch = lib.branch || "";
        libraryPath = lib.path || "";
        libraryType = "all";
        results = []; selected = null; error = ""; page = 1; query = "";
        reload();
    }
    function setLibraryType(t) {
        if (libraryType === t) return;
        libraryType = t;
        if (source === "lib" || source === "local") { page = 1; reload(); }
    }
    // accepts "owner/repo", "owner/repo@branch", "owner/repo/sub/dir", or a github URL.
    function addLibrary(input) {
        var s = ("" + input).trim().replace(/^https?:\/\/github\.com\//, "").replace(/\.git$/, "");
        if (s.length === 0) return;
        var branch = "";
        var at = s.indexOf("@");
        if (at > 0) { branch = s.substring(at + 1); s = s.substring(0, at); }
        var parts = s.split("/").filter(p => p.length > 0);
        if (parts.length < 2) { error = "Use owner/repo"; return; }
        var repo = parts[0] + "/" + parts[1];
        var lib = { name: parts[1], repo: repo, branch: branch, path: parts.slice(2).join("/") };
        var libs = (cfg.libraries || []).slice();
        for (var i = 0; i < libs.length; i++)
            if (libs[i].repo === repo) { setLibrary(libs[i]); return; }
        libs.push(lib);
        cfg.libraries = libs;
        saveSettings();
        setLibrary(lib);
    }
    function removeLibrary(repo) {
        cfg.libraries = (cfg.libraries || []).filter(l => l.repo !== repo);
        saveSettings();
        if (source === "lib" && libraryRepo === repo) setSource("wallhaven");
    }

    // switch library and load its first page. live has no query/pages.
    function setSource(s) {
        if (source === s) return;
        source = s;
        if (s === "local") libraryType = "all";
        results = []; selected = null; error = ""; page = 1; localSelection = [];
        reload();
    }
    function reload() {
        if (source === "live") loadLive();
        else if (source === "local") loadLocal();
        else search(query, 1, source === "wallhaven" ? topRange : "");
    }
    function loadLive() {
        searching = true; error = "";
        searchProc.running = false;
        searchProc.command = ["ryowalls", "live-list"];
        searchProc.running = true;
    }
    // copy a user's own mp4 into livewalls, then refresh the grid.
    function importLive(url) {
        importProc.command = ["ryowalls", "live-import", ("" + url).replace(/^file:\/\//, "")];
        importProc.running = true;
    }

    // ---- local wallpapers: browse and prune what is already on disk ---------
    function loadLocal() {
        searching = true; error = "";
        var args = ["ryowalls", "local-list", "--type", libraryType];
        if (query.length > 0) args = args.concat(["--query", query]);
        searchProc.running = false;
        searchProc.command = args;
        searchProc.running = true;
    }
    property var localSelection: []
    function localSelected(item) { return !!item && root.localSelection.indexOf(item.id) >= 0; }
    function toggleLocalSelect(item) {
        if (!item) return;
        var s = root.localSelection.slice();
        var i = s.indexOf(item.id);
        if (i >= 0) s.splice(i, 1); else s.push(item.id);
        root.localSelection = s;
    }
    function selectAllLocal() { root.localSelection = root.results.map(r => r.id); }
    function clearLocalSelection() { root.localSelection = []; }
    function removeLocalSelected() {
        if (root.localSelection.length === 0) return;
        rmProc.command = ["ryowalls", "local-remove"].concat(root.localSelection);
        rmProc.running = true;
    }
    Process {
        id: rmProc
        onExited: { root.localSelection = []; if (root.source === "local") root.loadLocal(); }
    }

    // safe palette read: index into the 16 colours with a fallback.
    function col(i, fallback) {
        return (palette && palette.length > i && palette[i]) ? palette[i] : (fallback || "#000000");
    }

    // ---- tune: the look. Persisted to ryowalls.json, mirrored to the state file
    // ryoku-shell reads, so preview, Set Wallpaper and Super+W cycles match.
    // Defaults pass through to the wallust config until you change something.
    readonly property bool paletteChanged: cfg.tone !== "dark" || cfg.character !== "natural"
    readonly property string paletteName: {
        var fam;
        if (cfg.tone === "light")
            fam = cfg.character === "pastel" ? "softlight"
                : cfg.character === "natural" ? "light" : "saliencelight";
        else
            fam = cfg.character === "pastel" ? "softdark"
                : cfg.character === "vivid" ? "harddark"
                : cfg.character === "salient" ? "saliencedark" : "dark";
        return fam + "16";
    }
    readonly property var tuneFlags: {
        var f = [];
        if (root.paletteChanged) f = f.concat(["--palette", root.paletteName]);
        if (cfg.colorspace.length) f = f.concat(["--colorspace", cfg.colorspace]);
        if (cfg.backend.length) f = f.concat(["--backend", cfg.backend]);
        if (cfg.saturation > 0) f = f.concat(["--saturation", "" + cfg.saturation]);
        if (cfg.threshold > 0) f = f.concat(["--threshold", "" + cfg.threshold]);
        if (cfg.contrast) f.push("--contrast");
        return f;
    }
    readonly property bool tuned: tuneFlags.length > 0

    onTuneFlagsChanged: _retune.restart()
    Timer { id: _retune; interval: 220; onTriggered: root._preview() }

    function resetTune() {
        cfg.tone = "dark"; cfg.character = "natural";
        cfg.colorspace = ""; cfg.backend = ""; cfg.saturation = 0; cfg.threshold = 0; cfg.contrast = false;
        cfgFile.writeAdapter();
    }
    function _writeTuneFor(image) {
        tuneAdapter.image = image;
        tuneAdapter.palette = root.paletteChanged ? root.paletteName : "";
        tuneAdapter.colorspace = cfg.colorspace;
        tuneAdapter.backend = cfg.backend;
        tuneAdapter.saturation = cfg.saturation;
        tuneAdapter.threshold = cfg.threshold;
        tuneAdapter.contrast = cfg.contrast;
        tuneAdapter.frame = cfg.frame;
        tuneState.writeAdapter();
    }

    // ---- search -------------------------------------------------------------
    function search(q, p, range) {
        query = (q || "").trim();
        page = Math.max(1, p || 1);
        topRange = range || "";
        error = "";
        _searchErr = "";
        searching = true;
        if (source === "local") { loadLocal(); return; }
        var args;
        if (source === "moewalls") {
            args = ["moewalls-search", "--page", "" + page, "--json"];
            if (query.length > 0) args.push("--query", query);
        } else if (source === "motionbgs") {
            args = ["motionbgs-search", "--page", "" + page, "--json"];
            if (query.length > 0) args.push("--query", query);
        } else if (source === "ryoku") {
            args = ["extras-search", "--json"];
            if (query.length > 0) args.push("--query", query);
        } else if (source === "lib") {
            args = ["library-list", libraryRepo, "--page", "" + page, "--type", libraryType, "--json"];
            if (libraryBranch.length > 0) args.push("--branch", libraryBranch);
            if (libraryPath.length > 0) args.push("--path", libraryPath);
            if (query.length > 0) args.push("--query", query);
        } else {
            args = ["search", "--query", query, "--page", "" + page, "--json"];
            if (topRange.length > 0) args.push("--top-range", topRange);
            if (ratios.length > 0) args.push("--ratios", ratios);
            if (cfg.nsfw && apiKey.length > 0) args.push("--purity", "111");
        }
        searchProc.running = false;
        searchProc.command = cmd(args);
        searchProc.running = true;
    }
    function searchLatest(q) { search(q, 1, ""); }
    function searchTop(range) { search(query, 1, range); }
    function nextPage() { if (!searching) search(query, page + 1, topRange); }
    function prevPage() { if (page > 1 && !searching) search(query, page - 1, topRange); }
    function setRatios(r) { ratios = r || ""; search(query, 1, topRange); }

    function _parseResults(text) {
        var rows = [];
        var lines = text.split("\n").filter(l => l.trim().length > 0);
        try {
            for (const l of lines)
                rows.push(JSON.parse(l));
            results = rows;
            error = "";
        } catch (e) {
            error = "Could not read results";
            results = [];
        }
        // keep a live preview: follow the search with the first result.
        if (results.length > 0)
            select(results[0]);
        else
            selected = null;
    }

    // ---- selection + palette ------------------------------------------------
    function select(item) {
        if (!item)
            return;
        selected = item;
        adjust = { brightness: 0, contrast: 0, saturation: 0, warmth: 0, vignette: false };
        adjustPreview = "";
        _preview();
    }
    function _preview() {
        if (!selected)
            return;
        var src = (adjustActive && adjustPreview.length > 0) ? _adjSlot(adjustRev) : (selected.thumb || "");
        _previewFrom(src);
    }
    // extract the wallust scheme from a specific image (the thumb, or the graded
    // preview when an adjustment is live) without touching the running desktop.
    function _previewFrom(src) {
        palette = [];
        if (!src || ("" + src).length === 0) { paletteLoading = false; return; }
        paletteLoading = true;
        palProc.running = false;
        palProc.command = cmd(["palette", src].concat(root.tuneFlags));
        palProc.running = true;
    }

    // ---- apply (download full res, then set + theme through the shell) -------
    // wallhaven downloads the image, moewalls downloads the webm into livewalls,
    // live is already local so it sets straight away. all three land in the same
    // set path so the daemon (awww or mpvpaper) fans out on the file type.
    function apply(item) {
        var it = item || selected;
        if (!it || busy)
            return;
        if (source === "live") { setPath(it.video); return; }
        if (source === "local") { setPath(it.video && ("" + it.video).length > 0 ? it.video : it.path); return; }
        busy = true;
        status = "Downloading";
        _dlPath = "";
        _setAfter = true;
        dlProc.command = _downloadCmd(it);
        dlProc.running = true;
    }
    function setPath(path) {
        if (busy) return;
        busy = true;
        _commitSet(path);
    }
    function isVideoPath(p) { return /\.(mp4|webm|mkv|mov)$/i.test("" + p); }
    function _editedPath(path) {
        var slash = ("" + path).lastIndexOf("/");
        var dot = ("" + path).lastIndexOf(".");
        return dot > slash ? path.slice(0, dot) + ".edit" + path.slice(dot) : path + ".edit";
    }
    // set a wallpaper, first baking the image grade into a sibling .edit file when
    // an adjustment is live, so the desktop matches the preview. videos are never
    // graded, so they set straight through.
    function _commitSet(path) {
        if (adjustActive && !isVideoPath(path)) {
            status = "Applying edits";
            bakeProc._orig = path;
            bakeProc._out = _editedPath(path);
            bakeProc.command = ["ryowalls", "adjust", path, bakeProc._out].concat(_adjFlags());
            bakeProc.running = true;
            return;
        }
        _writeTuneFor(path);
        status = "Setting wallpaper";
        setProc.command = ["ryoku-shell", "wallpaper", "set", path];
        setProc.running = true;
    }
    Process {
        id: bakeProc
        property string _out: ""
        property string _orig: ""
        onExited: code => {
            var p = (code === 0) ? bakeProc._out : bakeProc._orig;
            root._writeTuneFor(p);
            root.status = "Setting wallpaper";
            setProc.command = ["ryoku-shell", "wallpaper", "set", p];
            setProc.running = true;
        }
    }
    function download(item) {
        var it = item || selected;
        if (!it || busy)
            return;
        busy = true;
        status = "Downloading";
        _dlPath = "";
        _setAfter = false;
        dlProc.command = cmd(["download", it.id, it.path]);
        dlProc.running = true;
    }
    property bool _setAfter: true
    function openWeb(item) {
        var it = item || selected;
        var url = it ? (it.wallhaven_url || it.moewalls_url) : "";
        if (url)
            Qt.openUrlExternally(url);
    }

    function saveSettings() { cfgFile.writeAdapter(); }

    // frame scrubbing for a live wallpaper: persist the second, then re-theme off
    // the new frame. repaint re-extracts + re-runs wallust without restarting
    // mpvpaper, so scrubbing stays smooth. debounced since the slider fires often.
    function retuneFrame(sec) {
        cfg.frame = sec;
        cfgFile.writeAdapter();
        frameDebounce.restart();
    }
    Timer {
        id: frameDebounce
        interval: 250
        onTriggered: {
            if (root.selected && root.selected.video) root._writeTuneFor(root.selected.video);
            repaintProc.running = false;
            repaintProc.command = ["ryoku-shell", "wallpaper", "repaint"];
            repaintProc.running = true;
        }
    }
    Process { id: repaintProc }

    // live motion: persist the fps cap / fit, then relaunch mpvpaper with fresh
    // opts if a live wallpaper is showing. debounced so dragging fps doesn't
    // thrash the daemon.
    function setLiveFps(v) { cfg.liveFps = Math.round(v); cfgFile.writeAdapter(); liveReload.restart(); }
    function setLiveFit(v) { cfg.liveFit = v; cfgFile.writeAdapter(); liveReload.restart(); }
    Timer {
        id: liveReload
        interval: 300
        onTriggered: {
            reloadProc.running = false;
            reloadProc.command = ["ryoku-shell", "wallpaper", "live-reload"];
            reloadProc.running = true;
        }
    }
    Process { id: reloadProc }

    // status lines clear themselves so the bar never carries a stale message.
    onStatusChanged: if (status.length > 0) statusClear.restart()
    Timer { id: statusClear; interval: 4000; onTriggered: root.status = "" }

    Process {
        id: searchProc
        stdout: StdioCollector { onStreamFinished: root._parseResults(text) }
        stderr: StdioCollector { onStreamFinished: root._searchErr = text }
        onExited: code => {
            root.searching = false;
            if (code !== 0) {
                root.error = root._searchErr.trim() || "Search failed";
                root.results = [];
            }
        }
    }

    Process {
        id: palProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.palette = text.trim().split("\n").filter(l => l.trim().length > 0);
                root.paletteLoading = false;
            }
        }
        onExited: code => { if (code !== 0) { root.palette = []; root.paletteLoading = false; } }
    }

    Process {
        id: dlProc
        stdout: StdioCollector { onStreamFinished: root._dlPath = (text.trim().split("\n").pop() || "") }
        onExited: code => {
            if (code === 0 && root._dlPath.length > 0 && root._enhanceAfterDl) {
                root._enhanceAfterDl = false;
                root.busy = false;
                root._startEnhance(root._dlPath);
            } else if (code === 0 && root._dlPath.length > 0 && root._setAfter) {
                root._commitSet(root._dlPath);
            } else {
                root.busy = false;
                root.status = code === 0 ? "Saved to Pictures" : "Download failed";
                root._setAfter = true;
                root._enhanceAfterDl = false;
            }
        }
    }

    Process {
        id: setProc
        onExited: code => {
            root.busy = false;
            root.status = code === 0 ? "Wallpaper set" : "Could not set wallpaper";
        }
    }

    Process {
        id: importProc
        onExited: code => {
            if (code === 0 && root.source === "live") root.loadLive();
            else if (code !== 0) root.status = "Import failed";
        }
    }

    FileView {
        id: cfgFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/ryowalls.json"
        watchChanges: true
        printErrors: false
        onLoadFailed: cfgFile.writeAdapter()
        onLoaded: {}
        JsonAdapter {
            id: cfg
            property string apiKey: ""
            property bool nsfw: false
            property bool fitScreen: false
            property string tone: "dark"
            property string character: "natural"
            property string colorspace: ""
            property string backend: ""
            property int saturation: 0
            property int threshold: 0
            property bool contrast: false
            // live wallpapers: which second of the video wallust samples, and
            // whether mpvpaper pauses while a window covers it.
            property real frame: 1
            property bool pauseWhenCovered: false
            // live wallpaper motion: max fps (15-60; 60 plays at the clip's own
            // rate) and screen mapping (fill = cover, fit = letterbox).
            property int liveFps: 60
            property string liveFit: "fill"
            // user-added wallpaper libraries: [{name, repo, branch, path}]
            property var libraries: []
        }
    }

    // mirror of the resolved look for ryoku-shell's theming to read on every set,
    // so the applied desktop matches the preview. write-only from here.
    FileView {
        id: tuneState
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku-wallust.json"
        printErrors: false
        JsonAdapter {
            id: tuneAdapter
            property string image: ""
            property string palette: ""
            property string colorspace: ""
            property string backend: ""
            property int saturation: 0
            property int threshold: 0
            property bool contrast: false
            property real frame: 1
        }
    }
    readonly property var settings: cfg
}
