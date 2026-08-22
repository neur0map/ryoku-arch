# Architecture

## The grosshack mechanism

`pam_fprintd_grosshack.so` is a patched `pam_fprintd`: at conversation start
it forks `fprintd-verify` **and** presents the password prompt. The sensor
scans while `pam_unix` waits — either success ends the conversation:

```
auth  sufficient  pam_fprintd_grosshack.so   touch -> success
auth  sufficient  pam_unix.so                password -> success
```

## PAM services

| Service | File | Loaded by |
|---|---|---|
| lock screen | `~/.local/share/quickshell-lockscreen/assets/pam/ryoku-lock` | `PamContext.configDirectory` (no `/etc/pam.d` edit) |
| sudo / sddm | `/etc/pam.d/sudo`, `/etc/pam.d/sddm` | one injected line via pkexec |

`ryoku-lock` stack:

```
auth        sufficient  pam_fprintd_grosshack.so
auth        sufficient  pam_unix.so try_first_pass nullok
auth        required    pam_env.so
auth        required    pam_deny.so
account     required    pam_unix.so
password    required    pam_deny.so
session     required    pam_unix.so
```

Quickshell forks a subprocess per conversation which calls
`pam_start_confdir(config, user, conv, configDirectory)` then
`pam_authenticate`. Signals surface as QML properties: `active`,
`responseRequired`, `message`; results arrive in `onCompleted`
(`PamResult.Success/Failed/MaxTries`) and failures without completion in
`onError`.

## Arm lifecycle (lock screen)

```
Super+L -> ryoku-shell lock -> WlSessionLock.secure == true
    -> shim.armWhenReady = true          (onArmWhenReadyChanged)
    -> maybeArm()                        (also called by both probes)
         armFingerprint()
              armPrepProc: pkill -u $USER -x fprintd-verify; sleep 0.2
              pam.start()                ("ryoku-lock" from assets/pam)
                  state = "scanning"     theme shows SENSOR ACTIVE
touch -> EnrollStatus/VerifyStatus match
       -> onCompleted(Success) -> loginSucceeded() -> reveal + unlock
fail/timeout/error -> onCompleted(Failed) | onError
                   -> rearmTimer (1s) -> armFingerprint() again
unlock (secure false) -> resetAuth(): abort + state=idle
```

### Fix 1: the arm race

The readiness probes (`fprintd-list` + toggle file) usually finish *before*
the compositor confirms the lock surface. If arming only happens when probes
complete, `armWhenReady` flips true afterwards and nothing ever arms. The
shim therefore arms on `onArmWhenReadyChanged` as well.

### Fix 2: stale verifiers

Killing quickshell's PAM subprocess (abort/unlock) orphans the forked
`fprintd-verify` grandchild. The orphan keeps the sensor claim, so the next
scan cannot start — the user touches, nothing happens, and only burning a
password cycle (fail → re-arm → fresh verifier) recovers. Every arm now runs
`pkill -u $USER -x fprintd-verify` first.

### Robustness

- `onError` resets state instead of leaving "scanning" forever
- finger probe retries up to 3× (fprintd is D-Bus activated, may be waking)
- `pam.start()` failure is logged with config/dir/user context

## Settings backend (hub)

All fprintd interaction runs as the invoking user; only the sudo/SDDM
toggles use pkexec.

| Concern | Mechanism |
|---|---|
| enrolled fingers + sensor name | `fprintd-list $USER` (parsed) |
| enroll progress | stage passes parsed live from stdout/stderr of `fprintd-enroll`; total from D-Bus property `num-enroll-stages` (`busctl call net.reactivated.Fprint ...`) |
| verify | `fprintd-verify [-f finger]`, exit code cross-checked against `Verify result:` token |
| delete | `fprintd-delete [-f finger]`; friendly-name labels in `~/.config/qylock/fingerprints.json` cleaned in sync |
| lock toggle | `~/.config/qylock/fingerprint` (`on`/`off`) |
| sudo/sddm toggles | `pkexec bash -c 'sed -i "1i <line>"'` to add, `sed -i '/pam_fprintd_grosshack/d'` to remove; backup written first |

Stream parsing uses per-stream offsets so cumulative `StdioCollector` buffers
are never counted twice. Retry statuses (`enroll-swipe-too-short`,
`enroll-finger-not-centered`, …) map to human guidance lines in the modal.

## Race conditions covered

- fingerprint wins during password windup → `_unlocked` guard in the theme;
  reveal flourish plays without a second authentication
- typed password during an armed scan → fed into the open conversation
  (`pendingPassword` stash + `onResponseRequiredChanged`)
- outside-click on the modal mid-enroll → ignored (would discard stages)
