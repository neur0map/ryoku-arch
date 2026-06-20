package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestParseProcSwaps(t *testing.T) {
	in := "Filename\t\t\t\tType\t\tSize\t\tUsed\t\tPriority\n" +
		"/swap/swapfile                          file\t\t16777212\t1744224\t\t-1\n" +
		"/dev/nvme0n1p3                          partition\t8388604\t0\t\t-2\n" +
		"/var/lib/with\\040space/swapfile         file\t\t1024\t\t0\t\t-3\n"
	got := parseProcSwaps(in)
	if len(got) != 2 {
		t.Fatalf("got %d file swaps, want 2 (partition excluded): %+v", len(got), got)
	}
	if got[0].path != "/swap/swapfile" || got[0].sizeKB != 16777212 {
		t.Errorf("first swap = %+v, want path /swap/swapfile size 16777212", got[0])
	}
	if got[1].path != "/var/lib/with space/swapfile" {
		t.Errorf("escaped path = %q, want the \\040 unescaped to a space", got[1].path)
	}
}

func TestParseProcSwapsHeaderOnly(t *testing.T) {
	if got := parseProcSwaps("Filename Type Size Used Priority\n"); len(got) != 0 {
		t.Errorf("header-only input should yield no swaps, got %+v", got)
	}
}

func TestDirOnlyContains(t *testing.T) {
	dir := t.TempDir()
	if dirOnlyContains(dir, "swapfile") {
		t.Error("empty dir should not report only-contains")
	}
	if err := os.WriteFile(filepath.Join(dir, "swapfile"), []byte("x"), 0o600); err != nil {
		t.Fatal(err)
	}
	if !dirOnlyContains(dir, "swapfile") {
		t.Error("dir holding only the swapfile should match")
	}
	// A second file must block the auto-fix so surgery never runs on a shared dir.
	if err := os.WriteFile(filepath.Join(dir, "other"), []byte("y"), 0o600); err != nil {
		t.Fatal(err)
	}
	if dirOnlyContains(dir, "swapfile") {
		t.Error("dir with an extra file must not match")
	}
}
