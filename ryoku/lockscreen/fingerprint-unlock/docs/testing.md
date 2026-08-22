# Testing Checklist

Run `./install.sh`, then `systemctl --user restart ryoku-shell`.
Enroll one finger first (Settings → Lockscreen → Fingerprint).

## 1. Enrollment

- [ ] ENROLL FINGERPRINT opens the modal; ring spins while waiting
- [ ] each accepted touch advances the ring (`n/total`); total appears within ~2s
- [ ] lifting early shows retry guidance ("lift and touch again", "too short", ...)
- [ ] completion swaps the ring for a check and asks to name the print
- [ ] SAVE stores the label; SKIP stores the raw name; both close + refresh list

## 2. Lock screen (the core fix)

- [ ] lock (`Super+L` or `loginctl lock-session`)
- [ ] hint appears **without touching anything**: pulsing "SENSOR ACTIVE · TOUCH OR TYPE"
- [ ] touch once → reveal plays, session unlocks (no Enter, no password)
- [ ] lock again → type the password instead → unlocks mid-scan
- [ ] lock again → wrong password → ACCESS DENIED → sensor re-arms by itself
- [ ] repeat lock/unlock 5×: every fresh lock accepts touch on the FIRST try

## 3. Sudo / SDDM toggles

- [ ] polkit prompt appears on toggle; cancelling shows a gentle error, state unchanged
- [ ] sudo ON: `sudo -k && sudo true` → touch works; OFF: back to password
- [ ] `/etc/pam.d/sudo.ryoku-fp-bak` exists after first change
- [ ] toggle state survives page reopen (grep-based status read)
- [ ] a pre-existing grosshack line in `/etc/pam.d/sddm` shows ON before any click
- [ ] removal deletes only the grosshack line (diff against the `.ryoku-fp-bak`)

## 4. Prints management

- [ ] two-step delete: ✕ → SURE? (3s window) → removed; label gone from list too
- [ ] REMOVE ALL same pattern; list empties, empty-state text appears
- [ ] VERIFY per finger and VERIFY ALL show MATCH / NO MATCH plate; auto-closes on match
- [ ] friendly names survive hub restarts (`~/.config/qylock/fingerprints.json`)

## 5. Regression / edge cases

- [ ] fingerprint disabled (toggle off): lock shows no hint, password only
- [ ] no fingers enrolled: prints column explains itself; enroll still offered
- [ ] fprintd stopped (`systemctl stop fprintd`): section says so, RETRY works
- [ ] SDDM greeter sign-in unaffected by the settings changes
- [ ] Escape closes the modal when idle; ABORT stops enroll mid-run
