package main

import "testing"

func TestResolvePresetValue(t *testing.T) {
	seg := &Tunable{Kind: "segment", Options: []string{"auto", "low", "high"}}
	if resolvePresetValue(seg, "low") != "low" {
		t.Error("valid segment option should pass through")
	}
	if resolvePresetValue(seg, "turbo") != "" {
		t.Error("segment option not offered must resolve to skip")
	}
	sl := &Tunable{Kind: "slider", Min: 5, Max: 125}
	if resolvePresetValue(sl, "max") != "125" {
		t.Errorf("max = %q, want 125", resolvePresetValue(sl, "max"))
	}
	if resolvePresetValue(sl, "min") != "5" {
		t.Errorf("min = %q, want 5", resolvePresetValue(sl, "min"))
	}
	if resolvePresetValue(sl, "70") != "70" {
		t.Error("a concrete number (custom preset) should pass through")
	}
	if resolvePresetValue(sl, "quiet") != "" {
		t.Error("a symbolic that is not min/max/number must skip on a slider")
	}
}

// A built-in preset resolves only against the knobs a machine has: the
// Performance preset on an NVIDIA-only box hits nothing AMD, and vice versa.
func TestResolveJobsGeneric(t *testing.T) {
	perf := findBuiltin("Performance")
	if perf == nil {
		t.Fatal("Performance built-in missing")
	}
	// AMD-only machine with overdrive: perf_level + sclk_od apply, power_limit
	// (an nvidia knob here) and thermal are absent, so they are skipped.
	amd := []Tunable{
		{GPU: "0000:65:00.0", ID: "perf_level", Kind: "segment", Options: []string{"auto", "low", "high"}},
		{GPU: "0000:65:00.0", ID: "sclk_od", Kind: "slider", Min: 800, Max: 2799},
	}
	jobs := resolveJobs(perf, amd)
	if len(jobs) != 2 {
		t.Fatalf("want 2 jobs (perf_level, sclk_od), got %d: %+v", len(jobs), jobs)
	}
	// perf_level must resolve before sclk_od so manual-mode sticks.
	if jobs[0].ID != "perf_level" || jobs[1].ID != "sclk_od" {
		t.Errorf("job order wrong: %+v", jobs)
	}
	if jobs[1].Value != "2799" {
		t.Errorf("sclk_od max = %q, want 2799", jobs[1].Value)
	}
	// A machine with no matching knobs yields nothing, never a guess.
	if got := resolveJobs(perf, []Tunable{{GPU: "x", ID: "gt_freq", Kind: "slider", Min: 300, Max: 1900}}); len(got) != 0 {
		t.Errorf("no matching knob should yield 0 jobs, got %+v", got)
	}
}

func TestPresetSaveListDelete(t *testing.T) {
	t.Setenv("XDG_CONFIG_HOME", t.TempDir())
	// no file yet: only the three built-ins
	if got := len(allPresets()); got != 3 {
		t.Fatalf("fresh machine should have 3 built-ins, got %d", got)
	}
	if err := saveCustomPresets([]preset{{Name: "My OC", Entries: []presetEntry{{GPU: "0000:65:00.0", ID: "sclk_od", Value: "2700"}}}}); err != nil {
		t.Fatal(err)
	}
	all := allPresets()
	if len(all) != 4 || all[3].Name != "My OC" || all[3].Builtin {
		t.Fatalf("custom preset not listed after built-ins: %+v", all)
	}
	if isBuiltin("My OC") {
		t.Error("custom name must not read as built-in")
	}
	// delete leaves only built-ins
	customs := loadCustomPresets()
	out := customs[:0]
	for _, p := range customs {
		if p.Name != "My OC" {
			out = append(out, p)
		}
	}
	if err := saveCustomPresets(out); err != nil {
		t.Fatal(err)
	}
	if len(allPresets()) != 3 {
		t.Error("delete should return to 3 built-ins")
	}
}

func findBuiltin(name string) *preset {
	for i := range builtinPresets {
		if builtinPresets[i].Name == name {
			return &builtinPresets[i]
		}
	}
	return nil
}
