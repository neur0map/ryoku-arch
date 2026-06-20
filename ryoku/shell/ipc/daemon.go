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
	{"sidebar", false},
	{"visualizer", true},
}

// pillSurfaces maps a client command to the pill IpcHandler function it toggles.
var pillSurfaces = map[string]string{
	"launcher":         "launcher",
	"clipboard":        "clipboard",
	"link":             "link",
	"inbox":            "inbox",
	"wallpaper-picker": "wallpaper",
	"mixer":            "mixer",
	"calendar":         "calendar",
	"power":            "power",
	"battery":          "battery",
	"media":            "media",
	"peek":             "peek",
	"hide":             "hide",
	"sysinfo":          "sysinfo",
	"stash":            "stash",
	"toolkit":          "toolkit",
	"utilities":        "utilities",
	"workspaces":       "workspaces",
}

type daemon struct {
	mu             sync.Mutex
	sup            map[string]bool      // components that already have a supervisor goroutine
	proc           map[string]*exec.Cmd // current live process per component
	wallMu         sync.Mutex           // serializes the wallpaper hot path (pick + transition)
	paintSig       chan struct{}        // coalescing wake for the palette/border worker
	ledsSig        chan struct{}        // coalescing wake for the OpenRGB worker
	lastTransition int                  // index of the last transition preset; guarded by wallMu
	quit           chan struct{}
	closed         bool
	ln             net.Listener
	voiceMu        sync.Mutex // serializes voice (Super+`) toggles
	voiceOn        bool       // dictation active; guarded by voiceMu
}

func runDaemon() error {
	path := sockPath()
	if c, err := net.DialTimeout("unix", path, 300*time.Millisecond); err == nil {
		c.Close()
		return fmt.Errorf("a daemon is already running at %s", path)
	}
	_ = os.Remove(path)
	ln, err := net.Listen("unix", path)
	if err != nil {
		return err
	}

	d := &daemon{
		sup:      map[string]bool{},
		proc:     map[string]*exec.Cmd{},
		paintSig: make(chan struct{}, 1),
		ledsSig:  make(chan struct{}, 1),
		quit:     make(chan struct{}),
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
// processes inherit. deploy.sh and the installer install the module under
// ~/.local/lib/qt6/qml, which is not a default Qt import path.
func setupQmlImportPath() {
	home, err := os.UserHomeDir()
	if err != nil {
		return
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
	go d.paintWorker()
	go d.ledsWorker()
	go func() {
		d.wallMu.Lock()
		defer d.wallMu.Unlock()
		_ = d.wallpaperApply("init", "")
	}()
	for _, c := range components {
		if c.persistent {
			d.ensure(c.name)
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
	line, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil && line == "" {
		return
	}
	fmt.Fprintln(conn, d.dispatch(strings.TrimSpace(line)))
}

// route resolves an IPC-style command to the Quickshell config, IpcHandler target,
// and function it triggers. ok is false for commands that need more than one IPC
// call (wallpaper, reload, status, ...).
func route(cmd string) (config, target, fn string, ok bool) {
	if f, p := pillSurfaces[cmd]; p {
		return "pill", "pill", f, true
	}
	switch cmd {
	case "sidebar":
		return "sidebar", "sidebar", "toggle", true
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

// dispatch turns one command line into actions and returns "ok" or "err ...".
func (d *daemon) dispatch(line string) string {
	fields := strings.Fields(line)
	if len(fields) == 0 {
		return "err empty command"
	}
	cmd, args := fields[0], fields[1:]

	if config, target, fn, ok := route(cmd); ok {
		d.ensure(config)
		mon := ""
		if needsMonitor(fn) {
			mon = activeMonitor()
		}
		return ipcCall(config, target, fn, mon)
	}

	switch cmd {
	case "voice":
		return d.voice()
	case "lock":
		return lockSession()
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
	default:
		return "err unknown command: " + cmd
	}
}

// voice toggles dictation on the Super+` tap: it flips Handy's transcription and
// the pill voice surface (the live mic wave) together. The first tap starts
// recording and shows the wave; the next stops, transcribes, and hides it.
// Tap-to-toggle uses only the reliable key-press edge, because Hyprland cannot
// deliver a key release once its modifier is released first, which would leave a
// hold-to-talk recording stuck on.
func (d *daemon) voice() string {
	d.voiceMu.Lock()
	defer d.voiceMu.Unlock()
	d.voiceOn = !d.voiceOn
	if d.voiceOn {
		d.ensure("pill")
		toggleHandy()
		return ipcCall("pill", "pill", "voiceShow", activeMonitor())
	}
	toggleHandy()
	return ipcCall("pill", "pill", "voiceHide", "")
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
