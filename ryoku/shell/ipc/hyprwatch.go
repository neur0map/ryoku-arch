package main

import (
	"bufio"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// hyprwatch keeps the focused monitor cached from Hyprland's event socket, so
// the keybind hot path resolves it with a mutex read instead of forking
// `hyprctl` on every press. focusedmon mirrors exactly what
// `hyprctl activeworkspace -j .monitor` would report (Hyprland sources both
// from the same focused-monitor name), and it is the single event for every
// active-monitor change, including the survivor refocus on unplug.

// hyprSocket2Path resolves Hyprland's event socket: the modern path sits under
// XDG_RUNTIME_DIR next to the request socket, older Hyprland kept it in /tmp.
// It prefers whichever exists so a login-time race (daemon up before the socket
// lands) still retries the right place, and returns "" with no instance
// signature so the watcher backs off rather than dialing a bogus path.
func hyprSocket2Path() string {
	his := os.Getenv("HYPRLAND_INSTANCE_SIGNATURE")
	if his == "" {
		return ""
	}
	var candidates []string
	if rt := os.Getenv("XDG_RUNTIME_DIR"); rt != "" {
		candidates = append(candidates, filepath.Join(rt, "hypr", his, ".socket2.sock"))
	}
	candidates = append(candidates, filepath.Join("/tmp", "hypr", his, ".socket2.sock"))
	for _, p := range candidates {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return candidates[0]
}

// parseFocusedMon pulls the monitor name out of a "focusedmon>>MON,WS" event.
// focusedmonv2 is rejected on purpose: matching v1 exactly means a future
// Hyprland that drops it fails loudly in the tests instead of going silently
// stale.
func parseFocusedMon(line string) (string, bool) {
	ev, data, ok := strings.Cut(line, ">>")
	if !ok || ev != "focusedmon" {
		return "", false
	}
	mon, _, _ := strings.Cut(data, ",")
	if mon == "" {
		return "", false
	}
	return mon, true
}

// parseMonitorRemoved pulls the name out of a "monitorremoved>>NAME" event, used
// to drop a cached monitor the moment its output disappears so the next keybind
// falls back to a fresh query instead of targeting a dead monitor.
func parseMonitorRemoved(line string) (string, bool) {
	ev, data, ok := strings.Cut(line, ">>")
	if !ok || ev != "monitorremoved" {
		return "", false
	}
	name := strings.TrimSpace(data)
	if name == "" {
		return "", false
	}
	return name, true
}

// setMonitor stores a focused-monitor name, ignoring the empty string so a
// transient failed seed (hyprctl hiccup on reconnect) never clobbers a known
// value; an empty cache only means "fall back to a fresh query".
func (d *daemon) setMonitor(s string) {
	if s == "" {
		return
	}
	d.monMu.Lock()
	d.activeMon = s
	d.monMu.Unlock()
}

func (d *daemon) clearMonitor() {
	d.monMu.Lock()
	d.activeMon = ""
	d.monMu.Unlock()
}

func (d *daemon) cachedMonitor() string {
	d.monMu.Lock()
	defer d.monMu.Unlock()
	return d.activeMon
}

// activeMonitor returns the focused monitor from the warm cache, falling back to
// a fresh query only when the cache is cold (before the first seed, or just
// after a removal cleared it). monFallback is a field so tests can prove the
// cache short-circuits the subprocess; production leaves it nil for queryActiveMonitor.
func (d *daemon) activeMonitor() string {
	if m := d.cachedMonitor(); m != "" {
		return m
	}
	fb := d.monFallback
	if fb == nil {
		fb = queryActiveMonitor
	}
	return fb()
}

// consumeHyprEvents reads the event stream until EOF, keeping the cache current:
// focusedmon updates it, monitorremoved of the cached output clears it.
func (d *daemon) consumeHyprEvents(r io.Reader) {
	sc := bufio.NewScanner(r)
	for sc.Scan() {
		line := sc.Text()
		if affectsWidgets(line) {
			select {
			case d.widgetSig <- struct{}{}:
			default:
			}
		}
		if livePauseEvent(line) {
			livePauseReconcile()
		}
		if mon, ok := parseFocusedMon(line); ok {
			d.setMonitor(mon)
			continue
		}
		if name, ok := parseMonitorRemoved(line); ok && name == d.cachedMonitor() {
			d.clearMonitor()
		}
	}
}

// watchHyprland subscribes to the Hyprland event socket for the daemon's life.
// On each connect it seeds the cache from one query (focusedmon only fires on
// change, so a single-monitor session would otherwise never populate it), then
// streams events until the socket drops and reconnects with a small backoff.
// The goroutine is reaped when the daemon process exits; the per-connection
// closer unblocks a parked Read on quit.
func (d *daemon) watchHyprland() {
	const minBackoff = 150 * time.Millisecond
	const maxBackoff = 5 * time.Second
	backoff := minBackoff
	for {
		select {
		case <-d.quit:
			return
		default:
		}

		var conn net.Conn
		if path := hyprSocket2Path(); path != "" {
			conn, _ = net.Dial("unix", path)
		}
		if conn == nil {
			select {
			case <-d.quit:
				return
			case <-time.After(backoff):
			}
			backoff = capDur(backoff*2, maxBackoff)
			continue
		}

		backoff = minBackoff
		d.setMonitor(queryActiveMonitor())

		done := make(chan struct{})
		go func() {
			select {
			case <-d.quit:
				conn.Close()
			case <-done:
			}
		}()
		d.consumeHyprEvents(conn)
		close(done)
		conn.Close()
	}
}
