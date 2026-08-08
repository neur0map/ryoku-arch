package main

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// powersounds watches the battery and AC line over sysfs and plays the battery,
// plug, and unplug cues. It is the only consumer of power state that lives in the
// daemon today; it reads /sys/class/power_supply directly rather than depend on a
// running UPower. A machine with no battery or no mains simply never fires those
// cues.

const powerSupplyRoot = "/sys/class/power_supply"

// batteryLowPercent is the critical threshold: at or below 3 (strictly under 4)
// the discharging-battery cue fires. batteryLowRepeat is how often it repeats
// while the machine stays in that state.
const (
	batteryLowPercent = 4
	batteryLowRepeat  = 60 * time.Second
	powerPoll         = 2 * time.Second
)

// powerState is the sysfs snapshot the cues key off.
type powerState struct {
	haveAC      bool // a Mains supply exists
	online      bool // AC is plugged in
	present     bool // a battery is present
	discharging bool // battery status is Discharging
	percent     int  // battery capacity 0..100
}

// readPowerState scans the power-supply class for the battery and mains devices.
// Missing attributes leave their fields zero, which the cue guards treat as "no
// cue".
func readPowerState() powerState {
	var st powerState
	entries, err := os.ReadDir(powerSupplyRoot)
	if err != nil {
		return st
	}
	for _, e := range entries {
		base := filepath.Join(powerSupplyRoot, e.Name())
		switch readTrim(filepath.Join(base, "type")) {
		case "Mains":
			st.haveAC = true
			if readTrim(filepath.Join(base, "online")) == "1" {
				st.online = true
			}
		case "Battery":
			if readTrim(filepath.Join(base, "present")) == "1" {
				st.present = true
			}
			if strings.EqualFold(readTrim(filepath.Join(base, "status")), "Discharging") {
				st.discharging = true
			}
			if n, err := strconv.Atoi(readTrim(filepath.Join(base, "capacity"))); err == nil {
				st.percent = n
			}
		}
	}
	return st
}

// watchPowerSounds fires the battery-low, plug, and unplug cues off sysfs.
//
// Plug/unplug: the very first AC reading only seeds the baseline so no cue fires
// at login for the state the machine booted in; thereafter every online change
// plays plug (on) or unplug (off).
//
// Battery low: while the battery is present, discharging, and under 4 percent,
// the cue plays at once on entering the state and then every 60 s until it
// leaves. Leaving the state (charging, plugged, or risen above the threshold)
// re-arms the immediate play for the next time it drops.
// powerCue tracks the state the cue guards need across polls.
type powerCue struct {
	acSeen    bool
	lastAC    bool
	lowActive bool
	lastLow   time.Time
}

// step folds one sysfs snapshot into the tracker and returns the cues to play.
// It is pure over its receiver and now so the skip-first-AC and battery-low
// immediate-then-repeat rules are unit-testable without sysfs or a clock.
func (c *powerCue) step(st powerState, now time.Time) []string {
	var cues []string
	if st.haveAC {
		if !c.acSeen {
			c.acSeen = true
			c.lastAC = st.online
		} else if st.online != c.lastAC {
			c.lastAC = st.online
			if st.online {
				cues = append(cues, soundPowerPlug)
			} else {
				cues = append(cues, soundPowerUnplug)
			}
		}
	}

	low := st.present && st.discharging && st.percent < batteryLowPercent
	if low {
		if !c.lowActive || now.Sub(c.lastLow) >= batteryLowRepeat {
			cues = append(cues, soundBatteryLow)
			c.lastLow = now
		}
		c.lowActive = true
	} else {
		c.lowActive = false
	}
	return cues
}

func (d *daemon) watchPowerSounds() {
	var c powerCue
	for {
		for _, cue := range c.step(readPowerState(), time.Now()) {
			playSound(cue)
		}
		select {
		case <-d.quit:
			return
		case <-time.After(powerPoll):
		}
	}
}
