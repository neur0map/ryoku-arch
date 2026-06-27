package main

import "testing"

func TestHookActionsBind(t *testing.T) {
	pass := &GPU{Slot: "0000:01:00.0", DrivesDisplay: false, Functions: []string{"0000:01:00.0", "0000:01:00.1"}}
	acts, err := hookActions("prepare", pass)
	if err != nil {
		t.Fatal(err)
	}
	if acts[0].Kind != "modprobe" || acts[0].Value != "vfio-pci" {
		t.Errorf("first action = %+v, want modprobe vfio-pci", acts[0])
	}
	if !hasWrite(acts, "/sys/bus/pci/devices/0000:01:00.0/driver_override", "vfio-pci") {
		t.Error("missing driver_override for the GPU function")
	}
	if !hasWrite(acts, "/sys/bus/pci/devices/0000:01:00.1/driver_override", "vfio-pci") {
		t.Error("missing driver_override for the audio function")
	}
	if !hasWrite(acts, "/sys/bus/pci/drivers_probe", "0000:01:00.0") {
		t.Error("missing drivers_probe")
	}
}

func TestHookActionsRelease(t *testing.T) {
	pass := &GPU{Slot: "0000:01:00.0", Functions: []string{"0000:01:00.0"}}
	acts, err := hookActions("release", pass)
	if err != nil {
		t.Fatal(err)
	}
	if !hasWrite(acts, "/sys/bus/pci/devices/0000:01:00.0/driver_override", "") {
		t.Error("release should clear driver_override")
	}
}

func TestHookRefusesWhenDgpuDrivesDisplay(t *testing.T) {
	pass := &GPU{Slot: "0000:01:00.0", DrivesDisplay: true, Functions: []string{"0000:01:00.0"}}
	if _, err := hookActions("prepare", pass); err == nil {
		t.Error("expected refusal: must not vfio-bind the GPU driving the screen")
	}
}

func hasWrite(acts []sysAction, path, val string) bool {
	for _, a := range acts {
		if (a.Kind == "write" || a.Kind == "write-ok") && a.Path == path && a.Value == val {
			return true
		}
	}
	return false
}
