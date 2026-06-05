pragma Singleton

import QtQuick
import Quickshell
import qs.settingsgui.Commons

Singleton {
  id: root

  // Map to track active sound players: resolvedPath -> MediaPlayer instance
  property var activePlayers: ({})

  property bool multimediaAvailable: false

  Item {
    id: playersContainer
  }

  Component.onCompleted: {
    // Test if QtMultimedia is available by trying to create a simple component
    try {
      var testComponent = Qt.createQmlObject(`
        import QtQuick
        import QtMultimedia
        Item {}
      `, root, "MultimediaTest");
      if (testComponent) {
        multimediaAvailable = true;
        testComponent.destroy();
        Logger.i("SoundService", "QtMultimedia found - sound playback enabled");
      }
    } catch (e) {
      multimediaAvailable = false;
      Logger.w("SoundService", "QtMultimedia not available - no audio will be played from ryoku");
    }
  }

  function resolvePath(soundPath) {
    if (!soundPath || soundPath === "") {
      return "";
    }

    let resolvedPath = soundPath;

    // If it's just a filename (no path separators), assume it's in Assets/Sounds/
    if (!soundPath.includes("/") && !soundPath.startsWith("file://")) {
      resolvedPath = Quickshell.shellDir + "/settingsgui" + "/Assets/Sounds/" + soundPath;
    } else if (!soundPath.startsWith("/") && !soundPath.startsWith("file://")) {
      // Relative path - assume it's relative to shellDir
      resolvedPath = Quickshell.shellDir + "/settingsgui" + "/" + soundPath;
    } else if (soundPath.startsWith("file://")) {
      resolvedPath = soundPath.substring(7); // Remove "file://" prefix
    }
    // Absolute paths are used as-is

    return resolvedPath;
  }

  function playSound(soundPath, options) {
    if (!soundPath || soundPath === "") {
      Logger.w("SoundService", "No sound path provided");
      return;
    }

    if (!multimediaAvailable) {
      Logger.d("SoundService", "QtMultimedia not available, cannot play sound:", soundPath);
      return;
    }

    const opts = options || {};
    const volume = opts.volume !== undefined ? opts.volume : 1.0;
    const fallback = opts.fallback !== undefined ? opts.fallback : false;
    const repeat = opts.repeat !== undefined ? opts.repeat : false;

    const resolvedPath = resolvePath(soundPath);

    if (repeat && activePlayers[resolvedPath]) {
      stopSound(soundPath);
    }

    const loopsValue = repeat ? "MediaPlayer.Infinite" : "1";
    const escapedPath = resolvedPath.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
    const playerQml = `
      import QtQuick
      import QtMultimedia
      import Quickshell
      import qs.settingsgui.Commons
      import qs.settingsgui.Services.System
      MediaPlayer {
        id: mediaPlayer
        property string resolvedPath: "${escapedPath}"
        property bool shouldFallback: ${fallback && !repeat}
        property real soundVolume: ${Math.max(0, Math.min(1, volume))}
        source: "file://${escapedPath}"
        loops: ${loopsValue}
        audioOutput: AudioOutput {
          volume: soundVolume
        }
        onErrorOccurred: {
          Logger.w("SoundService", "Error playing sound:", source, error, errorString);
          if (shouldFallback) {
            const fallbackPath = Quickshell.shellDir + "/settingsgui" + "/Assets/Sounds/notification.mp3";
            if (fallbackPath !== resolvedPath) {
              SoundService.playSound(fallbackPath, {
                volume: soundVolume,
                fallback: false,
                repeat: false
              });
            }
          }
          if (SoundService.activePlayers[resolvedPath]) {
            delete SoundService.activePlayers[resolvedPath];
          }
          destroy();
        }
        onPlaybackStateChanged: function (state) {
          if (state === MediaPlayer.StoppedState && loops === 1) {
            if (SoundService.activePlayers[resolvedPath]) {
              delete SoundService.activePlayers[resolvedPath];
            }
            destroy();
          }
        }
        Component.onCompleted: {
          play();
        }
      }
    `;

    try {
      const player = Qt.createQmlObject(playerQml, playersContainer, "MediaPlayer_" + resolvedPath.replace(/[^a-zA-Z0-9]/g, "_"));

      if (!player) {
        Logger.w("SoundService", "Failed to create MediaPlayer for:", resolvedPath);
        if (fallback && !repeat) {
          const defaultSound = Quickshell.shellDir + "/settingsgui" + "/Assets/Sounds/notification.mp3";
          if (defaultSound !== resolvedPath) {
            playSound(defaultSound, {
                        volume: volume,
                        fallback: false,
                        repeat: false
                      });
          }
        }
        return;
      }

      activePlayers[resolvedPath] = player;

      Logger.d("SoundService", "Playing sound:", resolvedPath, `(volume: ${Math.round(volume * 100)}%)`, repeat ? "(repeat)" : "");
    } catch (e) {
      Logger.w("SoundService", "Failed to create MediaPlayer:", e);
      if (fallback && !repeat) {
        const defaultSound = Quickshell.shellDir + "/settingsgui" + "/Assets/Sounds/notification.mp3";
        if (defaultSound !== resolvedPath) {
          playSound(defaultSound, {
                      volume: volume,
                      fallback: false,
                      repeat: false
                    });
        }
      }
    }
  }

  function stopSound(soundPath) {
    if (!multimediaAvailable) {
      return;
    }

    if (soundPath) {
      const resolvedPath = resolvePath(soundPath);

      if (activePlayers[resolvedPath]) {
        const player = activePlayers[resolvedPath];
        player.stop();
        delete activePlayers[resolvedPath];
        player.destroy();
        Logger.d("SoundService", "Stopped sound:", resolvedPath);
      }
    } else {
      const paths = Object.keys(activePlayers);
      for (let i = 0; i < paths.length; i++) {
        const path = paths[i];
        const player = activePlayers[path];
        player.stop();
        player.destroy();
      }
      activePlayers = {};
      Logger.d("SoundService", "Stopped all sounds");
    }
  }
}
