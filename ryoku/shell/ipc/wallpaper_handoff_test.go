package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Setting a video shows the clip through awww (its own first frame) plus the
// ryoku-livewall daemon on top, and does NOT kill awww: the still under the video
// is the clip's content, so nothing stale bleeds through and a later image switch
// transitions from a real frame. livewall is launched off the hot path (after the
// transcode), so the assert polls for it. Runs against recording stand-ins on
// PATH, so it never touches the real wallpaper daemon.
func TestShowLiveWallpaperHandoff(t *testing.T) {
	bin := t.TempDir()
	state := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", t.TempDir()) // no ryowalls.json
	t.Setenv("XDG_STATE_HOME", state)        // isolate the extracted frame
	t.Setenv("XDG_CACHE_HOME", t.TempDir())  // isolate the transcode cache
	liveLog := filepath.Join(state, "live.args")
	awwwLog := filepath.Join(state, "awww.args")
	alive := filepath.Join(state, "live.alive")

	fake := func(name, body string) {
		if err := os.WriteFile(filepath.Join(bin, name), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	// ryoku-livewall records its argv; ffmpeg (the liveFrame extract AND the
	// livewall transcode) creates its output file (the last arg), so awww gets an
	// `img` and livewallSource yields a cached clip; awww answers `query` and
	// records the rest; pgrep/pkill track a marker.
	fake("ryoku-livewall", `printf '%s\n' "$*" > "`+liveLog+`"`)
	fake("ffmpeg", `for a in "$@"; do o="$a"; done; : > "$o"`)
	fake("awww", `case "$1" in query) exit 0 ;; *) printf '%s\n' "$*" >> "`+awwwLog+`" ;; esac`)
	fake("pgrep", `[ -f "`+alive+`" ]`)
	fake("pkill", `rm -f "`+alive+`"; exit 0`)
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
	aw, err := os.ReadFile(awwwLog)
	if err != nil || !strings.Contains(string(aw), "img") {
		t.Errorf("awww did not paint the clip's frame under the video: %q err=%v", aw, err)
	}
	if strings.Contains(string(aw), "kill") {
		t.Errorf("awww must stay up under the video (its still is the clip's frame), not be killed: %q", aw)
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
