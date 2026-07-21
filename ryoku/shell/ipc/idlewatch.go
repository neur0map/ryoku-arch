package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

// idlewatch frees an idle palette (launcher, overview, ryolayer) after a grace
// of not being used. These palettes draw nothing while hidden yet hold a full
// Qt/jemalloc process, so freeing one reclaims ~a quarter gig of RSS until the
// next open, which respawns and shows it in a single cold start (setGate wakes
// the supervisor; ipcCall retries until the fresh instance answers). On by
// default: the shell ships cheap on RAM, so a palette gives up its resident
// process the moment it is idle; a user who wants instant opens opts out per
// palette. Every failure mode resolves to "keep the palette loaded".

// parkable reports whether a component is one of the idle-freeable palettes.
// All three are on-demand (not persistent): they start on their first keybind
// and park again after the idle grace.
func parkable(name string) bool {
	return name == "launcher" || name == "overview" || name == "ryolayer"
}

// unloadPaletteWhenIdle is the per-palette control that frees it after a grace
// of being hidden. On by default (perfFlagDefault true): the palette is on-
// demand, so keeping it after use only wastes RAM; a user opts OUT to keep it
// warm between opens. Keys live in performance.json beside the other unload
// flags.
func unloadPaletteWhenIdle(name string) bool {
	switch name {
	case "launcher":
		return perfFlagDefault("unloadLauncherWhenIdle", true)
	case "overview":
		return perfFlagDefault("unloadOverviewWhenIdle", true)
	case "ryolayer":
		return perfFlagDefault("unloadRyolayerWhenIdle", true)
	}
	return false
}

// ryolayerHasPins reports whether ryolayer.json holds at least one pinned
// widget. A pinned widget is an always-on desktop plate the ryolayer process
// renders even while its Super+G board is closed, so ryolayer must run at login
// to show it. No pins (the default) leaves ryolayer purely on-demand: it starts
// on the first Super+G and parks when idle.
func ryolayerHasPins() bool {
	dir := ryokuConfigDir()
	if dir == "" {
		return false
	}
	b, err := os.ReadFile(filepath.Join(dir, "ryolayer.json"))
	if err != nil {
		return false
	}
	var m struct {
		Widgets []struct {
			Pinned bool `json:"pinned"`
		} `json:"widgets"`
	}
	if json.Unmarshal(b, &m) != nil {
		return false
	}
	for _, w := range m.Widgets {
		if w.Pinned {
			return true
		}
	}
	return false
}

// markHidden / markShown record a palette's visibility for the idle-park worker.
// The palette QML reports every open change over the `state` command; a fresh
// process is assumed hidden (both palettes boot hidden and supervise marks them
// so), which starts the grace at launch so a never-opened palette parks on its
// own.
func (d *daemon) markHidden(name string) {
	d.parkMu.Lock()
	d.hiddenSince[name] = time.Now()
	d.parkMu.Unlock()
}

func (d *daemon) markShown(name string) {
	d.parkMu.Lock()
	delete(d.hiddenSince, name)
	d.parkMu.Unlock()
}

// setPaletteVisible is the `state <name> <0|1>` handler: visible cancels the park
// grace, hidden starts it.
func (d *daemon) setPaletteVisible(name string, visible bool) {
	if visible {
		d.markShown(name)
	} else {
		d.markHidden(name)
	}
}

// parkDue reports whether a palette hidden since `since` has been idle past the
// grace. Pure, so the worker's decision is unit-testable. A palette that is not
// currently hidden (absent from hiddenSince) is never due.
func parkDue(since time.Time, hidden bool, grace time.Duration, now time.Time) bool {
	return hidden && now.Sub(since) >= grace
}

// idlePark frees each parkable palette that has been hidden past the grace, when
// its opt-in is on and its process is actually running. A show command reopens
// the gate before this can re-fire, and supervise re-marks a respawn hidden, so
// the freshly reopened palette gets a full grace before it can park again.
func (d *daemon) idlePark() {
	const grace = 60 * time.Second
	tick := time.NewTicker(10 * time.Second)
	defer tick.Stop()
	for {
		select {
		case <-d.quit:
			return
		case <-tick.C:
		}
		for _, name := range []string{"launcher", "overview", "ryolayer"} {
			if !unloadPaletteWhenIdle(name) {
				continue
			}
			d.parkMu.Lock()
			since, hidden := d.hiddenSince[name]
			d.parkMu.Unlock()
			if !parkDue(since, hidden, grace, time.Now()) {
				continue
			}
			d.mu.Lock()
			running := d.proc[name] != nil
			d.mu.Unlock()
			if running {
				d.setGate(name, false)
			}
		}
	}
}
