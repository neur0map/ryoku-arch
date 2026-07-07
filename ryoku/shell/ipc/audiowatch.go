package main

import (
	"bufio"
	"os/exec"
	"strings"
	"syscall"
	"time"
)

// audiowatch frees the visualiser's memory when the desktop is silent, if the
// user opted in. The visualiser is a music spectrum; with no sound it draws
// nothing, so unloading the whole process reclaims its GPU/scene-graph memory
// (~a quarter gig of NVIDIA GL context) until audio returns. Every failure mode
// here resolves to "keep the visualiser running": a missing pactl, an unreadable
// flag, or a parse miss never drops the surface.

// parseAudioActive reports whether `pactl list sink-inputs` shows a stream that
// is actually producing sound. A paused or stopped player corks its input, so
// "Corked: no" is the signal that audio is live.
func parseAudioActive(s string) bool {
	return strings.Contains(s, "Corked: no")
}

// audioActive queries PulseAudio/PipeWire for a live stream. A probe failure
// returns true so the visualiser is never unloaded on uncertainty.
func audioActive() bool {
	out, err := exec.Command("pactl", "list", "sink-inputs").Output()
	if err != nil {
		return true
	}
	return parseAudioActive(string(out))
}

// unloadVisualizerWhenSilent is the opt-in that frees the visualiser's memory
// while the desktop is silent. Off by default; perfFlag lives in widgetwatch.go.
func unloadVisualizerWhenSilent() bool { return perfFlag("unloadVisualizerWhenSilent") }

// watchAudio parks the visualiser process after a grace period of silence (only
// when the opt-in is on) and brings it back the moment audio returns. It rides
// pactl's event stream so an idle desktop costs nothing; a periodic tick lets
// the silence grace elapse without events. The grace avoids flapping on the
// short gaps between tracks.
func (d *daemon) watchAudio() {
	const grace = 30 * time.Second
	var silentSince time.Time

	reeval := func() {
		if !unloadVisualizerWhenSilent() {
			silentSince = time.Time{}
			d.setGate("visualizer", true)
			return
		}
		if audioActive() {
			silentSince = time.Time{}
			d.setGate("visualizer", true)
			return
		}
		if silentSince.IsZero() {
			silentSince = time.Now()
		}
		if time.Since(silentSince) >= grace {
			d.setGate("visualizer", false)
		}
	}
	reeval()

	for {
		select {
		case <-d.quit:
			return
		default:
		}

		cmd := exec.Command("pactl", "subscribe")
		// Tie the subscriber's lifetime to ours: on SIGKILL, a crash, or a hard
		// restart the graceful d.quit cleanup never runs, and this child is
		// reparented to init. Each orphaned `pactl subscribe` holds a
		// PipeWire-Pulse client slot; enough of them exhaust the limit and new
		// streams (e.g. browser/YouTube audio) get refused.
		cmd.SysProcAttr = &syscall.SysProcAttr{Pdeathsig: syscall.SIGKILL}
		stdout, err := cmd.StdoutPipe()
		if err == nil {
			err = cmd.Start()
		}
		if err != nil {
			// No pactl available: keep the visualiser up and re-check slowly in
			// case the flag changes, but never park without a positive reading.
			d.setGate("visualizer", true)
			select {
			case <-d.quit:
				return
			case <-time.After(10 * time.Second):
			}
			continue
		}

		done := make(chan struct{})
		go func() {
			select {
			case <-d.quit:
				_ = cmd.Process.Kill()
			case <-done:
			}
		}()

		events := make(chan struct{}, 1)
		go func() {
			sc := bufio.NewScanner(stdout)
			for sc.Scan() {
				if strings.Contains(sc.Text(), "sink-input") {
					select {
					case events <- struct{}{}:
					default:
					}
				}
			}
			close(events)
		}()

		tick := time.NewTicker(5 * time.Second)
	stream:
		for {
			select {
			case <-d.quit:
				tick.Stop()
				close(done)
				_ = cmd.Wait()
				return
			case <-tick.C:
				reeval()
			case _, ok := <-events:
				if !ok {
					break stream // subprocess died: reconnect
				}
				reeval()
			}
		}
		tick.Stop()
		close(done)
		_ = cmd.Wait()
		select {
		case <-d.quit:
			return
		case <-time.After(time.Second):
		}
	}
}
