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

// UserEditsDir is the user's override tree, ~/.config/ryoku/user_edits, mirroring
// ~/.config. A regular file here wins over the Ryoku-owned base materialize lays
// (a fork); the tool's native last-wins include (settings.lua, user.lua,
// kitty user.conf) layers the rest on top so base fixes still land. Sparse by
// design: absent or empty means the machine runs pure base and the overlay is a
// no-op, so an update behaves exactly as it did before this existed.
func UserEditsDir() string {
	return filepath.Join(ConfigHome(), "ryoku", "user_edits")
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
