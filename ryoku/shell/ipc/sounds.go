package main

import (
	"embed"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// sounds plays the five event cues the shell owns: a shutter on screenshot, a
// cue on output volume up/down/mute (input stays silent), a critical-battery
// alert, and AC plug/unplug. The assets are OGA clips from the desktop sound
// theme, embedded in the daemon so playback needs no install path and no runtime
// asset lookup. Every failure mode is silent: a missing player, an unwritable
// cache, or an absent asset drops the cue rather than disturbing the caller.
// There is no per-sound volume scaling; each clip plays at the sink's level.

//go:embed assets/shutter.oga assets/volume-change.oga assets/battery-low.oga assets/power-plug.oga assets/power-unplug.oga
var soundAssets embed.FS

const (
	soundShutter      = "shutter"
	soundVolumeChange = "volume-change"
	soundBatteryLow   = "battery-low"
	soundPowerPlug    = "power-plug"
	soundPowerUnplug  = "power-unplug"
)

// knownSound gates the `sound <event>` verb so an external caller (the ryoshot
// screenshot config) can only trigger a real cue.
func knownSound(name string) bool {
	switch name {
	case soundShutter, soundVolumeChange, soundBatteryLow, soundPowerPlug, soundPowerUnplug:
		return true
	}
	return false
}

var (
	soundMu    sync.Mutex
	soundReady = map[string]string{} // event -> materialised cache path
)

// soundCacheDir is where embedded clips are written once so a PCM player can
// open them by path. Empty when no home/cache dir is resolvable.
func soundCacheDir() string {
	if d := os.Getenv("XDG_CACHE_HOME"); d != "" {
		return filepath.Join(d, "ryoku", "sounds")
	}
	if h := os.Getenv("HOME"); h != "" {
		return filepath.Join(h, ".cache", "ryoku", "sounds")
	}
	return ""
}

// soundFile materialises an embedded clip to the cache dir once and returns its
// path. Subsequent calls reuse the written file.
func soundFile(name string) (string, bool) {
	soundMu.Lock()
	defer soundMu.Unlock()
	if p, ok := soundReady[name]; ok {
		return p, true
	}
	dir := soundCacheDir()
	if dir == "" {
		return "", false
	}
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", false
	}
	dst := filepath.Join(dir, name+".oga")
	if _, err := os.Stat(dst); err != nil {
		data, err := soundAssets.ReadFile("assets/" + name + ".oga")
		if err != nil {
			return "", false
		}
		if err := os.WriteFile(dst, data, 0o644); err != nil {
			return "", false
		}
	}
	soundReady[name] = dst
	return dst, true
}

// soundPlayerArgv picks a PCM player for a clip path. PipeWire's pw-play is the
// session's own player (the same stack wpctl drives); paplay is the fallback.
func soundPlayerArgv(file string) []string {
	if p, err := exec.LookPath("pw-play"); err == nil {
		return []string{p, file}
	}
	if p, err := exec.LookPath("paplay"); err == nil {
		return []string{p, file}
	}
	return nil
}

// playSound fires an event cue without blocking the caller. The volume-change
// cue waits 50 ms first so the sink level has settled before it plays (matching
// the reference's pre-play pause). No cue applies any gain.
func playSound(name string) {
	go func() {
		if name == soundVolumeChange {
			time.Sleep(50 * time.Millisecond)
		}
		file, ok := soundFile(name)
		if !ok {
			return
		}
		argv := soundPlayerArgv(file)
		if argv == nil {
			return
		}
		_ = exec.Command(argv[0], argv[1:]...).Run()
	}()
}

// readTrim reads a sysfs attribute and trims it, returning "" on any error.
func readTrim(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}
