pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Lockscreen management. RyoStore owns discovery and installation; this page
// lists installed qylock themes and keeps activation, live preview, and greeter
// application in Settings.
// page owns the whole content region and draws its own head, states and grid.
// The pick only swaps the look, never the login. Every value is a Token; the
// live skin thumbnail is the one permitted specimen of colour (a lock preview),
// everything else is paper and ink.
Item {
    id: pg

    property var hub
    // A full-bleed page draws the whole content region itself: the shell hides
    // its side panel and global action bar and keeps only the rail.
    readonly property bool fullBleed: true

    // ── state (backend unchanged from the old page) ─────────────────────────
    property var skins: []
    property string active: ""
    property bool loading: true
    property bool loadFailed: false
    property string pendingSlug: ""   // "" idle, else the slug being applied
    property string error: ""

    // the in-session lock preview script; running it locks the screen with the
    // named skin so the user sees the real thing (an action, not a pane).
    readonly property string lockSh: Quickshell.env("HOME") + "/.local/share/quickshell-lockscreen/lock.sh"
    // the rail's search box drives this; skins filter live against it.
    readonly property string query: (pg.hub && pg.hub.query) ? ("" + pg.hub.query) : ""

    // responsive column count, same breakpoints as the old bento grid.
    readonly property int cols: width >= 1320 ? 4 : (width >= 980 ? 3 : (width >= 640 ? 2 : 1))

    // vector glyph paths (viewBox 24), inlined so the page carries no icon
    // dependency of its own.
    readonly property string pLock: "M5 11h14a1 1 0 0 1 1 1v8a1 1 0 0 1 -1 1H5a1 1 0 0 1 -1 -1v-8a1 1 0 0 1 1 -1z M8 11V7.5a4 4 0 0 1 8 0V11 M12 15v2.5"
    readonly property string pPlay: "M8 5.4l11 6.6 -11 6.6z"
    readonly property string pChevron: "M6 9.5l6 6 6 -6"
    readonly property string pRefresh: "M21 12a9 9 0 1 1 -2.6 -6.4 M21 3v5h-5"

    // ── sign-in keyring state (`ryoku keyring status --json`) ───────────────
    // A separate concern from the skin gallery: how the GNOME keyring unlocks at
    // sign-in. Read live so the section reflects PAM/keyring reality, applied
    // through `ryoku keyring set` (which pops polkit for the root PAM half, the
    // same UX as applying a skin reskins the greeter).
    property string kmode: ""
    property bool kdaemon: false
    property string kdefName: ""
    property string kdefFormat: ""      // encrypted · plaintext · absent
    property var knotes: []
    property bool kloading: true
    property string kerror: ""
    property string kpending: ""        // mode being applied, "" idle
    property string kconvertFor: ""     // "" hidden, else the mode awaiting a password
    property bool kconfirmReset: false
    property string kstdin: ""          // password piped to the next set, never argv
    // never-ask needs a blank keyring; an encrypted one blocks the switch until
    // the user converts it or starts fresh.
    readonly property bool kNeverAskBlocked: pg.kdefFormat === "encrypted"

    readonly property string kStatusLine: {
        if (pg.kloading)
            return "Checking\u2026";
        var parts = [];
        if (pg.kdefFormat === "encrypted")
            parts.push("your keyring is password-protected");
        else if (pg.kdefFormat === "plaintext")
            parts.push("your keyring is unlocked, no password");
        else if (pg.kdefFormat === "absent")
            parts.push("no keyring created yet");
        parts.push(pg.kdaemon ? "keyring agent running" : "keyring agent not running");
        return parts.join("  \u00b7  ");
    }

    // ── fingerprint unlock state (fprintd, live) ────────────────────────────
    // The sensor's lock-screen counterpart of the keyring card above: whether
    // the grosshack PAM stack offers a touch-to-unlock at the in-session lock,
    // and enrolment kept inside Settings. Everything reads/writes fprintd as
    // this user; nothing here touches root PAM files.
    property bool ffpEnabled: true            // ~/.config/qylock/fingerprint toggle
    property bool fdaemon: false              // fprintd service reachable
    property bool fready: false               // a device is present
    property string fdevice: ""
    property var ffingers: []                 // enrolled names from fprintd
    property var fnames: ({})                 // fingerprint name -> user label map
    property bool floading: true
    property string ferr: ""
    property string fpending: ""              // "" | "enroll" | "verify" | "del"
    property bool foverlay: false             // the enroll/verify modal
    property string foverlayMode: ""          // "enroll" | "verify"
    property string fstatus: ""               // live copy from fprintd output
    property string fresult: ""               // last finished action result
    property string fterm: ""                 // accumulated terminal output
    property int fprogress: -1                // -1 unknown, else percent
    property string fuser: Quickshell.env("USER") || "traveler"
    // naming flow after successful enroll
    property string fnewFinger: ""            // finger name just enrolled (from fprintd)
    property string fnameDraft: ""            // user's draft name for the new finger
    property bool fnaming: false              // showing the name field after enroll

    readonly property string fStatusLine: {
        if (pg.floading)
            return "Checking\u2026";
        if (!pg.fdaemon)
            return "fingerprint service is not running";
        if (!pg.fready)
            return "no fingerprint device found";
        var parts = [ pg.fdevice || "sensor" ];
        if (pg.ffingers.length === 0)
            parts.push("no fingers enrolled yet");
        else
            parts.push(pg.ffingers.length + (pg.ffingers.length === 1 ? " finger" : " fingers") + " enrolled");
        return parts.join("  \u00b7  ");
    }

    function ffriendly(finger) {
        return pg.fnames[finger] || finger.replace(/-/g, " ");
    }

    property bool settOpen: false

    Component.onCompleted: { pg.reload(); pg.kreload(); pg.freload(); }

    function kreload() {
        kstatusProc.running = true;
    }
    // pick a mode. never-ask on an encrypted keyring reveals the convert/reset
    // row instead of failing; anything else applies straight away.
    function kchoose(mode) {
        if (pg.kpending !== "")
            return;
        pg.kerror = "";
        pg.kconfirmReset = false;
        // Tested before the "already selected" guard on purpose. `keyring init`
        // records never-ask on a box whose keyring is still encrypted, so the
        // mode reads as active while nothing about it has taken effect. Bailing
        // out because the mode already matched made the row that actually fixes
        // it unreachable: the option looked chosen and the prompts kept coming.
        if (mode === "never-ask" && pg.kNeverAskBlocked) {
            pg.kconvertFor = "never-ask";
            return;
        }
        pg.kconvertFor = "";
        if (mode === pg.kmode)
            return;
        pg.kstdin = "";
        pg.kpending = mode;
        ksetProc.command = ["ryoku", "keyring", "set", mode];
        ksetProc.running = true;
    }
    function kconvert(pw) {
        if (pw.length === 0 || pg.kpending !== "")
            return;
        pg.kerror = "";
        pg.kstdin = pw + "\n";
        pg.kpending = pg.kconvertFor;
        ksetProc.command = ["ryoku", "keyring", "set", pg.kconvertFor, "--convert", "--password-stdin"];
        ksetProc.running = true;
    }
    function kreset() {
        if (pg.kpending !== "")
            return;
        pg.kerror = "";
        pg.kstdin = "";
        pg.kpending = pg.kconvertFor;
        ksetProc.command = ["ryoku", "keyring", "set", pg.kconvertFor, "--reset"];
        ksetProc.running = true;
    }

    // ── fingerprint actions ─────────────────────────────────────────────────
    function freload() {
        pg.floading = true;
        freadProc.running = true;
        flistProc.running = true;
        fnamesReadProc.running = true;
    }
    function fparseList(text) {
        var t = text || "";
        var dev = "";
        var m = t.match(/Using\s+device\s+(\S+)/i);
        if (m) dev = m[1];
        var fingers = [];
        var lines = t.split("\n");
        for (var i = 0; i < lines.length; i++) {
            var s = lines[i].trim();
            if (s.indexOf("- #") === 0) {
                var idx = s.indexOf(":", 3);
                if (idx > -1) fingers.push(s.slice(idx + 1).trim());
            }
        }
        pg.fdevice = dev;
        pg.ffingers = fingers;
        pg.fready = t.indexOf("Using device") !== -1 || t.indexOf("Device at") !== -1 || t.indexOf("found ") !== -1;
        pg.fdaemon = pg.fready && t.trim() !== "" && t.indexOf("no devices") === -1;
        pg.floading = false;
    }
    function ftoggle(v) {
        pg.ffpEnabled = v;
        fwriteProc.command = [
            "bash", "-c",
            "mkdir -p \"$HOME/.config/qylock\"; printf '%s\\n' " + (v ? "on" : "off") + " > \"$HOME/.config/qylock/fingerprint\""
        ];
        fwriteProc.running = true;
    }
    function fparseNames(text) {
        try {
            pg.fnames = JSON.parse(text || "{}");
        } catch (e) {
            pg.fnames = {};
        }
    }
    function fwriteNames() {
        var json = JSON.stringify(pg.fnames);
        fnamesWriteProc.command = ["bash", "-c", "mkdir -p \"$HOME/.config/qylock\"; cat > \"$HOME/.config/qylock/fingerprints.json\""];
        fnamesWriteProc.stdinEnabled = true;
        fnamesWriteProc.running = true;
        // Write happens in onStarted
    }
    function fstartEnroll() {
        pg.ferr = "";
        pg.fresult = "";
        pg.fprogress = -1;
        pg.fterm = "";
        pg.fstatus = "";
        pg.fpending = "enroll";
        pg.foverlayMode = "enroll";
        pg.fnaming = false;
        pg.fnewFinger = "";
        pg.fnameDraft = "";
        pg.foverlay = true;
        fenrollProc.command = ["fprintd-enroll"];
        fenrollProc.running = true;
    }
    function fstartVerify(finger) {
        pg.ferr = "";
        pg.fresult = "";
        pg.fprogress = -1;
        pg.fterm = "";
        pg.fstatus = "";
        pg.fpending = "verify";
        pg.foverlayMode = "verify";
        pg.foverlay = true;
        var cmd = ["fprintd-verify"];
        if (finger !== "")
            cmd.push("-f", finger);
        fverifyProc.command = cmd;
        fverifyProc.running = true;
    }
    function fdelete(finger) {
        pg.ferr = "";
        pg.fpending = "del";
        fdelProc.command = ["fprintd-delete", pg.fuser].concat(finger ? ["-f", finger] : []);
        fdelProc.running = true;
    }
    function fcloseOverlay() {
        if (pg.fpending === "enroll")
            fenrollProc.signal(15);
        if (pg.fpending === "verify")
            fverifyProc.signal(15);
        pg.fpending = "";
        pg.foverlay = false;
        pg.foverlayMode = "";
        pg.fstatus = "";
        pg.fresult = "";
        pg.fterm = "";
        pg.fprogress = -1;
        pg.fnaming = false;
        pg.fnewFinger = "";
        pg.fnameDraft = "";
    }
    function fappendTerm(raw) {
        var t = (raw || "").trim();
        if (!t) return;
        // Strip "Using device ..." lines, keep the rest
        var lines = t.split("\n");
        var out = [];
        for (var i = 0; i < lines.length; i++) {
            var s = lines[i].trim();
            if (s && !s.match(/^Using device/i))
                out.push(s);
        }
        if (out.length > 0)
            pg.fterm += out.join("\n") + "\n";
    }
    function fsaveName() {
        if (pg.fnewFinger !== "" && pg.fnameDraft.trim() !== "") {
            pg.fnames[pg.fnewFinger] = pg.fnameDraft.trim();
            fwriteNames();
        }
        pg.fnewFinger = "";
        pg.fnameDraft = "";
        pg.fnaming = false;
        pg.freload();
        pg.fcloseOverlay();
    }
    function fskipName() {
        if (pg.fnewFinger !== "") {
            var label = pg.fnewFinger.replace(/-/g, " ");
            pg.fnames[pg.fnewFinger] = label;
            fwriteNames();
        }
        pg.fnewFinger = "";
        pg.fnameDraft = "";
        pg.fnaming = false;
        pg.freload();
        pg.fcloseOverlay();
    }

    function browseStore() {
        Quickshell.execDetached(["ryostore", "open", "lockscreens"]);
    }
    function reload() {
        pg.loading = pg.skins.length === 0;
        pg.loadFailed = false;
        listProc.command = ["ryoku-hub", "lock", "list"];
        listProc.running = true;
    }
    function select(skin) {
        if (skin.slug === pg.active || pg.pendingSlug !== "")
            return;
        pg.error = "";
        pg.pendingSlug = skin.slug;
        actProc.command = ["ryoku-hub", "lock", "set", skin.slug];
        actProc.running = true;
    }
    function preview(slug) {
        Quickshell.execDetached([pg.lockSh, slug]);
    }

    // live filter: name, theme, slug, tags and copy all match the rail query.
    readonly property var shown: {
        var q = pg.query.trim().toLowerCase();
        if (q === "")
            return pg.skins;
        var out = [];
        for (var i = 0; i < pg.skins.length; i++) {
            var s = pg.skins[i];
            var hay = ((s.name || "") + " " + (s.theme || "") + " " + (s.slug || "") + " "
                + (s.summary || "") + " " + (s.blurb || "") + " " + ((s.tags || []).join(" "))).toLowerCase();
            if (hay.indexOf(q) !== -1)
                out.push(s);
        }
        return out;
    }

    // greedy masonry like the old grid: each tile drops into the shortest
    // column, its height estimated from the hero plus blurb length so the
    // columns stay balanced.
    function buildColumns(list, n) {
        var c = [], h = [], i;
        for (i = 0; i < n; i++) { c.push([]); h.push(0); }
        for (i = 0; i < list.length; i++) {
            var est = 300 + Math.ceil(((list[i].blurb || "").length) / 30) * 16;
            var min = 0;
            for (var j = 1; j < n; j++)
                if (h[j] < h[min]) min = j;
            c[min].push(list[i]);
            h[min] += est + Tokens.s3;
        }
        return c;
    }
    readonly property var grouped: pg.buildColumns(pg.shown, pg.cols)

    // ── installed themes from Ryoku Hub ─────────────────────────────────────
    Process {
        id: listProc
        command: ["ryoku-hub", "lock", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(this.text || "{}");
                    pg.skins = (response.skins || []).map((skin, index) => ({
                        slug: skin.slug,
                        name: skin.name || skin.slug,
                        theme: skin.theme || "",
                        preview: skin.preview || "",
                        summary: skin.summary || "",
                        blurb: skin.blurb || "",
                        tags: skin.tags || [],
                        active: skin.active === true,
                        installed: true,
                        ordinal: index + 1
                    }));
                    pg.active = response.active || "";
                    pg.loadFailed = false;
                } catch (e) {
                    pg.skins = [];
                    pg.loadFailed = true;
                }
                pg.loading = false;
            }
        }
    }
    Process {
        id: actProc
        stderr: StdioCollector { id: actErr }
        onExited: code => {
            if (code !== 0)
                pg.error = "Couldn't switch skin: " + (actErr.text.trim() || ("exit " + code));
            pg.pendingSlug = "";
            pg.reload();
        }
    }

    // ── sign-in keyring backend ─────────────────────────────────────────────
    Process {
        id: kstatusProc
        command: ["ryoku", "keyring", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    pg.kmode = o.mode || "";
                    pg.kdaemon = o.daemon_alive === true;
                    pg.knotes = o.notes || [];
                    var def = null;
                    var ks = o.keyrings || [];
                    for (var i = 0; i < ks.length; i++)
                        if (ks[i].role === "default")
                            def = ks[i];
                    pg.kdefName = def ? def.name : "";
                    pg.kdefFormat = def ? def.format : "";
                    // never-ask on paper, encrypted on disk: the mode cannot take
                    // effect, so open the convert/reset row without waiting for a
                    // click on an option that already looks selected.
                    if (pg.kmode === "never-ask" && pg.kdefFormat === "encrypted" && pg.kpending === "")
                        pg.kconvertFor = "never-ask";
                } catch (e) {
                    pg.kerror = "Couldn't read the keyring status.";
                }
                pg.kloading = false;
            }
        }
    }
    Process {
        id: ksetProc
        stdinEnabled: true
        stderr: StdioCollector { id: ksetErr }
        onStarted: {
            if (pg.kstdin.length > 0) {
                write(pg.kstdin);
                pg.kstdin = "";
            }
        }
        onExited: (code) => {
            pg.kpending = "";
            if (code !== 0) {
                pg.kerror = ksetErr.text.trim() || ("exit " + code);
            } else {
                pg.kconvertFor = "";
                pg.kconfirmReset = false;
            }
            pg.kreload();
        }
    }

    // ── fingerprint backend (fprintd as this user; no root) ──────────────────
    Process {
        id: freadProc
        command: [ "bash", "-c", "[ -f \"$HOME/.config/qylock/fingerprint\" ] && cat \"$HOME/.config/qylock/fingerprint\" || printf 'on'" ]
        stdout: StdioCollector { id: freadOut }
        onExited: () => {
            var v = freadOut.text.trim().toLowerCase();
            pg.ffpEnabled = !(v === "off" || v === "0" || v === "false");
        }
    }
    Process {
        id: flistProc
        command: ["fprintd-list", pg.fuser]
        stdout: StdioCollector { id: flistOut }
        onExited: (code) => {
            if (code !== 0 && flistOut.text.trim() === "") {
                pg.fdaemon = false; pg.fready = false; pg.ffingers = []; pg.floading = false;
                pg.ferr = "The fingerprint service is not running.";
                return;
            }
            pg.ferr = "";
            pg.fparseList(flistOut.text);
        }
    }
    Process {
        id: fwriteProc
        onExited: () => { pg.freload(); }
    }
    Process {
        id: fnamesReadProc
        command: ["bash", "-c", "[ -f \"$HOME/.config/qylock/fingerprints.json\" ] && cat \"$HOME/.config/qylock/fingerprints.json\" || printf '{}'" ]
        stdout: StdioCollector { id: fnamesReadOut }
        onExited: () => { pg.fparseNames(fnamesReadOut.text); }
    }
    Process {
        id: fnamesWriteProc
        stdinEnabled: true
        onStarted: {
            if (pg.fnames !== undefined) {
                write(JSON.stringify(pg.fnames));
            }
        }
        onExited: () => { pg.freload(); }
    }
    Process {
        id: fenrollProc
        stdout: StdioCollector { id: fenOut; waitForEnd: false }
        stderr: StdioCollector { id: fenErr; waitForEnd: false; onDataChanged: pg.fappendTerm(this.text) }
        onExited: (code) => {
            pg.fpending = "";
            var t = (fenErr.text || "") + (fenOut.text || "");
            pg.fappendTerm("\n--- " + (code === 0 ? "DONE" : "EXIT " + code) + " ---\n");
            if (/enroll-completed/i.test(t)) {
                var m = t.match(/Enrolling\s+([a-z0-9-]+-finger)/i);
                if (m) {
                    pg.fnewFinger = m[1];
                    pg.fnameDraft = m[1].replace(/-/g, " ");
                    pg.fnaming = true;
                    pg.fresult = "Enrollment complete. Name this fingerprint.";
                    return;
                }
                pg.fresult = "Fingerprint enrolled.";
            } else if (/enroll-data-full/i.test(t)) {
                pg.fresult = "Storage full.";
            } else if (code !== 0) {
                pg.fresult = code === 124 ? "Timed out." : "Enrollment stopped.";
            }
            pg.freload();
        }
    }
    Process {
        id: fverifyProc
        stdout: StdioCollector { id: fverOut; waitForEnd: false }
        stderr: StdioCollector { id: fverErr; waitForEnd: false; onDataChanged: pg.fappendTerm(this.text) }
        onExited: (code) => {
            pg.fpending = "";
            var t = (fverErr.text || "") + (fverOut.text || "");
            pg.fappendTerm("\n--- " + (code === 0 ? "MATCH" : "NO MATCH") + " ---\n");
            if (code === 0 || /verified/i.test(t)) {
                pg.fresult = "Fingerprint verified.";
            } else {
                pg.fresult = "No match.";
            }
        }
    }
    Process {
        id: fdelProc
        stderr: StdioCollector { id: fdelErr }
        onExited: (code) => {
            pg.fpending = "";
            if (code !== 0)
                pg.ferr = fdelErr.text.trim() || ("Couldn't remove the fingerprint (exit " + code + ").");
            else if (pg.fpending === "del") {
                // If we deleted a specific finger, remove it from names
                // fdelete is called with the finger name, so we need to track it
                // For simplicity, just reload names (fwriteNames cleans up missing)
            }
            pg.freload();
        }
    }

    // ── head: eyebrow, Fraunces title + refresh, blurb, error line ──────────
    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s6
        spacing: Tokens.s2

        Row {
            spacing: Tokens.s2
            Rectangle {
                width: 16; height: 1; color: Tokens.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "力"; color: Tokens.ink; font.family: Tokens.jp
                font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: I18n.tr("DESKTOP"); color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // title with its one utility action (rescan the installed skins) beside it.
        Item {
            width: parent.width
            height: title.height
            Text {
                id: title
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Lockscreen")
                color: Tokens.ink
                font.family: Tokens.display
                font.pixelSize: Tokens.fTitle
            }
            Btn {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("BROWSE RYOSTORE")
                onAct: pg.browseStore()
            }
        }

        Text {
            width: Math.min(parent.width, 720)
            // the load-bearing caveat, kept verbatim: it only swaps the look,
            // never your login.
            text: I18n.tr("Pick the skin your lock and sign-in screens wear. It only swaps the look, never your login; applying reskins the sign-in screen too, so you will be asked for your password.")
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
        Text {
            width: Math.min(parent.width, 720)
            visible: pg.error !== ""
            // no red on the sheet: an error is the brightest ink and the word.
            text: pg.error
            color: Tokens.ink; font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall; font.weight: Font.Medium; wrapMode: Text.WordWrap
        }
    }

    // marginalia dressing the head's empty right margin (eyebrow line). Ink only.
    Marginalia {
        anchors { right: parent.right; top: head.top }
        anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s1
        kana: "施錠"
        index: "03"; label: I18n.tr("DESKTOP")
        glyph: "column"; glyph2: "wave"
    }

    // ── loading / empty-or-failed state ─────────────────────────────────────
    Column {
        anchors.centerIn: parent
        visible: pg.loading || pg.loadFailed
        spacing: Tokens.s3
        width: Math.min(pg.width - Tokens.s6 * 2, 420)

        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pg.loading
            path: pg.pRefresh; size: 26; weight: 2; tint: Tokens.inkMuted
            RotationAnimator on rotation {
                from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: pg.loading
            }
        }
        Glyph {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pg.loadFailed
            path: pg.pLock; size: 44; tint: Tokens.inkFaint
        }
        Text {
            width: parent.width
            visible: pg.loadFailed
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: I18n.tr("No lock skins found. Install qylock to add some.")
            color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
        }
        Btn {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: pg.loadFailed
            text: I18n.tr("TRY AGAIN")
            onAct: pg.reload()
        }
    }

    // ── no-matches state (a search that filtered everything out) ────────────
    Text {
        anchors.centerIn: parent
        visible: !pg.loading && !pg.loadFailed && pg.shown.length === 0 && pg.query.trim() !== ""
        text: I18n.tr("No skins match your search.")
        color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
    }

    // ── Sign-in & Fingerprint: combined collapsible settings card ──────────────
    Rectangle {
        id: sett
        property bool open: false
        anchors { left: parent.left; right: parent.right; top: head.bottom }
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s4
        implicitHeight: settCol.implicitHeight + Tokens.s4 * 2
        height: implicitHeight
        radius: Tokens.radius
        color: "transparent"
        border.width: Tokens.border
        border.color: Tokens.line

        Column {
            id: settCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: Tokens.s4; anchors.rightMargin: Tokens.s4; anchors.topMargin: Tokens.s4
            spacing: Tokens.s2

            // header with collapse chevron
            Row {
                width: parent.width
                spacing: Tokens.s2
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Sign-in & Fingerprint")
                    color: Tokens.ink; font.family: Tokens.ui
                    font.pixelSize: Tokens.fRow; font.weight: Font.DemiBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x
                    text: pg.settOpen ? "" : (pg.kStatusLine + "  \u00b7  " + pg.fStatusLine)
                    color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall; elide: Text.ElideRight
                }
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    path: pg.pChevron; size: 15; weight: 2; rotation: pg.settOpen ? 90 : -90
                    tint: Tokens.ink
                    Behavior on rotation { NumberAnimation { duration: Tokens.snap } }
                }
            }

            TapHandler { onTapped: pg.settOpen = !pg.settOpen }

            // collapsible content
            Column {
                visible: pg.settOpen
                spacing: Tokens.s3
                topPadding: Tokens.s2

                // ── Keyring section ──
                Column {
                    spacing: Tokens.s2

                    Row {
                        width: parent.width
                        spacing: Tokens.s2
                        Text { text: I18n.tr("Keyring"); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fMicro; font.weight: Font.Medium; font.capitalization: Font.AllUppercase; font.letterSpacing: Tokens.trackMark }
                    }

                    // three-mode chip row.
                    Row { topPadding: Tokens.s1; spacing: Tokens.s2
                        Chip { label: I18n.tr("Unlock at sign-in"); mode: "unlock-on-login" }
                        Chip { label: I18n.tr("Never ask"); mode: "never-ask" }
                        Chip { label: I18n.tr("Ask each time"); mode: "ask" }
                    }

                    Text { width: parent.width; topPadding: Tokens.s1; text: pg.kStatusLine; color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
                    Text { width: parent.width; visible: pg.knotes.length > 0 && pg.kconvertFor === ""; text: pg.knotes.join("\n"); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap; lineHeight: 1.3 }

                    Column {
                        width: parent.width; visible: pg.kconvertFor !== ""; topPadding: Tokens.s2; spacing: Tokens.s2
                        Text { width: parent.width; text: I18n.tr("That keyring is locked with a password. Enter it to switch it to no-password, or start fresh (your old keyring is backed up, never deleted)."); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
                        Row { spacing: Tokens.s2
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 240; height: Tokens.ctlH + 4; radius: Tokens.radius; color: "transparent"; border.width: Tokens.border; border.color: kpwField.activeFocus ? Tokens.ink : Tokens.line; Behavior on border.color { ColorAnimation { duration: Tokens.snap } }
                                TextInput { id: kpwField; anchors.fill: parent; anchors.leftMargin: Tokens.s3; anchors.rightMargin: Tokens.s3; verticalAlignment: TextInput.AlignVCenter; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; echoMode: TextInput.Password; selectByMouse: true; selectionColor: Tokens.ink; selectedTextColor: Tokens.inkOnBone; onAccepted: pg.kconvert(text)
                                    Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter } visible: kpwField.text.length === 0; text: I18n.tr("Current keyring password"); color: Tokens.inkFaint; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall }
                                }
                            }
                            Btn { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("CONVERT"); compact: true; armed: pg.kpending === "" && kpwField.text.length > 0; onAct: pg.kconvert(kpwField.text) }
                            Btn { anchors.verticalCenter: parent.verticalCenter; text: pg.kconfirmReset ? I18n.tr("CONFIRM - START FRESH") : I18n.tr("START FRESH (KEEPS A BACKUP)"); compact: true; armed: pg.kpending === ""; onAct: { if (pg.kconfirmReset) pg.kreset(); else pg.kconfirmReset = true; } }
                        }
                    }
                    Text { width: parent.width; visible: pg.kerror !== ""; topPadding: Tokens.s1; text: pg.kerror; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; font.weight: Font.Medium; wrapMode: Text.WordWrap }
                }

                // hairline separator
                Rectangle { width: parent.width; height: Tokens.border; color: Tokens.line; visible: pg.settOpen && pg.ffingers.length >= 0 }

                // ── Fingerprint section ──
                Column {
                    visible: pg.settOpen && (pg.fdaemon || pg.floading)
                    spacing: Tokens.s2

                    Row {
                        width: parent.width
                        spacing: Tokens.s2
                        Text { text: I18n.tr("Fingerprint"); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fMicro; font.weight: Font.Medium; font.capitalization: Font.AllUppercase; font.letterSpacing: Tokens.trackMark }
                    }

                    // toggle row
                    Row { width: parent.width; topPadding: Tokens.s1; spacing: Tokens.s2
                        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Unlock with fingerprint"); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall }
                        Sw { anchors.verticalCenter: parent.verticalCenter; on: pg.ffpEnabled; onToggled: (v) => pg.ftoggle(v) }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.tr(pg.ffpEnabled ? "On \u00b7 the lock screen listens for a touch" : "Off \u00b7 password only"); color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap; width: parent.width - 200 }
                    }

                    // enrolled fingers list
                    Text { width: parent.width; topPadding: Tokens.s1; text: pg.fStatusLine; color: Tokens.inkDim; font.family: Tokens.mono; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }

                    Column {
                        spacing: Tokens.s1
                        Repeater {
                            model: pg.ffingers
                            delegate: Row {
                                width: parent.width
                                spacing: Tokens.s2
                                Text { width: 160; text: pg.ffriendly(modelData); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall }
                                Text { width: 100; text: modelData; color: Tokens.inkDim; font.family: Tokens.mono; font.pixelSize: Tokens.fSmall }
                                Btn { text: I18n.tr("VERIFY"); compact: true; onAct: pg.fstartVerify(modelData); armed: pg.fpending === "" && pg.fdaemon && pg.fready }
                                Btn { text: "\u2715"; compact: true; onAct: pg.fdelete(modelData); armed: pg.fpending === "" }
                            }
                        }
                    }

                    // actions row
                    Row { topPadding: Tokens.s2; spacing: Tokens.s2
                        Btn { text: pg.fpending === "" ? I18n.tr("ENROLL FINGERPRINT") : I18n.tr("ENROLLING\u2026"); armed: pg.fpending === "" && pg.fdaemon && pg.fready; onAct: pg.fstartEnroll() }
                        Btn { text: I18n.tr("VERIFY ANY"); compact: true; armed: pg.fpending === "" && pg.fdaemon && pg.fready && pg.ffingers.length > 0; onAct: pg.fstartVerify("") }
                        Btn { text: pg.fpending === "confirm" ? I18n.tr("CONFIRM - REMOVE ALL") : I18n.tr("REMOVE ALL"); compact: true; armed: pg.ffingers.length > 0; onAct: { if (pg.fpending === "confirm") { pg.fdelete(""); pg.fpending = ""; } else { pg.fpending = "confirm"; } } }
                    }

                    Text { width: parent.width; visible: pg.ferr !== ""; topPadding: Tokens.s1; text: pg.ferr; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; font.weight: Font.Medium; wrapMode: Text.WordWrap }
                }
            }
        }
    }

    // ── the gallery grid ────────────────────────────────────────────────────
    Flickable {
        id: flick
        anchors {
            left: parent.left; right: parent.right
            top: sett.bottom; bottom: parent.bottom
            leftMargin: Tokens.s6; rightMargin: Tokens.s6
            topMargin: Tokens.s4; bottomMargin: Tokens.s6
        }
        visible: !pg.loading && !pg.loadFailed && pg.shown.length > 0
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
        contentWidth: width
        contentHeight: masonry.implicitHeight + Tokens.s4
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

        Row {
            id: masonry
            width: flick.width - Tokens.s3   // reserve a lane for the scroll rail
            spacing: Tokens.s3

            Repeater {
                model: pg.cols
                delegate: Column {
                    id: column
                    required property int index
                    width: (masonry.width - (pg.cols - 1) * Tokens.s3) / pg.cols
                    spacing: Tokens.s3

                    Repeater {
                        model: pg.grouped[column.index] || []
                        delegate: LockTile {
                            required property var modelData
                            width: column.width
                            viewport: flick
                            skin: modelData
                            ordinal: modelData.ordinal || 0
                            active: modelData.slug === pg.active
                            busy: pg.pendingSlug === modelData.slug
                            onApplied: pg.select(modelData)
                            onPreviewed: pg.preview(modelData.slug)
                        }
                    }
                }
            }
        }
    }

    // ── a stroked vector glyph (viewBox 24), tint-able ──────────────────────
    component Glyph: Item {
        id: g
        property string path: ""
        property color tint: Tokens.inkMuted
        property real size: 20
        property real weight: 1.7
        implicitWidth: size
        implicitHeight: size
        Shape {
            anchors.centerIn: parent
            width: 24; height: 24
            scale: g.size / 24
            preferredRendererType: Shape.CurveRenderer
            antialiasing: true
            ShapePath {
                strokeColor: g.tint
                strokeWidth: g.weight
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: g.path }
            }
        }
    }

    // ── one sign-in mode chip ───────────────────────────────────────────────
    // same grammar as a tile: selected = ink border + tint10 fill + a dot.
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string mode: ""
        readonly property bool on: pg.kmode === chip.mode
        readonly property bool busy: pg.kpending === chip.mode
        implicitWidth: chLab.implicitWidth + Tokens.s4 * 2
        height: Tokens.ctlH + 4
        radius: Tokens.radius
        color: chip.on ? Tokens.tint10 : (chHover.hovered ? Tokens.tint5 : "transparent")
        border.width: Tokens.border
        border.color: chip.on ? Tokens.ink : (chHover.hovered ? Tokens.lineStrong : Tokens.line)
        opacity: (pg.kpending !== "" && !chip.busy) ? 0.4 : 1
        Behavior on color { ColorAnimation { duration: Tokens.snap } }
        Behavior on border.color { ColorAnimation { duration: Tokens.snap } }
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

        Row {
            id: chLab
            anchors.centerIn: parent
            spacing: Tokens.s1
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.on
                width: 5; height: 5; radius: 2.5; color: Tokens.ink
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.busy ? (I18n.tr(chip.label) + "\u2026") : I18n.tr(chip.label)
                color: chip.on ? Tokens.ink : Tokens.inkMuted
                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                font.weight: chip.on ? Font.DemiBold : Font.Medium
            }
        }

        HoverHandler { id: chHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: pg.kchoose(chip.mode) }
    }

    // ── one lock-skin tile ──────────────────────────────────────────────────
    // gallery grammar: selected = ink border + tint10 fill + corner dot. The
    // hero is the real skin thumbnail (a permitted colour specimen) when the
    // theme shipped a preview.gif, else a drawn lock silhouette.
    component LockTile: Rectangle {
        id: tile

        property var skin: ({})
        property int ordinal: 0
        property bool active: false
        property bool busy: false      // an apply is in flight for this skin
        property Flickable viewport: null
        signal applied()
        signal previewed()

        // near-viewport test: map the tile into the Flickable and keep a 600px
        // margin so a remote thumbnail loads just before it scrolls in. reading
        // contentY/height makes the binding re-eval as the list scrolls.
        readonly property bool onScreen: {
            if (!viewport)
                return true;
            viewport.contentY;
            viewport.height;
            var top = tile.mapToItem(viewport, 0, 0).y;
            return top < viewport.height + 600 && top + tile.height > -600;
        }

        implicitHeight: body.implicitHeight + Tokens.s6
        radius: Tokens.radius
        color: tile.active ? Tokens.tint10 : (hover.hovered ? Tokens.tint5 : "transparent")
        border.width: Tokens.border
        border.color: tile.active ? Tokens.ink : (hover.hovered ? Tokens.lineStrong : Tokens.line)
        Behavior on color { ColorAnimation { duration: Tokens.snap } }
        Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

        // gallery selection dot
        Rectangle {
            anchors { top: parent.top; right: parent.right; topMargin: Tokens.s2; rightMargin: Tokens.s2 }
            width: 5; height: 5; radius: 2.5
            color: Tokens.ink
            visible: tile.active
        }

        Column {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: Tokens.s4
            spacing: 0

            // preview hero: 16:9 well over paper, hairline frame.
            Rectangle {
                id: media
                width: parent.width
                height: Math.round(width * 9 / 16)
                radius: Tokens.radius
                color: "transparent"
                border.width: Tokens.border
                border.color: (tile.active || hover.hovered) ? Tokens.ink : Tokens.line
                clip: true
                Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

                // the real skin, animated. a lock thumbnail is a permitted
                // colour specimen, so it stays as shipped.
                AnimatedImage {
                    id: gif
                    anchors.fill: parent
                    anchors.margins: 1
                    source: tile.onScreen ? (tile.skin.preview || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                    playing: tile.onScreen
                }

                // silhouette: shown while the thumbnail loads, or when the skin
                // shipped none.
                Glyph {
                    anchors.centerIn: parent
                    visible: gif.status !== AnimatedImage.Ready
                    path: pg.pLock; size: 34; tint: Tokens.inkMuted
                }

                // Installed themes can always be previewed with the real lock.
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom; margins: Tokens.s2 }
                    width: pvRow.implicitWidth + Tokens.s4
                    height: Tokens.ctlH
                    radius: Tokens.radius
                    visible: !tile.busy
                    // a scrim over a colour specimen to seat the label, not an
                    // app-surface fill.
                    color: Qt.rgba(0, 0, 0, 0.55)
                    border.width: Tokens.border
                    border.color: pvArea.containsMouse ? Tokens.ink : Tokens.lineStrong
                    opacity: (hover.hovered || pvArea.containsMouse) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
                    Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

                    Row {
                        id: pvRow
                        anchors.centerIn: parent
                        spacing: Tokens.s1
                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            path: pg.pPlay; size: 11; weight: 2; tint: Tokens.ink
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Preview"); color: Tokens.ink
                            font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                            font.weight: Font.Medium
                        }
                    }
                    MouseArea {
                        id: pvArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tile.previewed()
                    }
                }

                // apply overlay
                Rectangle {
                    anchors.fill: parent
                    visible: tile.busy
                    color: Qt.rgba(0, 0, 0, 0.6)
                    Column {
                        anchors.centerIn: parent
                        spacing: Tokens.s2
                        Glyph {
                            anchors.horizontalCenter: parent.horizontalCenter
                            path: pg.pRefresh; size: 22; weight: 2; tint: Tokens.ink
                            RotationAnimator on rotation {
                                from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: tile.busy
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.tr("Applying\u2026"); color: Tokens.ink
                            font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; font.weight: Font.Medium
                        }
                    }
                }
            }

            Item { width: 1; height: Tokens.s4 }

            // ordinal + state badge
            Item {
                width: parent.width
                height: number.implicitHeight

                Text {
                    id: number
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    // an index is file-truth chrome, so mono.
                    text: (tile.ordinal < 10 ? "0" : "") + tile.ordinal
                    color: (tile.active || hover.hovered) ? Tokens.ink : Tokens.inkFaint
                    font.family: Tokens.mono; font.pixelSize: Tokens.fValue
                    Behavior on color { ColorAnimation { duration: Tokens.snap } }
                }

                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Tokens.s1 + 3
                    visible: tile.busy || tile.active
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 3; color: Tokens.ink
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: tile.busy ? I18n.tr("APPLYING") : I18n.tr("ACTIVE")
                        color: Tokens.ink
                        font.family: Tokens.ui; font.pixelSize: 10
                        font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                    }
                }
            }

            // theme family tags
            Text {
                width: parent.width
                topPadding: Tokens.s3
                visible: (tile.skin.tags || []).length > 0
                text: (tile.skin.tags || []).join("  \u00b7  ")
                color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                font.capitalization: Font.AllUppercase
                elide: Text.ElideRight
            }

            // skin name
            Text {
                width: parent.width
                topPadding: (tile.skin.tags || []).length > 0 ? Tokens.s2 : Tokens.s3
                text: tile.skin.name || ""
                color: Tokens.ink
                font.family: Tokens.ui; font.pixelSize: Tokens.fRow; font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            // one-line summary
            Text {
                width: parent.width
                topPadding: Tokens.s1
                visible: (tile.skin.summary || "") !== ""
                text: tile.skin.summary || ""
                color: Tokens.inkDim
                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                elide: Text.ElideRight
            }

            // blurb, two lines
            Text {
                width: parent.width
                topPadding: Tokens.s2
                visible: (tile.skin.blurb || "") !== ""
                text: tile.skin.blurb || ""
                color: Tokens.inkMuted
                font.family: Tokens.ui; font.pixelSize: 12
                lineHeight: 1.32
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        // hover affordance: this tile will apply on click.
        Glyph {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: Tokens.s4; bottomMargin: Tokens.s4 }
            path: pg.pChevron; size: 15; weight: 2; rotation: -90
            tint: Tokens.ink
            opacity: (hover.hovered && !tile.active && !tile.busy) ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
        }

        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (!tile.active && !tile.busy) tile.applied() }
    }

    // ── enroll/verify modal: mini terminal ──────────────────────────────────
    Rectangle {
        id: fovl
        anchors.fill: parent
        visible: pg.foverlay
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
        color: Qt.rgba(0, 0, 0, 0.6)
        z: 999
        MouseArea { anchors.fill: parent; onClicked: (m) => { m.accepted = true; } }

        Item {
            anchors.centerIn: parent
            width: Math.min(parent.width - Tokens.s6 * 2, 520)
            height: 340

            Rectangle {
                id: plate
                anchors.fill: parent
                radius: Tokens.radius
                color: "#1a1a1a"
                border.width: 1
                border.color: "#333"
                clip: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 0
                    spacing: 0

                    // title bar
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#222"
                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.s3 }
                            spacing: Tokens.s2
                            Rectangle { width: 6; height: 6; radius: 3; color: pg.fpending !== "" ? "#4ade80" : "#666" }
                            Text {
                                text: pg.foverlayMode === "enroll" ? "fprintd-enroll" : "fprintd-verify"
                                color: "#888"; font.family: Tokens.mono
                                font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        // close button
                        Text {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Tokens.s3 }
                            text: "x"; color: closeMa.containsMouse ? "#fff" : "#666"
                            font.family: Tokens.mono; font.pixelSize: 12; font.bold: true
                            MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: pg.fcloseOverlay() }
                        }
                    }

                    // terminal output
                    Flickable {
                        id: termScroll
                        width: parent.width
                        height: parent.height - 32 - (namingCol.visible ? namingCol.height : 0) - 40
                        clip: true
                        contentHeight: termText.implicitHeight + Tokens.s3 * 2
                        contentY: Math.max(0, contentHeight - height)
                        flickableDirection: Flickable.VerticalFlick
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds

                        Text {
                            id: termText
                            width: parent.width
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.s3 }
                            text: pg.fterm !== "" ? pg.fterm : "Waiting for sensor\u2026\n"
                            color: "#ccc"; font.family: Tokens.mono
                            font.pixelSize: 11; wrapMode: Text.WordWrap
                            textFormat: Text.PlainText
                        }

                        // auto-scroll to bottom on new content
                        Connections {
                            target: pg
                            function onFtermChanged() {
                                termScroll.contentY = Math.max(0, termScroll.contentHeight - termScroll.height)
                            }
                        }

                        // scrollbar track
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 2
                            width: 4; height: parent.height; radius: 2; color: "#333"
                            visible: termScroll.contentHeight > termScroll.height
                            Rectangle {
                                width: parent.width
                                height: Math.max(20, parent.height * termScroll.height / termScroll.contentHeight)
                                radius: 2; color: "#555"
                                y: termScroll.contentY * parent.height / termScroll.contentHeight
                            }
                        }
                    }

                    // naming step after enroll
                    Column {
                        id: namingCol
                        width: parent.width
                        visible: pg.fnaming
                        padding: Tokens.s3
                        spacing: Tokens.s2
                        Rectangle {
                            width: parent.width; height: 1; color: "#333"
                        }
                        Text { width: parent.width; text: "Name this fingerprint"; color: "#888"; font.family: Tokens.mono; font.pixelSize: 10 }
                        Rectangle {
                            width: parent.width; height: 28; radius: 4; color: "#222"; border.width: 1; border.color: "#444"
                            TextInput {
                                anchors.fill: parent; anchors.leftMargin: Tokens.s3; anchors.rightMargin: Tokens.s3; verticalAlignment: TextInput.AlignVCenter
                                color: "#ddd"; font.family: Tokens.mono; font.pixelSize: 11
                                text: pg.fnameDraft
                                onTextChanged: pg.fnameDraft = text
                                onAccepted: pg.fsaveName()
                                focus: true
                            }
                        }
                        Row { spacing: Tokens.s2
                            Btn { text: "SAVE"; onAct: pg.fsaveName() }
                            Btn { text: "SKIP"; compact: true; onAct: pg.fskipName() }
                        }
                    }

                    // bottom bar
                    Rectangle {
                        width: parent.width
                        height: 40
                        color: "#222"
                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.s3 }
                            spacing: Tokens.s2
                            Text {
                                visible: pg.fpending !== ""
                                color: "#4ade80"; font.family: Tokens.mono; font.pixelSize: 10
                                text: "\u25cf"
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite; running: pg.fpending !== ""
                                    NumberAnimation { from: 1; to: 0.3; duration: 600 }
                                    NumberAnimation { from: 0.3; to: 1; duration: 600 }
                                }
                            }
                            Text {
                                visible: pg.fpending !== ""
                                color: "#666"; font.family: Tokens.mono; font.pixelSize: 10
                                text: pg.foverlayMode === "enroll" ? "Touch sensor to enroll" : "Touch sensor to verify"
                            }
                            Text {
                                visible: pg.fpending === "" && pg.fresult !== ""
                                color: "#888"; font.family: Tokens.mono; font.pixelSize: 10
                                text: pg.fresult
                            }
                        }
                        Btn {
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Tokens.s3 }
                            text: pg.fpending !== "" ? "ABORT" : "CLOSE"
                            onAct: pg.fcloseOverlay()
                        }
                    }
                }
            }
        }
    }
}
