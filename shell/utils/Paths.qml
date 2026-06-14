pragma Singleton

import QtQuick
import Quickshell
import Ryoku
import Ryoku.Config

Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string pictures: Quickshell.env("XDG_PICTURES_DIR") || `${home}/Pictures`
  readonly property string videos: Quickshell.env("XDG_VIDEOS_DIR") || `${home}/Videos`

  readonly property string data: `${Quickshell.env("XDG_DATA_HOME") || `${home}/.local/share`}/ryoku-shell`
  readonly property string state: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/ryoku-shell`
  readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || `${home}/.cache`}/ryoku-shell`
  readonly property string config: `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/ryoku-shell`
  readonly property string runtime: Quickshell.env("RYOKU_SHELL_RUNTIME_DIR") || `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/quickshell/ryoku-shell`
  readonly property string ryokuBridge: `${runtime}/scripts/ryoku`

  readonly property string imagecache: `${cache}/imagecache`
  readonly property string notifimagecache: `${imagecache}/notifs`
  readonly property string wallsdir: Quickshell.env("RYOKU_SHELL_WALLPAPERS_DIR") || absolutePath(GlobalConfig.paths.wallpaperDir)
  readonly property string recsdir: Quickshell.env("RYOKU_SHELL_RECORDINGS_DIR") || `${videos}/Recordings`
  readonly property string libdir: Quickshell.env("RYOKU_SHELL_LIB_DIR") || "/usr/lib/ryoku-shell"

  function toLocalFile(path: url): string {
    path = Qt.resolvedUrl(path);
    return path.toString() ? CUtils.toLocalFile(path) : "";
  }

  function absolutePath(path: string): string {
    return toLocalFile(path.replace(/~|(\$({?)HOME(}?))+/, home));
  }

  function shortenHome(path: string): string {
    return path.replace(home, "~");
  }
}
