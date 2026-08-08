package main

import (
	"encoding/json"
	"os"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// profileNames extracts the ordered profile names from the raw Profiles
// property (aa{sv}), skipping malformed rows and preserving service order.
func TestProfileNames(t *testing.T) {
	raw := []map[string]dbus.Variant{
		{"Profile": dbus.MakeVariant("power-saver"), "Driver": dbus.MakeVariant("amd_pstate")},
		{"Profile": dbus.MakeVariant("balanced")},
		{"Driver": dbus.MakeVariant("only")}, // no Profile key, skipped
		{"Profile": dbus.MakeVariant("performance")},
	}
	got := profileNames(raw)
	want := []string{"power-saver", "balanced", "performance"}
	if len(got) != len(want) {
		t.Fatalf("profileNames = %v, want %v", got, want)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("profileNames[%d] = %q, want %q (order must be preserved)", i, got[i], want[i])
		}
	}

	if profileNames("not the right type") != nil {
		t.Error("profileNames on a wrong-typed value should be nil")
	}
}

// TestLivePowerProfilesFrame exercises the real publish path against the running
// power-profiles daemon and prints the frame, as evidence the topic renders live
// data. Gated so the default `go test` stays deterministic and bus-free.
func TestLivePowerProfilesFrame(t *testing.T) {
	if os.Getenv("RYOKU_LIVE_DBUS") == "" {
		t.Skip("set RYOKU_LIVE_DBUS=1 to run the live power-profiles integration")
	}
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		t.Skipf("no system bus: %v", err)
	}
	defer conn.Close()
	p := &powerProfilesState{
		conn:  conn,
		obj:   conn.Object(ppBusName, dbus.ObjectPath(ppPath)),
		topic: newStateTopic(),
	}
	ch := p.topic.subscribe()
	p.publish()
	select {
	case frame := <-ch:
		t.Logf("powerprofiles frame: %s", frame)
		var m struct {
			Active   string   `json:"active_profile"`
			Profiles []string `json:"profiles"`
		}
		if err := json.Unmarshal(frame, &m); err != nil {
			t.Fatalf("frame is not valid JSON: %v", err)
		}
		if len(m.Profiles) == 0 {
			t.Error("no profiles from the running daemon")
		}
	case <-time.After(3 * time.Second):
		t.Fatal("no powerprofiles frame published")
	}
}
