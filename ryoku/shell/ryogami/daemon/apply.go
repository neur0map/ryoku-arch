package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// The apply path: publish the frame the shell QML renders, persist the
// per-output state for restore, bump the catalog's apply count, trigger the
// matugen palette, and broadcast the applied event the picker listens for.

// applyWallpaper handles static and video applies, dispatching on the
// video_engine knob: "ryogami" (the C player + READY handshake, default) or
// "in_shell" (the clip publishes as videoPath and the shell decodes it).
func (d *daemon) applyWallpaper(wpType, path, mode string, outputs []string, mute map[string]bool, volume map[string]int) error {
	if path == "" {
		return fmt.Errorf("missing 'path' parameter")
	}
	if _, err := os.Stat(path); err != nil {
		return fmt.Errorf("wallpaper not readable: %v", err)
	}
	fit := contentFit()
	isVideo := wpType == "video"
	paint := path
	prefs := wallPrefs()
	if isVideo {
		if still := liveStill(path, d.config().videoFrame()); still != "" {
			paint = still
		}
	}

	if isVideo && prefs.Engine == "in_shell" {
		if d.video.Playing() {
			d.video.Stop()
		}
		name := filepath.Base(path)
		key := strings.TrimSuffix(name, filepath.Ext(name))
		clip := path
		if !prefs.Enabled {
			clip = ""
		} else if entry, ok := d.store.get(keyFor(d.store, name, key)); ok && entry.VideoFile != "" && entry.VideoFile != path {
			// Animated image formats are transcoded to mp4 at scan time: the
			// player cannot advance those frames from the original.
			clip = entry.VideoFile
			if mp4Still := liveStill(entry.VideoFile, d.config().videoFrame()); mp4Still != "" {
				paint = mp4Still
			}
		} else if prefs.Transcode {
			if capped := transcodeCachePath(path, prefs.TransFps, prefs.TransWidth); capped != "" && fileExists(capped) {
				clip = capped
				if mp4Still := liveStill(capped, d.config().videoFrame()); mp4Still != "" {
					paint = mp4Still
				}
			} else {
				clip = ""
				d.transcodeAsync(path, outputs, prefs)
			}
		}
		d.surface.show(paint, fit, d.transitionFor(mode), false, true, clip)
		d.setCurrent(name)
		d.saveOutputs(outputs, wpType, path, mute)
		d.store.mutate(keyFor(d.store, name, key), func(e *Entry) { e.ApplyCount++ })
		d.broadcast("ryogami.wall.applied", map[string]interface{}{
			"type": wpType, "name": name, "path": path, "we_id": "", "key": key,
		})
		return nil
	}

	live := isVideo
	if !isVideo && d.video.Playing() {
		d.video.Stop()
	}
	// A reveal transition is an image operation: the clip's still gets one
	// too, so a switch onto or off a video animates like any other. Only a
	// video without a still falls back to a bare cut, with the live flag
	// telling the painter to yield immediately.
	frameLive := live && paint == path
	var tr interface{}
	if !frameLive {
		if picked := d.transitionFor(mode); picked != nil {
			tr = picked
		}
	}
	seq := d.paintSeq.Add(1)
	if live {
		// The player's READY/exit handshake swaps the painter between the
		// clip's still and yielding to the video surface below it. The yield
		// waits out the reveal so the transition is never cut short, and the
		// sequence guard drops a flip the user has already switched past.
		revealUntil := time.Now()
		if p, okT := tr.(*pickedTransition); okT {
			dur := p.DurationMs
			if dur <= 0 {
				dur = transitionDurationMs
			}
			revealUntil = revealUntil.Add(time.Duration(dur+150) * time.Millisecond)
		}
		repaint := func(l bool) {
			if l {
				if wait := time.Until(revealUntil); wait > 0 {
					time.Sleep(wait)
				}
			}
			if d.paintSeq.Load() != seq {
				return
			}
			d.repaintOutputs(outputs, paint, fit, l)
		}
		d.video.Play(outputs, path, liveFit(fit), d.config().ResourceTier, repaint)
	}
	if len(outputs) == 0 || contains(outputs, "*") {
		d.surface.show(paint, fit, tr, frameLive, live, "")
	} else {
		for _, out := range outputs {
			d.surface.showOutput(out, paint, fit, tr, frameLive, live, "")
		}
	}
	name := filepath.Base(path)
	d.setCurrent(name)
	d.saveOutputs(outputs, wpType, path, mute)
	key := strings.TrimSuffix(name, filepath.Ext(name))
	d.store.mutate(keyFor(d.store, name, key), func(e *Entry) { e.ApplyCount++ })
	// The palette follows through ryoku-shell: its ryogami bridge watches the
	// frame and drives the matugen pipeline (the enriched template context the
	// deployed templates need), so the daemon never execs matugen itself.
	d.broadcast("ryogami.wall.applied", map[string]interface{}{
		"type": wpType, "name": name, "path": path, "we_id": "", "key": key,
	})
	return nil
}

// keyFor resolves the store key for an applied file: entries under subfolders
// carry the relative name, so a basename-derived key needs a fallback search.
func keyFor(s *store, name, key string) string {
	if _, okKey := s.get(key); okKey {
		return key
	}
	for _, e := range s.list(false) {
		if filepath.Base(e.Name) == name {
			return e.Key
		}
	}
	return key
}

func contains(list []string, s string) bool {
	for _, v := range list {
		if v == s {
			return true
		}
	}
	return false
}

// saveOutputs persists {output: {type, path}} to cacheDir/outputs.json for the
// startup restore, mirroring the Rust daemon: a broadcast apply clears the map
// to a single "*" entry, a per-output apply removes "*".
func (d *daemon) saveOutputs(outputs []string, wpType, path string, mute map[string]bool) {
	cacheDir := d.config().cacheDir()
	state := map[string]map[string]interface{}{}
	loadJSON(filepath.Join(cacheDir, "outputs.json"), &state)
	keys := outputs
	if len(keys) == 0 || contains(keys, "*") {
		keys = []string{"*"}
		state = map[string]map[string]interface{}{}
	} else {
		delete(state, "*")
	}
	for _, k := range keys {
		state[k] = map[string]interface{}{"type": wpType, "path": path, "mute": mute[k]}
	}
	_ = os.MkdirAll(cacheDir, 0o755)
	saveJSON(filepath.Join(cacheDir, "outputs.json"), state)
}

// restoreOutputs republishes the persisted wallpaper on startup so the shell
// never sits on the empty retained frame after a daemon restart.
func (d *daemon) restoreOutputs() {
	cacheDir := d.config().cacheDir()
	state := map[string]map[string]interface{}{}
	loadJSON(filepath.Join(cacheDir, "outputs.json"), &state)
	fit := contentFit()
	restored := ""
	restore := func(out string, e map[string]interface{}) {
		p, _ := e["path"].(string)
		if p == "" || !fileExists(p) {
			return
		}
		live := e["type"] == "video"
		paint := p
		prefs := wallPrefs()
		if live && prefs.Engine == "in_shell" {
			name := filepath.Base(p)
			key := strings.TrimSuffix(name, filepath.Ext(name))
			clip := p
			if !prefs.Enabled {
				clip = ""
			} else if entry, ok := d.store.get(keyFor(d.store, name, key)); ok && entry.VideoFile != "" && entry.VideoFile != p {
				clip = entry.VideoFile
				if mp4Still := liveStill(entry.VideoFile, d.config().videoFrame()); mp4Still != "" {
					paint = mp4Still
				}
			} else if prefs.Transcode {
				if capped := transcodeCachePath(p, prefs.TransFps, prefs.TransWidth); capped != "" && fileExists(capped) {
					clip = capped
					if mp4Still := liveStill(capped, d.config().videoFrame()); mp4Still != "" {
						paint = mp4Still
					}
				} else {
					clip = ""
					d.transcodeAsync(p, []string{out}, prefs)
				}
			}
			if out == "*" {
				d.surface.show(paint, fit, nil, false, true, clip)
			} else {
				d.surface.showOutput(out, paint, fit, nil, false, true, clip)
			}
			restored = filepath.Base(p)
			return
		}

		if live {
			var outs []string
			if out != "*" {
				outs = []string{out}
			}
			if still := liveStill(p, d.config().videoFrame()); still != "" {
				paint = still
			}
			seq := d.paintSeq.Add(1)
			repaint := func(l bool) {
				if d.paintSeq.Load() != seq {
					return
				}
				d.repaintOutputs(outs, paint, fit, l)
			}
			d.video.Play(outs, p, liveFit(fit), d.config().ResourceTier, repaint)
		}
		frameLive := live && paint == p
		if out == "*" {
			d.surface.show(paint, fit, nil, frameLive, live, "")
		} else {
			d.surface.showOutput(out, paint, fit, nil, frameLive, live, "")
		}
		restored = filepath.Base(p)
	}
	if e, okAll := state["*"]; okAll {
		restore("*", e)
	} else {
		for out, e := range state {
			restore(out, e)
		}
	}
	if restored != "" {
		d.setCurrent(restored)
		fmt.Fprintf(os.Stderr, "ryogami: auto-restored wallpaper: %s\n", restored)
	}
}

func fileExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.Mode().IsRegular()
}

// outputsState answers wall.outputs from the persisted map, adding the mute
// flag the picker's monitor popup reads (audio routing itself is the shell's
// domain, so mute is echoed state, not a mixer control).
func (d *daemon) outputsState() map[string]interface{} {
	state := map[string]map[string]interface{}{}
	loadJSON(filepath.Join(d.config().cacheDir(), "outputs.json"), &state)
	out := map[string]interface{}{}
	for k, e := range state {
		entry := map[string]interface{}{"type": e["type"], "mute": e["mute"] == true}
		if p, okPath := e["path"].(string); okPath {
			entry["path"] = p
		}
		out[k] = entry
	}
	return out
}

func (d *daemon) setAudio(mute *bool, outputs []string) {
	cacheDir := d.config().cacheDir()
	state := map[string]map[string]interface{}{}
	loadJSON(filepath.Join(cacheDir, "outputs.json"), &state)
	for k, e := range state {
		if len(outputs) > 0 && !contains(outputs, k) {
			continue
		}
		if mute != nil {
			e["mute"] = *mute
			state[k] = e
		}
	}
	saveJSON(filepath.Join(cacheDir, "outputs.json"), state)
}

// deleteWallpaper removes the source file and the catalog row, then tells
// every client the file is gone.
func (d *daemon) deleteWallpaper(key string) error {
	e, okKey := d.store.remove(key)
	if !okKey {
		return fmt.Errorf("unknown wallpaper: %s", key)
	}
	src := e.VideoFile
	if src == "" {
		src = filepath.Join(d.config().wallpaperDir(), e.Name)
	}
	if err := os.Remove(src); err != nil && !os.IsNotExist(err) {
		return err
	}
	for _, t := range []string{e.Thumb, e.ThumbSm} {
		if t != "" {
			_ = os.Remove(t)
		}
	}
	d.broadcast("ryogami.wall.file_removed", map[string]interface{}{"name": e.Name, "type": e.Type})
	return nil
}

// importWallpaper copies a file into the wallpaper dir and rescans, so the new
// entry flows to clients through the cached event.
func (d *daemon) importWallpaper(src string) error {
	if !fileExists(src) {
		return fmt.Errorf("source not readable: %s", src)
	}
	dst := filepath.Join(d.config().wallpaperDir(), filepath.Base(src))
	b, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	if err := os.WriteFile(dst, b, 0o644); err != nil {
		return err
	}
	now := time.Now()
	_ = os.Chtimes(dst, now, now)
	go d.rescan(true)
	return nil
}

// marshalable sanity check for events carrying Entry values.
var _ = json.Marshal

// repaintOutputs republishes paint on the apply's output set with the given
// live flag and no transition: the READY/exit handshake's frame swaps are
// cuts, never reveals.
func (d *daemon) repaintOutputs(outputs []string, paint, fit string, live bool) {
	if len(outputs) == 0 || contains(outputs, "*") {
		d.surface.show(paint, fit, nil, live, true, "")
		return
	}
	for _, out := range outputs {
		d.surface.showOutput(out, paint, fit, nil, live, true, "")
	}
}

// transcodeAsync builds the in-shell transcode cache off the hot path, then
// re-applies the same wallpaper so the frame points at the bite-sized cache.
func (d *daemon) transcodeAsync(path string, outputs []string, prefs wallTune) {
	go func() {
		capped := ensureVideoTranscode(path, prefs.TransFps, prefs.TransWidth)
		if capped == "" {
			return
		}
		_ = d.applyWallpaper("video", path, "live-reload", outputs, nil, nil)
	}()
}
