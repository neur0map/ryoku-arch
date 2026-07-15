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
    property string pendingSelect: ""    // select this VM after the next reload (post-rename)
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
    // the sticky fault surface: errors stay up until dismissed or the next
    // verb succeeds — a fault that clears itself after 4.5s never happened.
    property string fault: ""            // first line, for the fault row
    property string faultDetail: ""      // full engine stderr, un-truncated
    function raiseFault(text) {
        var t = ("" + text).trim();
        if (t.length === 0)
            return;
        fault = t.split("\n")[0];
        faultDetail = t;
        status = "";
    }
    function clearFault() { fault = ""; faultDetail = ""; }
    function info(msg) { status = msg; }

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

    // info lines clear themselves — but not while an operation runs, so a long
    // seal/restore keeps "Sealing alpine" pinned instead of decaying to mystery.
    onStatusChanged: if (status.length > 0 && !busy) statusClear.restart()
    onBusyChanged: if (!busy && status.length > 0) statusClear.restart()
    Timer { id: statusClear; interval: 4500; onTriggered: root.status = "" }
    // bytes to a short human size ("1.9 GB", "880 MB"), for disk footprints.
    function human(b) {
        b = +b || 0;
        if (b <= 0)
            return "0";
        var u = ["B", "KB", "MB", "GB", "TB"], i = 0;
        while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
        return (b < 10 && i > 0 ? b.toFixed(1) : Math.round(b)) + " " + u[i];
    }

    // ---- library ------------------------------------------------------------
    function select(name) {
        // re-selecting the same machine (the 5s poll) keeps the stale detail
        // on screen until the fresh one lands — nulling it blinked every
        // det-gated section once a poll.
        if (name !== selectedName || detail === null)
            detail = null;
        selectedName = name;
        if (name.length > 0) {
            getProc.command = ["ryovm", "get", name];
            getProc.running = true;
            root.loadUsb(name);
        }
    }
    function reselect() { if (selectedName.length > 0) select(selectedName); }

    function launch(name, mode, disposable) {
        if (busy)
            return;
        busy = true;
        status = disposable ? "Starting " + name + " (disposable)" : "Starting " + name;
        var cmd = ["ryovm", "launch", name, mode || "window"];
        if (disposable === true)
            cmd.push("--disposable");
        runProc.exec(cmd);
    }
    // seal = the golden-state anchor: one reserved snapshot + the conf stamp.
    function seal(name) {
        if (busy)
            return;
        busy = true;
        status = "Sealing " + name;
        runProc.exec(["ryovm", "seal", name]);
    }
    function restoreSeal(name) {
        if (busy)
            return;
        busy = true;
        status = "Restoring the seal on " + name;
        runProc.exec(["ryovm", "restore-seal", name]);
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
        if (busy)
            return;
        busy = true;
        status = ({ "create": "Saving snapshot", "restore": "Restoring snapshot", "delete": "Deleting snapshot" })[sub] || "Working";
        runProc.exec(["ryovm", "snapshot", name, sub].concat(tag ? [tag] : []));
    }
    function openFolder(name) {
        folderProc.command = ["ryovm", "folder"].concat(name ? [name] : []);
        folderProc.running = true;
    }
    function openSsh(name) {
        sshProc.vmName = name;
        sshProc.command = ["ryovm", "ssh", name];
        sshProc.running = true;
    }
    // copy the ready-to-paste ssh command for a running VM.
    function copySsh(name) {
        copyProc.command = ["sh", "-c", "ryovm ssh \"$1\" | tr -d '\\n' | wl-copy", "--", name];
        copyProc.running = true;
    }
    // host USB devices + this VM's assignments (usb_devices in its conf).
    property var usb: []
    function loadUsb(name) {
        if (!name || name.length === 0) { usb = []; return; }
        usbProc.command = ["ryovm", "usb", "list", name];
        usbProc.running = true;
    }
    function setUsb(name, id, on) {
        usbSetProc.command = ["ryovm", "usb", "set", name, id, on ? "on" : "off"];
        usbSetProc.running = true;
    }
    // rename repoints the conf, dir and relative paths, then reselects the new
    // name once the reloaded list carries it (via pendingSelect).
    function renameVm(name, next) {
        if (busy || !next || next === name)
            return;
        busy = true;
        status = "Renaming to " + next;
        pendingSelect = next;
        runProc.exec(["ryovm", "rename", name, next]);
    }
    function resizeDisk(name, size) {
        if (busy)
            return;
        busy = true;
        status = "Resizing " + name + " disk";
        runProc.exec(["ryovm", "resize", name, "" + size]);
    }
    // reclaim frees the disk image (and re-installable media) but keeps the
    // machine's config, so it can be reinstalled later.
    function reclaimDisk(name) {
        if (busy)
            return;
        busy = true;
        status = "Reclaiming " + name + " disk";
        runProc.exec(["ryovm", "delete", name, "--disk-only"]);
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

    // ---- instant (prebuilt cloud image + ryoku burn account) ----------------
    property var cloudList: []
    property bool cloudLoading
    function loadCloud() {
        if (cloudList.length > 0) return;
        cloudLoading = true;
        cloudProc.running = true;
    }
    // instant reuses the create streaming pipeline (same download/config/done
    // JSON), so the download bar and "created" hand-off work unchanged.
    function instant(os, name, disposable) {
        if (downloading) return;
        downloading = true;
        dlName = name && name.length > 0 ? name : os + "-instant";
        dlPhase = "resolve"; dlProgress = 0; dlBps = 0; dlIndeterminate = true; dlLog = "";
        status = "Building " + dlName;
        var cmd = ["ryovm", "instant", os];
        if (name && name.length > 0) cmd.push(name);
        if (disposable === true) cmd.push("--disposable");
        createProc.command = cmd;
        createProc.running = true;
    }

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
            if (o.name) {
                selectedName = o.name;
                root.created(o.name);
            }
            break;
        case "cancelled": status = "Download cancelled"; break;
        case "error": root.raiseFault(o.message || "Download failed"); break;
        }
    }
    // a finished create announces itself so the app can bring the new machine
    // on screen instead of stranding the user in the catalogue.
    signal created(string name)
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
        property string last: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.vmsLoading = false;
                // identical payload = nothing happened: keep the same model
                // object so the library never rebuilds (a fresh array every
                // 5s poll tore down every card and replayed their entrance).
                if (this.text === listProc.last)
                    return;
                listProc.last = this.text;
                try {
                    var arr = JSON.parse(this.text);
                    root.vms = arr;
                    if (root.pendingSelect.length > 0) {
                        var want = root.pendingSelect;
                        root.pendingSelect = "";
                        if (arr.some(v => v.name === want)) { root.select(want); return; }
                    }
                    // a deleted machine must not leave a dead selection behind
                    // (the pane would empty out and reselect() would fail 5s
                    // after 5s forever): advance to the next machine.
                    if (root.selectedName.length > 0 && !arr.some(v => v.name === root.selectedName)) {
                        root.select(arr.length > 0 ? arr[0].name : "");
                        return;
                    }
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
        property string last: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text === getProc.last && root.detail !== null)
                    return;
                getProc.last = this.text;
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
        id: cloudProc
        command: ["ryovm", "cloud-catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.cloudLoading = false;
                try { root.cloudList = JSON.parse(this.text); } catch (e) { root.cloudList = []; }
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
    // updating the live bar; on exit, drops the download UI and reloads. A
    // create that dies without ever emitting an error phase (a crashed engine)
    // still surfaces its stderr instead of the pane just vanishing.
    Process {
        id: createProc
        property string errText: ""
        property bool sawTerminalPhase: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var s = ("" + line);
                if (s.indexOf('"done"') >= 0 || s.indexOf('"error"') >= 0 || s.indexOf('"cancelled"') >= 0)
                    createProc.sawTerminalPhase = true;
                root._onCreateLine(line);
            }
        }
        stderr: StdioCollector { onStreamFinished: createProc.errText = this.text }
        onStarted: { errText = ""; sawTerminalPhase = false; }
        onExited: (code) => {
            root.downloading = false;
            root.dlPhase = "";
            if (code !== 0 && !createProc.sawTerminalPhase)
                root.raiseFault("create failed (exit " + code + ")"
                    + (createProc.errText.trim().length > 0 ? "\n" + createProc.errText.trim() : ""));
            root.refresh();
        }
    }
    // shared lifecycle runner: any verb that mutates, then reloads the library.
    // Commands issued while one runs are QUEUED — Process.exec mid-run is a
    // silent no-op, which used to eat rapid stepper clicks and even a Launch.
    // Consecutive writes to the same config key coalesce to the final value.
    Process {
        id: runProc
        property string errText: ""
        property string outText: ""
        property var queue: []
        function exec(cmd) {
            if (running) {
                if (cmd[1] === "config") {
                    for (var i = 0; i < queue.length; i++) {
                        if (queue[i][1] === "config" && queue[i][2] === cmd[2] && queue[i][3] === cmd[3]) {
                            queue[i] = cmd;
                            return;
                        }
                    }
                }
                queue.push(cmd);
                return;
            }
            errText = "";
            outText = "";
            command = cmd;
            running = true;
        }
        stderr: StdioCollector { onStreamFinished: runProc.errText = this.text }
        stdout: StdioCollector { onStreamFinished: runProc.outText = this.text }
        onExited: (code) => {
            if (code !== 0 && runProc.errText.trim().length > 0) {
                root.raiseFault(runProc.errText.trim());
            } else if (code === 0) {
                root.clearFault();
                // the engine speaks in one-line receipts; show them.
                if (runProc.outText.trim().length > 0)
                    root.info(runProc.outText.trim().split("\n")[0]);
            }
            if (runProc.queue.length > 0) {
                var next = runProc.queue.shift();
                runProc.errText = "";
                runProc.outText = "";
                runProc.command = next;
                runProc.running = true;
                return;                      // stay busy until the queue drains
            }
            root.busy = false;
            root.refresh();
        }
    }
    Process {
        id: copyProc
        onExited: (code) => {
            if (code === 0)
                root.info("SSH command copied");
            else
                root.raiseFault("Could not copy the SSH command");
        }
    }
    Process {
        id: usbProc
        property string last: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text === usbProc.last && root.usb.length > 0)
                    return;
                usbProc.last = this.text;
                try { root.usb = JSON.parse(this.text); } catch (e) { root.usb = []; }
            }
        }
    }
    Process {
        id: usbSetProc
        property string errText: ""
        stderr: StdioCollector { onStreamFinished: usbSetProc.errText = this.text }
        onExited: (code) => {
            if (code !== 0 && usbSetProc.errText.trim().length > 0)
                root.raiseFault(usbSetProc.errText.trim());
            root.loadUsb(root.selectedName);
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
        property string vmName: ""
        stdout: StdioCollector {
            onStreamFinished: {
                var c = this.text.trim();
                if (c.length === 0)
                    return;
                // $TERMINAL wins over the shipped kitty. QEMU's user-net accepts
                // the TCP connect while the guest is still booting, so a bare ssh
                // sits in a pitch-black window with no sign of life (and a plain
                // timeout would kill a session the user IS logged into). Narrate
                // instead: say where and as whom, heartbeat while waiting for the
                // real "SSH-" banner — however long the boot takes — then hand
                // over to a plain interactive ssh. Held open on failure so the
                // fix is readable.
                var pm = c.match(/-p (\d+)/);
                var um = c.match(/(\S+)@localhost/);
                var script = [
                    "cmd=$1; port=$2; vm=$3; user=$4",
                    "printf '  %s — ssh to localhost:%s as \\033[1m%s\\033[0m\\n' \"$vm\" \"$port\" \"$user\"",
                    "printf '  wrong account? set it once:  ryovm config %s ryovm_ssh_user <guest user>\\n\\n' \"$vm\"",
                    "hinted=",
                    "until b=$(timeout 3 bash -c \"exec 3<>/dev/tcp/127.0.0.1/$port && head -c4 <&3\" 2>/dev/null); [ \"$b\" = \"SSH-\" ]; do",
                    "  printf '\\r  waiting for the guest to answer — %ss (first boot can take a minute; Ctrl+C aborts) ' \"$SECONDS\"",
                    "  if [ \"$SECONDS\" -ge 20 ] && [ -z \"$hinted\" ]; then hinted=1; printf '\\n  still booting — a fresh cloud image provisions itself on first boot (Arch and Fedora take about a minute). This is normal.\\n'; fi",
                    "  if [ \"$SECONDS\" -ge 180 ]; then printf '\\n\\n  no answer after 3 minutes — the guest may have no SSH server (a live installer ISO never does), or it did not boot.\\n  press Enter to close\\n'; read _; exit 1; fi",
                    "  sleep 1",
                    "done",
                    "printf '\\n  answered — connecting.\\n\\n'",
                    "$cmd",
                    "ec=$?",
                    "if [ $ec -ne 0 ]; then echo; echo \"ssh exited $ec — a password you never set means the guest has no '$user' account: ryovm config $vm ryovm_ssh_user <guest user>\"; echo 'press Enter to close'; read _; fi"
                ].join("\n");
                Quickshell.execDetached(["sh", "-c",
                    "exec \"${TERMINAL:-kitty}\" --class ryovm-ssh -e bash -c \"$1\" ryovm-ssh \"$2\" \"$3\" \"$4\" \"$5\"",
                    "--", script, c, pm ? pm[1] : "", sshProc.vmName, um ? um[1] : ""]);
            }
        }
    }
    // keep Launch/Stop in step while the window is open. caps ride along (five
    // `command -v` checks) so installing the engine lights the app up within 5s
    // instead of after a restart.
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            listProc.running = true;
            capsProc.running = true;
            if (root.selectedName.length > 0)
                root.reselect();
        }
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
