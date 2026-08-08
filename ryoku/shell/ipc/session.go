package main

import (
	"encoding/json"
	"log"
	"os/exec"
	"strings"
)

// session.go runs the session power actions the confirmation dialog triggers:
// logout, reboot, and shutdown. Each maps to the documented systemctl
// invocation and is fire-and-forget, matching the reference's three helper
// functions (spawn a process, log a non-zero exit, never block the caller).
// Reboot and poweroff tear the session down, so the reply is best-effort.
//
// There is deliberately no suspend action: the reference tree has none (no
// suspend helper, no quick-action, no systemctl suspend), so Ryoku adds none.
var sessionActions = map[string][]string{
	"logout":   {"systemctl", "--user", "exit"},
	"reboot":   {"systemctl", "reboot"},
	"shutdown": {"systemctl", "poweroff"},
}

// sessionActionArgv returns the argv for a session power action, or false for an
// unknown one. Split from the exec so the documented mapping is unit-testable
// without powering the machine off.
func sessionActionArgv(action string) ([]string, bool) {
	argv, ok := sessionActions[action]
	return argv, ok
}

// startSession registers the session power-action calls. QML's confirmation
// dialog invokes `call session.<action>` once the user confirms; the daemon runs
// the documented systemctl command. Registration only: no process is spawned
// here, so it is always safe to wire in.
func (d *daemon) startSession() {
	for action := range sessionActions {
		action := action
		d.registerCall("session."+action, func(json.RawMessage) (any, error) {
			runSessionAction(action)
			return map[string]any{"ok": true}, nil
		})
	}
}

// runSessionAction fires the action's command and reaps it in the background, so
// a failure is logged without blocking the caller (reboot and poweroff normally
// never return). stderr is captured for the log; stdin and stdout are discarded.
func runSessionAction(action string) {
	argv, ok := sessionActionArgv(action)
	if !ok {
		log.Printf("ryoku-shell: unknown session action %q", action)
		return
	}
	cmd := exec.Command(argv[0], argv[1:]...)
	var stderr strings.Builder
	cmd.Stderr = &stderr
	if err := cmd.Start(); err != nil {
		log.Printf("ryoku-shell: session %s: %v", action, err)
		return
	}
	go func() {
		if err := cmd.Wait(); err != nil {
			log.Printf("ryoku-shell: session %s: %v: %s", action, err, strings.TrimSpace(stderr.String()))
		}
	}()
}
