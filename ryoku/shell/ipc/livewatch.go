package main

import (
	"encoding/json"
	"os/exec"
	"time"
)

// Stops the video wallpaper while a window is fullscreen (the backdrop's still
// frame stays underneath). Keyed on real fullscreen, not the widget layer's
// "covered", which trips on any workspace that merely holds a window.

func pauseLiveWallpaperWhenFullscreen() bool {
	return perfFlagDefault("pauseLiveWallpaperWhenFullscreen", true)
}

// liveShouldStop decides whether to pause the video wallpaper: while a window is
// fullscreen (its still frame stays under it, so nothing on screen changes) or
// whenever Power Saver is shaping the desktop, to drop the decode drain.
func liveShouldStop(pauseOnFullscreen, fullscreen, saver bool) bool {
	return (pauseOnFullscreen && fullscreen) || saver
}

// saverActive reports whether Power Saver should shape the desktop: the active
// power profile is power-saver and the user left "Follow the power profile" on
// (performance.json powerProfileEffects, default on). Without a power-profiles
// connection it reads false, so the wallpaper keeps playing.
func (d *daemon) saverActive() bool {
	if d.pp == nil || !perfFlagDefault("powerProfileEffects", true) {
		return false
	}
	return d.pp.activeProfile() == ppSaver
}

// parseAnyFullscreen reports whether any client is fullscreen, from the JSON of
// `hyprctl clients`. Unparseable input returns false, so the wallpaper is only
// ever stopped on a confident reading.
func parseAnyFullscreen(clientsJSON []byte) bool {
	var clients []struct {
		Fullscreen any `json:"fullscreen"`
	}
	if json.Unmarshal(clientsJSON, &clients) != nil {
		return false
	}
	for _, c := range clients {
		switch v := c.Fullscreen.(type) {
		case bool:
			if v {
				return true
			}
		case float64:
			// Hyprland reports a mode here: 0 none, 1 maximised, 2 fullscreen.
			// Only a real fullscreen covers the wallpaper.
			if v >= 2 {
				return true
			}
		}
	}
	return false
}

func anyFullscreen() bool {
	out, err := exec.Command("hyprctl", "clients", "-j").Output()
	if err != nil {
		return false
	}
	return parseAnyFullscreen(out)
}

// liveGateWorker stops the video wallpaper while something is fullscreen and
// restarts it once nothing is. Woken by the same window events the widget gate
// uses, with a tick so a state change without an event still lands.
func (d *daemon) liveGateWorker() {
	stopped := false
	reeval := func() {
		want := liveShouldStop(pauseLiveWallpaperWhenFullscreen(), anyFullscreen(), d.saverActive())
		if want && !stopped {
			d.stopLive()
			stopped = true
		} else if !want && stopped {
			d.resumeLive()
			stopped = false
		}
	}
	reeval()
	tick := time.NewTicker(5 * time.Second)
	defer tick.Stop()
	for {
		select {
		case <-d.quit:
			return
		case <-d.liveSig:
			reeval()
		case <-tick.C:
			reeval()
		}
	}
}

// resumeLive relaunches the saved clip when the wallpaper is a video and no player
// is up. nil preset: a resume of what is already on screen, not a switch.
func (d *daemon) resumeLive() {
	cur := readState()
	if !isVideo(cur) || !isFile(cur) || liveAlive() {
		return
	}
	_ = d.showLiveWallpaper(cur)
}
