package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"golang.org/x/sys/unix"
)

// osd.go feeds the brightness OSD. The volume and mic OSDs read PipeWire
// directly in QML, where Ryoku already owns the audio graph, so their change
// events and value are observable without the daemon. Brightness has no such
// QML-observable source: the media keys and the `brightness` verb both drive
// ryoku-cmd-brightness straight to the backlight, so the daemon watches the
// primary backlight and pushes a fraction plus a monotonically rising sequence
// to the `osd` topic. QML shows the brightness OSD when the sequence advances
// and binds `value` to the slider; the bucket->icon mapping lives once in QML
// beside the volume and mic buckets. Contract 12 sec 3, sec 9.

type osdState struct {
	topic *stateTopic
	seq   int
}

// backlightDevice picks the primary backlight: the first entry under
// /sys/class/backlight. Absent (a desktop with no panel) means no watcher, so
// the brightness OSD simply never fires, matching the reference where a missing
// brightness device produces no update. Mirrors brightness_service().primary.
func backlightDevice() string {
	const base = "/sys/class/backlight"
	ents, err := os.ReadDir(base)
	if err != nil || len(ents) == 0 {
		return ""
	}
	return filepath.Join(base, ents[0].Name())
}

// readSysInt reads a single integer sysfs attribute.
func readSysInt(path string) (int, bool) {
	b, err := os.ReadFile(path)
	if err != nil {
		return 0, false
	}
	n, err := strconv.Atoi(strings.TrimSpace(string(b)))
	if err != nil {
		return 0, false
	}
	return n, true
}

// startOsd registers the `osd` topic and, when a backlight exists, starts the
// watcher goroutine that republishes on every brightness change.
func (d *daemon) startOsd() {
	o := &osdState{topic: d.registerTopic("osd")}
	o.publish(0)
	if dev := backlightDevice(); dev != "" {
		go o.watchBacklight(dev)
	}
}

// publish writes the current osd frame. The topic drops a byte-identical frame,
// so republishing an unchanged value never wakes a QML binding.
func (o *osdState) publish(value float64) {
	frame, _ := json.Marshal(map[string]any{
		"brightness": map[string]any{"seq": o.seq, "value": value},
	})
	o.topic.publish(frame)
}

// watchBacklight blocks in poll(2) on the backlight's actual_brightness sysfs
// attribute, which the kernel wakes with POLLPRI on every brightness change
// (media keys, the brightness verb, or anything else). Each wake recomputes the
// fraction, bumps the sequence, and republishes. The first read is the current
// value and does NOT bump the sequence, so a fresh subscriber never flashes the
// OSD at startup. Reading the attribute after each poll re-arms the notify.
func (o *osdState) watchBacklight(dev string) {
	maxb, ok := readSysInt(filepath.Join(dev, "max_brightness"))
	if !ok || maxb <= 0 {
		return
	}
	fd, err := unix.Open(filepath.Join(dev, "actual_brightness"), unix.O_RDONLY, 0)
	if err != nil {
		return
	}
	defer unix.Close(fd)

	buf := make([]byte, 32)
	if cur, ok := readActual(fd, buf); ok {
		o.publish(float64(cur) / float64(maxb))
	}
	for {
		fds := []unix.PollFd{{Fd: int32(fd), Events: unix.POLLPRI | unix.POLLERR}}
		n, err := unix.Poll(fds, -1)
		if err != nil {
			if err == unix.EINTR {
				continue
			}
			return
		}
		if n == 0 {
			continue
		}
		cur, ok := readActual(fd, buf)
		if !ok {
			continue
		}
		o.seq++
		o.publish(float64(cur) / float64(maxb))
	}
}

// readActual reads the backlight level via pread at offset 0, which both fetches
// the value and clears the pending poll condition on the sysfs file.
func readActual(fd int, buf []byte) (int, bool) {
	n, err := unix.Pread(fd, buf, 0)
	if err != nil || n <= 0 {
		return 0, false
	}
	v, err := strconv.Atoi(strings.TrimSpace(string(buf[:n])))
	if err != nil {
		return 0, false
	}
	return v, true
}
