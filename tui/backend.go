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

// commandFor maps a menu item to the bash engine that backs it. Each engine is
// run with its own gum/dashboard UI disabled so its plain output can be
// captured into the viewport.
func commandFor(it menuItem) (string, []string, []string) {
	switch it.key {
	case "update":
		return "ryoku-update", []string{"-y"}, []string{
			"RYOKU_UPDATE_DASHBOARD=0",
			"RYOKU_TUI=1",
		}
	case "doctor":
		return "ryoku-doctor", nil, []string{
			"RYOKU_DOCTOR_PLAIN=1",
			"RYOKU_TUI=1",
		}
	case "recovery":
		return "ryoku-call911now", nil, []string{
			"RYOKU_TUI=1",
		}
	}
	return "true", nil, nil
}

func readLog() []string {
	path := os.Getenv("RYOKU_UPDATE_LOG")
	if path == "" {
		path = filepath.Join(stateDir(), "quickshell", "user", "update.log")
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return []string{styWarn.Render("No update log found at " + path)}
	}
	lines := strings.Split(strings.TrimRight(string(b), "\n"), "\n")
	const tail = 800
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
