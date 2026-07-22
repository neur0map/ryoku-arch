package keyring

import "fmt"

// Drift is what a convergence pass found: the safe user-side changes it made
// (or would make in check-only), and the things it must not touch on its own --
// the root PAM stack and password-protected keyrings -- each with the exact
// command that fixes it.
type Drift struct {
	Fixes    []string
	Warnings []string
	Remedy   string
	Mode     string
}

// Reconcile converges the user side of the keyring policy and reports the drift
// a reconciler must warn about but never fix silently. Safe, idempotent, and
// scoped to the user's own files: it records the inferred mode when nothing is
// recorded yet, and repoints the default keyring at login for unlock-on-login.
// It never edits /etc/pam.d/sddm (root) or rekeys a keyring (needs a password);
// those surface as warnings with the command that resolves them. checkOnly
// reports the intended fixes without applying them.
func Reconcile(checkOnly bool) Drift {
	st := gatherStatus()
	d := Drift{Mode: st.Mode}

	// record the inferred mode so the choice is explicit and stable across
	// updates. Once written, later passes see it as configured and no-op.
	if st.ModeSource == "inferred" {
		if checkOnly {
			d.Fixes = append(d.Fixes, fmt.Sprintf("record the inferred mode (%s) in keyring.json", st.Mode))
		} else if err := writeConfig(st.Mode); err == nil {
			d.Fixes = append(d.Fixes, fmt.Sprintf("recorded the inferred mode (%s) in keyring.json", st.Mode))
		} else {
			d.Warnings = append(d.Warnings, fmt.Sprintf("could not record the keyring mode: %v", err))
		}
	}

	// unlock-on-login needs the default alias pointing at the login keyring, so
	// apps that ask for the default get the PAM-unlocked store. A safe, user-side
	// file write.
	if st.Mode == ModeUnlockOnLogin && defaultKeyringName() != "login" {
		if checkOnly {
			d.Fixes = append(d.Fixes, "point the default keyring at login")
		} else if _, changed, err := pointDefaultAt("login"); err != nil {
			d.Warnings = append(d.Warnings, fmt.Sprintf("could not point the default keyring at login: %v", err))
		} else if changed {
			d.Fixes = append(d.Fixes, "pointed the default keyring at login")
		}
	}

	// PAM drift: the stack is a root file, so doctor only warns and hands over
	// the exact privileged command.
	wantPAM := st.Mode == ModeUnlockOnLogin
	if st.PamPresent != wantPAM {
		verb := "still carries"
		if wantPAM {
			verb = "does not carry"
		}
		d.Warnings = append(d.Warnings, fmt.Sprintf("the SDDM PAM stack %s pam_gnome_keyring but mode is %s", verb, st.Mode))
		d.Remedy = fmt.Sprintf("sudo ryoku keyring apply-pam %s", st.Mode)
	}

	// autologin + unlock-on-login cannot work: there is no login password for
	// PAM to reuse under autologin.
	if st.Autologin && st.Mode == ModeUnlockOnLogin {
		d.Warnings = append(d.Warnings, "autologin is configured but mode is unlock-on-login, which has no login password to reuse; switch to never-ask")
		if d.Remedy == "" {
			d.Remedy = "ryoku keyring set never-ask"
		}
	}

	// never-ask needs the default-pointed keyring blank; an encrypted one needs a
	// password to convert, which doctor never has.
	if st.Mode == ModeNeverAsk {
		for _, k := range st.Keyrings {
			if k.Role == "default" && k.Format == fmtEncrypted {
				d.Warnings = append(d.Warnings, fmt.Sprintf("the %q keyring is still password-protected but mode is never-ask; convert or reset it", k.Name))
				if d.Remedy == "" {
					d.Remedy = "ryoku keyring set never-ask --convert  (or --reset to start fresh)"
				}
			}
		}
	}

	return d
}
