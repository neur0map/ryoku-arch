package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Setting a video shows the clip's own first frame (a still the in-shell backdrop
// paints) with the ryoku-livewall player launched on top. livewall runs off the
// hot path (after the transcode), so the assert polls for it. Runs against
// recording stand-ins on PATH, so it never touches the real player.
func TestShowLiveWallpaperHandoff(t *testing.T) {
	bin := t.TempDir()
	state := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", t.TempDir()) // no ryowalls.json
	t.Setenv("XDG_STATE_HOME", state)        // isolate the extracted frame
	t.Setenv("XDG_CACHE_HOME", t.TempDir())  // isolate the transcode cache
	liveLog := filepath.Join(state, "live.args")

	fake := func(name, body string) {
		if err := os.WriteFile(filepath.Join(bin, name), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	// ryoku-livewall records its argv; ffmpeg (the liveFrame extract AND the
	// livewall transcode) creates its output file (the last arg), so liveFrame
	// yields a still and livewallSource a cached clip; pgrep/pkill are inert here.
	fake("ryoku-livewall", `printf '%s\n' "$*" > "`+liveLog+`"`)
	fake("ffmpeg", `for a in "$@"; do o="$a"; done; : > "$o"`)
	fake("pgrep", `exit 1`)
	fake("pkill", `exit 0`)
	fake("hyprctl", `printf '%s' '[{"width":1920,"scale":1}]'`)
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	vid := filepath.Join(t.TempDir(), "clip.mp4")
	if err := os.WriteFile(vid, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := (&daemon{}).showLiveWallpaper(vid); err != nil {
		t.Fatalf("showLiveWallpaper: %v", err)
	}

	// The launch is async (transcode off the hot path); wait for livewall to run.
	var got []byte
	for range 100 {
		if b, err := os.ReadFile(liveLog); err == nil && len(b) > 0 {
			got = b
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if !strings.Contains(string(got), ".mp4") || !strings.Contains(string(got), liveCapWidth()) {
		t.Errorf("livewall not launched with the transcoded clip + cap width %s: %q", liveCapWidth(), got)
	}
}

// A live-wall switch shows the clip's still, then the player launches over it and
// the backdrop steps aside only when the player reports its first painted frame
// (READY). Pins that handoff -- the surface is marked live after READY, so the
// clip shows through with no black seam.
func TestShowLiveWallpaperFlipsLiveAfterReady(t *testing.T) {
	bin := t.TempDir()
	state := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", state)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	liveLog := filepath.Join(state, "live.args")
	alive := filepath.Join(state, "live.alive")

	fake := func(name, body string) {
		if err := os.WriteFile(filepath.Join(bin, name), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	// The player records its argv, marks itself alive, reports READY on stdout,
	// and stays up; pgrep/pkill track the marker; ffmpeg yields the still + clip.
	fake("ryoku-livewall", `printf '%s\n' "$*" > "`+liveLog+`"; : > "`+alive+`"; printf 'READY\n'; sleep 2`)
	fake("ffmpeg", `for a in "$@"; do o="$a"; done; : > "$o"`)
	fake("pgrep", `[ -f "`+alive+`" ]`)
	fake("pkill", `rm -f "`+alive+`"; exit 0`)
	fake("hyprctl", `printf '%s' '[{"width":1920,"scale":1}]'`)
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	vid := filepath.Join(t.TempDir(), "clip.mp4")
	if err := os.WriteFile(vid, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	d := &daemon{wall: &wallSurface{cacheDir: t.TempDir()}, quit: make(chan struct{})}
	defer close(d.quit)
	if err := d.showLiveWallpaper(vid); err != nil {
		t.Fatalf("showLiveWallpaper: %v", err)
	}

	live := func() bool {
		d.wall.mu.Lock()
		defer d.wall.mu.Unlock()
		return d.wall.live
	}
	for range 200 {
		if live() {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Error("backdrop never stepped aside (live never set) after the player reported READY")
}

// A daemon restart orphans a running ryoku-livewall (KillMode=process), so the
// fresh daemon must re-adopt the survivor -- publish the clip's still and mark the
// surface live -- not restart it or (as it once did) return early and leave the
// fresh opaque backdrop covering the still-playing video, blacking out the desktop.
// Pins that init adopts: it marks the surface live and never relaunches or kills it.
func TestWallInitAdoptsSurvivingLivewall(t *testing.T) {
	bin := t.TempDir()
	state := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	t.Setenv("XDG_STATE_HOME", state)
	t.Setenv("XDG_CACHE_HOME", t.TempDir())
	liveLog := filepath.Join(state, "live.args")
	pkillLog := filepath.Join(state, "pkill.args")

	fake := func(name, body string) {
		if err := os.WriteFile(filepath.Join(bin, name), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	// A player is already alive (pgrep succeeds); record any relaunch and any pkill.
	fake("ryoku-livewall", `printf '%s\n' "$*" > "`+liveLog+`"`)
	fake("ffmpeg", `for a in "$@"; do o="$a"; done; : > "$o"`)
	fake("pgrep", `exit 0`)
	fake("pkill", `printf '%s\n' "$*" >> "`+pkillLog+`"; exit 0`)
	fake("hyprctl", `printf '%s' '[{"width":1920,"scale":1}]'`)
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	vid := filepath.Join(t.TempDir(), "clip.mp4")
	if err := os.WriteFile(vid, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(state, "ryoku-wallpaper"), []byte(vid+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	d := &daemon{wall: &wallSurface{cacheDir: t.TempDir()}, quit: make(chan struct{})}
	defer close(d.quit)
	d.wallInit()

	d.wall.mu.Lock()
	gotLive := d.wall.live
	d.wall.mu.Unlock()
	if !gotLive {
		t.Error("init did not mark the surface live for the surviving player: the fresh backdrop would cover the still-playing video")
	}
	if b, err := os.ReadFile(liveLog); err == nil && len(b) > 0 {
		t.Errorf("init relaunched the surviving player instead of adopting it: %q", b)
	}
	if b, _ := os.ReadFile(pkillLog); strings.Contains(string(b), liveDaemon) {
		t.Errorf("init killed the surviving player instead of adopting it; pkill calls:\n%s", b)
	}
}

// An update replaces the video backend (mpvpaper -> phonto -> ryoku-livewall)
// but cannot kill the detached player the old daemon left behind, and that
// orphan's background surface stacks above awww's, occluding every static set
// (the beta-16 -> beta-17 "wallpaper won't change" upgrade bug). The bootstrap
// pass reaps the legacy backends BEFORE the init apply: this pins the exact
// configuration where init early-returns (static state, awww alive) and would
// otherwise never reach a kill path, leaving the orphan on screen.
func TestWallInitReapsLegacyBackends(t *testing.T) {
	bin := t.TempDir()
	state := t.TempDir()
	t.Setenv("XDG_STATE_HOME", state)
	log := filepath.Join(state, "pkill.args")
	awwwLog := filepath.Join(state, "awww.args")
	fake := func(name, body string) {
		if err := os.WriteFile(filepath.Join(bin, name), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	fake("pkill", `printf '%s\n' "$*" >> "`+log+`"; exit 1`)
	fake("pgrep", `exit 1`)
	// awww is alive and answers query, so init takes its earliest image return.
	fake("awww", `printf '%s\n' "$*" >> "`+awwwLog+`"; exit 0`)
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	// saved wallpaper is a static image that exists.
	pic := filepath.Join(t.TempDir(), "still.jpg")
	if err := os.WriteFile(pic, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(state, "ryoku-wallpaper"), []byte(pic+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	(&daemon{}).wallInit()

	b, err := os.ReadFile(log)
	if err != nil {
		t.Fatalf("pkill never ran: %v", err)
	}
	for _, want := range []string{"-x mpvpaper", "-x phonto"} {
		if !strings.Contains(string(b), want) {
			t.Errorf("wallInit did not reap %q; pkill calls:\n%s", want, b)
		}
	}
	// the early return must hold: awww is only queried, never repainted.
	if aw, _ := os.ReadFile(awwwLog); strings.Contains(string(aw), "img") {
		t.Errorf("init repainted awww on the early-return path: %q", aw)
	}
}
