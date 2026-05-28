package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

// ryokuPath resolves the installed Ryoku checkout.
func ryokuPath() string {
	if p := os.Getenv("RYOKU_PATH"); p != "" {
		return p
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "ryoku")
}

func stateDir() string {
	if p := os.Getenv("XDG_STATE_HOME"); p != "" {
		return p
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "state")
}

func detectChannel() string {
	b, err := os.ReadFile(filepath.Join(stateDir(), "ryoku", "channel"))
	if err == nil {
		if s := strings.TrimSpace(string(b)); s != "" {
			return s
		}
	}
	out, err := exec.Command("git", "-C", ryokuPath(), "rev-parse", "--abbrev-ref", "HEAD").Output()
	if err == nil {
		if s := strings.TrimSpace(string(out)); s != "" {
			return s
		}
	}
	return "main"
}

func detectVersion() string {
	// ryoku-version is the canonical source (it reads $RYOKU_PATH/.version,
	// then falls back to a short git SHA + the literal "preview" if neither
	// is present). Use it first so the header matches what `ryoku-version`
	// prints elsewhere in the system.
	if out, err := exec.Command("ryoku-version").Output(); err == nil {
		if s := strings.TrimSpace(string(out)); s != "" {
			return s
		}
	}
	for _, name := range []string{".version", "version"} {
		b, err := os.ReadFile(filepath.Join(ryokuPath(), name))
		if err == nil {
			if s := strings.TrimSpace(string(b)); s != "" {
				return s
			}
		}
	}
	if out, err := exec.Command("git", "-C", ryokuPath(), "rev-parse", "--short", "HEAD").Output(); err == nil {
		if s := strings.TrimSpace(string(out)); s != "" {
			return "g" + s
		}
	}
	return "unknown"
}

func sudoCached() bool {
	return exec.Command("sudo", "-n", "true").Run() == nil
}

// commandFor maps a menu item to the engine that backs it. All of these are
// handed the real terminal via tea.ExecProcess so they render full-fidelity.
func commandFor(it menuItem) (string, []string, []string) {
	switch it.key {
	case "update":
		// ryoku-update draws its own scroll-region dashboard (RYOKU ascii) and
		// logs itself to update.log via its internal `script` wrapper.
		return "ryoku-update", []string{"-y"}, []string{"RYOKU_TUI=1"}
	case "doctor":
		return "ryoku-doctor", nil, []string{"RYOKU_TUI=1"}
	case "recovery":
		return "ryoku-call911now", nil, []string{"RYOKU_TUI=1"}
	case "packages":
		// gpk is itself a TUI ("eye-candy package viewer"); it needs the
		// terminal, so it is handed over like the others (not detached).
		return "gpk", nil, nil
	}
	return "true", nil, nil
}

func updateLogPath() string {
	if p := os.Getenv("RYOKU_UPDATE_LOG"); p != "" {
		return p
	}
	return filepath.Join(stateDir(), "quickshell", "user", "update.log")
}

// runLogPath is where the TUI tees a doctor/recovery run so the Logs view can
// replay it (update has its own update.log; gpk has no log).
func runLogPath(key string) string {
	return filepath.Join(stateDir(), "quickshell", "user", "ryoku-tui-"+key+".log")
}

// ensureRunLog returns runLogPath(key) after making sure its directory exists.
func ensureRunLog(key string) string {
	p := runLogPath(key)
	_ = os.MkdirAll(filepath.Dir(p), 0o755)
	return p
}

// readLogFile loads a captured log for the Logs viewport (tail-limited, with
// progress-bar carriage returns collapsed).
func readLogFile(path string) []string {
	if path == "" {
		path = updateLogPath()
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return []string{styWarn.Render("No log found yet at " + path)}
	}
	lines := strings.Split(strings.TrimRight(string(b), "\n"), "\n")
	const tail = 1200
	if len(lines) > tail {
		lines = lines[len(lines)-tail:]
	}
	for i := range lines {
		lines[i] = stripCarriage(lines[i])
	}
	return lines
}

// launchDetached starts a GUI/program in its own session so it outlives the TUI.
func launchDetached(name string) error {
	path, err := exec.LookPath(name)
	if err != nil {
		return err
	}
	cmd := exec.Command(path)
	devnull, _ := os.Open(os.DevNull)
	cmd.Stdin = devnull
	cmd.Stdout = nil
	cmd.Stderr = nil
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	return cmd.Start()
}

// stripCarriage collapses a line that used \r to redraw (progress bars) down to
// its final rendered segment, and trims a trailing \r.
func stripCarriage(s string) string {
	s = strings.TrimRight(s, "\r")
	if i := strings.LastIndex(s, "\r"); i >= 0 {
		s = s[i+1:]
	}
	return s
}
