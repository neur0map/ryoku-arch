#!/usr/bin/env python3
# Capture the default sink's monitor as mono PCM (PipeWire) and emit one line of
# downsampled amplitude samples per frame, so the visualiser's line style can
# draw the actual audio waveform: a real oscilloscope, not a spectrum.
#
# Self-contained so Quickshell can exec a single process (SIGTERM reaches it,
# and it tears down pw-record, leaving nothing orphaned): it resolves the
# default sink's monitor node, spawns pw-record on it, and downsamples the raw
# s16le stream. Prints space-separated floats in [-1, 1], ~60 lines a second.
# The Pulse path (parec) cannot connect on this stack, so we go PipeWire-native,
# and pw-record needs the numeric node id, not the monitor name.
import sys
import array
import shutil
import signal
import subprocess

RATE = 48000
WIN = 1600   # samples per drawn frame (~33 ms window)
OUT = 220    # points emitted per frame
HOP = 800    # samples advanced per frame (~60 fps)


def monitor_target():
    try:
        sink = subprocess.check_output(["pactl", "get-default-sink"], text=True).strip()
        rows = subprocess.check_output(["pactl", "list", "short", "sources"], text=True)
    except Exception:
        return None
    want = sink + ".monitor"
    monitors = []
    for line in rows.splitlines():
        f = line.split("\t")
        if len(f) >= 2 and f[1].endswith(".monitor"):
            monitors.append(f[0])
            if f[1] == want:
                return f[0]
    return monitors[0] if monitors else None


if not shutil.which("pw-record"):
    sys.exit(0)
tgt = monitor_target()
if tgt is None:
    sys.exit(0)

proc = subprocess.Popen(
    ["pw-record", "--target", tgt, "--rate", str(RATE), "--channels", "1",
     "--format", "s16", "--raw", "-"],
    stdout=subprocess.PIPE)


def cleanup(*_):
    try:
        proc.terminate()
    except Exception:
        pass
    sys.exit(0)


signal.signal(signal.SIGTERM, cleanup)
signal.signal(signal.SIGINT, cleanup)

step = max(1, WIN // OUT)
buf = bytearray()
read = proc.stdout.read
write = sys.stdout.write
flush = sys.stdout.flush

try:
    while True:
        chunk = read(4096)
        if not chunk:
            break
        buf += chunk
        while len(buf) >= WIN * 2:
            a = array.array("h")
            a.frombytes(bytes(buf[:WIN * 2]))
            out = [("%.3f" % (a[i] / 32768.0)) for i in range(0, WIN, step)]
            write(" ".join(out[:OUT]) + "\n")
            flush()
            del buf[:HOP * 2]
except (BrokenPipeError, KeyboardInterrupt):
    pass
finally:
    cleanup()
