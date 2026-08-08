# Ryoku Roadmap

This roadmap captures the additions and hardening opportunities identified by reviewing all 94 QML files in Omarchy Quattro at commit [`fd1034f`](https://github.com/basecamp/omarchy/tree/fd1034f71b16aa45d5431ab41ed9e48c89fdac8e). Each item names the corresponding Omarchy Quattro source path so the behavior can be re-examined without creating a second Ryoku architecture.

## Adoption principles

- Port behavior into Ryoku's existing typed daemon, QML services, launcher providers, bar products, package delivery, and receipt-gated plugin system.
- Do not introduce a second menu, theme, plugin, service, or configuration convention.
- Keep privileged operations, long-running processes, polling, validation, and sensitive data outside QML.
- Preserve upstream MIT attribution when code or data is reused rather than independently reimplemented.
- Deliver shared behavior through both QSBar and FrameBars unless an item explicitly targets one product.

## Phase 1: Correctness and lifecycle foundations

These changes reduce contradictory state, duplicated work, and monitor-specific failures before more product surfaces are added.

### Centralize media-player selection

**Outcome:** `shell.services.Media` becomes the sole owner of active MPRIS selection, stable player preference, play ordering, and source cycling. QSBar and FrameBars consume the same selected player, including when `playerctld` or multiple playing applications are present.

**Ryoku integration:** Reuse the existing `Audio.streams` metadata to prefer players with active playback streams. Remove local active-player selectors after all consumers migrate.

**Omarchy Quattro reference:**

- `shell/plugins/services/media/Service.qml:17-30,82-136,425-444`

**Cost:** Low to medium. No new dependency, privilege, or network surface.

### Centralize plugin discovery and service instances

**Outcome:** Plugin discovery runs once per shell process, and every enabled plugin has at most one service instance shared by desktop and popout hosts. Multi-monitor setups no longer duplicate plugin polling, CLI processes, or state.

**Ryoku integration:** Move the existing receipt-aware registry into a process-wide service owner. Retain Store receipt checks, version checks, explicit enablement, and `PluginObjectSlot`'s construct-before-swap behavior.

**Omarchy Quattro reference:**

- `shell/shell.qml:274-337`
- `shell/services/PluginRegistry.qml:576-665`

**Cost:** Medium. The existing unsandboxed-QML plugin trust boundary remains unchanged.

### Add monitor-origin remap recovery

**Outcome:** Long-lived bar, frame, wallpaper, and desktop layer surfaces recover when an existing screen changes global `x` or `y` during dock, undock, rotation, or topology changes.

**Ryoku integration:** Watch the surviving screen object, settle topology movement briefly, then unmap and remap the affected surface. Compose this with existing resource-loss and closed-window recovery rather than replacing it.

**Omarchy Quattro reference:**

- `shell/Ui/ScreenMoveRemap.qml:3-40`
- `shell/plugins/bar/Bar.qml:938-946`
- `shell/plugins/background/Background.qml:181-195`

**Cost:** Low for the helper and medium to apply it across all long-lived surfaces.

### Introduce a shared keyboard-panel interaction contract

**Outcome:** Shortcut-opened panels acquire focus reliably and share semantic Escape, Tab, Shift-Tab, arrows, vim movement, Enter, Space, Delete, and text-key behavior. Pointer-only dismissal layers on other outputs do not monopolize keyboard focus.

**Ryoku integration:** Create a Ryoku-owned semantic key dispatcher and input-mode-aware focus primitive. Migrate panels incrementally, beginning with clipboard, network, and audio. Preserve each panel's own cursor and action state machine.

**Omarchy Quattro reference:**

- `shell/Ui/PanelKeyCatcher.qml:3-85`
- `shell/Ui/KeyboardPanel.qml:80-101,248-260,333-378`
- `shell/plugins/bar/Bar.qml:391-446`

**Cost:** Medium to high because both QSBar variants and applicable FrameBars menus require compositor and multi-monitor interaction testing.

### Centralize screen-fitted popup geometry

**Outcome:** Popups remain fully operable on compact, portrait, scaled, and mixed-resolution displays. Content exceeding available space scrolls instead of clipping off-screen.

**Ryoku integration:** Add one shared fitted-card geometry primitive that accounts for bar thickness and margins, caps width and height, and exposes a bounded viewport. Migrate fixed-width QSBar panels and unbounded FrameBars surfaces.

**Omarchy Quattro reference:**

- `shell/Ui/PopupCard.qml:28-58`
- `shell/plugins/panels/audio/Panel.qml:649-672`

**Cost:** Medium. No dependency or security cost.

### Extract pointer-movement gating for hybrid lists

**Outcome:** Keyboard selection no longer jumps when scrolling moves a delegate underneath a stationary pointer.

**Ryoku integration:** Extract the equivalent guard already used by Ryoku's launcher and reuse it in network and future keyboard-plus-pointer lists. Reset the gate only after real pointer movement in stable coordinates.

**Omarchy Quattro reference:**

- `shell/Ui/PointerMoveGate.qml:3-51`
- `shell/plugins/clipboard/Clipboard.qml:181-194,245-248,520-521`

**Cost:** Low. No dependency or security cost.

## Phase 2: Highest-value user features

### Add on-demand Wi-Fi QR sharing

**Outcome:** The active Wi-Fi connection can be shared with a phone or another device using a QR code. Open, WPA, WEP, and hidden networks are represented correctly; enterprise connections are rejected. Password reveal is explicit, and all secret-bearing UI state is cleared when the overlay closes.

**Ryoku integration:**

- Add a typed, one-shot `network.wifiShare` daemon call.
- Return the result only to the requesting call; never publish a password-bearing QR or plaintext password on the persistent `network` topic.
- Keep secrets out of argv and logs.
- Ignore late replies after close, disconnect, interface change, or request replacement.
- Render the QR as one image or `Canvas` node rather than thousands of QML rectangles.
- Invoke one shared overlay from QSBar and FrameBars network surfaces.

**Omarchy Quattro reference:**

- `shell/plugins/panels/network/Panel.qml:460-517,941-991`
- `shell/plugins/panels/network/WifiQrPanel.qml:39-139`
- `bin/omarchy-network-qr:19-80`

**Cost:** Medium. Requires NetworkManager secret access and either `qrencode` or a small in-process Go QR encoder.

### Add searchable, keyboard-driven clipboard history

**Outcome:** Users can filter the existing typed clipboard history and operate it entirely from the keyboard. Selection remains stable across filtering and model updates.

**Ryoku integration:**

- Filter by preview, filename, kind, and MIME type.
- Preserve selection by entry ID rather than row index.
- Keep the selected row visible.
- Map Enter to copy, Delete to remove, and Shift+Delete to guarded clear.
- Preserve Ryoku's no-synthetic-paste contract.
- Add clipboard to FrameBars' keyboard-focus policy.

**Omarchy Quattro reference:**

- `shell/plugins/clipboard/Clipboard.qml:133-194,337-380`
- `shell/plugins/clipboard/ClipboardHistory.js:92-95,155-189`

**Cost:** Medium. No new dependency, privilege, or clipboard exposure.

### Add a blocking select/input prompt broker

**Outcome:** Ryoku helpers and plugins can request a shell-native choice or text prompt and wait for a typed accept or cancel result without temporary-file polling.

**Ryoku integration:**

- Add typed `prompt.pick` and `prompt.reply` calls plus a `prompt` topic.
- Publish `{active, requestId, mode, prompt, options:[{label,value,icon?}]}`.
- Distinguish cancellation from empty input.
- Return opaque values so duplicate labels remain safe.
- Guarantee timeout, daemon shutdown, replacement, and close unblock the caller exactly once.
- Treat returned values as data and never execute them automatically.
- Follow the existing screenshare request/reply lifecycle.

**Omarchy Quattro reference:**

- `shell/plugins/menu/Menu.qml:117-134,715-833`
- `bin/omarchy-menu-select:67-93`

**Cost:** Medium. No new runtime dependency or privilege.

### Add a built-in emoji launcher provider

**Outcome:** Emoji search and copy are available directly in Ryoku's launcher without configuring `rofimoji` or a separate fullscreen overlay.

**Ryoku integration:** Bundle a keyworded Unicode catalogue, add a non-default `emoji:` or `:` provider, cap results before creating rows, and reuse the existing launcher dispatcher, virtualization, keyboard navigation, and clipboard action. Synthetic paste, if offered, must remain an explicit secondary action with short-lived clipboard ownership.

**Omarchy Quattro reference:**

- `shell/plugins/emojis/EmojiSearch.js:18-37`
- `shell/plugins/emojis/Emojis.qml:69-150,199-239`
- `shell/plugins/emojis/emojis.json`
- `bin/omarchy-menu-emoji-insert`

**Cost:** Small. Preserve the upstream MIT notice if the catalogue or helper is reused.

### Remember and switch power profiles per source

**Outcome:** An opt-in setting applies one profile on AC and another on battery. Manual choices update the mapping for the current source.

**Ryoku integration:** Persist `{autoSwitch, acProfile, batteryProfile}`, observe UPower's source state beside the existing power-profiles service, and coalesce rapid changes to the latest state. Missing batteries, unknown source state, unavailable profiles, and desktops must not force a profile. Default `autoSwitch` to false.

**Omarchy Quattro reference:**

- `shell/plugins/services/battery/Service.qml:43-72`
- `bin/omarchy-powerprofiles-set:13-69`

**Cost:** Low. No new dependency or privilege beyond the existing D-Bus setter.

### Add session reminders with visible outstanding state

**Outcome:** Users can create multiple lightweight reminders with a duration and optional message, inspect due times, and cancel or clear them. Reminders survive shell reloads and arrive through the normal notification path.

**Ryoku integration:** Add a daemon-owned `reminders` topic and typed `reminders.add`, `reminders.cancel`, and `reminders.clear` calls. Use user-systemd timers or equivalent durable scheduling, store messages as data rather than command arguments, and reuse the prompt broker for minutes and optional text. Explicitly define login and reboot survival semantics.

**Omarchy Quattro reference:**

- `shell/plugins/reminders/ReminderFlow.qml:34-96`
- `shell/plugins/reminders/ReminderFlowModel.js:1-13`
- `shell/plugins/bar/indicators/Reminder.qml:10-48`
- `bin/omarchy-reminder:24-62,78-135,180-225`

**Cost:** Medium. Uses the existing systemd user manager and notification service.

### Make audio surfaces bounded and keyboard-operable

**Outcome:** Large device and application-stream lists remain on-screen and can be controlled without a pointer.

**Ryoku integration:** Add a bounded vertical viewport, one section-and-row cursor, visible-selection scrolling, Left/Right volume changes, Enter/Space device or mute actions, and consistent behavior across QSBar and FrameBars. Search is unnecessary for normally short audio lists.

**Omarchy Quattro reference:**

- `shell/plugins/panels/audio/Panel.qml:250-355,649-689`

**Cost:** Medium. No new dependency or privilege.

### Stabilize FrameBars Wi-Fi ordering

**Outcome:** FrameBars shows the connected network first, then saved networks, then remaining networks by signal strength, matching QSBar and avoiding NetworkManager enumeration-order churn.

**Ryoku integration:** Sort the typed daemon snapshot or the FrameBars list after SSID deduplication. Keep selection stable while scans update raw access points.

**Omarchy Quattro reference:**

- `shell/plugins/panels/network/Model.js:267-282`

**Cost:** Low. No new dependency or security boundary.

## Phase 3: Platform extensions

### Add slow-application launch feedback

**Outcome:** Applications that take longer than two seconds to present a window receive persistent launch feedback that closes when a new or newly active top-level appears, or after a bounded timeout. Normal launches remain flash-free.

**Ryoku integration:** Keep one launcher-level owner with a serial guard so overlapping launches cannot close each other's feedback. Render through Ryoku's existing OSD language rather than creating a parallel notification history entry or copying Quattro's generic OSD bus.

**Omarchy Quattro reference:**

- `shell/services/AppLibrary.qml:157-188,225-258`
- `shell/plugins/osd/Osd.qml:54-80,115-136`

**Cost:** Medium. No new dependency.

### Add a host-owned plugin glyph trigger

**Outcome:** Installed frame-popout plugins can expose a discoverable bar glyph without loading arbitrary third-party QML directly into latency-sensitive bar layout.

**Ryoku integration:** Render the glyph from receipt-validated manifest icon and label metadata and toggle the plugin's existing frame popout. Support both active bar products while keeping plugin code in its current content and service hosts.

**Omarchy Quattro reference:**

- `shell/services/BarWidgetRegistry.qml:10-33`
- `shell/shell.qml:666-708`
- `shell/plugins/bar/Bar.qml:1458-1466`

**Cost:** Medium. Does not expand the existing plugin trust boundary.

### Add an optional Tailscale Store plugin

**Outcome:** Tailscale users can see connection state, connect or disconnect, copy peer addresses, and select an exit node without making Tailscale a core desktop dependency.

**Ryoku integration:** Begin with `tailscale status --json`, up/down, peer copy, and exit-node selection. Keep bounded CLI execution and parsing in a daemon-owned optional capability or one shared plugin service. Treat operator authorization as an explicit one-time setup action. Keep peer data and authentication URLs memory-only. Defer accounts, Mullvad, Taildrop, and high-frequency polling.

**Omarchy Quattro reference:**

- `shell/plugins/panels/tailscale/Service.qml:16-20,123-192,336-455`
- `shell/plugins/panels/tailscale/Panel.qml:44-49,193-304,415-429,579-706`
- `shell/plugins/panels/tailscale/Model.js`
- `shell/plugins/panels/tailscale/TailscaleIcon.qml`

**Cost:** Medium to high. Optional `tailscale`/`tailscaled`, browser login, and one-time PolicyKit authorization.

### Add opt-in persistent notification history and media

**Outcome:** Missed notifications and allowed thumbnails survive shell or daemon restarts while retaining bounded history and clear-all behavior.

**Ryoku integration:** Keep live notification QObjects and actions in QML, send plain snapshots to a daemon ingestion call, and publish a daemon-owned history topic. Store data atomically under owner-only permissions, canonicalize allowed temporary image paths, cap item and byte counts, enforce retention, and make persistence explicitly configurable.

**Omarchy Quattro reference:**

- `shell/plugins/notifications/Service.qml:79-98,451-655`

**Cost:** Medium. No new dependency, but bodies and images are privacy-sensitive.

### Add fingerprint enrollment and qylock authentication

**Outcome:** Enrolled users can unlock with a fingerprint while password PAM remains available in parallel and continues to be the failure-safe fallback.

**Ryoku integration:** Add enrollment, removal, and status to Lockscreen settings. Ship `fprintd`/libfprint and a narrowly reviewed root-owned Ryoku PAM service. Start the fingerprint PAM conversation only after `WlSessionLock.secure`, suppress it in preview/testing, retry failures with a bound, abort on unlock or teardown, and make simultaneous password/fingerprint success idempotent. Keep authentication inside qylock rather than daemon IPC.

**Omarchy Quattro reference:**

- `shell/plugins/lock/Service.qml:87-218,304-368`

**Cost:** High. Authentication-critical packaging, PAM policy, hardware gating, and security review are required.

## Explicit non-goals

### Do not port the Quattro plugin host or global hot reload

Quattro destroys all panels, services, and widgets before clearing the component cache and rescanning. Ryoku's receipt-owned, versioned, explicit-enable, swap-on-success loader has the stronger lifecycle and delivery model.

**Omarchy Quattro reference:**

- `shell/services/PluginRegistry.qml:576-665`
- `shell/shell.qml:739-758`

### Do not port the full command menu or icon indexer

Ryoku already has the stronger launcher: federated providers, frecency, desktop actions, script compatibility, virtualized results, and dedicated settings. A second menu and action configuration convention would add arbitrary-command and maintenance surface without a missing capability. Only the external prompt protocol is additive.

**Omarchy Quattro reference:**

- `shell/plugins/menu/Menu.qml:508-559,945-1091`
- `shell/services/AppLibrary.qml`

### Do not port Dropbox into the core desktop

The Quattro implementation repeatedly walks the entire Dropbox tree, depends on Python, `dropbox-cli`, and Nautilus, exposes private paths, and uses hard-coded quota assumptions. If demand appears, a Store plugin should use bounded status calls or a supported API without recursive periodic scans.

**Omarchy Quattro reference:**

- `shell/plugins/panels/dropbox/Service.qml:34-65,155-255`
- `shell/plugins/panels/dropbox/status.py:10-16,46-96`

### Do not port the custom border, theme, and control stack

It duplicates Ryoku's established visual language and adds shape nodes, broad token parsing, bindings, and a second component convention for no missing user capability.

**Omarchy Quattro reference:**

- `shell/Ui/BorderOverlay.qml`
- `shell/Commons/Border.qml`
- `shell/Commons/BorderGeometry.js`
- `shell/Commons/Color.qml`
- `shell/Commons/Style.qml`

### Do not port the image picker

Ryoku already has bounded asynchronous thumbnail decoding, nearby-item loading, wallpaper and theme catalogues, screenshot/video routes, and a better lifecycle. A future arbitrary-directory picker must retain those bounds and use typed daemon requests.

**Omarchy Quattro reference:**

- `shell/plugins/image-picker/ImagePicker.qml:89-135,408-512`

### Do not port the speed test

Ryoku's Cloudflare implementation already has calibrated samples, latency, retry, cancellation, per-request and overall timeouts, edge and country data, and immediate offline transitions.

**Omarchy Quattro reference:**

- `shell/plugins/panels/network/Panel.qml:706-770,1021-1053`

### Do not port the generic payload OSD wholesale

Ryoku's volume, microphone, and brightness OSD observes real source state, suppresses login-sync flashes, and cancels cleanly. Arbitrary status text should remain a notification unless it belongs to the bounded slow-launch feedback use case.

**Omarchy Quattro reference:**

- `shell/plugins/osd/Osd.qml:54-80,115-136`

### Do not port the draggable four-edge bar

FrameBars already provides four independently configurable per-monitor rails. Adding the same capability to QSBar would duplicate behavior and multiply panel anchoring and layout paths.

**Omarchy Quattro reference:**

- `shell/plugins/bar/Bar.qml:238-263,938-970`

### Do not port notification-card styling directly

Ryoku already has stronger explicit default and secondary notification actions. If unread/read parity or persistent media is added, extend the shared Ryoku notification model and card rather than introducing a second notification UI.

**Omarchy Quattro reference:**

- `shell/plugins/notifications/components/NotificationCard.qml`

### Do not reproduce QR matrices with one delegate per module

The feature is valuable, but `Repeater { model: qrSize * qrSize }` creates thousands of QML objects for larger QR codes. Use one rendered image or canvas-backed node.

**Omarchy Quattro reference:**

- `shell/plugins/panels/network/WifiQrPanel.qml:103-139`

## Recommended execution order

1. Centralize media-player selection.
2. Centralize plugin discovery and service ownership.
3. Add monitor-origin remap recovery.
4. Introduce shared keyboard-panel and fitted-popup primitives.
5. Add Wi-Fi QR sharing.
6. Add searchable keyboard clipboard history.
7. Add the prompt broker.
8. Add the emoji launcher provider.
9. Add per-source automatic power profiles.
10. Build reminders using the prompt broker.
11. Bound and keyboard-enable audio surfaces.
12. Add slow-launch feedback and host-owned plugin glyphs.
13. Evaluate Tailscale, persistent notifications, and fingerprint unlock as separate security and product projects.
