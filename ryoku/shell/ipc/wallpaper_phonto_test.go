package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Setting a video must (1) stop the image daemon so no still bleeds under the
// clip (the overlay fix) and (2) launch the GPU's video daemon with the clip.
// Runs for both backends against recording stand-ins on PATH, forcing liveDaemon
// so it is GPU-independent and never touches the real wallpaper daemon.
func TestShowLiveWallpaperHandoff(t *testing.T) {
	for _, backend := range []string{daemonPhonto, daemonMpvpaper} {
		t.Run(backend, func(t *testing.T) {
			bin := t.TempDir()
			state := t.TempDir()
			t.Setenv("XDG_CONFIG_HOME", t.TempDir()) // no ryowalls.json -> fill
			liveLog := filepath.Join(state, "live.args")
			awwwLog := filepath.Join(state, "awww.args")
			alive := filepath.Join(state, "live.alive")
			killed := filepath.Join(state, "awww.killed")

			fake := func(name, body string) {
				if err := os.WriteFile(filepath.Join(bin, name), []byte("#!/bin/sh\n"+body+"\n"), 0o755); err != nil {
					t.Fatal(err)
				}
			}
			// the backend records its argv and marks itself alive; pgrep reports
			// the marker; pkill clears it; awww records subcommands (assert "kill").
			fake(backend, `printf '%s\n' "$*" > "`+liveLog+`"; : > "`+alive+`"`)
			fake("awww", `case "$1" in
kill) : > "`+killed+`"; printf '%s\n' "$*" >> "`+awwwLog+`" ;;
query) [ -f "`+killed+`" ] && exit 1 || exit 0 ;;
*) printf '%s\n' "$*" >> "`+awwwLog+`" ;;
esac`)
			fake("pgrep", `[ -f "`+alive+`" ]`)
			fake("pkill", `rm -f "`+alive+`"; exit 0`)
			t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))

			orig := liveDaemon
			liveDaemon = backend
			t.Cleanup(func() { liveDaemon = orig })

			vid := filepath.Join(t.TempDir(), "clip.mp4")
			if err := os.WriteFile(vid, []byte("x"), 0o644); err != nil {
				t.Fatal(err)
			}
			if err := (&daemon{}).showLiveWallpaper(vid); err != nil {
				t.Fatalf("showLiveWallpaper: %v", err)
			}
			if got, err := os.ReadFile(liveLog); err != nil || !strings.Contains(string(got), vid) {
				t.Errorf("%s not launched with the clip: %q err=%v", backend, got, err)
			}
			if ka, err := os.ReadFile(awwwLog); err != nil || !strings.Contains(string(ka), "kill") {
				t.Errorf("image daemon not stopped before the video (awww kill missing): %q err=%v", ka, err)
			}
		})
	}
}
