package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"strings"
)

const (
	bashLoader = `[ -r "$HOME/.config/bash/ryoku.bash" ] && . "$HOME/.config/bash/ryoku.bash"`
	zshLoader  = `[ -r "$HOME/.config/zsh/ryoku.zsh" ] && . "$HOME/.config/zsh/ryoku.zsh"`
)

var accountShells = map[string]string{
	"fish": "/usr/bin/fish",
	"bash": "/usr/bin/bash",
	"zsh":  "/usr/bin/zsh",
}

type shellChoice struct {
	Key       string `json:"key"`
	Label     string `json:"label"`
	Path      string `json:"path"`
	Installed bool   `json:"installed"`
}

type shellState struct {
	Current string        `json:"current"`
	Choices []shellChoice `json:"choices"`
}

func validateShellChoice(key string, choices map[string]string, shellsFile string) (string, error) {
	path, ok := choices[key]
	if !ok {
		return "", fmt.Errorf("shell must be fish, bash, or zsh")
	}
	if st, err := os.Stat(path); err != nil || st.IsDir() || st.Mode()&0o111 == 0 {
		return "", fmt.Errorf("%s is not installed", key)
	}
	b, err := os.ReadFile(shellsFile)
	if err != nil {
		return "", fmt.Errorf("read /etc/shells: %w", err)
	}
	for _, line := range strings.Split(string(b), "\n") {
		if strings.TrimSpace(line) == path {
			return path, nil
		}
	}
	return "", fmt.Errorf("%s is not listed in /etc/shells", path)
}

func ensureShellLoaders(home, key string) (bool, error) {
	var files map[string]string
	switch key {
	case "fish":
		return false, nil
	case "bash":
		files = map[string]string{
			filepath.Join(home, ".bashrc"):       bashLoader,
			filepath.Join(home, ".bash_profile"): bashLoader,
		}
	case "zsh":
		files = map[string]string{filepath.Join(home, ".zshrc"): zshLoader}
	default:
		return false, fmt.Errorf("unknown shell %q", key)
	}
	changed := false
	for path, line := range files {
		one, err := ensureLoaderLast(path, line)
		if err != nil {
			return false, err
		}
		changed = changed || one
	}
	return changed, nil
}

func ensureLoaderLast(path, line string) (bool, error) {
	var old []byte
	mode := os.FileMode(0o644)
	if st, err := os.Lstat(path); err == nil {
		if st.Mode()&os.ModeSymlink != 0 {
			return false, fmt.Errorf("refusing to replace symlink %s", path)
		}
		mode = st.Mode().Perm()
		old, err = os.ReadFile(path)
		if err != nil {
			return false, err
		}
	} else if !os.IsNotExist(err) {
		return false, err
	}

	var body strings.Builder
	for _, part := range strings.SplitAfter(string(old), "\n") {
		if strings.TrimSuffix(part, "\n") != line {
			body.WriteString(part)
		}
	}
	if body.Len() > 0 && !strings.HasSuffix(body.String(), "\n") {
		body.WriteByte('\n')
	}
	body.WriteString(line)
	body.WriteByte('\n')
	next := []byte(body.String())
	if string(next) == string(old) {
		return false, nil
	}
	tmp := path + ".ryoku-tmp"
	if err := os.WriteFile(tmp, next, mode); err != nil {
		return false, err
	}
	if err := os.Rename(tmp, path); err != nil {
		_ = os.Remove(tmp)
		return false, err
	}
	return true, nil
}

func shellKey(path string) string {
	for key, candidate := range accountShells {
		if path == candidate {
			return key
		}
	}
	return filepath.Base(path)
}

func passwdShell(path, username string) (string, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	for _, line := range strings.Split(string(b), "\n") {
		parts := strings.Split(line, ":")
		if len(parts) == 7 && parts[0] == username {
			return parts[6], nil
		}
	}
	return "", fmt.Errorf("user %s not found", username)
}

func runShellPref(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("shell needs get|set")
	}
	current, err := user.Current()
	if err != nil {
		return err
	}
	switch args[0] {
	case "get":
		path, err := passwdShell("/etc/passwd", current.Username)
		if err != nil {
			return err
		}
		state := shellState{Current: shellKey(path)}
		for _, key := range []string{"fish", "bash", "zsh"} {
			path := accountShells[key]
			_, err := os.Stat(path)
			state.Choices = append(state.Choices, shellChoice{Key: key, Label: strings.Title(key), Path: path, Installed: err == nil})
		}
		return json.NewEncoder(os.Stdout).Encode(state)
	case "set":
		if len(args) != 2 {
			return fmt.Errorf("shell set needs fish, bash, or zsh")
		}
		path, err := validateShellChoice(args[1], accountShells, "/etc/shells")
		if err != nil {
			return err
		}
		if _, err := ensureShellLoaders(current.HomeDir, args[1]); err != nil {
			return err
		}
		if err := escalateSelf("shell", "apply", args[1]); err != nil {
			return err
		}
		syncSessionShell(path)
		return nil
	case "apply":
		if len(args) != 2 || os.Geteuid() != 0 {
			return fmt.Errorf("shell apply requires privileged fish, bash, or zsh")
		}
		path, err := validateShellChoice(args[1], accountShells, "/etc/shells")
		if err != nil {
			return err
		}
		uid := os.Getenv("PKEXEC_UID")
		invoking, err := user.LookupId(uid)
		if err != nil || invoking.Uid == "0" {
			return fmt.Errorf("cannot resolve invoking user")
		}
		out, err := exec.Command("usermod", "-s", path, invoking.Username).CombinedOutput()
		if err != nil {
			return fmt.Errorf("set login shell: %v: %s", err, strings.TrimSpace(string(out)))
		}
		return nil
	default:
		return fmt.Errorf("shell needs get|set")
	}
}

var runSessionCommand = func(name string, args ...string) error {
	return exec.Command(name, args...).Run()
}

func syncSessionShell(path string) {
	_ = os.Setenv("SHELL", path)
	_ = runSessionCommand("systemctl", "--user", "set-environment", "SHELL="+path)
	_ = runSessionCommand("dbus-update-activation-environment", "--systemd", "SHELL="+path)
	_ = runSessionCommand("hyprctl", "eval", fmt.Sprintf("hl.env(%q, %q)", "SHELL", path))
	_ = runSessionCommand("ryoku", "reload")
}
