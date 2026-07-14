package main

import "time"

// idlewatch frees a resident-but-hidden palette after a grace of not being used,
// if the user opted in. The launcher and the overview draw nothing while hidden
// (a basic, render-on-demand loop) yet keep a full Qt/jemalloc process resident
// so they open instantly. Freeing one reclaims ~a quarter gig of RSS until the
// next open, which respawns it and shows it in a single cold start (setGate wakes
// the supervisor; ipcCall retries until the fresh instance answers). Off by
// default: the palettes trade RAM for an instant open, so a user only gives that
// up deliberately. Every failure mode resolves to "keep the palette loaded".

// parkable reports whether a component is one of the idle-freeable palettes.
func parkable(name string) bool {
	return name == "launcher" || name == "overview"
}

// unloadPaletteWhenIdle is the per-palette opt-in that frees it after a grace of
// being hidden. Keys mirror the widget/visualiser unload flags in
// performance.json; a missing file or key is off.
func unloadPaletteWhenIdle(name string) bool {
	switch name {
	case "launcher":
		return perfFlag("unloadLauncherWhenIdle")
	case "overview":
		return perfFlag("unloadOverviewWhenIdle")
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
		for _, name := range []string{"launcher", "overview"} {
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
