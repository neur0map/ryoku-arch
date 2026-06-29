package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// widgetwatch frees the desktop-widget layer's memory when windows cover the
// desktop on every monitor, if the user opted in. The widgets ride the wallpaper
// layer, so when no monitor shows an empty workspace they are already invisible;
// unloading the process then reclaims its scene-graph + GL memory until an empty
// desktop returns. Every failure mode resolves to "keep the widgets loaded", so
// a probe miss never leaves a bare desktop.

// parsePerfFlag reads a boolean opt-in from a performance.json body. Anything
// malformed, absent, or the wrong type is false, so an optimisation stays off
// unless the user clearly turned it on.
func parsePerfFlag(b []byte, key string) bool {
	var m map[string]any
	if json.Unmarshal(b, &m) != nil {
		return false
	}
	v, _ := m[key].(bool)
	return v
}

// perfFlag reads one opt-in out of ~/.config/ryoku/performance.json (the file
// the Performance section in Ryoku Settings writes). A missing file is off.
func perfFlag(key string) bool {
	dir := os.Getenv("XDG_CONFIG_HOME")
	if dir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return false
		}
		dir = filepath.Join(home, ".config")
	}
	b, err := os.ReadFile(filepath.Join(dir, "ryoku", "performance.json"))
	if err != nil {
		return false
	}
	return parsePerfFlag(b, key)
}

// perfFlagDefault is perfFlag with an explicit default, for optimisations that
// ship on by default (the user opts out). A missing file, missing key, or wrong
// type all yield def.
func perfFlagDefault(key string, def bool) bool {
	dir := os.Getenv("XDG_CONFIG_HOME")
	if dir == "" {
		home, err := os.UserHomeDir()
		if err != nil {
			return def
		}
		dir = filepath.Join(home, ".config")
	}
	b, err := os.ReadFile(filepath.Join(dir, "ryoku", "performance.json"))
	if err != nil {
		return def
	}
	var m map[string]any
	if json.Unmarshal(b, &m) != nil {
		return def
	}
	if v, ok := m[key].(bool); ok {
		return v
	}
	return def
}

// On by default: the widgets ride the wallpaper, so freeing them while every
// screen is covered is invisible and reclaims their scene-graph + GL memory.
func unloadWidgetsWhenCovered() bool { return perfFlagDefault("unloadWidgetsWhenCovered", true) }

// parseDesktopVisible reports whether any monitor's active workspace is empty,
// i.e. the wallpaper (and the widgets on it) is showing somewhere. It is given
// the JSON of `hyprctl monitors` and `hyprctl workspaces`. Unparseable or empty
// input returns true, so the widgets are only ever parked on a confident,
// fully-covered reading.
func parseDesktopVisible(monitorsJSON, workspacesJSON []byte) bool {
	var mons []struct {
		ActiveWorkspace struct {
			ID int `json:"id"`
		} `json:"activeWorkspace"`
	}
	var wss []struct {
		ID      int `json:"id"`
		Windows int `json:"windows"`
	}
	if json.Unmarshal(monitorsJSON, &mons) != nil || json.Unmarshal(workspacesJSON, &wss) != nil {
		return true
	}
	if len(mons) == 0 {
		return true
	}
	windows := make(map[int]int, len(wss))
	for _, w := range wss {
		windows[w.ID] = w.Windows
	}
	for _, m := range mons {
		if windows[m.ActiveWorkspace.ID] == 0 {
			return true
		}
	}
	return false
}

// desktopVisible queries Hyprland for the per-monitor active workspaces and
// their window counts. A failed probe returns true (keep the widgets up).
func desktopVisible() bool {
	mon, err := exec.Command("hyprctl", "monitors", "-j").Output()
	if err != nil {
		return true
	}
	ws, err := exec.Command("hyprctl", "workspaces", "-j").Output()
	if err != nil {
		return true
	}
	return parseDesktopVisible(mon, ws)
}

// affectsWidgets reports whether a Hyprland event line could change which
// workspace is visible or how many windows it holds.
func affectsWidgets(line string) bool {
	for _, p := range []string{"openwindow", "closewindow", "movewindow", "workspace", "focusedmon", "monitoradded", "monitorremoved"} {
		if strings.HasPrefix(line, p) {
			return true
		}
	}
	return false
}

// widgetGateWorker parks the widget layer after a grace period of being fully
// covered (only when the opt-in is on) and reloads it the instant an empty
// desktop reappears. Window/workspace events wake it through widgetSig; a tick
// lets the cover grace elapse without events. Reload is immediate and only the
// unload waits, so flicking through covered workspaces never drops the widgets.
func (d *daemon) widgetGateWorker() {
	const grace = 3 * time.Second
	var coveredSince time.Time
	reeval := func() {
		if !unloadWidgetsWhenCovered() || desktopVisible() {
			coveredSince = time.Time{}
			d.setGate("widgets", true)
			return
		}
		if coveredSince.IsZero() {
			coveredSince = time.Now()
		}
		if time.Since(coveredSince) >= grace {
			d.setGate("widgets", false)
		}
	}
	reeval()
	tick := time.NewTicker(5 * time.Second)
	defer tick.Stop()
	for {
		select {
		case <-d.quit:
			return
		case <-d.widgetSig:
			reeval()
		case <-tick.C:
			reeval()
		}
	}
}
