package main

import (
	"path/filepath"
	"testing"
	"time"
)

func TestParseSnapshots(t *testing.T) {
	// shape from `qemu-img info --output=json`: names may contain spaces, the
	// date comes from date-sec, and a disk with no snapshots omits the key.
	const withSnaps = `{"snapshots":[
		{"name":"clean install","date-sec":1782754145,"date-nsec":817025000,"id":"1","vm-state-size":0},
		{"name":"before-update","date-sec":1782754146,"date-nsec":822966000,"id":"2","vm-state-size":0}
	]}`
	got, err := parseSnapshots([]byte(withSnaps))
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 2 {
		t.Fatalf("got %d snapshots, want 2: %+v", len(got), got)
	}
	if got[0].Name != "clean install" || got[1].Name != "before-update" {
		t.Errorf("names = %q, %q", got[0].Name, got[1].Name)
	}
	wantDate := time.Unix(1782754145, 0).Format("2006-01-02 15:04")
	if got[0].Date != wantDate {
		t.Errorf("date = %q, want %q (from date-sec)", got[0].Date, wantDate)
	}

	// a fresh disk has no "snapshots" key: an empty, non-nil slice (marshals []).
	empty, err := parseSnapshots([]byte(`{"format":"qcow2"}`))
	if err != nil {
		t.Fatal(err)
	}
	if empty == nil || len(empty) != 0 {
		t.Errorf("no-snapshots disk = %+v, want empty non-nil slice", empty)
	}

	if _, err := parseSnapshots([]byte("not json")); err == nil {
		t.Error("expected an error on unparseable disk info")
	}
}

func TestListSnapshotsNoDisk(t *testing.T) {
	v := VM{Name: "ghost", Display: "windowed", DiskPath: filepath.Join(t.TempDir(), "absent.qcow2")}
	snaps, err := listSnapshots(v)
	if err != nil {
		t.Fatalf("listing a VM with no disk should not error: %v", err)
	}
	if len(snaps) != 0 {
		t.Errorf("absent disk listed %d snapshots", len(snaps))
	}
}

// the full lifecycle against the real qemu-img, the only way to prove the create
// guard, restore, and delete behave as the Hub assumes.
func TestSnapshotLifecycle(t *testing.T) {
	if !lookPath("qemu-img") {
		t.Skip("qemu-img not installed")
	}
	dir := t.TempDir()
	t.Setenv("XDG_DATA_HOME", dir) // vmReset resolves the firmware-store path here
	v := VM{Name: "t", Display: "windowed", DiskPath: filepath.Join(dir, "t.qcow2"), DiskGB: 1}
	if err := ensureDisk(v); err != nil {
		t.Fatal(err)
	}

	if snaps, _ := listSnapshots(v); len(snaps) != 0 {
		t.Fatalf("new disk already has %d snapshots", len(snaps))
	}
	if err := createSnapshot(v, "clean"); err != nil {
		t.Fatalf("create: %v", err)
	}
	snaps, err := listSnapshots(v)
	if err != nil || len(snaps) != 1 || snaps[0].Name != "clean" {
		t.Fatalf("after create: snaps=%+v err=%v", snaps, err)
	}
	if err := createSnapshot(v, "clean"); err == nil {
		t.Error("duplicate snapshot name should be rejected")
	}
	if err := createSnapshot(v, "   "); err == nil {
		t.Error("blank snapshot name should be rejected")
	}
	if err := restoreSnapshot(v, "clean"); err != nil {
		t.Errorf("restore: %v", err)
	}
	if err := restoreSnapshot(v, "nope"); err == nil {
		t.Error("restoring a missing snapshot should error")
	}
	if err := deleteSnapshot(v, "clean"); err != nil {
		t.Errorf("delete: %v", err)
	}
	if snaps, _ := listSnapshots(v); len(snaps) != 0 {
		t.Errorf("snapshot survived delete: %+v", snaps)
	}
	if err := deleteSnapshot(v, "nope"); err == nil {
		t.Error("deleting a missing snapshot should error")
	}
}

func TestVMResetWipesSnapshots(t *testing.T) {
	if !lookPath("qemu-img") {
		t.Skip("qemu-img not installed")
	}
	dir := t.TempDir()
	t.Setenv("XDG_DATA_HOME", dir)
	v := VM{Name: "t", Display: "windowed", DiskPath: filepath.Join(dir, "t.qcow2"), DiskGB: 1}
	if err := ensureDisk(v); err != nil {
		t.Fatal(err)
	}
	if err := createSnapshot(v, "keep"); err != nil {
		t.Fatal(err)
	}
	if err := vmReset(v); err != nil {
		t.Fatalf("reset: %v", err)
	}
	if !fileExists(v.DiskPath) {
		t.Error("reset should leave a fresh empty disk in place")
	}
	if snaps, _ := listSnapshots(v); len(snaps) != 0 {
		t.Errorf("reset left %d snapshots behind", len(snaps))
	}
}
