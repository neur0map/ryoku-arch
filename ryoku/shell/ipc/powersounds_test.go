package main

import (
	"testing"
	"time"
)

func TestKnownSound(t *testing.T) {
	for _, ev := range []string{soundShutter, soundVolumeChange, soundBatteryLow, soundPowerPlug, soundPowerUnplug} {
		if !knownSound(ev) {
			t.Errorf("knownSound(%q) = false, want true", ev)
		}
	}
	for _, ev := range []string{"", "timer", "shutter ", "unknown"} {
		if knownSound(ev) {
			t.Errorf("knownSound(%q) = true, want false", ev)
		}
	}
}

func TestPowerCueSkipsFirstAC(t *testing.T) {
	var c powerCue
	now := time.Unix(0, 0)
	// First reading only seeds the baseline: no plug/unplug at login.
	if cues := c.step(powerState{haveAC: true, online: true}, now); len(cues) != 0 {
		t.Fatalf("first AC reading played %v, want none", cues)
	}
	// Unplug after the baseline fires the unplug cue.
	if cues := c.step(powerState{haveAC: true, online: false}, now); len(cues) != 1 || cues[0] != soundPowerUnplug {
		t.Fatalf("unplug played %v, want [power-unplug]", cues)
	}
	// Plug back in fires the plug cue.
	if cues := c.step(powerState{haveAC: true, online: true}, now); len(cues) != 1 || cues[0] != soundPowerPlug {
		t.Fatalf("plug played %v, want [power-plug]", cues)
	}
	// No change is silent.
	if cues := c.step(powerState{haveAC: true, online: true}, now); len(cues) != 0 {
		t.Fatalf("unchanged AC played %v, want none", cues)
	}
}

func TestPowerCueBatteryLow(t *testing.T) {
	var c powerCue
	t0 := time.Unix(1000, 0)
	low := powerState{present: true, discharging: true, percent: 3}

	// Entering the low state plays immediately.
	if cues := c.step(low, t0); len(cues) != 1 || cues[0] != soundBatteryLow {
		t.Fatalf("entering low played %v, want [battery-low]", cues)
	}
	// Still low, but under 60 s: silent.
	if cues := c.step(low, t0.Add(59*time.Second)); len(cues) != 0 {
		t.Fatalf("low before repeat played %v, want none", cues)
	}
	// 60 s later: repeats.
	if cues := c.step(low, t0.Add(60*time.Second)); len(cues) != 1 || cues[0] != soundBatteryLow {
		t.Fatalf("low at repeat played %v, want [battery-low]", cues)
	}
	// At the threshold (4 percent) it is no longer low.
	if cues := c.step(powerState{present: true, discharging: true, percent: 4}, t0.Add(120*time.Second)); len(cues) != 0 {
		t.Fatalf("percent==4 played %v, want none", cues)
	}
	// Dropping back below re-arms the immediate play.
	if cues := c.step(low, t0.Add(121*time.Second)); len(cues) != 1 || cues[0] != soundBatteryLow {
		t.Fatalf("re-entering low played %v, want [battery-low]", cues)
	}
}

func TestPowerCueChargingSilent(t *testing.T) {
	var c powerCue
	now := time.Unix(0, 0)
	// Present and low but charging: no battery cue.
	if cues := c.step(powerState{present: true, discharging: false, percent: 1}, now); len(cues) != 0 {
		t.Fatalf("charging low battery played %v, want none", cues)
	}
	// Discharging but absent: no battery cue.
	if cues := c.step(powerState{present: false, discharging: true, percent: 1}, now); len(cues) != 0 {
		t.Fatalf("absent battery played %v, want none", cues)
	}
}
