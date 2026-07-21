package main

import (
	"os"
	"path/filepath"
	"testing"
)

// ids returns the tunable ids for a gpu, so a test asserts the shape without
// caring about order or the other fields.
func ids(ts []Tunable, gpu string) []string {
	var out []string
	for _, t := range ts {
		if t.GPU == gpu {
			out = append(out, t.ID)
		}
	}
	return out
}

func has(ts []Tunable, gpu, id string) *Tunable { return findTunable(ts, gpu, id) }

func TestBuildTunablesNvidia(t *testing.T) {
	in := tuneInputs{gpus: []gpuProbe{{
		slot: "0000:01:00.0", driver: "nvidia",
		nv: &nvInfo{powerSupported: true, powerMinW: 5, powerMaxW: 125, powerCurW: 80,
			persistence: false, clockMaxGr: 3105, clockCurGr: 675},
	}}}
	ts := buildTunables(in)
	if pl := has(ts, "0000:01:00.0", "power_limit"); pl == nil || pl.Max != 125 || pl.Kind != "slider" {
		t.Fatalf("power_limit missing or wrong: %+v", pl)
	}
	if has(ts, "0000:01:00.0", "persistence") == nil {
		t.Error("persistence toggle missing")
	}
	if cl := has(ts, "0000:01:00.0", "clock_lock"); cl == nil || cl.Risk != "advanced" {
		t.Error("clock_lock should be present and advanced")
	}
}

// A laptop GPU that reports power management unsupported must not show a slider.
func TestBuildTunablesNvidiaNoPower(t *testing.T) {
	in := tuneInputs{gpus: []gpuProbe{{
		slot: "0000:01:00.0", driver: "nvidia",
		nv: &nvInfo{powerSupported: false, clockMaxGr: 0},
	}}}
	ts := buildTunables(in)
	if has(ts, "0000:01:00.0", "power_limit") != nil {
		t.Error("power_limit must be hidden when unsupported")
	}
	if has(ts, "0000:01:00.0", "clock_lock") != nil {
		t.Error("clock_lock must be hidden when max clock unknown")
	}
}

func TestBuildTunablesAMD(t *testing.T) {
	in := tuneInputs{gpus: []gpuProbe{{
		slot: "0000:65:00.0", driver: "amdgpu",
		amdPerfLevel: "auto",
		amdOD:        &odRange{minMHz: 800, maxMHz: 2799, curMin: 800, curMax: 2799},
	}}}
	ts := buildTunables(in)
	if pl := has(ts, "0000:65:00.0", "perf_level"); pl == nil || pl.Kind != "segment" {
		t.Fatal("perf_level segment missing")
	}
	if od := has(ts, "0000:65:00.0", "sclk_od"); od == nil || od.Min != 800 || od.Max != 2799 || od.Risk != "advanced" {
		t.Fatalf("sclk_od wrong: %+v", od)
	}
	// No power1_cap and no pwm1 on this APU: neither knob may appear.
	if has(ts, "0000:65:00.0", "power_cap") != nil || has(ts, "0000:65:00.0", "fan_pct") != nil {
		t.Error("APU without hwmon cap/fan must not expose power_cap or fan_pct")
	}
}

func TestBuildTunablesPlatform(t *testing.T) {
	in := tuneInputs{platform: &platformProfile{choices: []string{"quiet", "balanced", "performance"}, current: "balanced"}}
	ts := buildTunables(in)
	th := has(ts, "platform", "thermal")
	if th == nil || th.Value != "balanced" || len(th.Options) != 3 {
		t.Fatalf("thermal profile wrong: %+v", th)
	}
}

// A machine with nothing writable returns an empty list, which the page renders
// as a clean read-only state.
func TestBuildTunablesEmpty(t *testing.T) {
	if ts := buildTunables(tuneInputs{gpus: []gpuProbe{{slot: "x", driver: "nouveau"}}}); len(ts) != 0 {
		t.Errorf("unsupported driver must yield no knobs, got %v", ids(ts, "x"))
	}
}

func TestParseOD(t *testing.T) {
	// The real pp_od_clk_voltage layout from an amdgpu APU.
	s := "OD_SCLK:\n0:        800Mhz\n1:       2799Mhz\nOD_RANGE:\nSCLK:     800Mhz       2799Mhz\n"
	od := parseOD(s)
	if od == nil {
		t.Fatal("parseOD returned nil for valid input")
	}
	if od.minMHz != 800 || od.maxMHz != 2799 || od.curMax != 2799 {
		t.Errorf("parseOD = %+v", od)
	}
	if parseOD("") != nil {
		t.Error("empty pp_od_clk_voltage must parse to nil (overdrive locked)")
	}
	if parseOD("OD_SCLK:\n0: 800Mhz\n") != nil {
		t.Error("missing OD_RANGE must yield nil, not a zero range")
	}
}

func TestClampAndValidate(t *testing.T) {
	if clampf(200, 5, 125) != 125 {
		t.Error("over-max must clamp to max")
	}
	if clampf(1, 5, 125) != 5 {
		t.Error("under-min must clamp to min")
	}
	if !inList([]string{"auto", "low", "high"}, "low") {
		t.Error("valid segment option rejected")
	}
	if inList([]string{"auto", "low", "high"}, "turbo") {
		t.Error("invalid segment option accepted")
	}
}

// TestApplyKnobFakeSysfs exercises the real write dispatch against a temp sysfs
// tree, so the privileged half is proven without root or touching a GPU. The
// nvidia knobs go through nvidia-smi (a real exec) and are not covered here.
func TestApplyKnobFakeSysfs(t *testing.T) {
	root := t.TempDir()
	t.Setenv("RYOKU_SYSFS_ROOT", root)
	dev := filepath.Join(root, "sys/class/drm/card0/device")
	hw := filepath.Join(dev, "hwmon", "hwmon3")
	mustMkdir(t, hw)
	// seed the files a real amdgpu card exposes
	seed(t, filepath.Join(dev, "power_dpm_force_performance_level"), "auto")
	seed(t, filepath.Join(dev, "pp_od_clk_voltage"), "OD_SCLK:\n0: 800Mhz\n1: 2799Mhz\nOD_RANGE:\nSCLK: 800Mhz 2799Mhz\n")
	seed(t, filepath.Join(hw, "power1_cap"), "15000000")
	seed(t, filepath.Join(hw, "pwm1_enable"), "2")
	seed(t, filepath.Join(hw, "pwm1"), "0")
	seed(t, filepath.Join(root, "sys/firmware/acpi/platform_profile"), "balanced")

	in := tuneInputs{gpus: []gpuProbe{{slot: "0000:65:00.0", card: "card0", driver: "amdgpu"}}}

	if err := applyKnob(in, "0000:65:00.0", "perf_level", "high"); err != nil {
		t.Fatal(err)
	}
	if got := readTrim(filepath.Join(dev, "power_dpm_force_performance_level")); got != "high" {
		t.Errorf("perf_level = %q, want high", got)
	}

	// power_cap takes watts and must land as microwatts.
	if err := applyKnob(in, "0000:65:00.0", "power_cap", "12"); err != nil {
		t.Fatal(err)
	}
	if got := readTrim(filepath.Join(hw, "power1_cap")); got != "12000000" {
		t.Errorf("power1_cap = %q, want 12000000", got)
	}

	// fan_pct switches to manual (1) and writes the scaled duty.
	if err := applyKnob(in, "0000:65:00.0", "fan_pct", "50"); err != nil {
		t.Fatal(err)
	}
	if got := readTrim(filepath.Join(hw, "pwm1_enable")); got != "1" {
		t.Errorf("pwm1_enable = %q, want 1", got)
	}
	if got := readTrim(filepath.Join(hw, "pwm1")); got != "127" {
		t.Errorf("pwm1 = %q, want 127 (50%% of 255)", got)
	}

	// sclk_od ends the commit protocol with "c" left in the file.
	if err := applyKnob(in, "0000:65:00.0", "sclk_od", "2600"); err != nil {
		t.Fatal(err)
	}
	if got := readTrim(filepath.Join(dev, "pp_od_clk_voltage")); got != "c" {
		t.Errorf("pp_od_clk_voltage last write = %q, want c", got)
	}
	if got := readTrim(filepath.Join(dev, "power_dpm_force_performance_level")); got != "manual" {
		t.Errorf("sclk_od must switch perf to manual, got %q", got)
	}

	// platform thermal writes the profile file directly.
	if err := applyKnob(in, "platform", "thermal", "quiet"); err != nil {
		t.Fatal(err)
	}
	if got := readTrim(filepath.Join(root, "sys/firmware/acpi/platform_profile")); got != "quiet" {
		t.Errorf("platform_profile = %q, want quiet", got)
	}
}

func mustMkdir(t *testing.T, p string) {
	t.Helper()
	if err := os.MkdirAll(p, 0o755); err != nil {
		t.Fatal(err)
	}
}

func seed(t *testing.T, p, content string) {
	t.Helper()
	mustMkdir(t, filepath.Dir(p))
	if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func TestNormalizePerf(t *testing.T) {
	for in, want := range map[string]string{"auto": "auto", "low": "low", "high": "high", "manual": "auto", "profile_peak": "auto"} {
		if got := normalizePerf(in); got != want {
			t.Errorf("normalizePerf(%q) = %q, want %q", in, got, want)
		}
	}
}
