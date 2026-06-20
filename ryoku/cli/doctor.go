package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

// ryoku doctor runs convergent reconcilers: idempotent fixes for stateful drift
// that `ryoku update` and `ryoku materialize` cannot express declaratively (disk
// layout and the like). Each reconciler reports "ok" when the machine already
// matches the desired state, otherwise it converges (or, with --check, reports
// what it would do). Reconcilers are safe to run on every update; retire one once
// every supported install has run it, so the set stays small instead of piling up
// like an ordered migration ledger.

type recStatus int

const (
	recOK recStatus = iota
	recFixed
	recWouldFix
	recWarn
	recFailed
)

type recResult struct {
	status recStatus
	detail string
}

func okRes(f string, a ...any) recResult    { return recResult{recOK, fmt.Sprintf(f, a...)} }
func fixedRes(f string, a ...any) recResult { return recResult{recFixed, fmt.Sprintf(f, a...)} }
func wouldRes(f string, a ...any) recResult { return recResult{recWouldFix, fmt.Sprintf(f, a...)} }
func warnRes(f string, a ...any) recResult  { return recResult{recWarn, fmt.Sprintf(f, a...)} }
func failRes(f string, a ...any) recResult  { return recResult{recFailed, fmt.Sprintf(f, a...)} }

type reconciler struct {
	name string
	run  func(checkOnly bool) recResult
}

func reconcilers() []reconciler {
	return []reconciler{
		{"swap kept out of snapshots", reconcileSwapSubvolume},
	}
}

// cmdDoctor runs every reconciler. `--check` (or `-n`) reports without changing
// anything.
func cmdDoctor(args []string) error {
	checkOnly := false
	for _, a := range args {
		if a == "--check" || a == "-n" || a == "--dry-run" {
			checkOnly = true
		}
	}
	if runDoctor(checkOnly, false) {
		return fmt.Errorf("one or more checks failed; see the output above")
	}
	return nil
}

// runDoctor runs the reconcilers and prints one line each. quiet drops the
// "already ok" lines when called from `ryoku update`. It returns whether any
// reconciler failed; the update caller ignores that so a finding never aborts an
// update.
func runDoctor(checkOnly, quiet bool) bool {
	anyFailed := false
	for _, r := range reconcilers() {
		res := r.run(checkOnly)
		switch res.status {
		case recOK:
			if !quiet {
				fmt.Printf("  ok    %s: %s\n", r.name, res.detail)
			}
		case recFixed:
			fmt.Printf("  fixed %s: %s\n", r.name, res.detail)
		case recWouldFix:
			fmt.Printf("  todo  %s: %s\n", r.name, res.detail)
		case recWarn:
			fmt.Fprintf(os.Stderr, "  warn  %s: %s\n", r.name, res.detail)
		case recFailed:
			anyFailed = true
			fmt.Fprintf(os.Stderr, "  fail  %s: %s\n", r.name, res.detail)
		}
	}
	return anyFailed
}

// --- reconciler: keep the swapfile out of snapshotted subvolumes --------------

// reconcileSwapSubvolume relocates a swapfile that lives inside @ (the
// snapshotted root) into its own btrfs subvolume. btrfs cannot snapshot a
// subvolume that holds an active swapfile, so the old installer layout made every
// snapper snapshot fail. Only the exact layout the old installer produced (a
// single swapfile in a plain directory on btrfs) is auto-fixed; anything else is
// reported for a human. It no-ops once the swapfile already sits in its own
// subvolume, and skips machines that do not snapshot root.
func reconcileSwapSubvolume(checkOnly bool) recResult {
	if !exists("/etc/snapper/configs/root") {
		return okRes("root snapshots not configured, nothing to keep out of them")
	}
	for _, sw := range activeSwapFiles() {
		dir := filepath.Dir(sw.path)
		if !isBtrfs(dir) || isBtrfsSubvolumeRoot(dir) {
			continue // not btrfs, or already its own subvolume: nothing to do
		}
		if !dirOnlyContains(dir, filepath.Base(sw.path)) {
			return warnRes("swapfile %s blocks snapshots; move it into its own subvolume by hand (%s holds other files)", sw.path, dir)
		}
		if checkOnly {
			return wouldRes("swapfile %s sits in snapshotted %s; would move it into its own btrfs subvolume", sw.path, dir)
		}
		if err := relocateSwapToSubvolume(sw, dir); err != nil {
			return failRes("relocating %s: %v", sw.path, err)
		}
		return fixedRes("moved %s into its own btrfs subvolume so snapshots work", sw.path)
	}
	return okRes("swap is out of snapshots")
}

type swapFile struct {
	path   string
	sizeKB int64
}

func activeSwapFiles() []swapFile {
	b, err := os.ReadFile("/proc/swaps")
	if err != nil {
		return nil
	}
	return parseProcSwaps(string(b))
}

// parseProcSwaps returns the file-backed swaps from /proc/swaps content. The
// first line is a header; the path field escapes spaces as \040.
func parseProcSwaps(s string) []swapFile {
	var out []swapFile
	sc := bufio.NewScanner(strings.NewReader(s))
	for i := 0; sc.Scan(); i++ {
		if i == 0 {
			continue
		}
		f := strings.Fields(sc.Text())
		if len(f) < 3 || f[1] != "file" {
			continue
		}
		size, err := strconv.ParseInt(f[2], 10, 64)
		if err != nil {
			continue
		}
		out = append(out, swapFile{path: strings.ReplaceAll(f[0], `\040`, " "), sizeKB: size})
	}
	return out
}

// isBtrfs reports whether path lives on a btrfs filesystem.
func isBtrfs(path string) bool {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err != nil {
		return false
	}
	return int64(st.Type) == 0x9123683E // BTRFS_SUPER_MAGIC
}

// isBtrfsSubvolumeRoot reports whether path is the root of a btrfs subvolume;
// those always carry inode 256.
func isBtrfsSubvolumeRoot(path string) bool {
	var st syscall.Stat_t
	if err := syscall.Stat(path, &st); err != nil {
		return false
	}
	return st.Ino == 256
}

func dirOnlyContains(dir, name string) bool {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return false
	}
	return len(entries) == 1 && entries[0].Name() == name
}

// relocateSwapToSubvolume swaps off the file, turns its directory into a btrfs
// subvolume, recreates the swapfile inside it at the same path and size, and
// swaps it back on. The path is unchanged, so the fstab swap entry still resolves
// and the nested subvolume appears with its parent: no fstab edit is needed.
func relocateSwapToSubvolume(sw swapFile, dir string) error {
	steps := [][]string{
		{"swapoff", sw.path},
		{"rm", "-f", sw.path},
		{"rmdir", dir},
		{"btrfs", "subvolume", "create", dir},
		{"btrfs", "filesystem", "mkswapfile", "--size", fmt.Sprintf("%dk", sw.sizeKB), sw.path},
		{"swapon", sw.path},
	}
	for _, s := range steps {
		if err := run("sudo", s...); err != nil {
			return fmt.Errorf("%s: %w", strings.Join(s, " "), err)
		}
	}
	return nil
}
