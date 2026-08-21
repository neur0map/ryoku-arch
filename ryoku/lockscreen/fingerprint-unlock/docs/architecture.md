# Architecture: Fingerprint Unlock

This document explains how the fingerprint unlock feature works at every layer,
from the PAM stack up to the theme UI.

## Overview

```
+-------------------+     +-------------------+     +-------------------+
|   Theme (QML)     |     |  SddmShim (QML)   |     |  PAM Service      |
|   Main.qml        |<--->|  SddmShim.qml     |<--->|  ryoku-lock       |
|                   |     |                   |     |                   |
| - fpHint text     |     | - PamContext      |     | - grosshack pair  |
| - fpPulse anim    |     | - fpEnabled       |     | - pam_fprintd     |
| - boomReveal      |     | - fpHasFingers    |     | - pam_unix        |
| - _unlocked guard |     | - armFingerprint  |     +-------------------+
+-------------------+     | - resetAuth       |
                          +-------------------+
```

## PAM Stack (`assets/pam/ryoku-lock`)

```
auth  sufficient  pam_fprintd_grosshack.so
auth  sufficient  pam_unix.so try_first_pass nullok
auth  required    pam_env.so
auth  required    pam_deny.so
account required  pam_unix.so
password required pam_deny.so
session required  pam_unix.so
```

### How grosshack works

`pam_fprintd_grosshack.so` is a modified version of `pam_fprintd` that forks
`fprintd-verify` at the **start** of the PAM conversation. This means:

1. The fingerprint sensor begins scanning immediately
2. `pam_unix.so` simultaneously waits for a typed password
3. The **first** successful auth (touch OR type) wins
4. Both paths race in the same PAM conversation

This is the same mechanism used in `/etc/pam.d/sddm`, so the behavior at the
lock screen matches the sign-in screen exactly.

### Why inline (not include)

The `ryoku-lock` file lives in the lock's own `assets/pam/` directory and is
loaded via `PamContext.configDirectory`. An `include system-login` would resolve
against this confdir (not `/etc/pam.d`) and fail. The inline tail mirrors the
module list the bundled DMS lock ships for its lock services.

## SddmShim (`shim/SddmShim.qml`)

The shim replaces the default Quickshell SDDM shim to add fingerprint support.
It exposes the same API as a real SDDM greeter so themes work unchanged.

### Properties exposed to theme

| Property | Type | Source | Purpose |
|---|---|---|---|
| `sddm.fingerprintHint` | bool | hardcoded `true` | Gate: show the sensor hint (false under real SDDM) |
| `sddm.fingerprintReady` | bool | `fpEnabled && fpHasFingers` | Sensor is available |
| `sddm.fingerprintState` | string | PAM conversation | `idle` / `scanning` / `success` / `fail` |
| `sddm.fingerprintUnlock` | bool | PAM completion | True if sensor won (not typed) |

### Readiness probes

Two independent probes run on lock start:

1. **fpToggleProc**: reads `~/.config/qylock/fingerprint` (the Settings toggle)
2. **fpListProc**: runs `fprintd-list` to check for enrolled fingers

Both call `maybeArm()` when done. The arm only fires when ALL conditions are met:
- Toggle is on (or file missing, default on)
- At least one finger is enrolled
- `armWhenReady` is true (lock surface is secured)
- No PAM conversation is already active

### PAM conversation flow

```
armFingerprint()
  -> pam.user = currentUser
  -> pam.pendingPassword = ""
  -> pam.start()
  -> PAM reads ryoku-lock service
  -> pam_fprintd_grossfork forks fprintd-verify
  -> sensor begins scanning
  -> fingerprintState = "scanning"

  [user touches sensor]
  -> fprintd-verify succeeds
  -> PAM conversation completes with Success
  -> onCompleted(PamResult.Success)
  -> fingerprintUnlock = (scanning && !typed)
  -> fingerprintState = "success"
  -> sddm.loginSucceeded()
  -> loginctl unlock-session

  [OR user types password]
  -> onResponseRequiredChanged (pam_unix prompt)
  -> pam.respond(password)
  -> PAM conversation completes with Success
  -> same flow as above, but fingerprintUnlock = false

  [OR scan fails]
  -> PAM conversation completes with failure
  -> onCompleted(non-Success)
  -> fingerprintState = "fail"
  -> sddm.loginFailed()
  -> rearmTimer.restart() (700ms)
  -> sensor re-arms for next touch
```

## Lock Shell (`lock_shell.qml`)

The entry point for `ryoku-shell lock`. Key fingerprint integration:

### Wayland session lock

```
WlSessionLock
  onSecureChanged:
    if secure:
      write qylock.locked marker
      sddmShim.armWhenReady = true  <-- arms the sensor
    else:
      remove qylock.locked marker
      sddmShim.armWhenReady = false
      sddmShim.resetAuth()          <-- aborts PAM conversation
```

### Login success handler

```
onLoginSucceeded:
  shellRoot.authenticated = true
  loginctl unlock-session
  quitTimer.start()  <-- exits the lock screen
```

## Theme (`Main.qml`)

### Fingerprint hint

The hint sits between the user name and the password field. It uses:
- `mainText` color (full brightness) while scanning, not dim `subColor`
- A pulse animation (opacity 1.0 -> 0.45 -> 1.0) while the sensor listens
- Red (#ff4444) on failure
- `height: 0` when invisible (clean collapse)

### Race condition protection

An `_unlocked` guard prevents `boomSequence.onFinished: doLogin()` from firing
a second PAM auth if the fingerprint wins mid-windup:

```
onLoginSucceeded:
  if fingerprintUnlock:
    _unlocked = true
    windupAnim.stop()
    boomTriggerTimer.stop()
    boomSequence.stop()    <-- kills the running animation
    boomReveal.start()     <-- plays reveal without doLogin()
```

Without this guard, if the fingerprint wins after `boomTriggerTimer` fires
(at 1450ms) but before `boomSequence` finishes, `doLogin()` would be called
a second time, starting a duplicate PAM conversation.

### Reveal flourish

On sensor win, `boomReveal` plays the same scale/flash animation as the
windup's reveal, but without `onFinished: doLogin()`. This gives visual
feedback that the unlock succeeded without triggering a second auth.

## Settings Page (`LockscreenPage.qml`)

### Fingerprint card

Under the "Sign-in & Fingerprint" collapsible section:

- **Toggle**: writes `~/.config/qylock/fingerprint` (`on`/`off`)
- **Status line**: device name, enrolled finger count
- **Finger list**: each finger with VERIFY and DELETE buttons
- **Actions**: ENROLL FINGERPRINT, VERIFY ANY, REMOVE ALL

### Enrollment modal

A dark terminal-style overlay that shows live fprintd output:

- Captures **stderr** (where fprintd actually outputs)
- Displays raw output in a monospace Flickable with auto-scroll
- Blinking green dot while the command is running
- ABORT/CLOSE button sends SIGTERM to the fprintd child

### Finger naming

After successful enrollment, the modal shows a text field where the user can
assign a friendly name (e.g. "right index"). Names are stored in
`~/.config/qylock/fingerprints.json` and displayed in the finger list.

## Data Flow

```
~/.config/qylock/fingerprint     <-- Settings toggle ("on"/"off")
~/.config/qylock/fingerprints.json  <-- finger name labels
~/.local/share/quickshell-lockscreen/
  shim/SddmShim.qml              <-- PAM + fingerprint state
  lock_shell.qml                  <-- lock entry point
  assets/pam/ryoku-lock           <-- PAM service
~/.local/share/qylock/themes/
  clockwork/orbital/Main.qml     <-- theme with sensor hint
~/.config/quickshell/hub/pages/
  LockscreenPage.qml              <-- Settings fingerprint card
```
