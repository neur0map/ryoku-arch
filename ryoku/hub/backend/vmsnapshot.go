package main

// vmsnapshot.go: the VM's disk-state quality-of-life layer. The persistent
// qcow2 already survives across launches; this adds the controls that make that
// persistence usable: named snapshots to roll back to (internal qcow2 snapshots
// via qemu-img, the same disk for windowed and passthrough), and a reset that
// wipes the disk back to an empty machine. All of it operates on the powered-off
// disk file, so every entry point refuses while the VM is running.

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Snapshot is one restore point on the VM disk, as shown in the Hub.
type Snapshot struct {
	Name string `json:"name"`
	Date string `json:"date"`
}

func runVMSnapshot(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("vm snapshot needs list|create|restore|delete")
	}
	v := loadVM()
	switch args[0] {
	case "list":
		snaps, err := listSnapshots(v)
		if err != nil {
			return err
		}
		return printJSON(snaps)
	case "create":
		if len(args) < 2 {
			return fmt.Errorf("vm snapshot create needs a name")
		}
		return createSnapshot(v, args[1])
	case "restore":
		if len(args) < 2 {
			return fmt.Errorf("vm snapshot restore needs a name")
		}
		return restoreSnapshot(v, args[1])
	case "delete":
		if len(args) < 2 {
			return fmt.Errorf("vm snapshot delete needs a name")
		}
		return deleteSnapshot(v, args[1])
	default:
		return fmt.Errorf("unknown vm snapshot subcommand: %s", args[0])
	}
}

// listSnapshots returns the disk's restore points, newest first. A VM that has
// never launched has no disk yet, which is not an error: it lists as empty.
func listSnapshots(v VM) ([]Snapshot, error) {
	if v.DiskPath == "" || !fileExists(v.DiskPath) {
		return []Snapshot{}, nil
	}
	out, err := exec.Command("qemu-img", "info", "--output=json", v.DiskPath).Output()
	if err != nil {
		return nil, fmt.Errorf("reading the VM disk failed: %w", err)
	}
	return parseSnapshots(out)
}

// parseSnapshots maps `qemu-img info --output=json` into the Hub's shape. A disk
// with no snapshots omits the key entirely, so the result is an empty (never
// nil) slice that marshals to [].
func parseSnapshots(b []byte) ([]Snapshot, error) {
	var info struct {
		Snapshots []struct {
			Name    string `json:"name"`
			DateSec int64  `json:"date-sec"`
		} `json:"snapshots"`
	}
	if err := json.Unmarshal(b, &info); err != nil {
		return nil, fmt.Errorf("parsing the disk info failed: %w", err)
	}
	snaps := make([]Snapshot, 0, len(info.Snapshots))
	for _, s := range info.Snapshots {
		snaps = append(snaps, Snapshot{
			Name: s.Name,
			Date: time.Unix(s.DateSec, 0).Format("2006-01-02 15:04"),
		})
	}
	return snaps, nil
}

func createSnapshot(v VM, name string) error {
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("a snapshot needs a name")
	}
	if vmRunning(v) {
		return fmt.Errorf("stop the VM before taking a snapshot")
	}
	if v.DiskPath == "" || !fileExists(v.DiskPath) {
		return fmt.Errorf("the VM has no disk yet; launch it once first")
	}
	// qemu-img happily creates a second snapshot with the same name (a distinct
	// id), which the Hub then cannot address unambiguously, so reject duplicates
	// up front.
	snaps, err := listSnapshots(v)
	if err != nil {
		return err
	}
	for _, s := range snaps {
		if s.Name == name {
			return fmt.Errorf("a snapshot named %q already exists", name)
		}
	}
	return qemuImg("snapshot", "-c", name, v.DiskPath)
}

func restoreSnapshot(v VM, name string) error {
	if vmRunning(v) {
		return fmt.Errorf("stop the VM before restoring a snapshot")
	}
	if v.DiskPath == "" || !fileExists(v.DiskPath) {
		return fmt.Errorf("the VM has no disk to restore")
	}
	return qemuImg("snapshot", "-a", name, v.DiskPath)
}

func deleteSnapshot(v VM, name string) error {
	if vmRunning(v) {
		return fmt.Errorf("stop the VM before deleting a snapshot")
	}
	if v.DiskPath == "" || !fileExists(v.DiskPath) {
		return fmt.Errorf("the VM has no disk")
	}
	return qemuImg("snapshot", "-d", name, v.DiskPath)
}

// vmReset wipes the VM back to an empty machine: it removes the disk (and every
// snapshot inside it) and the UEFI variable store, then recreates a fresh empty
// disk so the machine stays configured and ready to reinstall.
func vmReset(v VM) error {
	if vmRunning(v) {
		return fmt.Errorf("stop the VM before resetting it")
	}
	if v.DiskPath == "" {
		return fmt.Errorf("the VM has no disk path")
	}
	if err := os.Remove(v.DiskPath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("removing the VM disk failed: %w", err)
	}
	// the OVMF vars remember boot entries pointing at the old install; drop them
	// so the next launch boots a pristine firmware, not a dangling boot order.
	vars := filepath.Join(vmDataDir(), v.Name+"_VARS.fd")
	if err := os.Remove(vars); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("removing the VM firmware store failed: %w", err)
	}
	return ensureDisk(v)
}

// qemuImg runs a qemu-img subcommand and surfaces its stderr, which is already
// phrased for a person (for example "snapshot not found").
func qemuImg(args ...string) error {
	cmd := exec.Command("qemu-img", args...)
	var stderr strings.Builder
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		if msg := strings.TrimSpace(stderr.String()); msg != "" {
			return fmt.Errorf("%s", msg)
		}
		return err
	}
	return nil
}
