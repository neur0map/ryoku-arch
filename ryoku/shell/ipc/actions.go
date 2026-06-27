package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// shellDir (RYOKU_SHELL_DIR): run components straight out of a repo checkout
// (qs -p <dir>/quickshell/<name>) instead of an installed config under
// ~/.config. empty in a deployed setup.
var shellDir = os.Getenv("RYOKU_SHELL_DIR")

// qsSelect: qs config selector for a component. by repo path in dev, by config
// name when deployed.
func qsSelect(name string) []string {
	if shellDir != "" {
		return []string{"-p", filepath.Join(shellDir, "quickshell", name)}
	}
	return []string{"-c", name}
}

// ipcCall: invoke a Quickshell IpcHandler function. component may have just
// been started, so it retries briefly until the instance answers.
func ipcCall(config, target, fn, arg string) string {
	argv := append(qsSelect(config), "ipc", "call", target, fn)
	if arg != "" {
		argv = append(argv, arg)
	}
	var out []byte
	var err error
	for i := 0; i < 10; i++ {
		out, err = exec.Command("qs", argv...).CombinedOutput()
		if err == nil {
			return "ok"
		}
		time.Sleep(150 * time.Millisecond)
	}
	msg := strings.TrimSpace(string(out))
	if msg == "" {
		msg = err.Error()
	}
	return "err qs ipc " + config + "/" + fn + ": " + msg
}

// ipcCallN = ipcCall for IpcHandler functions that take more than one arg
// (e.g. pluginPopout(mon, id)). empty trailing args still go positionally.
func ipcCallN(config, target, fn string, args ...string) string {
	argv := append(qsSelect(config), "ipc", "call", target, fn)
	argv = append(argv, args...)
	var out []byte
	var err error
	for i := 0; i < 10; i++ {
		out, err = exec.Command("qs", argv...).CombinedOutput()
		if err == nil {
			return "ok"
		}
		time.Sleep(150 * time.Millisecond)
	}
	msg := strings.TrimSpace(string(out))
	if msg == "" {
		msg = err.Error()
	}
	return "err qs ipc " + config + "/" + fn + ": " + msg
}

// activeMonitor: name of the monitor holding the focused workspace.
func activeMonitor() string {
	out, err := exec.Command("hyprctl", "activeworkspace", "-j").Output()
	if err != nil {
		return ""
	}
	var w struct {
		Monitor string `json:"monitor"`
	}
	if json.Unmarshal(out, &w) != nil {
		return ""
	}
	return w.Monitor
}

// lockSession locks the screen with qylock, the in-session lock Ryoku ships.
// the shell has no lock of its own.
func lockSession() string {
	if pgrepRunning("quickshell.*quickshell-lockscreen.*/lock_shell.qml") {
		return "ok"
	}
	lock := filepath.Join(os.Getenv("HOME"), ".local", "share", "quickshell-lockscreen", "lock.sh")
	cmd := exec.Command(lock)
	if err := cmd.Start(); err != nil {
		return "err lock: " + err.Error()
	}
	if cmd.Process != nil {
		_ = cmd.Process.Release()
	}
	return "ok"
}

// toggleHandy flips Handy transcription on the running instance (the Super+`
// tap). Handy is an optional AUR app (handy-bin); when absent this is a no-op
// and the voice visualizer keeps working as a plain mic meter. the flag is
// forwarded to the already-running instance via Handy's single-instance plugin,
// so the process started here exits right away.
func toggleHandy() {
	if _, err := exec.LookPath("handy"); err != nil {
		return
	}
	cmd := exec.Command("handy", "--toggle-transcription")
	if err := cmd.Start(); err != nil {
		return
	}
	// reap the short-lived forwarder in the background, else it lingers as a
	// zombie; toggleHandy fires twice per dictation (key down + key up).
	go func() { _ = cmd.Wait() }()
}

// startCliphist starts the wl-paste watchers that feed clipboard history, once.
func startCliphist() {
	for _, kind := range []string{"text", "image"} {
		pattern := "wl-paste --type " + kind + " --watch cliphist"
		if pgrepRunning(pattern) {
			continue
		}
		cmd := exec.Command("wl-paste", "--type", kind, "--watch", "cliphist", "store")
		_ = cmd.Start()
		if cmd.Process != nil {
			_ = cmd.Process.Release()
		}
	}
}

func pgrepRunning(pattern string) bool {
	return exec.Command("pgrep", "-f", pattern).Run() == nil
}

func stateDir() string {
	if d := os.Getenv("XDG_STATE_HOME"); d != "" {
		return d
	}
	return filepath.Join(os.Getenv("HOME"), ".local", "state")
}
