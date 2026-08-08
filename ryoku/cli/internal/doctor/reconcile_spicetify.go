package doctor

import (
	"bytes"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"ryoku-cli/internal/sys"
)

// reconcileSpicetifyCanvas wires the Ryoku Canvas spicetify extension for a user
// who runs Spotify, so the desktop music widget's "Spotify Canvas" backdrop works
// out of the box. Spotify's Canvas token is bot-gated, so the shell daemon cannot
// fetch it (ipc/music.go); the extension runs inside the spicetified client, where
// a valid session token exists, and relays the Canvas URL to the daemon's loopback
// endpoint (ryoku/apps/spicetify/ryoku-canvas.js).
//
// Gated on Spotify being installed -- nothing to spicetify otherwise. Every
// spicetify step is best-effort and bounded: a missing AUR helper, an unwritable
// Spotify install (root-owned /opt/spotify), a flatpak client spicetify cannot
// reach, or a Spotify update that invalidated the patch all degrade to a warning
// and NEVER block `ryoku update`. Idempotent: the extension is (re)placed, enabled
// and applied only when it is missing, stale, or not yet enabled.
func reconcileSpicetifyCanvas(checkOnly bool) recResult {
	if !spotifyInstalled() {
		return okRes("no Spotify installed; the Canvas spicetify setup is not needed")
	}
	src := spicetifyCanvasSource()
	if src == "" {
		return okRes("Canvas extension asset not present yet (ships with ryoku-desktop; arrives on the package update)")
	}
	extDir := filepath.Join(sys.ConfigHome(), "spicetify", "Extensions")
	dst := filepath.Join(extDir, "ryoku-canvas.js")

	needCli := !sys.Has("spicetify")
	needPlace := !sameBytes(src, dst)
	needEnable := !needCli && !spicetifyExtensionEnabled()
	if !needCli && !needPlace && !needEnable {
		return okRes("Ryoku Canvas spicetify extension is installed, enabled, and applied")
	}
	if checkOnly {
		var todo []string
		if needCli {
			todo = append(todo, "install spicetify-cli")
		}
		if needPlace {
			todo = append(todo, "place the Ryoku Canvas extension")
		}
		if needEnable {
			todo = append(todo, "enable + apply it")
		}
		return wouldRes("Spotify is installed but the Ryoku Canvas setup is incomplete: %s", strings.Join(todo, ", ")).
			withFix("ryoku doctor")
	}

	var did []string
	if needCli {
		if !installSpicetifyCli() {
			return warnRes("Spotify is installed but spicetify-cli is missing and could not be built from the AUR").
				withFix("install it by hand (yay -S spicetify-cli), then run `ryoku doctor`")
		}
		did = append(did, "installed spicetify-cli")
	}
	if err := os.MkdirAll(extDir, 0o755); err != nil {
		return warnRes("could not create %s: %v", extDir, err)
	}
	if err := sys.CopyFile(src, dst); err != nil {
		return warnRes("could not place the Ryoku Canvas extension at %s: %v", dst, err).
			withFix("copy %s to %s by hand", src, dst)
	}
	did = append(did, "placed the Ryoku Canvas extension")
	if !spicetifyExtensionEnabled() {
		_ = spicetifyRun(60*time.Second, "config", "extensions", "ryoku-canvas.js")
	}
	if err := spicetifyApply(); err != nil {
		return warnRes("the Ryoku Canvas extension is in place and enabled, but `spicetify apply` did not complete: %v", err).
			withFix("run `spicetify backup apply` once (a native /opt/spotify needs write access first: sudo chmod a+wr -R /opt/spotify /opt/spotify/Apps)")
	}
	did = append(did, "applied it to Spotify")
	return fixedRes("Ryoku Canvas: %s", strings.Join(did, ", "))
}

// spotifyInstalled reports whether any Spotify client is present: the native
// package, the launcher, or the flatpak.
func spotifyInstalled() bool {
	if sys.PkgInstalled("spotify") || sys.PkgInstalled("spotify-launcher") {
		return true
	}
	if sys.Has("flatpak") && exec.Command("flatpak", "info", "com.spotify.Client").Run() == nil {
		return true
	}
	return false
}

// spicetifyCanvasSource is the shipped ryoku-canvas.js: the package asset, else
// the checkout on a dev box.
func spicetifyCanvasSource() string {
	cands := []string{"/usr/share/ryoku/spicetify/ryoku-canvas.js"}
	if repo := sys.ResolveRepo(); repo != "" {
		cands = append(cands, filepath.Join(repo, "ryoku", "apps", "spicetify", "ryoku-canvas.js"))
	}
	for _, p := range cands {
		if sys.Exists(p) {
			return p
		}
	}
	return ""
}

// spicetifyExtensionEnabled reports whether ryoku-canvas.js is already in the
// spicetify extensions list, so enabling stays idempotent (the config verb
// appends, so a blind re-run would duplicate it).
func spicetifyExtensionEnabled() bool {
	out, err := sys.RunOut("spicetify", "config", "extensions")
	if err != nil {
		return false
	}
	return strings.Contains(out, "ryoku-canvas.js")
}

// installSpicetifyCli builds spicetify-cli from the AUR, bounded, with whatever
// helper is present. Best-effort: false when no helper or the build fails.
func installSpicetifyCli() bool {
	for _, helper := range []string{"yay", "paru"} {
		if !sys.Has(helper) {
			continue
		}
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		err := exec.CommandContext(ctx, helper, "-S", "--needed", "--noconfirm", "spicetify-cli").Run()
		cancel()
		if err == nil && sys.Has("spicetify") {
			return true
		}
	}
	return false
}

func spicetifyRun(timeout time.Duration, args ...string) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()
	return exec.CommandContext(ctx, "spicetify", args...).Run()
}

// spicetifyApply patches the Spotify client. A first-ever run needs `backup
// apply` to seed spicetify's backup; a later run is a plain `apply`. Both are
// bounded so a wedge cannot stall an update, and the caller treats any failure as
// advisory.
func spicetifyApply() error {
	if err := spicetifyRun(90*time.Second, "apply"); err == nil {
		return nil
	}
	return spicetifyRun(120*time.Second, "backup", "apply")
}

// sameBytes reports whether both paths exist with identical contents.
func sameBytes(a, b string) bool {
	ba, err := os.ReadFile(a)
	if err != nil {
		return false
	}
	bb, err := os.ReadFile(b)
	if err != nil {
		return false
	}
	return bytes.Equal(ba, bb)
}
