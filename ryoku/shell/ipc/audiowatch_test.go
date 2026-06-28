package main

import (
	"os/exec"
	"testing"
	"time"
)

func TestParseAudioActive(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want bool
	}{
		{"uncorked", "Sink Input #1\n\tCorked: no\n", true},
		{"corked", "Sink Input #1\n\tCorked: yes\n", false},
		{"empty", "", false},
		{"none", "no sink inputs found", false},
		{"mixed", "Corked: yes\nCorked: no\n", true},
	}
	for _, c := range cases {
		if got := parseAudioActive(c.in); got != c.want {
			t.Errorf("%s: parseAudioActive = %v, want %v", c.name, got, c.want)
		}
	}
}

func TestParseUnloadFlag(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want bool
	}{
		{"true", `{"unloadVisualizerWhenSilent":true}`, true},
		{"false", `{"unloadVisualizerWhenSilent":false}`, false},
		{"other flag", `{"freezeVisualizerWhenIdle":true}`, false},
		{"absent", `{}`, false},
		{"malformed", `not json`, false},
		{"empty", ``, false},
		{"wrong type", `{"unloadVisualizerWhenSilent":"yes"}`, false},
	}
	for _, c := range cases {
		if got := parseUnloadFlag([]byte(c.in)); got != c.want {
			t.Errorf("%s: parseUnloadFlag = %v, want %v", c.name, got, c.want)
		}
	}
}

func newGateDaemon() *daemon {
	return &daemon{
		proc:     map[string]*exec.Cmd{},
		gateWant: map[string]bool{},
		gateWake: map[string]chan struct{}{},
	}
}

func TestGateDefaultsToAllowed(t *testing.T) {
	d := newGateDaemon()
	if !d.gateAllows("visualizer") {
		t.Fatal("a component with no gate must be allowed to run (safe default)")
	}
}

func TestGateCloseAndOpen(t *testing.T) {
	d := newGateDaemon()
	d.setGate("visualizer", false)
	if d.gateAllows("visualizer") {
		t.Fatal("a closed gate must block the start")
	}
	ch := d.gateWaitCh("visualizer")
	d.setGate("visualizer", true)
	if !d.gateAllows("visualizer") {
		t.Fatal("an opened gate must allow the start")
	}
	select {
	case <-ch:
	default:
		t.Fatal("opening the gate must wake a parked supervisor")
	}
}

func TestGateCloseKillsLiveProcess(t *testing.T) {
	d := newGateDaemon()
	cmd := exec.Command("sleep", "30")
	if err := cmd.Start(); err != nil {
		t.Skipf("cannot start sleep: %v", err)
	}
	d.mu.Lock()
	d.proc["visualizer"] = cmd
	d.mu.Unlock()

	done := make(chan struct{})
	go func() { _ = cmd.Wait(); close(done) }()

	d.setGate("visualizer", false)

	select {
	case <-done:
	case <-time.After(3 * time.Second):
		_ = cmd.Process.Kill()
		t.Fatal("closing the gate must SIGTERM the live process so the supervisor parks")
	}
}

func TestSetGateNoopOnSameState(t *testing.T) {
	d := newGateDaemon()
	d.setGate("visualizer", true)
	ch := d.gateWaitCh("visualizer")
	select {
	case <-ch:
	default:
	}
	d.setGate("visualizer", true)
	select {
	case <-ch:
		t.Fatal("repeating the same gate state must not re-signal the wake channel")
	default:
	}
}
