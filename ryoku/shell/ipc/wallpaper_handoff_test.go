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
	if !strings.Contains(string(got), ".mp4") || !strings.Contains(string(got), liveCapWidth) {
		t.Errorf("livewall not launched with the transcoded clip + cap width %s: %q", liveCapWidth, got)
	}
	aw, err := os.ReadFile(awwwLog)
	if err != nil || !strings.Contains(string(aw), "img") {
		t.Errorf("awww did not paint the clip's frame under the video: %q err=%v", aw, err)
	}
	if strings.Contains(string(aw), "kill") {
		t.Errorf("awww must stay up under the video (its still is the clip's frame), not be killed: %q", aw)
	}
}
