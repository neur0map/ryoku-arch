package main

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
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
	{"pill", true},
	{"launcher", true},
	{"visualizer", true},
	{"widgets", true},
	{"overview", true},
}

// pillSurfaces maps a client command to the pill IpcHandler function it toggles.
var pillSurfaces = map[string]string{
	"clipboard":  "clipboard",
	"link":       "link",
	"inbox":      "inbox",
	"mixer":      "mixer",
	"calendar":   "calendar",
	"power":      "power",
	"battery":    "battery",
	"peek":       "peek",
	"hide":       "hide",
	"stash":      "stash",
	"toolkit":    "toolkit",
	"utilities":  "utilities",
	"system":     "sidebarRight", // Super+Alt+D: right (System) sidebar
	"workspaces": "workspaces",
}

type daemon struct {
	mu             sync.Mutex
	sup            map[string]bool      // components that already have a supervisor goroutine
	proc           map[string]*exec.Cmd // current live process per component
	wallMu         sync.Mutex           // serializes the wallpaper hot path (pick + transition)
	paintSig       chan struct{}        // coalescing wake for the palette/border worker
	ledsSig        chan struct{}        // coalescing wake for the OpenRGB worker
	widgetSig      chan struct{}        // coalescing wake for the widget-occupancy gate
	lastTransition int                  // index of the last transition preset; guarded by wallMu
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
}

func runDaemon() error {
	path := sockPath()
	if c, err := net.DialTimeout("unix", path, 300*time.Millisecond); err == nil {
		c.Close()
		return fmt.Errorf("a daemon is already running at %s", path)
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
		sup:       map[string]bool{},
		proc:      map[string]*exec.Cmd{},
		paintSig:  make(chan struct{}, 1),
		ledsSig:   make(chan struct{}, 1),
		widgetSig: make(chan struct{}, 1),
		quit:      make(chan struct{}),
		gateWant:  map[string]bool{},
		gateWake:  map[string]chan struct{}{},
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

// setupQmlImportPath puts the home-installed Ryoku QML modules (the Ryoku.Blobs
// plugin behind the frame) on the import path the supervised quickshell
// processes inherit. deploy.sh installs the modules under ~/.local/lib/qt6/qml,
// which is not a default Qt import path.
//
// Only a home-deployed daemon (a dev checkout or a recovery run, itself living
// in ~/.local/bin) prefers that dir; a packaged /usr/bin daemon sticks to the
// packaged modules under /usr/lib/qt6/qml. Whoever owns the daemon owns the
// QML: without this, one old deploy leaves a frozen plugin that silently
// shadows every future pacman update of ryoku-blobs.
func setupQmlImportPath() {
	home, err := os.UserHomeDir()
	if err != nil {
		return
	}
	exe, _ := os.Executable()
	if !strings.HasPrefix(exe, home+string(os.PathSeparator)) {
		if _, err := os.Stat("/usr/lib/qt6/qml/Ryoku/Blobs/qmldir"); err == nil {
			return
		}
	}
	dir := filepath.Join(home, ".local", "lib", "qt6", "qml")
	for _, v := range []string{"QML2_IMPORT_PATH", "QML_IMPORT_PATH"} {
		if cur := os.Getenv(v); cur != "" {
			_ = os.Setenv(v, dir+string(os.PathListSeparator)+cur)
		} else {
			_ = os.Setenv(v, dir)
		}
	}
}

// bootstrap brings the shell up: clipboard-history watchers, the theme workers,
// the wallpaper daemon and the first wallpaper, then the persistent Quickshell
// components.
func (d *daemon) bootstrap() {
	startCliphist()
	d.prompter = startKeyringPrompter()
	go d.paintWorker()
	go d.ledsWorker()
	go d.watchHyprland()
	go d.watchAudio()
	go d.widgetGateWorker()
	go func() {
		d.wallMu.Lock()
		defer d.wallMu.Unlock()
		_ = d.wallpaperApply("init", "")
	}()
	go d.startComponents()
}

// startupStagger spaces the persistent components' cold starts at login so a
// handful of Quickshell processes do not contend for the GPU and CPU in the same
// frame (the boot-contention burst iNiR calls out).
const startupStagger = 250 * time.Millisecond

// startComponents brings the persistent components up one at a time, pill first,
// leaving startupStagger between each. ensure is idempotent, so a keybind that
// needs a component before its turn still starts it at once.
func (d *daemon) startComponents() {
	for _, c := range components {
		if !c.persistent {
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

// ensure guarantees a supervisor goroutine exists for a component.
func (d *daemon) ensure(name string) {
	d.mu.Lock()
	if d.sup[name] {
		d.mu.Unlock()
		return
	}
	d.sup[name] = true
	d.mu.Unlock()
	go d.supervise(name)
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
		if err := cmd.Start(); err != nil {
			time.Sleep(backoff)
			backoff = capDur(backoff*2, 30*time.Second)
			continue
		}
		d.mu.Lock()
		d.proc[name] = cmd
		d.mu.Unlock()

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
	fmt.Fprintln(conn, d.dispatch(cmd))
}

// route resolves an IPC-style command to the Quickshell config, IpcHandler target,
// and function it triggers. ok is false for commands that need more than one IPC
// call (wallpaper, reload, status, ...).
func route(cmd string) (config, target, fn string, ok bool) {
	if f, p := pillSurfaces[cmd]; p {
		return "pill", "pill", f, true
	}
	switch cmd {
	case "launcher":
		return "launcher", "launcher", "toggle", true
	case "overview":
		return "overview", "overview", "toggle", true
	case "visualizer":
		return "visualizer", "visualizer", "toggle", true
	case "visualizer-overlay":
		return "visualizer", "visualizer", "overlay", true
	}
	return "", "", "", false
}

// needsMonitor reports whether an IpcHandler function takes the active monitor.
func needsMonitor(fn string) bool {
	return fn != "hide"
}

// stashSendPath pulls the file out of a "stash-send <file>" line. The path can
// hold spaces, so it's the whole remainder after the verb, not a split field.
// ok is false when no path was given.
func stashSendPath(line string) (path string, ok bool) {
	path = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(line), "stash-send"))
	return path, path != ""
}

// dispatch turns one command line into actions and returns "ok" or "err ...".
func (d *daemon) dispatch(line string) string {
	fields := strings.Fields(line)
	if len(fields) == 0 {
		return "err empty command"
	}
	cmd, args := fields[0], fields[1:]

	if config, target, fn, ok := route(cmd); ok {
		d.ensure(config)
		if config == "visualizer" {
			// an explicit toggle/overlay must win over the audio-unload gate.
			d.setGate("visualizer", true)
		}
		mon := ""
		if needsMonitor(fn) {
			mon = d.activeMonitor()
		}
		if config == "pill" {
			return pillIpc(fn, mon)
		}
		return ipcCall(config, target, fn, mon)
	}

	switch cmd {
	case "voice":
		return d.voice()
	case "lock":
		return lockSession()
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
	case "reload":
		d.reload()
		return "ok"
	case "status":
		return d.status()
	case "ping":
		return "ok"
	case "quit":
		d.signalQuit()
		return "ok"
	case "plugin":
		// plugin <id> [toggle] -> toggle that plugin's frame popout. Reserved for
		// future per-host actions (show/hide); toggle is the default.
		if len(args) < 1 {
			return "err plugin: missing id"
		}
		d.ensure("pill")
		return pillIpc("pluginPopout", d.activeMonitor(), args[0])
	case "plugins":
		// plugins reload -> the per-monitor PluginPopouts watch plugins.json and
		// re-discover on change, so a Settings save retunes live; this is a no-op
		// acknowledgement kept for an explicit force path.
		if len(args) >= 1 && args[0] == "reload" {
			return "ok"
		}
		return "err plugins: unknown action"
	case "stash-send":
		// stash-send <file> -> open the deck's LocalSend picker on that file.
		// Send goes straight to the qs client: its argv keeps a spaced path
		// intact where the pill's space-joined socket line would not.
		path, ok := stashSendPath(line)
		if !ok {
			return "err stash-send: missing file"
		}
		d.ensure("pill")
		return ipcCallN("pill", "pill", "stashSend", d.activeMonitor(), path)
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
		d.ensure("pill")
		return pillIpc("voiceOff", d.activeMonitor())
	}
	d.voiceOn = !d.voiceOn
	if d.voiceOn {
		d.ensure("pill")
		voxtypeRecord("start")
		return pillIpc("voiceShow", d.activeMonitor())
	}
	voxtypeRecord("stop")
	return pillIpc("voiceHide")
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
