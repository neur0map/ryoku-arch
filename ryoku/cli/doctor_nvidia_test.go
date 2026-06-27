package main

import "testing"

// idempotency lock on the NVIDIA reconciler. canonical config we write must
// read back ok (else doctor rebuilds the initramfs every run); pre-fix or
// missing config = "needs fixing".
func TestNvidiaConfigOK(t *testing.T) {
	cases := []struct {
		name             string
		modprobe, mkinit string
		want             bool
	}{
		{"canonical config the reconciler writes", nvidiaModprobeConf, nvidiaMkinitcpioConf, true},
		{"old install: modeset only, no nouveau blacklist", "options nvidia_drm modeset=1 fbdev=1\n", nvidiaMkinitcpioConf, false},
		{"blacklisted but nvidia modules not in the initramfs", nvidiaModprobeConf, "", false},
		{"both drop-ins missing (readFileSafe error strings)", "(open /etc/modprobe.d/nvidia.conf: no such file or directory)", "(open /etc/mkinitcpio.conf.d/nvidia.conf: no such file or directory)", false},
	}
	for _, c := range cases {
		if got := nvidiaConfigOK(c.modprobe, c.mkinit); got != c.want {
			t.Errorf("%s: nvidiaConfigOK(...) = %v, want %v", c.name, got, c.want)
		}
	}
}
