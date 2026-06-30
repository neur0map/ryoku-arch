pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The app's state: host readiness, the local VM library, the quickget OS
// catalogue, and the lifecycle pipeline, all driven through the `ryovm` engine.
// One quickemu .conf per VM, so the library is naturally multi-VM.
Singleton {
    id: root

    // ---- host readiness -----------------------------------------------------
    property var caps: ({})
    readonly property bool capsLoaded: caps.ready !== undefined
    readonly property bool ready: caps.ready === true
    readonly property bool kvmOff: capsLoaded && caps.kvm === false

    // ---- library ------------------------------------------------------------
    property var vms: []
    property bool vmsLoading
    property string selectedName: ""
    property var detail: null            // full `get` of the selected VM
    readonly property var selected: {
        for (var i = 0; i < vms.length; i++)
            if (vms[i].name === selectedName)
                return vms[i];
        return null;
    }

    // ---- catalogue (browse + create) ----------------------------------------
    property var osList: []              // grouped by OS, each with releases/editions
    property bool catalogLoading
    property bool catalogReady           // the on-disk catalogue cache exists (icons resolvable)
    property string catalogError
    property var selectedOs: null        // an osList entry, in Catalog mode
    property var paths: ({})             // engine paths + provider, for Settings
    // OSes that actually have brand art upstream (the rest get a monogram). The
    // prefetch verb warms every logo in parallel and returns this set, so the
    // Catalog can float logo-bearing systems to a "Popular" section.
    property var iconSet: ({})
    function hasArt(slug) { return slug && iconSet[slug] === true; }

    // ---- OS logo cache (real SVG brand marks, cached to disk by the engine) --
    // memoised slug -> local file path (or "" when an OS has no logo), so a card
    // resolves each logo once instead of per paint/recycle. iconRev forces the
    // bindings that read iconCache to re-evaluate when an entry lands.
    property var iconCache: ({})
    property var iconPending: ({})
    property int iconRev: 0
    function iconFor(slug) { void iconRev; return (slug && iconCache[slug] !== undefined) ? iconCache[slug] : ""; }
    function beginIcon(slug) {
        if (!slug || !catalogReady || iconCache[slug] !== undefined || iconPending[slug])
            return false;
        iconPending[slug] = true;
        return true;
    }
    function setIcon(slug, path) { var c = iconCache; c[slug] = path; iconCache = c; iconPending[slug] = false; iconRev++; }

    // ---- pipeline -----------------------------------------------------------
    property bool busy
    property string status

    // ---- in-app download (the fast Go fetcher, streamed live) ---------------
    property bool downloading
    property string dlName               // VM being built
    property string dlPhase              // resolve | download | config
    property real dlProgress             // 0..1 (0 when indeterminate)
    property real dlBps                  // bytes/sec, for a live rate
    property bool dlIndeterminate        // fallback (quickget) path: no byte total
    property string dlLog                // last fallback log line

    // ---- settings (persisted to ~/.config/ryoku/ryovm.json) -----------------
    readonly property var settings: cfg

    function refresh() {
        capsProc.running = true;
        listProc.running = true;
    }

    Component.onCompleted: {
        root.refresh();
        // warm the catalogue cache so Library logos resolve even before the user
        // opens Catalog (cached to disk by the engine, so it's a no-op after the
        // first run), and read the engine paths for the Settings panel.
        root.loadCatalog(false);
        pathsProc.running = true;
    }

    // status lines clear themselves so the bar never carries a stale message.
    onStatusChanged: if (status.length > 0) statusClear.restart()
    Timer { id: statusClear; interval: 4500; onTriggered: root.status = "" }

    // ---- library ------------------------------------------------------------
    function select(name) {
        selectedName = name;
        detail = null;
        if (name.length > 0) {
            getProc.command = ["ryovm", "get", name];
            getProc.running = true;
        }
    }
    function reselect() { if (selectedName.length > 0) select(selectedName); }

    function launch(name, mode) {
        if (busy)
            return;
        busy = true;
        status = "Starting " + name;
        runProc.exec(["ryovm", "launch", name, mode || "window"]);
    }
    function stop(name) {
        if (busy)
            return;
        busy = true;
        status = "Stopping " + name;
        runProc.exec(["ryovm", "stop", name]);
    }
    function openConsole(name) { runProc.exec(["ryovm", "console", name]); }
    function deleteVm(name) {
        if (busy)
            return;
        busy = true;
        status = "Deleting " + name;
        runProc.exec(["ryovm", "delete", name]);
    }
    function setConfig(name, key, value) { runProc.exec(["ryovm", "config", name, key, "" + value]); }
    function snapshot(name, sub, tag) {
        busy = true;
        status = sub === "create" ? "Saving snapshot" : sub === "restore" ? "Restoring" : "Working";
        runProc.exec(["ryovm", "snapshot", name, sub].concat(tag ? [tag] : []));
    }
    function openFolder(name) {
        folderProc.command = ["ryovm", "folder"].concat(name ? [name] : []);
        folderProc.running = true;
    }
    function openSsh(name) {
        sshProc.command = ["ryovm", "ssh", name];
        sshProc.running = true;
    }

    // ---- catalogue ----------------------------------------------------------
    function loadCatalog(force) {
        if (osList.length > 0 && !force)
            return;
        catalogLoading = true;
        catalogError = "";
        catProc.command = force ? ["ryovm", "catalog", "--refresh"] : ["ryovm", "catalog"];
        catProc.running = true;
    }
    function selectOs(entry) { selectedOs = entry; }

    // create downloads the image in-app with a live bar (the Go fetcher streams
    // JSON), so progress shows in the window and Cancel actually stops it -- no
    // detached terminal that can't report being closed.
    function createVm(os, release, edition) {
        if (downloading)
            return;
        downloading = true;
        dlName = os + "-" + release + (edition ? "-" + edition : "");
        dlPhase = "resolve";
        dlProgress = 0;
        dlBps = 0;
        dlIndeterminate = false;
        dlLog = "";
        status = "Downloading " + os;
        createProc.command = ["ryovm", "create", os, release].concat(edition ? [edition] : []);
        createProc.running = true;
    }
    // setting running=false sends SIGTERM, which the engine traps to kill the
    // fetcher and wipe the half-image, then reports phase:cancelled.
    function cancelCreate() { if (downloading) createProc.running = false; }
    function _onCreateLine(line) {
        var s = ("" + line).trim();
        if (s.length === 0)
            return;
        var o;
        try { o = JSON.parse(s); } catch (e) { return; }
        if (o.event !== undefined) {              // a ryovm-fetch progress object
            if (o.total > 0) { dlProgress = Math.max(0, Math.min(1, o.recv / o.total)); dlIndeterminate = false; }
            if (o.bps !== undefined) dlBps = o.bps;
            return;
        }
        switch (o.phase) {
        case "resolve": dlPhase = "resolve"; break;
        case "config": dlPhase = "config"; dlProgress = 1; break;
        case "download":
            dlPhase = "download";
            if (o.name) dlName = o.name;
            if (o.fallback === true) dlIndeterminate = true;
            break;
        case "log": dlLog = o.line || ""; break;
        case "done":
            status = (o.name || dlName) + " is ready";
            if (o.name) selectedName = o.name;
            break;
        case "cancelled": status = "Download cancelled"; break;
        case "error": status = o.message || "Download failed"; break;
        }
    }
    // a VM from any local ISO, off-catalogue (full QEMU reach). os is the logo
    // slug (defaults to the guest type, so windows/macos/android still get marks).
    function importVm(name, iso, guest, os) {
        busy = true;
        status = "Creating " + name;
        runProc.exec(["ryovm", "import", name, iso, guest || "linux", os || guest || "linux"]);
    }

    function _group(rows) {
        var map = {};
        var order = [];
        for (var i = 0; i < rows.length; i++) {
            var r = rows[i];
            var key = r.OS;
            if (!map[key]) {
                map[key] = { os: key, name: r["Display Name"] || key, png: r.PNG || "", svg: r.SVG || "", rels: {}, relOrder: [] };
                order.push(key);
            }
            var g = map[key];
            if (!g.rels[r.Release]) { g.rels[r.Release] = []; g.relOrder.push(r.Release); }
            if (r.Option && r.Option.length > 0 && g.rels[r.Release].indexOf(r.Option) < 0)
                g.rels[r.Release].push(r.Option);
        }
        var out = [];
        for (var j = 0; j < order.length; j++) {
            var e = map[order[j]];
            out.push({ os: e.os, name: e.name, png: e.png, svg: e.svg, releases: e.relOrder, editions: e.rels });
        }
        out.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
        return out;
    }

    // ---- processes ----------------------------------------------------------
    Process {
        id: capsProc
        command: ["ryovm", "caps"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.caps = JSON.parse(this.text); }
                catch (e) { console.log("ryovm: caps parse failed: " + e); }
            }
        }
    }
    Process {
        id: listProc
        command: ["ryovm", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.vmsLoading = false;
                try {
                    var arr = JSON.parse(this.text);
                    root.vms = arr;
                    if (root.selectedName.length === 0 && arr.length > 0)
                        root.select(arr[0].name);
                    else if (root.selectedName.length > 0)
                        root.reselect();
                } catch (e) { root.vms = []; }
            }
        }
        onStarted: root.vmsLoading = true
    }
    Process {
        id: getProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.detail = JSON.parse(this.text); }
                catch (e) { root.detail = null; }
            }
        }
    }
    Process {
        id: catProc
        stdout: StdioCollector { id: catOut }
        stderr: StdioCollector { id: catErr }
        onExited: (code) => {
            root.catalogLoading = false;
            if (code === 0) {
                // the on-disk cache now exists: Library logos can resolve, and
                // we can warm every catalogue logo in parallel + learn which OSes
                // have art (for the Popular sort).
                root.catalogReady = true;
                prefetchProc.running = true;
                try { root.osList = root._group(JSON.parse(catOut.text)); root.catalogError = ""; return; }
                catch (e) { root.catalogError = "Could not read the OS catalogue"; }
            } else {
                root.catalogError = catErr.text.trim() || "Could not fetch the OS catalogue";
            }
        }
    }
    // warm every logo in parallel and learn which OSes have art. Reassign a fresh
    // object so the iconSet bindings (OsGrid's Popular sort) re-evaluate; bump
    // iconRev so cards already showing a monogram pick up a newly cached logo.
    Process {
        id: prefetchProc
        command: ["ryovm", "prefetch"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var map = JSON.parse(this.text);   // { os: "/abs/path", ... }
                    var set = {};
                    var cache = root.iconCache;
                    for (var os in map) {
                        set[os] = true;
                        cache[os] = map[os];           // seed the path cache directly
                    }
                    root.iconSet = set;
                    root.iconCache = cache;            // reassign so iconFor bindings re-evaluate
                    root.iconRev++;                    // warm tiles render the local file at once
                } catch (e) {}
            }
        }
    }
    Process {
        id: pathsProc
        command: ["ryovm", "paths"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.paths = JSON.parse(this.text); } catch (e) {} }
        }
    }
    // in-app create: streams JSON (resolve/download/config/done) line by line,
    // updating the live bar; on exit, drops the download UI and reloads.
    Process {
        id: createProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root._onCreateLine(line)
        }
        onExited: {
            root.downloading = false;
            root.dlPhase = "";
            root.refresh();
        }
    }
    // shared lifecycle runner: any verb that mutates, then reloads the library.
    Process {
        id: runProc
        property string errText: ""
        function exec(cmd) { errText = ""; command = cmd; running = true; }
        stderr: StdioCollector { onStreamFinished: runProc.errText = this.text }
        onExited: (code) => {
            root.busy = false;
            if (code !== 0 && runProc.errText.trim().length > 0)
                root.status = runProc.errText.trim().split("\n")[0];
            root.refresh();
        }
    }
    Process {
        id: folderProc
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim();
                if (p.length > 0)
                    Quickshell.execDetached(["xdg-open", p]);
            }
        }
    }
    Process {
        id: sshProc
        stdout: StdioCollector {
            onStreamFinished: {
                var c = this.text.trim();
                if (c.length > 0)
                    Quickshell.execDetached(["kitty", "--class", "ryovm-ssh", "-e", "sh", "-c", c]);
            }
        }
    }
    // keep Launch/Stop in step while the window is open.
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: { listProc.running = true; if (root.selectedName.length > 0) root.reselect(); }
    }

    FileView {
        id: cfgFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/ryovm.json"
        watchChanges: true
        printErrors: false
        onLoadFailed: cfgFile.writeAdapter()
        JsonAdapter {
            id: cfg
            property int defaultCores: 4
            property int defaultRam: 8
            property int defaultDisk: 64
            property string defaultDisplay: "window"
        }
    }
    function saveSettings() { cfgFile.writeAdapter(); }
}
