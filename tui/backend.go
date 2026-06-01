package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// ryokuPath resolves the installed Ryoku checkout.
func ryokuPath() string {
	if p := os.Getenv("RYOKU_PATH"); p != "" {
		return p
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "ryoku")
}

// gitCmd builds a git command pinned to the Ryoku checkout that NEVER prompts
// for credentials. Without this, a CI token that leaked into the shipped .git
// makes `git fetch` 401 and hang the TUI on a username prompt at startup.
func gitCmd(args ...string) *exec.Cmd {
	c := exec.Command("git", append([]string{"-C", ryokuPath()}, args...)...)
	c.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_ASKPASS=/bin/true",
		"GCM_INTERACTIVE=never",
	)
	return c
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
	out, err := gitCmd("rev-parse", "--abbrev-ref", "HEAD").Output()
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
	if out, err := gitCmd("rev-parse", "--short", "HEAD").Output(); err == nil {
		if s := strings.TrimSpace(string(out)); s != "" {
			return "g" + s
		}
	}
	return "unknown"
}

func sudoCached() bool {
	return exec.Command("sudo", "-n", "true").Run() == nil
}

// checkUpdateAvailable does a quiet fetch of the active channel and reports
// whether the local checkout is behind origin (a newer version exists) and by
// how many commits. Best-effort: any failure (offline, no git) reports "no
// update" rather than erroring.
func checkUpdateAvailable() (bool, int) {
	ch := detectChannel()
	_ = gitCmd("-c", "gc.auto=0", "fetch", "--quiet", "origin", ch).Run()
	out, err := gitCmd("rev-list", "--count", "HEAD..origin/"+ch).Output()
	if err != nil {
		return false, 0
	}
	n, _ := strconv.Atoi(strings.TrimSpace(string(out)))
	return n > 0, n
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

// stripCarriage collapses a line that used \r to redraw (progress bars) down to
// its final rendered segment, and trims a trailing \r.
func stripCarriage(s string) string {
	s = strings.TrimRight(s, "\r")
	if i := strings.LastIndex(s, "\r"); i >= 0 {
		s = s[i+1:]
	}
	return s
}
