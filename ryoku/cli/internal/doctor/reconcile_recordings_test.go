package doctor

import (
	"os"
	"path/filepath"
	"testing"
)

// fixture builds an isolated HOME with a Ryoku Motion sink of its own.
func recFixture(t *testing.T) (home, dir, motion string) {
	t.Helper()
	home = t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_VIDEOS_DIR", "")
	t.Setenv("RYOKU_SHELL_RECORDINGS_DIR", "")
	dir = filepath.Join(home, "Videos", "Recordings")
	motion = filepath.Join(home, ".config", "ryomotion", "recordings")
	if err := os.MkdirAll(motion, 0o755); err != nil {
		t.Fatal(err)
	}
	return home, dir, motion
}

// TestRecordingsFoldsMotionIn: Ryoku Motion cannot be told where to record, so
// its directory becomes a link into the one directory and what it already
// recorded moves across. Nothing may be lost on the way.
func TestRecordingsFoldsMotionIn(t *testing.T) {
	_, dir, motion := recFixture(t)
	for _, n := range []string{"recording-1.webm", "recording-1.session.json"} {
		if err := os.WriteFile(filepath.Join(motion, n), []byte(n), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	if got := reconcileRecordingsDir(true); got.status != recWouldFix {
		t.Fatalf("check-only should report a fix, got %v (%s)", got.status, got.detail)
	}
	if _, err := os.Lstat(filepath.Join(motion, "recording-1.webm")); err != nil {
		t.Fatal("check-only must not move anything")
	}

	if got := reconcileRecordingsDir(false); got.status != recFixed {
		t.Fatalf("apply should fix, got %v (%s)", got.status, got.detail)
	}
	for _, n := range []string{"recording-1.webm", "recording-1.session.json"} {
		if _, err := os.Stat(filepath.Join(dir, n)); err != nil {
			t.Errorf("%s did not reach %s", n, dir)
		}
	}
	fi, err := os.Lstat(motion)
	if err != nil || fi.Mode()&os.ModeSymlink == 0 {
		t.Fatalf("Ryoku Motion's directory should be a symlink now: %v", err)
	}
	if target, _ := os.Readlink(motion); target != dir {
		t.Errorf("symlink points at %q, want %q", target, dir)
	}

	// Idempotent: a second pass has nothing left to do.
	if got := reconcileRecordingsDir(false); got.status != recOK {
		t.Errorf("second pass should be a no-op, got %v (%s)", got.status, got.detail)
	}
}

// TestRecordingsNeverOverwrites: a name already taken in the target must not
// clobber the file that is there.
func TestRecordingsNeverOverwrites(t *testing.T) {
	_, dir, motion := recFixture(t)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	keep := filepath.Join(dir, "clip.mp4")
	if err := os.WriteFile(keep, []byte("original"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(motion, "clip.mp4"), []byte("incoming"), 0o644); err != nil {
		t.Fatal(err)
	}

	reconcileRecordingsDir(false)

	if b, _ := os.ReadFile(keep); string(b) != "original" {
		t.Fatalf("the existing recording was overwritten: %q", b)
	}
	if b, err := os.ReadFile(filepath.Join(dir, "clip-1.mp4")); err != nil || string(b) != "incoming" {
		t.Errorf("the incoming recording should land beside it as clip-1.mp4: %v %q", err, b)
	}
}

// TestRecordingsHonoursTheSetting: the Hub's `directory` key is what everything
// resolves, so the reconciler has to follow it too.
func TestRecordingsHonoursTheSetting(t *testing.T) {
	home, _, _ := recFixture(t)
	custom := filepath.Join(home, "Clips")
	if err := os.MkdirAll(filepath.Join(home, ".config", "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(home, ".config", "ryoku", "recording.json"),
		[]byte(`{"fps":60,"directory":"`+custom+`"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if got := recordingsDir(); got != custom {
		t.Fatalf("recordingsDir() = %q, want the configured %q", got, custom)
	}
	reconcileRecordingsDir(false)
	if _, err := os.Stat(custom); err != nil {
		t.Errorf("the configured directory was not created: %v", err)
	}
	if target, _ := os.Readlink(filepath.Join(home, ".config", "ryomotion", "recordings")); target != custom {
		t.Errorf("Ryoku Motion points at %q, want %q", target, custom)
	}
}

// TestRecordingsLeavesForeignSinkAlone: gpu-screen-recorder's own default is
// reported, never migrated, since someone may be running it deliberately.
func TestRecordingsLeavesForeignSinkAlone(t *testing.T) {
	home, _, _ := recFixture(t)
	stray := filepath.Join(home, "Videos", "ScreenRecordings")
	if err := os.MkdirAll(stray, 0o755); err != nil {
		t.Fatal(err)
	}
	clip := filepath.Join(stray, "2026_07_26_14_26_17_record.mp4")
	if err := os.WriteFile(clip, []byte("x"), 0o644); err != nil {
		t.Fatal(err)
	}
	got := reconcileRecordingsDir(false)
	if got.status != recNote {
		t.Fatalf("a foreign sink should be a note, got %v (%s)", got.status, got.detail)
	}
	if _, err := os.Stat(clip); err != nil {
		t.Error("the foreign recording must be left where it is")
	}
	if got.remedy == "" {
		t.Error("the note should carry the command to move them")
	}
}
