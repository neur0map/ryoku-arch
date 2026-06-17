package main

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"os/exec"
	"os/signal"
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
}

// pillSurfaces maps a client command to the pill IpcHandler function it toggles.
var pillSurfaces = map[string]string{
	"launcher":         "launcher",
	"clipboard":        "clipboard",
	"link":             "link",
	"wallpaper-picker": "wallpaper",
	"mixer":            "mixer",
	"calendar":         "calendar",
	"power":            "power",
	"battery":          "battery",
	"media":            "media",
	"peek":             "peek",
	"hide":             "hide",
}

type daemon struct {
	mu     sync.Mutex
	sup    map[string]bool      // components that already have a supervisor goroutine
	proc   map[string]*exec.Cmd // current live process per component
	wallMu sync.Mutex           // serializes wallpaper changes
	quit   chan struct{}
	closed bool
	ln     net.Listener
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

	d := &daemon{sup: map[string]bool{}, proc: map[string]*exec.Cmd{}, quit: make(chan struct{})}
	d.ln = ln

	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
		<-sig
		d.signalQuit()
	}()

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

// bootstrap brings the shell up: clipboard-history watchers, the wallpaper daemon
// and the first wallpaper, then the persistent Quickshell components.
func (d *daemon) bootstrap() {
	startCliphist()
	go func() {
		d.wallMu.Lock()
		defer d.wallMu.Unlock()
		_ = wallpaperApply("init", "")
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
			backoff = capDur(backoff*2, 30*time.Second)
		} else {
			backoff = time.Second
		}
		time.Sleep(backoff)
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
		err := wallpaperApply(mode, arg)
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
