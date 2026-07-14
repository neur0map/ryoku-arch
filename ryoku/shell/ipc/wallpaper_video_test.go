package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestIsVideo(t *testing.T) {
	cases := map[string]bool{
		"/x/a.mp4": true, "/x/a.MP4": true, "/x/a.webm": true,
		"/x/a.mkv": true, "/x/a.mov": true,
		"/x/a.jpg": false, "/x/a.png": false, "/x/a.gif": false, "/x/plain": false,
	}
	for p, want := range cases {
		if got := isVideo(p); got != want {
			t.Errorf("isVideo(%q) = %v, want %v", p, got, want)
		}
	}
}

func TestFrameOffset(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_STATE_HOME", dir)
	tune := filepath.Join(dir, "ryoku-wallust.json")
	video := "/home/x/Pictures/livewalls/clip.mp4"

	// no tune -> the auto default
	if got := frameOffset(video); got != "1" {
		t.Fatalf("no tune: got %q want 1", got)
	}
	// a tune for this video -> its chosen second
	_ = os.WriteFile(tune, []byte(`{"image":"`+video+`","frame":3.5}`), 0o644)
	if got := frameOffset(video); got != "3.50" {
		t.Fatalf("matching tune: got %q want 3.50", got)
	}
	// a tune keyed to another video never bleeds across
	if got := frameOffset("/home/x/other.mp4"); got != "1" {
		t.Fatalf("other video: got %q want 1", got)
	}
	// frame 0 falls back to the default
	_ = os.WriteFile(tune, []byte(`{"image":"`+video+`","frame":0}`), 0o644)
	if got := frameOffset(video); got != "1" {
		t.Fatalf("zero frame: got %q want 1", got)
	}
}

// livewallSource transcodes a clip once and caches it (keyed by path+mtime+cap): a
// second call reuses the cache without re-running ffmpeg.
func TestLivewallSource(t *testing.T) {
	bin := t.TempDir()
	cache := t.TempDir()
	t.Setenv("XDG_CACHE_HOME", cache)
	runs := filepath.Join(cache, "ffmpeg.runs")
	// fake ffmpeg: append a run marker, then create the output (its last arg).
	body := `printf x >> "` + runs + `"; for a in "$@"; do o="$a"; done; : > "$o"`
	if err := os.WriteFile(filepath.Join(bin, "ffmpeg"), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

	vid := filepath.Join(t.TempDir(), "clip.mp4")
	if err := os.WriteFile(vid, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	first := livewallSource(vid, "1280")
	if first == "" || !strings.HasSuffix(first, ".mp4") {
		t.Fatalf("first transcode returned %q", first)
	}
	if !strings.Contains(first, filepath.Join("ryoku", "livewall")) {
		t.Errorf("cache not under ryoku/livewall: %q", first)
	}
	if second := livewallSource(vid, "1280"); second != first {
		t.Errorf("cache key not stable: %q != %q", second, first)
	}
	if b, _ := os.ReadFile(runs); len(b) != 1 {
		t.Errorf("ffmpeg ran %d times, want 1 (miss then cache reuse)", len(b))
	}
}
