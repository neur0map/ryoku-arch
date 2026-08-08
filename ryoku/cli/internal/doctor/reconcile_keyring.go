package doctor

import (
	"strings"

	"ryoku-cli/internal/keyring"
)

// reconcileKeyring watches the GNOME keyring unlock policy for drift. It lets
// the keyring package converge the user side (record the inferred mode, point
// the default keyring at login for unlock-on-login) and only warns about what a
// reconciler must never touch on its own: the root SDDM PAM stack and a
// password-protected keyring. Every warning carries the exact command that
// resolves it. Idempotent.
func reconcileKeyring(checkOnly bool) recResult {
	d := keyring.Reconcile(checkOnly)
	switch {
	case len(d.Warnings) > 0:
		detail := strings.Join(d.Warnings, "; ")
		if len(d.Fixes) > 0 {
			detail += " (converged: " + strings.Join(d.Fixes, "; ") + ")"
		}
		r := warnRes("%s", detail)
		if d.Remedy != "" {
			r = r.withFix("%s", d.Remedy)
		}
		return r
	case len(d.Fixes) > 0:
		if checkOnly {
			return wouldRes("%s", strings.Join(d.Fixes, "; "))
		}
		return fixedRes("%s", strings.Join(d.Fixes, "; "))
	default:
		return okRes("keyring mode %s is consistent with the system wiring", d.Mode)
	}
}
