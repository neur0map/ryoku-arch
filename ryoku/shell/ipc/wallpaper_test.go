package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestPickTransitionNeverRepeats(t *testing.T) {
	d := &daemon{}
	prev := -1
	for i := 0; i < 1000; i++ {
		if args := d.pickTransition(); args == nil {
			t.Fatal("pickTransition returned nil with presets defined")
		}
		if d.lastTransition == prev {
			t.Fatalf("transition %d repeated back-to-back", d.lastTransition)
		}
		prev = d.lastTransition
	}
}

func TestPresetsShareOneSpeed(t *testing.T) {
	// shared speed enforcement. no preset carries its own --transition-duration
	// or --transition-fps (showWallpaper appends those), so all presets stay
	// in lockstep.
	for _, p := range transitionPresets {
		for _, a := range p.args {
			if a == "--transition-duration" || a == "--transition-fps" {
				t.Fatalf("preset %q sets %s itself; speed must stay shared", p.name, a)
			}
		}
	}
}

func TestTuneArgsPerImageGuard(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_STATE_HOME", dir)

	wall := "/home/x/Pictures/Wallpapers/current.jpg"
	if err := os.WriteFile(filepath.Join(dir, "ryoku-wallpaper"), []byte(wall+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	write := func(js string) {
		if err := os.WriteFile(filepath.Join(dir, "ryoku-wallust.json"), []byte(js), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	has := func(args []string, flag, val string) bool {
		for i := 0; i+1 < len(args); i++ {
			if args[i] == flag && args[i+1] == val {
				return true
			}
		}
		return false
	}

	// matching image -> flags apply
	write(`{"image":"` + wall + `","palette":"harddark16","saturation":85}`)
	got := tuneArgs()
	if !has(got, "-p", "harddark16") || !has(got, "--saturation", "85") {
		t.Fatalf("matching image should yield flags, got %v", got)
	}

	// different image -> no flags
	write(`{"image":"/home/x/Pictures/Wallpapers/other.jpg","palette":"harddark16"}`)
	if got := tuneArgs(); got != nil {
		t.Fatalf("foreign image should yield nil, got %v", got)
	}

	// legacy file, no image -> no flags (stale-file safety)
	write(`{"palette":"harddarkcomp16","saturation":17}`)
	if got := tuneArgs(); got != nil {
		t.Fatalf("image-less file should yield nil, got %v", got)
	}
}

func TestWallpaperRepaintSignalsPaintOnly(t *testing.T) {
	d := &daemon{paintSig: make(chan struct{}, 1)}
	if err := d.wallpaperApply("repaint", ""); err != nil {
		t.Fatalf("repaint returned error: %v", err)
	}
	select {
	case <-d.paintSig:
		// signalled, as expected
	default:
		t.Fatal("repaint did not schedule the paint worker")
	}
}
