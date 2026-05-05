# Audio and Media

How audio control and media player integration work in iNiR.

## Audio

### PipeWire integration

iNiR controls audio through PipeWire via the Quickshell PipeWire module and `wpctl` (WirePlumber's CLI). This means it works with PipeWire out of the box, no PulseAudio compatibility layer needed.

### Volume control

Keybinds and OSD handle the basics:

| Key | Action |
|-----|--------|
| Volume Up / Down | Adjust default sink volume |
| Mute | Toggle default sink mute |
| Mic Mute | Toggle default source mute |

The OSD (on-screen display) appears for volume and brightness changes, showing the current level with an animated bar.

### Per-app mixer

The right sidebar (ii) and action center (waffle) include a per-app volume mixer. Each app that's outputting audio appears with its own volume slider. You can mute individual apps or adjust their volume independently.

### EasyEffects

If EasyEffects is installed, iNiR detects its virtual sink and controls the physical sink behind it instead. This means volume control works correctly whether EasyEffects is running or not. A toggle in the right sidebar/action center lets you enable/disable EasyEffects.

### IPC

```bash
inir audio volumeUp         # Increase volume
inir audio volumeDown       # Decrease volume
inir audio toggleMute       # Toggle mute
inir audio toggleMicMute    # Toggle mic mute
inir audio getVolume        # Get current volume (0.0-1.0)
```

## Media players

### MPRIS support

iNiR picks up any MPRIS-compatible media player automatically. Spotify, Firefox, mpv, VLC, Celluloid, Amberol, whatever speaks MPRIS shows up in the media controls.

The media player widget appears in:
- The bar (compact now-playing indicator)
- Media controls popup (`iiMediaControls`)
- Right sidebar
- Waffle action center

### Player prioritization

When multiple players are active, iNiR picks the most relevant one:

1. A player that's currently playing beats one that's paused
2. The user's manually selected ("tracked") player beats auto-detection
3. If nothing is playing, the last active player stays visible

### YT Music

The left sidebar includes a full YT Music player. It uses mpv for playback and yt-dlp for stream extraction. Search, queue management, playlists, and playback controls all work from within the shell.

When YT Music is playing via the sidebar AND a browser tab is also showing YT Music, iNiR deduplicates them in the media controls (you see one player, not two).

### Media controls layouts

The media controls popup has multiple layout presets you can choose from in Settings. Different presets show different arrangements of album art, controls, and track info.

## SongRec (music recognition)

If SongRec is installed, you can trigger music recognition from the shell. It listens to your audio output, identifies the song (Shazam-style), and shows the result. Useful when you hear something playing and want to know what it is.
