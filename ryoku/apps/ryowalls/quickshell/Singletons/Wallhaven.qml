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

    // upscaling is offered only when the machine can do it (a Vulkan upscaler is
    // installed); the toggle then injects RYOWALLS_UPSCALE so downloads enhance.
    property bool upscaleImage: false
    Process {
        id: capsProc
        running: true
        command: ["ryowalls", "caps"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.upscaleImage = !!JSON.parse(text).upscaleImage; } catch (e) {} }
        }
    }

    function cmd(args) {
        var pre = keyPrefix.slice();
        if (cfg.upscale && root.upscaleImage) {
            if (pre.length === 0) pre = ["env"];
            pre = pre.concat(["RYOWALLS_UPSCALE=1"]);
        }
        return pre.concat(["ryowalls"]).concat(args);
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
        if (source === "lib") { page = 1; reload(); }
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
        results = []; selected = null; error = ""; page = 1;
        reload();
    }
    function reload() {
        if (source === "live") loadLive();
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
        _preview();
    }
    function _preview() {
        if (!selected)
            return;
        palette = [];
        // local live videos ship no poster; the daemon derives the real palette
        // from a frame on set, so skip the preview fetch here.
        if (!selected.thumb || selected.thumb.length === 0) {
            paletteLoading = false;
            return;
        }
        paletteLoading = true;
        palProc.running = false;
        palProc.command = cmd(["palette", selected.thumb].concat(root.tuneFlags));
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
        busy = true;
        status = "Downloading";
        _dlPath = "";
        _setAfter = true;
        if (source === "moewalls")
            dlProc.command = cmd(["moewalls-download", it.id, it.dl]);
        else if (source === "motionbgs")
            dlProc.command = cmd(["motionbgs-download", it.id, it.dl]);
        else if (source === "ryoku")
            dlProc.command = cmd(["extras-download", it.id, it.dl]);
        else if (source === "lib")
            dlProc.command = cmd(["library-download", it.id, it.dl]);
        else
            dlProc.command = cmd(["download", it.id, it.path]);
        dlProc.running = true;
    }
    function setPath(path) {
        if (busy) return;
        busy = true;
        _writeTuneFor(path);
        status = "Setting wallpaper";
        setProc.command = ["ryoku-shell", "wallpaper", "set", path];
        setProc.running = true;
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
            if (code === 0 && root._dlPath.length > 0 && root._setAfter) {
                root._writeTuneFor(root._dlPath);
                root.status = "Setting wallpaper";
                setProc.command = ["ryoku-shell", "wallpaper", "set", root._dlPath];
                setProc.running = true;
            } else {
                root.busy = false;
                root.status = code === 0 ? "Saved to Pictures" : "Download failed";
                root._setAfter = true;
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
            // enhance saved wallpapers with a Vulkan upscaler (sharper, but slower + bigger).
            property bool upscale: false
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
