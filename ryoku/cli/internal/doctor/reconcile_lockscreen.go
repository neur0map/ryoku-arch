package doctor

import (
	"os"
	"os/exec"
	"path/filepath"

	"ryoku-cli/internal/sys"
)

// ---- reconciler: the in-session lockscreen -----------------------------------
//
// `ryoku-shell lock` execs ~/.local/share/quickshell-lockscreen/lock.sh, and
// only the ISO installer ever laid that down. A box that predates the step, or
// where it failed, has a dead lock button and, worse, suspends without locking:
// hypridle's before_sleep runs the same command. The bundle now ships in
// ryoku-desktop (and lives in a checkout), so this can heal it anywhere.

func lockerPath() string {
	return filepath.Join(os.Getenv("HOME"), ".local", "share", "quickshell-lockscreen", "lock.sh")
}

func legacyTapePath() string {
	return filepath.Join(os.Getenv("HOME"), ".local", "share", "qylock", "themes", "clockwork", "tape", "Main.qml")
}

func needsLockscreenInstaller(lockerPresent, legacyTape bool) bool {
	return !lockerPresent || legacyTape
}

// lockscreenInstaller finds the shipped installer: the package payload first,
// the checkout on a dev box.
func lockscreenInstaller() string {
	if p := "/usr/share/ryoku/lockscreen/install-qylock"; sys.Exists(p) {
		return p
	}
	if repo := sys.ResolveRepo(); repo != "" {
		if p := filepath.Join(repo, "ryoku", "lockscreen", "install-qylock"); sys.Exists(p) {
			return p
		}
	}
	return ""
}

func reconcileLockscreen(checkOnly bool) recResult {
	lockerPresent := sys.Exists(lockerPath())
	legacyTape := sys.Exists(legacyTapePath())
	if !needsLockscreenInstaller(lockerPresent, legacyTape) {
		return okRes("in-session lockscreen installed")
	}
	installer := lockscreenInstaller()
	if installer == "" {
		if legacyTape {
			return warnRes("the legacy Tape lockscreen needs migration and no lockscreen bundle is available").
				withFix("ryoku update (ships the lockscreen bundle), then ryoku doctor")
		}
		return warnRes("the in-session lockscreen is missing and no bundle is available to install it; the lock button and lock-on-sleep do nothing").
			withFix("ryoku update (ships the lockscreen bundle), then ryoku doctor")
	}
	if checkOnly {
		if legacyTape {
			return wouldRes("the legacy Tape lockscreen needs one-time Store migration").
				withFix("ryoku doctor")
		}
		return wouldRes("the in-session lockscreen is missing; the lock button and lock-on-sleep do nothing").
			withFix("ryoku doctor")
	}
	// RYOKU_QYLOCK_USER_ONLY skips the SDDM greeter half: it needs root, the
	// installer already did it at install time, and a user-session doctor run
	// must not hang on a sudo prompt.
	cmd := exec.Command(installer)
	cmd.Env = append(os.Environ(), "RYOKU_QYLOCK_USER_ONLY=1")
	if out, err := cmd.CombinedOutput(); err != nil {
		return failRes("lockscreen install failed: %v (%s)", err, firstLine(string(out))).
			withFix("run %s by hand to see why", installer)
	}
	if !sys.Exists(lockerPath()) {
		return failRes("lockscreen installer ran but %s did not appear", lockerPath())
	}
	if legacyTape && !sys.Exists(legacyTapePath()) {
		return fixedRes("migrated the legacy Tape lockscreen into Store ownership")
	}
	if lockerPresent {
		return okRes("in-session lockscreen installed; custom legacy Tape retained")
	}
	return fixedRes("installed the in-session lockscreen; the lock button and lock-on-sleep work again")
}
