package main

import (
	"bufio"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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

// parseUnloadFlag reads the unloadVisualizerWhenSilent opt-in from a
// performance.json body. Anything malformed or absent means off (the default
// keeps the visualiser loaded).
func parseUnloadFlag(b []byte) bool {
	var m map[string]any
	if json.Unmarshal(b, &m) != nil {
		return false
	}
	v, _ := m["unloadVisualizerWhenSilent"].(bool)
	return v
}

func unloadVisualizerWhenSilent() bool {
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
	return parseUnloadFlag(b)
}

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
