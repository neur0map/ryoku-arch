package main

import "testing"

func TestGroupPlanItems(t *testing.T) {
	on := true
	var items []planItem
	for _, l := range []string{
		"Resume the previous run",
		"NVIDIA proprietary drivers", "Switch login to SDDM", "Ryoku greeter theme",
		"Switch to NetworkManager", "Remove rival shells", "Disable conflicting daemons",
		"Retire the Omarchy repo", "Carry over monitor layout",
		"AUR extras", "Developer toolchain", "fish as login shell",
	} {
		items = append(items, planItem{label: l, on: &on})
	}
	got := groupPlanItems(items)
	headers := 0
	for _, it := range got {
		if it.on == nil {
			headers++
		}
	}
	if headers != 3 {
		t.Fatalf("want 3 section headers over %d toggles, got %d", len(items), headers)
	}
	if got[0].on == nil {
		t.Fatal("the resume row stays on top, before any header")
	}
	if firstToggle(got) != 0 {
		t.Fatalf("first toggle should be the resume row, got %d", firstToggle(got))
	}

	short := groupPlanItems(items[:6])
	if len(short) != 6 {
		t.Fatalf("short plans stay flat, got %d rows", len(short))
	}
}
