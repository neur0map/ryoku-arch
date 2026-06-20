package main

import (
	"encoding/json"
	"os"
	"path/filepath"
)

// runStatePath is the cross-process update-state file the shell's update island
// watches ($XDG_RUNTIME_DIR/ryoku-update.json). `ryoku update` writes its
// progress here so the island shows the Ryoku wave while a real update runs.
func runStatePath() string {
	d := os.Getenv("XDG_RUNTIME_DIR")
	if d == "" {
		d = "/tmp"
	}
	return filepath.Join(d, "ryoku-update.json")
}

// publishRun writes the island run state. phase is "running" or "idle"; progress
// is 0..1. Best-effort: a write failure never blocks the update.
func publishRun(phase string, progress float64) {
	b, err := json.Marshal(map[string]any{"phase": phase, "progress": progress})
	if err != nil {
		return
	}
	_ = os.WriteFile(runStatePath(), b, 0o644)
}
