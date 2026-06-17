package main

import (
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// The wallpaper daemon Ryoku drives. Kept as a constant so swapping it (swww, etc.)
// is a one-line change.
const (
	wallDaemon      = "awww"
	wallDaemonStart = "awww-daemon"
)

func wallDir() string   { return filepath.Join(os.Getenv("HOME"), "Ryoku", "wallpapers") }
func wallState() string { return filepath.Join(stateDir(), "ryoku-wallpaper") }
func wallBag() string   { return filepath.Join(stateDir(), "ryoku-wallpaper-bag") }

// wallpaperApply selects a wallpaper per mode (init, set, next) and applies it,
// then rethemes with wallust and reloads Hyprland. It is best-effort: a missing
// wallpaper directory or daemon is a no-op rather than an error.
func wallpaperApply(mode, arg string) error {
	wasRunning := wallDaemonAlive()
	if !ensureWallDaemon() {
		return nil
	}

	var pic string
	switch mode {
	case "init":
		if wasRunning {
			return nil
		}
		if cur := readState(); cur != "" && isFile(cur) {
			pic = cur
		} else {
			pic = popBag()
		}
	case "set":
		if !isFile(arg) {
			return nil
		}
		pic = arg
	default: // next
		pic = popBag()
	}
	if pic == "" {
		return nil
	}

	if err := exec.Command(wallDaemon, "img", pic,
		"--transition-type", "wave",
		"--transition-angle", "30",
		"--transition-wave", "60,30",
		"--transition-fps", "60",
		"--transition-step", "90").Run(); err != nil {
		return err
	}

	_ = os.MkdirAll(stateDir(), 0o755)
	_ = os.WriteFile(wallState(), []byte(pic+"\n"), 0o644)
	_ = exec.Command("wallust", "run", pic).Run()
	_ = exec.Command("hyprctl", "reload").Run()
	return nil
}

func wallDaemonAlive() bool {
	return exec.Command(wallDaemon, "query").Run() == nil
}

func ensureWallDaemon() bool {
	if wallDaemonAlive() {
		return true
	}
	for attempt := 0; attempt < 5; attempt++ {
		cmd := exec.Command(wallDaemonStart)
		_ = cmd.Start()
		if cmd.Process != nil {
			_ = cmd.Process.Release()
		}
		for i := 0; i < 15; i++ {
			if wallDaemonAlive() {
				return true
			}
			time.Sleep(200 * time.Millisecond)
		}
	}
	return false
}

func listPics() []string {
	var pics []string
	_ = filepath.WalkDir(wallDir(), func(p string, info os.DirEntry, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		switch strings.ToLower(filepath.Ext(p)) {
		case ".jpg", ".jpeg", ".png":
			pics = append(pics, p)
		}
		return nil
	})
	return pics
}

// popBag returns the next wallpaper from a shuffled bag, refilling and reshuffling
// when the bag runs out so every wallpaper shows once per cycle.
func popBag() string {
	for refilled := false; ; {
		lines := readLines(wallBag())
		if len(lines) == 0 {
			if refilled {
				return ""
			}
			refillBag()
			refilled = true
			continue
		}
		pic := lines[0]
		writeLines(wallBag(), lines[1:])
		if isFile(pic) {
			return pic
		}
	}
}

func refillBag() {
	pics := listPics()
	if len(pics) == 0 {
		return
	}
	rand.Shuffle(len(pics), func(i, j int) { pics[i], pics[j] = pics[j], pics[i] })
	if cur := readState(); cur != "" && len(pics) > 1 && pics[0] == cur {
		pics = append(pics[1:], cur)
	}
	_ = os.MkdirAll(stateDir(), 0o755)
	writeLines(wallBag(), pics)
}

func readState() string {
	b, err := os.ReadFile(wallState())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func readLines(path string) []string {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var out []string
	for _, l := range strings.Split(string(b), "\n") {
		if l = strings.TrimSpace(l); l != "" {
			out = append(out, l)
		}
	}
	return out
}

func writeLines(path string, lines []string) {
	data := ""
	if len(lines) > 0 {
		data = strings.Join(lines, "\n") + "\n"
	}
	_ = os.WriteFile(path, []byte(data), 0o644)
}

func isFile(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}
