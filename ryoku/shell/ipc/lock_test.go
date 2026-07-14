package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// fakeLocker lays a stub lock.sh where lockSession looks for it. The script
// body decides whether and when the qylock "secure" marker appears.
func fakeLocker(t *testing.T, home, body string) {
	t.Helper()
	dir := filepath.Join(home, ".local", "share", "quickshell-lockscreen")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "lock.sh"), []byte("#!/bin/sh\n"+body), 0o755); err != nil {
		t.Fatal(err)
	}
}

// lockSession must hold hypridle's before_sleep_cmd until the compositor
// confirms the lock (the marker), not return the instant the locker spawns:
// returning early releases logind's sleep inhibitor while the desktop is
// still in the framebuffer.
func TestLockSessionWaitsForMarker(t *testing.T) {
	home := t.TempDir()
	run := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", run)
	old := lockWait
	lockWait = 2 * time.Second
	defer func() { lockWait = old }()

	// the locker confirms after 150ms, then stays up like the real one.
	fakeLocker(t, home, "sleep 0.15\numask 077\n: > \"$XDG_RUNTIME_DIR/qylock.locked\"\nsleep 2\n")

	start := time.Now()
	if got := lockSession(); got != "ok" {
		t.Fatalf("lockSession = %q, want ok", got)
	}
	elapsed := time.Since(start)
	if _, err := os.Stat(filepath.Join(run, "qylock.locked")); err != nil {
		t.Fatal("lockSession returned without the compositor-confirmed marker")
	}
	if elapsed < 100*time.Millisecond {
		t.Fatalf("returned in %v: did not wait for the lock to be confirmed", elapsed)
	}
	if elapsed >= lockWait {
		t.Fatalf("took %v: marker did not short-circuit the timeout", elapsed)
	}
}

// A marker left by a killed locker must not fake "locked": lockSession clears
// it before spawning, and a locker that never confirms only rides out the
// bounded wait (suspend is delayed, never blocked).
func TestLockSessionClearsStaleMarker(t *testing.T) {
	home := t.TempDir()
	run := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_RUNTIME_DIR", run)
	old := lockWait
	lockWait = 200 * time.Millisecond
	defer func() { lockWait = old }()

	marker := filepath.Join(run, "qylock.locked")
	if err := os.WriteFile(marker, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	spawned := filepath.Join(run, "spawned")
	// records the spawn, never confirms the lock.
	fakeLocker(t, home, ": > \""+spawned+"\"\nsleep 2\n")

	start := time.Now()
	if got := lockSession(); got != "ok" {
		t.Fatalf("lockSession = %q, want ok", got)
	}
	if time.Since(start) < lockWait {
		t.Fatal("a locker that never confirms must ride out the bounded wait")
	}
	if _, err := os.Stat(marker); err == nil {
		t.Fatal("stale marker survived: a dead locker's marker faked the locked state")
	}
	waitFor(t, spawned)
}

// waitFor polls briefly for a file the fake locker writes asynchronously.
func waitFor(t *testing.T, path string) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(path); err == nil {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("%s never appeared: lock.sh was not spawned", path)
}
