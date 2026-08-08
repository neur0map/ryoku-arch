package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

// component is a Quickshell config the daemon keeps alive. Persistent components
// start with the daemon and are restarted if they exit; the rest are started the
// first time a command needs them.
type component struct {
	name       string
	persistent bool
}

var components = []component{
	// One consolidated instance renders every surface in-process (bar, backdrop,
	//	launcher, visualizer, widgets, overview), replacing the old
	// per-surface Quickshell configs. Always-on, as the pill frame was.
	{"shell", true},
}

// parseDisabledComponents pulls the "disabledComponents" string array from a
// performance.json body. shell is never returned: it is the whole in-process
// desktop, so turning it off is not offered. A malformed or absent list
// disables nothing.
func parseDisabledComponents(b []byte) map[string]bool {
	var m struct {
		Disabled []string `json:"disabledComponents"`
	}
	out := map[string]bool{}
	if json.Unmarshal(b, &m) != nil {
		return out
	}
	for _, name := range m.Disabled {
		if name != "shell" {
			out[name] = true
		}
	}
	return out
}

// componentDisabled reports whether a component is turned off via
// performance.json's disabledComponents array. Disabled components never start,
// at boot or on demand. shell is always on; a missing file disables nothing.
func componentDisabled(name string) bool {
	if name == "shell" {
		return false
	}
	// ryoku: with surfaces consolidated into the single shell, per-surface disable
	// is now internal to the shell; performance.json's disabledComponents no longer
	// maps to separate processes, so this only ever guards components that no
	// longer exist.
	b, err := os.ReadFile(perfPath())
	if err != nil {
		return false
	}
	return parseDisabledComponents(b)[name]
}

type daemon struct {
	mu             sync.Mutex
	sup            map[string]bool      // components that already have a supervisor goroutine
	proc           map[string]*exec.Cmd // current live process per component
	wallMu         sync.Mutex           // serializes the wallpaper hot path (pick + apply)
	paintSig       chan struct{}        // coalescing wake for the palette/border worker
	ledsSig        chan struct{}        // coalescing wake for the OpenRGB worker
	widgetSig      chan struct{}        // coalescing wake for the widget-occupancy gate
	liveSig        chan struct{}        // coalescing wake for the live-wallpaper fullscreen gate
	quit           chan struct{}
	closed         bool
	ln             net.Listener
	voiceMu        sync.Mutex               // serializes voice (Super+`) toggles
	voiceOn        bool                     // dictation active; guarded by voiceMu
	prompter       *prompter                // GNOME keyring system prompter (nil when unavailable)
	monMu          sync.Mutex               // guards activeMon
	activeMon      string                   // focused monitor, kept warm by watchHyprland
	monFallback    func() string            // monitor source when the cache is cold; tests swap it
	gateMu         sync.Mutex               // guards gateWant / gateWake
	gateWant       map[string]bool          // component -> may run now (absent = yes)
	gateWake       map[string]chan struct{} // wakes a parked supervisor when its gate opens
	parkMu         sync.Mutex               // guards hiddenSince
	hiddenSince    map[string]time.Time     // parkable palette -> when it last went hidden (absent = shown)
	topicsMu       sync.Mutex               // guards topics
	topics         map[string]*stateTopic   // subsystem name -> pub/sub state topic
	callsMu        sync.Mutex               // guards calls
	calls          map[string]callFunc      // "topic.method" -> control handler
	clip           *clipState               // clipboard history state (nil until started)
	tray           *trayState               // system tray watcher/host state (nil until started)
	wall           *wallSurface             // in-shell desktop wallpaper (nil until started)
	lastTransition int                      // previous wallpaper transition preset index (-1 = none); guarded by wallMu
	polkit         *polkitAgent             // PolicyKit1 authentication agent (nil until started)
	settings       *settingsStore           // shell.json store (nil until startSettings); theme apply patches through it
}

func runDaemon() error {
	path := sockPath()
	if c, err := net.DialTimeout("unix", path, 300*time.Millisecond); err == nil {
		c.Close()
		// A daemon is already listening. Take over only a stale one: an
		// incumbent left from a previous Hyprland instance, whose
		// HYPRLAND_INSTANCE_SIGNATURE differs from this session's. A stale
		// daemon supervises its quickshell children against the dead compositor
		// socket, so workspaces freeze and monitor-aware commands fail; the fresh
		// login-time daemon must displace it and rebind to the live session.
		// A same-session incumbent, an older one that cannot report its
		// signature, or our own missing signature are left alone, so a genuine
		// double-start still refuses.
		mySig := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
		incSig, ok := daemonSignature(path)
		if !shouldTakeOver(mySig, incSig, ok) {
			return fmt.Errorf("a daemon is already running at %s", path)
		}
		quitStaleDaemon(path)
	}
	_ = os.Remove(path)
	// The control socket drives session-scoped actions; keep it owner-only so a
	// second local user can't connect. net.Listen would otherwise leave it at
	// the ambient umask (0755 at the usual 022 -> unconnectable by others, but
	// that is luck, not policy). Forcing the umask around Listen makes the
	// socket 0700 atomically, with no world-visible window to chmod after.
	old := syscall.Umask(0o077)
	ln, err := net.Listen("unix", path)
	syscall.Umask(old)
	if err != nil {
		return err
	}

	d := &daemon{
		sup:            map[string]bool{},
		proc:           map[string]*exec.Cmd{},
		paintSig:       make(chan struct{}, 1),
		ledsSig:        make(chan struct{}, 1),
		widgetSig:      make(chan struct{}, 1),
		liveSig:        make(chan struct{}, 1),
		quit:           make(chan struct{}),
		gateWant:       map[string]bool{},
		gateWake:       map[string]chan struct{}{},
		hiddenSince:    map[string]time.Time{},
		lastTransition: -1,
	}
	d.ln = ln

	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
		<-sig
		d.signalQuit()
	}()

	setupQmlImportPath()

	d.bootstrap()

	for {
		conn, err := ln.Accept()
		if err != nil {
			select {
			case <-d.quit:
				d.shutdown()
				_ = os.Remove(path)
				return nil
			default:
				continue
			}
		}
		go d.handle(conn)
	}
}

// shouldTakeOver reports whether a daemon starting now should displace the
// incumbent already listening on the control socket. It takes over only a
// provably stale incumbent: one that reported a Hyprland instance signature
// (ok) different from this session's (mySig). A same-session incumbent, an
// unidentified one (an older binary that cannot answer, ok=false), or our own
// missing signature (mySig=="") all leave the incumbent in place, so a genuine
// double-start still refuses to run.
func shouldTakeOver(mySig, incSig string, ok bool) bool {
	return ok && mySig != "" && incSig != mySig
}

// daemonSignature asks the daemon at path for the Hyprland instance signature it
// was launched under. ok is false when the query fails or the reply is an error
// (an older daemon that predates the signature command), so the caller treats
// the incumbent as unidentified and does not displace it. An empty signature
// from a current daemon is a valid answer (ok=true, sig="").
func daemonSignature(path string) (sig string, ok bool) {
	conn, err := net.DialTimeout("unix", path, 300*time.Millisecond)
	if err != nil {
		return "", false
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(time.Second))
	if _, err := fmt.Fprintln(conn, "signature"); err != nil {
		return "", false
	}
	buf := make([]byte, 4096)
	n, _ := conn.Read(buf)
	resp := strings.TrimSpace(string(buf[:n]))
	if strings.HasPrefix(resp, "err ") {
		return "", false
	}
	return resp, true
}

// quitStaleDaemon tells the incumbent to quit and waits, bounded, for it to
// release the control socket so this daemon can bind. The incumbent reaps its
// own supervised quickshell children on quit, so the takeover strands no process
// holding a single-instance lock.
func quitStaleDaemon(path string) {
	if conn, err := net.DialTimeout("unix", path, 300*time.Millisecond); err == nil {
		_ = conn.SetDeadline(time.Now().Add(time.Second))
		fmt.Fprintln(conn, "quit")
		conn.Close()
	}
	for range 30 {
		conn, err := net.DialTimeout("unix", path, 100*time.Millisecond)
		if err != nil {
			return
		}
		conn.Close()
		time.Sleep(100 * time.Millisecond)
	}
}

// setupQmlImportPath puts the active shell config root and home-installed
// Ryoku plugins on the import path inherited by supervised Quickshell
// processes. External Store scenes import stable modules from the config root;
// dev sessions point at the checkout instead of a materialized copy.
func setupQmlImportPath() {
	home, err := os.UserHomeDir()
	if err != nil {
		return
	}
	configRoot := os.Getenv("XDG_CONFIG_HOME")
	if configRoot == "" {
		configRoot = filepath.Join(home, ".config")
	}
	shellRoot := filepath.Join(configRoot, "quickshell")
	if shellDir != "" {
		shellRoot = filepath.Join(shellDir, "quickshell")
	}
	dirs := []string{shellRoot}
	exe, _ := os.Executable()
	if strings.HasPrefix(exe, home+string(os.PathSeparator)) {
		dirs = append(dirs, filepath.Join(home, ".local", "lib", "qt6", "qml"))
	} else if _, err := os.Stat("/usr/lib/qt6/qml/Ryoku/Blobs/qmldir"); err != nil {
		dirs = append(dirs, filepath.Join(home, ".local", "lib", "qt6", "qml"))
	}
	prefix := strings.Join(dirs, string(os.PathListSeparator))
	for _, name := range []string{"QML2_IMPORT_PATH", "QML_IMPORT_PATH"} {
		value := prefix
		if current := os.Getenv(name); current != "" {
			value += string(os.PathListSeparator) + current
		}
		_ = os.Setenv(name, value)
	}
}

// bootstrap brings the shell up: the settings store (sole writer of shell.json,
// served over the settings topic), the clipboard history and its selection
// watcher, the tray host, the keyring prompter, the theme workers, the in-shell
// wallpaper surface and the first wallpaper, then the persistent Quickshell
// components.
func (d *daemon) bootstrap() {
	d.startSettings()
	d.startClipboard()
	d.startTray()
	d.startWeather()
	d.startMusic()
	d.startCalendar()
	d.startPowerProfiles()
	d.startNetwork()
	d.startOsd()
	d.prompter = startKeyringPrompter()
	d.startSession()
	d.startPolkit()
	d.startWallpaper()
	go d.paintWorker()
	go d.watchMatugenKnobs()
	go d.ledsWorker()
	go d.watchHyprland()
	go d.watchAudio()
	go d.watchPowerSounds()
	go d.widgetGateWorker()
	go d.idlePark()
	go func() {
		d.wallMu.Lock()
		defer d.wallMu.Unlock()
		d.wallInit()
	}()
	go d.startComponents()
	go d.liveGateWorker()
}

// startupStagger spaces the persistent components' cold starts at login so a
// handful of Quickshell processes do not contend for the GPU and CPU in the same
// frame (the boot-contention burst iNiR calls out).
const startupStagger = 250 * time.Millisecond

// reapStrays kills quickshell components left behind by a previous daemon. A
// daemon that was killed rather than asked to quit leaves its children running:
// they outlive it, and the replacement starts a second set on top, so the pill
// and the visualiser end up drawn twice. Anything matching a component we own
// is stray at this point, since our own are not started yet.
func (d *daemon) reapStrays() {
	self := os.Getpid()
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return
	}
	want := map[string]bool{}
	for _, c := range components {
		want[strings.Join(qsSelect(c.name), " ")] = true
	}
	for _, e := range entries {
		pid, err := strconv.Atoi(e.Name())
		if err != nil || pid == self {
			continue
		}
		raw, err := os.ReadFile(filepath.Join("/proc", e.Name(), "cmdline"))
		if err != nil {
			continue
		}
		fields := strings.Split(strings.TrimRight(string(raw), "\x00"), "\x00")
		if len(fields) < 3 || filepath.Base(fields[0]) != "qs" {
			continue
		}
		if want[strings.Join(fields[1:], " ")] {
			if p, err := os.FindProcess(pid); err == nil {
				_ = p.Signal(syscall.SIGTERM)
			}
		}
	}
}

// startComponents brings the persistent components up one at a time, pill first,
// leaving startupStagger between each. ensure is idempotent, so a keybind that
// needs a component before its turn still starts it at once.
func (d *daemon) startComponents() {
	d.reapStrays()
	for _, c := range components {
		if !startsAtBoot(c) {
			continue
		}
		d.ensure(c.name)
		select {
		case <-d.quit:
			return
		case <-time.After(startupStagger):
		}
	}
}

// startsAtBoot reports whether a component renders at login. Persistent
// components always do; on-demand palettes wait for their first keybind. A
// disabled component never starts.
func startsAtBoot(c component) bool {
	if componentDisabled(c.name) {
		return false
	}
	return c.persistent
}

// ensure guarantees a supervisor goroutine exists for a component.
func (d *daemon) ensure(name string) {
	if componentDisabled(name) {
		return
	}
	d.mu.Lock()
	if d.sup[name] {
		d.mu.Unlock()
		return
	}
	d.sup[name] = true
	d.mu.Unlock()
	go d.supervise(name)
}

// jemallocConf tunes the allocator Quickshell links. jemalloc defaults narenas
// to 4*ncpu (64 on a 16-thread box) and only returns freed pages to the OS on
// later allocation activity, so an idle shell that stops allocating keeps every
// dirty page mapped as RSS. Two arenas is ample for an event-driven GUI, and a
// background thread purges on the decay schedule even while idle. Each supervised
// qs process pays this once, so five of them stop hoarding a dozen arenas of
// freed heap apiece.
const jemallocConf = "narenas:2,background_thread:true,dirty_decay_ms:5000,muzzy_decay_ms:5000"

// qsEnv is the environment for a supervised quickshell process: the daemon's own
// env (which carries the QML import path setupQmlImportPath exports) plus the
// jemalloc tuning, unless the user already pinned MALLOC_CONF.
func qsEnv() []string {
	env := os.Environ()
	if os.Getenv("MALLOC_CONF") == "" {
		env = append(env, "MALLOC_CONF="+jemallocConf)
	}
	return env
}

// supervise runs `qs -c <name>` and restarts it whenever it exits, backing off if
// it dies immediately so a broken config does not spin the CPU.
func (d *daemon) supervise(name string) {
	backoff := time.Second
	for {
		select {
		case <-d.quit:
			return
		default:
		}
		// park while a gate keeps this component unloaded (the visualiser
		// audio-unload). a fresh open wakes us; the timeout is a safety re-check.
		for !d.gateAllows(name) {
			select {
			case <-d.quit:
				return
			case <-d.gateWaitCh(name):
			case <-time.After(5 * time.Second):
			}
		}
		cmd := exec.Command("qs", qsSelect(name)...)
		cmd.Env = qsEnv()
		if err := cmd.Start(); err != nil {
			time.Sleep(backoff)
			backoff = capDur(backoff*2, 30*time.Second)
			continue
		}
		d.mu.Lock()
		d.proc[name] = cmd
		d.mu.Unlock()
		if parkable(name) {
			d.markHidden(name)
		}

		start := time.Now()
		_ = cmd.Wait()

		d.mu.Lock()
		delete(d.proc, name)
		d.mu.Unlock()

		select {
		case <-d.quit:
			return
		default:
		}
		if time.Since(start) < 3*time.Second {
			// Died fast: likely a broken config. Back off exponentially so a
			// crash loop cannot spin the CPU.
			backoff = capDur(backoff*2, 30*time.Second)
			time.Sleep(backoff)
		} else {
			// Healthy run that exited (a reload or SIGTERM): respawn at once so
			// the surface does not blink out for a backoff interval.
			backoff = time.Second
		}
	}
}

// gateAllows reports whether the supervisor may (re)start name now. Any
// component without a gate defaults to true, so gating is strictly opt-in and a
// cleared gate never blocks a start.
func (d *daemon) gateAllows(name string) bool {
	d.gateMu.Lock()
	defer d.gateMu.Unlock()
	w, ok := d.gateWant[name]
	return !ok || w
}

// gateWaitCh returns name's wake channel, creating it on first use so a parked
// supervisor can block until its gate opens.
func (d *daemon) gateWaitCh(name string) chan struct{} {
	d.gateMu.Lock()
	defer d.gateMu.Unlock()
	ch := d.gateWake[name]
	if ch == nil {
		ch = make(chan struct{}, 1)
		d.gateWake[name] = ch
	}
	return ch
}

// setGate opens or closes a component's run gate. Opening wakes a parked
// supervisor; closing SIGTERMs the live process so its supervisor parks instead
// of respawning. Only real state changes act.
func (d *daemon) setGate(name string, want bool) {
	d.gateMu.Lock()
	prev, ok := d.gateWant[name]
	d.gateWant[name] = want
	ch := d.gateWake[name]
	if ch == nil {
		ch = make(chan struct{}, 1)
		d.gateWake[name] = ch
	}
	d.gateMu.Unlock()
	if ok && prev == want {
		return
	}
	if want {
		select {
		case ch <- struct{}{}:
		default:
		}
		return
	}
	d.mu.Lock()
	cmd := d.proc[name]
	d.mu.Unlock()
	if cmd != nil && cmd.Process != nil {
		_ = cmd.Process.Signal(syscall.SIGTERM)
	}
}

func (d *daemon) signalQuit() {
	d.mu.Lock()
	defer d.mu.Unlock()
	if !d.closed {
		d.closed = true
		close(d.quit)
		if d.ln != nil {
			_ = d.ln.Close()
		}
	}
}

// shutdown stops the supervised Quickshell processes.
func (d *daemon) shutdown() {
	d.mu.Lock()
	procs := make([]*exec.Cmd, 0, len(d.proc))
	for _, c := range d.proc {
		procs = append(procs, c)
	}
	d.mu.Unlock()
	for _, c := range procs {
		if c.Process != nil {
			_ = c.Process.Signal(syscall.SIGTERM)
		}
	}
}

func (d *daemon) handle(conn net.Conn) {
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(30 * time.Second))
	r := bufio.NewReader(conn)
	line, err := r.ReadString('\n')
	if err != nil && line == "" {
		return
	}
	cmd := strings.TrimSpace(line)
	// The keyring island returns the typed secret on a second line so it never
	// reaches a command line (and thus world-readable /proc/<pid>/cmdline).
	if strings.HasPrefix(cmd, "keyring-respond") {
		secret, _ := r.ReadString('\n')
		fmt.Fprintln(conn, d.keyringRespond(cmd, strings.TrimRight(secret, "\r\n")))
		return
	}
	// Typed subsystem state rides the same socket: a long-lived subscription
	// stream, or a request/response control call. Both outlive the one-shot
	// command deadline, which they clear for themselves.
	if strings.HasPrefix(cmd, "subscribe ") {
		d.serveSubscription(conn, cmd)
		return
	}
	if strings.HasPrefix(cmd, "call ") {
		d.serveCalls(conn, r, cmd)
		return
	}
	// A clipboard capture helper streams new selection bytes after its header
	// line, so they never reach a command line.
	if strings.HasPrefix(cmd, "clip-ingest ") {
		fmt.Fprintln(conn, d.clipIngest(cmd, r))
		return
	}
	if strings.HasPrefix(cmd, "clip-copy ") {
		fmt.Fprintln(conn, d.clipCopy(cmd))
		return
	}
	fmt.Fprintln(conn, d.dispatch(cmd))
}

var surfaceCommands = map[string]string{
	"menu screenshot": "screenshot",
	"menu stash":      "stash",
	// ryoku: launcher/overview/visualizer are toggled in-process
	// by the shell's own global:ryoku:* keybinds (CustomShortcut -> ShellState),
	// not by the daemon. These CLI verbs stay mapped to the closest openSurface
	// call on the shell target, but the shell's surface bus does not route these
	// ids yet, so they are no-ops pending the retire phase (wire the ids there, or
	// drop the dead verbs). Do NOT invent a shell IPC function for them.
	"menu app-launcher":  "launcher",
	"launcher":           "launcher",
	"overview":           "overview",
	"visualizer":         "visualizer",
	"visualizer-overlay": "visualizer-overlay",
}

// route resolves an IPC-style command to the single shell's IpcHandler config,
// target, and function it triggers. The consolidated shell renders every surface
// in-process, so a matched command always resolves to config and target "shell"
// and the openSurface entry point on its surface bus. ok is false for commands
// that need more than one IPC call (wallpaper, reload, status, ...).
func route(cmd string) (config, target, fn string, ok bool) {
	if _, ok := surfaceCommands[cmd]; ok {
		return "shell", "shell", "openSurface", true
	}
	if _, ok := menuID(cmd); ok {
		return "shell", "shell", "openSurface", true
	}
	return "", "", "", false
}

func validBarStyleID(id string) bool {
	if id == "" {
		return false
	}
	for _, r := range id {
		if (r < 'a' || r > 'z') && (r < '0' || r > '9') && r != '-' {
			return false
		}
	}
	return true
}

// dispatch turns one command line into actions and returns "ok" or "err ...".
func (d *daemon) dispatch(line string) string {
	fields := strings.Fields(line)
	if len(fields) == 0 {
		return "err empty command"
	}
	cmd, args := fields[0], fields[1:]
	routeCmd := cmd
	switch cmd {
	case "menu":
		// menu close clears every open menu. App launcher and dedicated frame
		// surfaces keep their established menu commands.
		switch {
		case len(args) == 1 && args[0] == "close":
			return d.menuClose()
		case len(args) == 1 && (args[0] == "app-launcher" || args[0] == "screenshot" || args[0] == "stash"):
			routeCmd = line
		default:
			if _, ok := menuID(line); !ok {
				return "err menu: unknown or malformed id"
			}
			routeCmd = line
		}
	case "bar":
		// bar <edge|all> <toggle|reveal|hide> drives the bar reveal state.
		edge, action, ok := parseBarEdge(args)
		if !ok {
			return "err bar: expected <top|bottom|left|right|all> <toggle|reveal|hide>"
		}
		return d.barToggle(edge, action)
	}
	if config, target, fn, ok := route(routeCmd); ok {
		if componentDisabled(config) {
			// the user turned this component off; its keybind is a silent no-op
			// rather than a failed ipc call to a process that will never start.
			return "ok"
		}
		d.ensure(config)
		if config == "visualizer" || parkable(config) {
			// an explicit toggle must win over the idle-unload gate: reopen a
			// parked visualiser or palette so its supervisor respawns, then
			// ipcCall retries until the fresh instance answers.
			d.setGate(config, true)
		}
		mon := d.activeMonitor()
		if config == "shell" {
			if fn == "openSurface" {
				id, menu := menuID(routeCmd)
				if !menu {
					id = surfaceCommands[routeCmd]
				}
				return shellIpc(fn, mon, id)
			}
			return shellIpc(fn, mon)
		}
		return ipcCall(config, target, fn, mon)
	}

	switch cmd {
	case "voice":
		return d.voice()
	case "barstyle":
		if len(args) != 1 || !validBarStyleID(args[0]) {
			return "err barstyle: expected one product id"
		}
		if d.settings == nil {
			return "err barstyle: settings not ready"
		}
		value, _ := json.Marshal(args[0])
		if err := d.settings.patch("barStyle", value); err != nil {
			return "err barstyle: " + err.Error()
		}
		return "ok"
	case "lock":
		// lock status is the reference check (prints locked/unlocked, exit 0);
		// bare lock engages the session lock.
		if len(args) >= 1 && args[0] == "status" {
			if isLocked() {
				return "locked"
			}
			return "unlocked"
		}
		return lockSession()
	case "audio":
		if len(args) != 1 {
			return "err audio: expected up, down, or mute"
		}
		return d.audio(args[0])
	case "brightness":
		if len(args) != 1 {
			return "err brightness: expected up or down"
		}
		return d.brightness(args[0])
	case "hub":
		switch len(args) {
		case 1:
			return d.hub(args[0], "")
		case 2:
			return d.hub(args[0], args[1])
		}
		return "err hub: expected open [section] or close"
	case "wallpaper-switcher":
		// spawn the picker as a one-shot modal (like ryoshot or the hub), not a
		// resident surface: it shows on launch and quits on close, so it holds no
		// memory while idle. flock keeps a second press from stacking a duplicate;
		// the goroutine reaps qs when it exits.
		go func() {
			_ = exec.Command("flock", append([]string{"-n", "-o", "/tmp/ryoku-wallpaper.lock", "qs"}, qsSelect("wallpaper")...)...).Run()
		}()
		return "ok"
	case "wallpaper":
		mode := "next"
		arg := ""
		if len(args) > 0 {
			mode = args[0]
		}
		if mode == "set" && len(args) > 1 {
			arg = args[1]
		}
		d.wallMu.Lock()
		err := d.wallpaperApply(mode, arg)
		d.wallMu.Unlock()
		if err != nil {
			return "err wallpaper: " + err.Error()
		}
		return "ok"
	case "theme":
		// Apply a colour scheme by writing theme.theme through the settings store
		// (the sole writer of shell.json), which validates the name, persists,
		// broadcasts, and schedules the retheme. `theme catalog` is served
		// client-side in main.go, so it never reaches here. Join the args so a
		// name with spaces ("Tokyo Night") survives the command split.
		if len(args) == 0 {
			return "err theme: expected a scheme name (or `catalog`)"
		}
		if d.settings == nil {
			return "err theme: settings not ready"
		}
		name, _ := json.Marshal(strings.Join(args, " "))
		if err := d.settings.patch("theme.theme", name); err != nil {
			return "err theme: " + err.Error()
		}
		return "ok"
	case "reload":
		d.reload()
		return "ok"
	case "status":
		return d.status()
	case "ping":
		return "ok"
	case "signature":
		// The Hyprland instance this daemon was launched under. A newly starting
		// daemon reads it to tell a stale incumbent (a previous session's) from
		// a same-session double-start before it takes over the control socket.
		return os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
	case "quit":
		d.signalQuit()
		return "ok"
	case "plugin":
		// plugin <id> [toggle] -> toggle that plugin's frame popout. Reserved for
		// future per-host actions (show/hide); toggle is the default.
		if len(args) < 1 {
			return "err plugin: missing id"
		}
		d.ensure("shell")
		return shellIpc("openSurface", d.activeMonitor(), "plugin:"+args[0])
	case "plugins":
		// plugins reload -> the per-monitor PluginPopouts watch plugins.json and
		// re-discover on change, so a Settings save retunes live; this is a no-op
		// acknowledgement kept for an explicit force path.
		if len(args) >= 1 && args[0] == "reload" {
			return "ok"
		}
		return "err plugins: unknown action"
	case "state":
		// a parkable palette (launcher/overview) reporting its open state for the
		// idle-park worker: `state <name> <0|1>`. 1 shows (cancels the park grace),
		// 0 hides (starts it).
		if len(args) < 2 {
			return "err state: need <name> <0|1>"
		}
		d.setPaletteVisible(args[0], args[1] == "1")
		return "ok"
	case "sound":
		// an event cue from a config outside the daemon (ryoshot fires the
		// shutter on capture). The daemon owns the assets and playback; it only
		// accepts a known event name.
		if len(args) != 1 || !knownSound(args[0]) {
			return "err sound: expected a known event"
		}
		playSound(args[0])
		return "ok"

	default:
		return "err unknown command: " + cmd
	}
}

// voice handles the Super+` tap. With dictation running it toggles Voxtype's
// transcription and the pill's mic-wave together (first tap records and shows
// the wave; the next stops, transcribes, and hides it). With dictation off it
// just flashes an "off" note on the pill. Tap-to-toggle rides only the key-press
// edge: Hyprland won't deliver a release once the modifier lifts first, which
// would otherwise leave a hold-to-talk recording stuck on.
func (d *daemon) voice() string {
	d.voiceMu.Lock()
	defer d.voiceMu.Unlock()
	if !dictationReady() {
		d.voiceOn = false
		d.ensure("shell")
		return shellIpc("openSurface", d.activeMonitor(), "voice-off")
	}
	d.voiceOn = !d.voiceOn
	if d.voiceOn {
		d.ensure("shell")
		voxtypeRecord("start")
		return shellIpc("openSurface", d.activeMonitor(), "voice")
	}
	voxtypeRecord("stop")
	return shellIpc("closeSurface", d.activeMonitor(), "voice")
}

// reload restarts every supervised component by terminating it; the supervisor
// goroutine then brings it back.
func (d *daemon) reload() {
	d.mu.Lock()
	procs := make([]*exec.Cmd, 0, len(d.proc))
	for _, c := range d.proc {
		procs = append(procs, c)
	}
	d.mu.Unlock()
	for _, c := range procs {
		if c.Process != nil {
			_ = c.Process.Signal(syscall.SIGTERM)
		}
	}
}

func (d *daemon) status() string {
	d.mu.Lock()
	defer d.mu.Unlock()
	var b strings.Builder
	for _, c := range components {
		state := "stopped"
		if _, ok := d.proc[c.name]; ok {
			state = "running"
		} else if d.sup[c.name] {
			state = "starting"
		}
		fmt.Fprintf(&b, "%s: %s\n", c.name, state)
	}
	return strings.TrimRight(b.String(), "\n")
}

func capDur(d, max time.Duration) time.Duration {
	if d > max {
		return max
	}
	return d
}
