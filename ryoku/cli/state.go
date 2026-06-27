package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"time"
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

// answerPath is the back-channel a prompt phase is answered on: the Hub (or a
// terminal) writes the chosen option label here, and `ryoku update` reads it.
func answerPath() string {
	d := os.Getenv("XDG_RUNTIME_DIR")
	if d == "" {
		d = "/tmp"
	}
	return filepath.Join(d, "ryoku-update-answer")
}

// publishPrompt writes a "prompt" phase the Hub renders as a question with option
// buttons. Any prior answer is cleared first so a stale click cannot satisfy this
// prompt. Best-effort, like publishRun.
func publishPrompt(id, title, detail string, options []string) {
	_ = os.Remove(answerPath())
	b, err := json.Marshal(map[string]any{
		"phase":    "prompt",
		"progress": 0.0,
		"prompt":   map[string]any{"id": id, "title": title, "detail": detail, "options": options},
	})
	if err != nil {
		return
	}
	_ = os.WriteFile(runStatePath(), b, 0o644)
}

// awaitAnswer blocks until the back-channel carries a choice or timeout elapses,
// then clears it. Returns the chosen option label and true, or "" and false on
// timeout (the caller then treats it as a decline).
func awaitAnswer(timeout time.Duration) (string, bool) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if b, err := os.ReadFile(answerPath()); err == nil {
			choice := strings.TrimSpace(string(b))
			_ = os.Remove(answerPath())
			if choice != "" {
				return choice, true
			}
		}
		time.Sleep(300 * time.Millisecond)
	}
	return "", false
}
