package sys

import (
	"io"
	"os"
	"os/exec"
	"path/filepath"
)

// BaseConfigDir is the package's base config tree that materialize lays into
// ~/.config. On a dev checkout RYOKU_CONFIG_BASE points at the repo copy; on a
// packaged install it is /usr/share/ryoku/config, shipped by ryoku-desktop.
func BaseConfigDir() string {
	if v := os.Getenv("RYOKU_CONFIG_BASE"); v != "" {
		return v
	}
	return "/usr/share/ryoku/config"
}

// CopyFile copies src to dst, preserving src's permission bits, via a temp file
// and atomic rename so a reader never sees a half-written file.
func CopyFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	si, err := in.Stat()
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	tmp := dst + ".ryoku-tmp"
	out, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, si.Mode().Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		os.Remove(tmp)
		return err
	}
	if err := out.Close(); err != nil {
		os.Remove(tmp)
		return err
	}
	return os.Rename(tmp, dst)
}

// HyprLive reports whether a Hyprland session is reachable for hyprctl.
func HyprLive() bool {
	return Has("hyprctl") && exec.Command("hyprctl", "version").Run() == nil
}
