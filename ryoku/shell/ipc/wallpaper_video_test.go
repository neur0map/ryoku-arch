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

// phontoArgs and mpvOpts must honour the ryowalls fit knob: phonto adds --scale
// fit only for "fit" (fill is its default); mpv maps fit to panscan and keeps
// hwdec + the mpris suppression.
func TestLiveLaunchArgs(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	rj := filepath.Join(cfg, "ryoku", "ryowalls.json")
	if err := os.MkdirAll(filepath.Dir(rj), 0o755); err != nil {
		t.Fatal(err)
	}
	vid := "/home/x/Pictures/livewalls/clip.mp4"

	// default (fill): phonto gets the clip alone; mpv hwdecs and fills.
	if got := strings.Join(phontoArgs(vid), " "); got != vid {
		t.Errorf("phonto fill must be the clip alone: %q", got)
	}
	if got := mpvOpts(); !strings.Contains(got, "hwdec=auto") || !strings.Contains(got, "panscan=1.0") {
		t.Errorf("mpv default must hwdec + fill (panscan 1.0): %q", got)
	}
	if got := mpvOpts(); !strings.Contains(got, "no-config") || !strings.Contains(got, "load-scripts=no") {
		t.Errorf("mpv opts must suppress mpris (no-config load-scripts=no): %q", got)
	}

	// fit: phonto adds --scale fit; mpv letterboxes (panscan 0.0).
	if err := os.WriteFile(rj, []byte(`{"liveFit":"fit"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := strings.Join(phontoArgs(vid), " "); got != vid+" --scale fit" {
		t.Errorf("phonto fit must add --scale fit: %q", got)
	}
	if got := mpvOpts(); !strings.Contains(got, "panscan=0.0") {
		t.Errorf("mpv fit must set panscan 0.0: %q", got)
	}
}
