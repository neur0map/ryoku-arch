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
		if !pauseLiveWallpaperWhenFullscreen() {
			if stopped {
				d.resumeLive()
				stopped = false
			}
			return
		}
		full := anyFullscreen()
		if full && !stopped {
			stopLive()
			stopped = true
			return
		}
		if !full && stopped {
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

// resumeLive relaunches the saved clip when the wallpaper is a video and no
// player is up. A still wallpaper is already on screen and needs nothing.
func (d *daemon) resumeLive() {
	cur := readState()
	if !isVideo(cur) || !isFile(cur) || liveAlive() {
		return
	}
	_ = d.showLiveWallpaper(cur)
}
