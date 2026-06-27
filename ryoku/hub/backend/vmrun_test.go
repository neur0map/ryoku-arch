package main

import "testing"

func TestLaunchBlocker(t *testing.T) {
	cases := []struct {
		verdict string
		blocked bool
	}{
		{"ready", false},
		{"needs-relogin", true},
		{"needs-reboot", true},
		{"needs-setup", true},
		{"incapable", true},
	}
	for _, tc := range cases {
		msg, blocked := launchBlocker(Capability{Verdict: tc.verdict})
		if blocked != tc.blocked {
			t.Errorf("verdict %q blocked = %v, want %v", tc.verdict, blocked, tc.blocked)
		}
		if blocked && msg == "" {
			t.Errorf("verdict %q blocked but gave no guidance", tc.verdict)
		}
	}
}
