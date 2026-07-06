package main

import (
	"os"
	"path/filepath"
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
