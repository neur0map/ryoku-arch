package sys

import (
	"os"
	"path/filepath"
	"syscall"
)

// Home is the user's home directory.
func Home() string {
	if h, err := os.UserHomeDir(); err == nil {
		return h
	}
	return os.Getenv("HOME")
}

// Xdg returns envVar's value, or Home()/fallback when it is unset.
func Xdg(envVar, fallback string) string {
	if v := os.Getenv(envVar); v != "" {
		return v
	}
	return filepath.Join(Home(), fallback)
}

// ConfigHome is $XDG_CONFIG_HOME (default ~/.config).
func ConfigHome() string { return Xdg("XDG_CONFIG_HOME", ".config") }

// StateDir is the CLI's state root, $XDG_STATE_HOME/ryoku (default
// ~/.local/state/ryoku).
func StateDir() string {
	return filepath.Join(Xdg("XDG_STATE_HOME", ".local/state"), "ryoku")
}

// IsBtrfs reports whether path lives on a btrfs filesystem.
func IsBtrfs(path string) bool {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err != nil {
		return false
	}
	return int64(st.Type) == 0x9123683E // BTRFS_SUPER_MAGIC
}

// IsBtrfsSubvolumeRoot reports whether path is the root of a btrfs subvolume:
// those always carry inode 256.
func IsBtrfsSubvolumeRoot(path string) bool {
	var st syscall.Stat_t
	if err := syscall.Stat(path, &st); err != nil {
		return false
	}
	return st.Ino == 256
}
