package main

import (
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
)

// wallSurface is the in-shell desktop wallpaper. Bringing the wallpaper in-shell
// (contract 08 sec 1, 2.6, 3.1) replaces the external image daemon: the daemon
// copies the chosen image into a revision-stamped cache file, bumps the revision,
// and publishes {path, revision, fit} on the `wallpaper` topic. The Quickshell
// backdrop config root (one ryoku-wallpaper Background window per monitor)
// subscribes and crossfades to each new revision, so wallpaper state, the colour
// scheme, and the shell all live in one process.
//
// A single global wallpaper is mirrored to every monitor: there is one cache file
// and one revision, and every backdrop window paints it (contract 08 sec 7).
type wallSurface struct {
	topic    *stateTopic
	cacheDir string

	mu         sync.Mutex
	revision   int
	path       string            // current cache file the surface paints ("" = none set)
	fit        string            // content fit -> QML Image.fillMode
	transition *pickedTransition // reveal preset for the current revision (nil = plain crossfade)
}

// wallSurfaceCacheDir is where the chosen image is copied (contract 08 sec 3.1).
// Files are revision-stamped so each swap is a distinct url the surface reloads
// without a stale pixmap-cache hit.
func wallSurfaceCacheDir() string {
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	return filepath.Join(base, "ryoku", "wallpaper")
}

// contentFitModes are the four fits the backdrop maps to Image.fillMode
// (contract 08 sec 3.3); Cover is the default.
var contentFitModes = map[string]bool{"Contain": true, "Cover": true, "Fill": true, "ScaleDown": true}

// wallpaperContentFit reads wallpaper.content_fit from shell.json, defaulting to
// Cover. The Go settings owner (settings.go) formalises this key; until a live
// change arrives the surface reads it per apply so a wallpaper set already honours
// the stored fit. An unknown or absent value is Cover, matching the schema
// default (contract 08 sec 8).
func wallpaperContentFit() string {
	const def = "Cover"
	dir := ryokuConfigDir()
	if dir == "" {
		return def
	}
	b, err := os.ReadFile(filepath.Join(dir, "shell.json"))
	if err != nil {
		return def
	}
	var m struct {
		Wallpaper struct {
			ContentFit string `json:"content_fit"`
		} `json:"wallpaper"`
	}
	if json.Unmarshal(b, &m) != nil {
		return def
	}
	if contentFitModes[m.Wallpaper.ContentFit] {
		return m.Wallpaper.ContentFit
	}
	return def
}

// startWallpaper registers the wallpaper topic and publishes the empty snapshot,
// so a backdrop that subscribes before the first image sees a defined frame.
func (d *daemon) startWallpaper() {
	dir := wallSurfaceCacheDir()
	_ = os.MkdirAll(dir, 0o755)
	d.wall = &wallSurface{
		topic:    d.registerTopic("wallpaper"),
		cacheDir: dir,
		fit:      wallpaperContentFit(),
	}
	d.wall.mu.Lock()
	d.wall.publishLocked()
	d.wall.mu.Unlock()
}

// show copies pic into a fresh revision-stamped cache file and publishes it with
// no reveal preset (nil transition), so the backdrop plays its plain crossfade.
// Used by init and by the live still-frame.
func (w *wallSurface) show(pic string) error {
	return w.showTransition(pic, nil)
}

// showTransition copies pic into a fresh revision-stamped cache file, bumps the
// revision, re-reads the content fit, records the reveal preset, and publishes the
// new frame. The backdrop reveals to it with tr's kind / easing / edge (or a plain
// crossfade when tr is nil). Cache files older than the previous revision are
// pruned once published, so the outgoing image is never removed mid-reveal.
func (w *wallSurface) showTransition(pic string, tr *pickedTransition) error {
	if w == nil {
		return nil
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	rev := w.revision + 1
	dst := filepath.Join(w.cacheDir, "wp-"+strconv.Itoa(rev)+strings.ToLower(filepath.Ext(pic)))
	if err := os.MkdirAll(w.cacheDir, 0o755); err != nil {
		return err
	}
	if err := copyFile(pic, dst); err != nil {
		return err
	}
	w.revision = rev
	w.path = dst
	w.fit = wallpaperContentFit()
	w.transition = tr
	w.publishLocked()
	w.prune()
	return nil
}

// republish re-reads the content fit and republishes the current frame without
// advancing the revision or recopying the image, so a live content-fit change
// re-fits the same wallpaper with no crossfade. Callers that re-apply settings
// (the repaint path) use it. A byte-identical frame is suppressed by the topic.
func (w *wallSurface) republish() {
	if w == nil {
		return
	}
	w.mu.Lock()
	defer w.mu.Unlock()
	w.fit = wallpaperContentFit()
	w.publishLocked()
}

// publishLocked marshals and ships the current frame. The caller holds w.mu.
func (w *wallSurface) publishLocked() {
	if w.topic == nil {
		return
	}
	frame, err := json.Marshal(struct {
		Path       string            `json:"path"`
		Revision   int               `json:"revision"`
		Fit        string            `json:"fit"`
		Transition *pickedTransition `json:"transition,omitempty"`
	}{w.path, w.revision, w.fit, w.transition})
	if err != nil {
		return
	}
	w.topic.publish(frame)
}

// prune drops cache files older than the current and previous revision. The
// caller holds w.mu.
func (w *wallSurface) prune() {
	entries, err := os.ReadDir(w.cacheDir)
	if err != nil {
		return
	}
	for _, e := range entries {
		name := e.Name()
		if !strings.HasPrefix(name, "wp-") {
			continue
		}
		if rev := revFromCacheName(name); rev == 0 || rev >= w.revision-1 {
			continue
		}
		_ = os.Remove(filepath.Join(w.cacheDir, name))
	}
}

// revFromCacheName parses the revision out of a "wp-<rev><ext>" cache filename;
// 0 for anything that does not match, so a stray file is left alone.
func revFromCacheName(name string) int {
	base := strings.TrimPrefix(name, "wp-")
	if i := strings.IndexByte(base, '.'); i >= 0 {
		base = base[:i]
	}
	rev, err := strconv.Atoi(base)
	if err != nil {
		return 0
	}
	return rev
}

// copyFile copies src to dst byte for byte, replacing dst if it exists.
func copyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		_ = out.Close()
		return err
	}
	return out.Close()
}
