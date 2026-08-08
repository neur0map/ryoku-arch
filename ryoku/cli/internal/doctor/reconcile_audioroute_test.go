package doctor

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// fakePactl puts a stub `pactl` on PATH. It answers the three queries the
// reconciler makes from the fixture strings, and appends every move it is asked
// to make to a log so the test can assert on what was actually moved.
func fakePactl(t *testing.T, defaultSink, sinks, sinkInputs string) (moves string) {
	t.Helper()
	bin := t.TempDir()
	log := filepath.Join(bin, "moves.log")
	script := "#!/bin/sh\n" +
		"case \"$1 $2\" in\n" +
		"'get-default-sink ') printf '%s\\n' '" + defaultSink + "' ;;\n" +
		"'list short') case \"$3\" in\n" +
		"  sinks) printf '%s' '" + sinks + "' ;;\n" +
		"  sink-inputs) printf '%s' '" + sinkInputs + "' ;;\n" +
		"esac ;;\n" +
		"'move-sink-input '*) printf '%s->%s\\n' \"$2\" \"$3\" >> '" + log + "' ;;\n" +
		"esac\n"
	if err := os.WriteFile(filepath.Join(bin, "pactl"), []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	return log
}

func readLog(t *testing.T, p string) string {
	t.Helper()
	b, err := os.ReadFile(p)
	if err != nil {
		return ""
	}
	return string(b)
}

const twoSinks = "30667\talsa_output.analog\tPipeWire\ts32le\tRUNNING\n38922\tbluez_output.bt\tPipeWire\tfloat32le\tIDLE\n"

// Playback already on the default sink is the healthy case: report ok and,
// above all, move nothing.
func TestAudioRoutingLeavesHealthyRoutingAlone(t *testing.T) {
	log := fakePactl(t, "bluez_output.bt", twoSinks, "37475\t38922\t37474\tPipeWire\n")
	if got := reconcileAudioRouting(false); got.status != recOK {
		t.Fatalf("healthy routing should be ok, got %v (%s)", got.status, got.detail)
	}
	if m := readLog(t, log); m != "" {
		t.Errorf("healthy routing must not move anything, moved: %q", m)
	}
}

// The break the shell actually hits: headphones become the default sink while
// the stream stays on the old one, so cava watches a device nothing plays to.
func TestAudioRoutingMovesStrandedPlayback(t *testing.T) {
	log := fakePactl(t, "bluez_output.bt", twoSinks, "37475\t30667\t37474\tPipeWire\n")

	if got := reconcileAudioRouting(true); got.status != recWouldFix {
		t.Fatalf("check-only should report a fix, got %v (%s)", got.status, got.detail)
	}
	if m := readLog(t, log); m != "" {
		t.Errorf("check-only must not move anything, moved: %q", m)
	}

	got := reconcileAudioRouting(false)
	if got.status != recFixed {
		t.Fatalf("stranded playback should be fixed, got %v (%s)", got.status, got.detail)
	}
	if m := readLog(t, log); !strings.Contains(m, "37475->bluez_output.bt") {
		t.Errorf("stream not moved onto the default sink, log: %q", m)
	}
}

// A deliberate split keeps one stream on the default sink. Guessing at intent
// there would drag an app the user moved on purpose back again, so leave it.
func TestAudioRoutingLeavesDeliberateSplitAlone(t *testing.T) {
	log := fakePactl(t, "bluez_output.bt", twoSinks,
		"37475\t30667\t37474\tPipeWire\n37476\t38922\t37474\tPipeWire\n")
	if got := reconcileAudioRouting(false); got.status != recOK {
		t.Fatalf("split routing should be left alone, got %v (%s)", got.status, got.detail)
	}
	if m := readLog(t, log); m != "" {
		t.Errorf("split routing must not move anything, moved: %q", m)
	}
}

// Silence is not a fault: with nothing playing there is no routing to judge.
func TestAudioRoutingIgnoresSilence(t *testing.T) {
	log := fakePactl(t, "bluez_output.bt", twoSinks, "")
	if got := reconcileAudioRouting(false); got.status != recOK {
		t.Fatalf("silence should be ok, got %v (%s)", got.status, got.detail)
	}
	if m := readLog(t, log); m != "" {
		t.Errorf("silence must not move anything, moved: %q", m)
	}
}
