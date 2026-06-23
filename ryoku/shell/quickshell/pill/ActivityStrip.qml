import QtQuick
import "Singletons"

/**
 * The live-activity island: the chips that ride beside the pill while their
 * state is live. Screen recording, a Discord voice call, and a WireGuard tunnel
 * are automatic status; the stash chip is an entry point that opens the file
 * stash. The strip folds shut to nothing when none of them is active.
 */
Row {
    id: root

    property real s: 1

    // The strip counts as island hover so an auto-hidden island stays revealed
    // while the cursor is on its chips. A passive ancestor handler (like the
    // pill's own) never blocks the chips' taps.
    property bool hovered: visible && stripHover.hovered

    signal requestSurface(string name)

    spacing: 6 * s

    HoverHandler { id: stripHover }

    ActivityChip {
        s: root.s
        active: Recorder.active
        label: Recorder.paused ? "PAUSE" : "REC"
        value: Recorder.elapsedText
        accent: Theme.vermLit
        dot: true
        dotOpacity: Recorder.paused ? 0.35 : Recorder.pulse
        clickable: true
        onActivated: Recorder.stop()
    }

    ActivityChip {
        s: root.s
        active: VoiceCall.active
        label: "CALL"
        value: VoiceCall.elapsedText
        accent: Theme.dim
    }

    ActivityChip {
        s: root.s
        active: Vpn.active || Vpn.badgeVisible
        label: Vpn.active ? "VPN" : "VPN-"
        value: Vpn.active ? Vpn.interfaceName : ""
        accent: Vpn.active ? Theme.flameGlow : Theme.faint
    }

    ActivityChip {
        s: root.s
        active: Stash.count > 0
        label: "STASH"
        value: Stash.count > 0 ? ("" + Stash.count) : ""
        accent: Theme.flameGlow
        clickable: true
        onActivated: root.requestSurface("stash")
    }

    ActivityChip {
        s: root.s
        active: Stash.recvState !== "idle"
        label: "RECV"
        value: Stash.recvCount > 0 ? ("" + Stash.recvCount) : ""
        accent: Theme.flameGlow
        dot: true
        clickable: true
        onActivated: root.requestSurface("stash")
    }
}
