package main

import (
	"reflect"
	"testing"
)

// The three power actions must map to the documented systemctl invocations, and
// there must be no suspend action anywhere: the reference tree has none, so
// inventing one is a parity failure.
func TestSessionActionArgv(t *testing.T) {
	want := map[string][]string{
		"logout":   {"systemctl", "--user", "exit"},
		"reboot":   {"systemctl", "reboot"},
		"shutdown": {"systemctl", "poweroff"},
	}
	for action, argv := range want {
		got, ok := sessionActionArgv(action)
		if !ok {
			t.Fatalf("sessionActionArgv(%q) missing", action)
		}
		if !reflect.DeepEqual(got, argv) {
			t.Errorf("sessionActionArgv(%q) = %v, want %v", action, got, argv)
		}
	}
	for _, absent := range []string{"suspend", "hibernate", "", "poweroff"} {
		if _, ok := sessionActionArgv(absent); ok {
			t.Errorf("sessionActionArgv(%q) exists; only logout/reboot/shutdown are actions", absent)
		}
	}
}

// startSession must register exactly the three calls, so QML's confirmation
// dialog can reach each action and nothing else.
func TestStartSessionRegistersCalls(t *testing.T) {
	d := &daemon{}
	d.startSession()
	for _, action := range []string{"logout", "reboot", "shutdown"} {
		if d.callHandler("session."+action) == nil {
			t.Errorf("session.%s call not registered", action)
		}
	}
	if d.callHandler("session.suspend") != nil {
		t.Error("session.suspend registered; no suspend action exists")
	}
}
