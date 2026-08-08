package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// apSecurity derives the reference SecurityType from the NetworkManager AP flag
// triple. WPA3 (SAE) and Enterprise (802.1X) win over the plain RSN/WPA/WEP/open
// ladder, and each flag family is checked against the right bit.
func TestApSecurity(t *testing.T) {
	const (
		privacy = 0x1
		psk     = 0x100
		km8021x = 0x200
		sae     = 0x400
	)
	cases := []struct {
		name            string
		flags, wpa, rsn uint32
		want            string
	}{
		{"open", 0, 0, 0, "None"},
		{"wep", privacy, 0, 0, "Wep"},
		{"wpa only", privacy, psk, 0, "Wpa"},
		{"wpa2 rsn", privacy, 0, psk, "Wpa2"},
		{"wpa2 measured", 0x1, 392, 392, "Wpa2"}, // the live "M" network
		{"wpa3 sae in rsn", privacy, 0, sae, "Wpa3"},
		{"wpa3 sae in wpa", privacy, sae, 0, "Wpa3"},
		{"enterprise rsn", privacy, 0, km8021x, "Enterprise"},
		{"enterprise beats wpa2", privacy, 0, km8021x | psk, "Enterprise"},
	}
	for _, c := range cases {
		if got := apSecurity(c.flags, c.wpa, c.rsn); got != c.want {
			t.Errorf("%s: apSecurity(%#x,%#x,%#x) = %q, want %q", c.name, c.flags, c.wpa, c.rsn, got, c.want)
		}
	}
}

// connectivityFromState maps the NMDeviceState to the three-state reveal label:
// only 100 is Connected, the 40..90 activation range is Connecting, everything
// else Disconnected.
func TestConnectivityFromState(t *testing.T) {
	cases := []struct {
		state uint32
		want  string
	}{
		{100, "Connected"},
		{40, "Connecting"}, {60, "Connecting"}, {90, "Connecting"},
		{30, "Disconnected"}, {20, "Disconnected"}, {0, "Disconnected"},
		{120, "Disconnected"}, // failed
	}
	for _, c := range cases {
		if got := connectivityFromState(c.state); got != c.want {
			t.Errorf("connectivityFromState(%d) = %q, want %q", c.state, got, c.want)
		}
	}
}

// wifiConnectSettings omits the security block for an open network and adds a
// WPA-PSK block with the passphrase when one is supplied.
func TestWifiConnectSettings(t *testing.T) {
	open := wifiConnectSettings("cafe", "")
	if _, ok := open["802-11-wireless-security"]; ok {
		t.Error("open network got a security block")
	}
	if ssid, _ := open["802-11-wireless"]["ssid"].Value().([]byte); string(ssid) != "cafe" {
		t.Errorf("ssid = %q, want cafe", ssid)
	}
	if typ, _ := open["connection"]["type"].Value().(string); typ != "802-11-wireless" {
		t.Errorf("type = %q, want 802-11-wireless", typ)
	}

	secured := wifiConnectSettings("home", "hunter2")
	sec := secured["802-11-wireless-security"]
	if sec == nil {
		t.Fatal("secured network missing security block")
	}
	if km, _ := sec["key-mgmt"].Value().(string); km != "wpa-psk" {
		t.Errorf("key-mgmt = %q, want wpa-psk", km)
	}
	if psk, _ := sec["psk"].Value().(string); psk != "hunter2" {
		t.Errorf("psk = %q, want hunter2", psk)
	}
}

// ssidSaved matches only stored wifi profiles with an equal SSID, ignoring
// non-wifi profiles that happen to share the string.
func TestSsidSaved(t *testing.T) {
	saved := []savedConn{
		{typ: "802-11-wireless", ssid: "home"},
		{typ: "wireguard", id: "vpn", ssid: ""},
		{typ: "802-3-ethernet", ssid: "cafe"}, // wrong type, same string
	}
	if !ssidSaved("home", saved) {
		t.Error("home should be saved")
	}
	if ssidSaved("cafe", saved) {
		t.Error("cafe is ethernet, not a saved wifi profile")
	}
	if ssidSaved("unknown", saved) {
		t.Error("unknown should not be saved")
	}
}

// apFrame carries every field the reveal binds to.
func TestApFrame(t *testing.T) {
	f := apFrame(&apInfo{Ssid: "M", Strength: 50, Security: "Wpa2", Bssid: "D6:31:27:89:88:78", Frequency: 5280, Saved: true, Active: true})
	for _, k := range []string{"ssid", "strength", "security", "bssid", "frequency", "saved", "active"} {
		if _, ok := f[k]; !ok {
			t.Errorf("apFrame missing key %q", k)
		}
	}
	if f["ssid"] != "M" || f["strength"] != 50 || f["active"] != true {
		t.Errorf("apFrame values wrong: %+v", f)
	}
}

func TestDnsServersForSelection(t *testing.T) {
	cases := []struct {
		name     string
		provider string
		custom   []string
		want     []string
		wantErr  bool
	}{
		{"dhcp", "dhcp", nil, nil, false},
		{"cloudflare", "cloudflare", nil, []string{
			"1.1.1.1", "1.0.0.1",
			"2606:4700:4700::1111", "2606:4700:4700::1001",
		}, false},
		{"google", "google", nil, []string{
			"8.8.8.8", "8.8.4.4",
			"2001:4860:4860::8888", "2001:4860:4860::8844",
		}, false},
		{"custom normalizes and deduplicates", "custom", []string{
			" 192.0.2.53 ", "2001:db8::53", "192.0.2.53",
		}, []string{"192.0.2.53", "2001:db8::53"}, false},
		{"custom requires a server", "custom", nil, nil, true},
		{"custom rejects hostnames", "custom", []string{"dns.example.com"}, nil, true},
		{"unknown provider", "quad9", nil, nil, true},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := dnsServersForSelection(c.provider, c.custom)
			if (err != nil) != c.wantErr {
				t.Fatalf("dnsServersForSelection() error = %v, wantErr %v", err, c.wantErr)
			}
			if !reflect.DeepEqual(got, c.want) {
				t.Errorf("dnsServersForSelection() = %#v, want %#v", got, c.want)
			}
		})
	}
}

func TestDnsProviderForServers(t *testing.T) {
	cases := []struct {
		name    string
		servers []string
		want    string
	}{
		{"empty is dhcp", nil, "dhcp"},
		{"cloudflare ignores order", []string{
			"2606:4700:4700::1001", "1.0.0.1",
			"2606:4700:4700::1111", "1.1.1.1",
		}, "cloudflare"},
		{"google", []string{
			"8.8.8.8", "8.8.4.4",
			"2001:4860:4860::8888", "2001:4860:4860::8844",
		}, "google"},
		{"provider subset stays custom", []string{"1.1.1.1"}, "custom"},
		{"unrecognized is custom", []string{"192.0.2.53"}, "custom"},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := dnsProviderForServers(c.servers); got != c.want {
				t.Errorf("dnsProviderForServers(%#v) = %q, want %q", c.servers, got, c.want)
			}
		})
	}
}

func TestDnsHelperArgs(t *testing.T) {
	got, err := dnsHelperArgs("Custom", []string{"192.0.2.53", "2001:db8::53"})
	if err != nil {
		t.Fatal(err)
	}
	want := []string{"custom", "192.0.2.53", "2001:db8::53"}
	if !reflect.DeepEqual(got, want) {
		t.Errorf("dnsHelperArgs() = %#v, want %#v", got, want)
	}
}

func TestDnsHelperPathUsesExecutableDirectory(t *testing.T) {
	previousShellDir := shellDir
	shellDir = ""
	t.Cleanup(func() { shellDir = previousShellDir })

	// Point the packaged-helper probe at an absent path so the executable-dir
	// fallback is reachable regardless of whether this host has ryoku-dns.
	previousPackaged := dnsPackagedHelper
	dnsPackagedHelper = filepath.Join(t.TempDir(), "absent-ryoku-dns")
	t.Cleanup(func() { dnsPackagedHelper = previousPackaged })

	executable, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	want := filepath.Join(filepath.Dir(executable), "ryoku-dns")
	if got := dnsHelperPath(); got != want {
		t.Errorf("dnsHelperPath() = %q, want %q", got, want)
	}
}

func TestDnsHelperPathPrefersPackaged(t *testing.T) {
	pkg := filepath.Join(t.TempDir(), "ryoku-dns")
	if err := os.WriteFile(pkg, []byte("#!/bin/sh\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	previousPackaged := dnsPackagedHelper
	dnsPackagedHelper = pkg
	t.Cleanup(func() { dnsPackagedHelper = previousPackaged })

	if got := dnsHelperPath(); got != pkg {
		t.Errorf("dnsHelperPath() = %q, want the packaged helper %q", got, pkg)
	}
}

// TestLiveNetworkFrame exercises the real snapshot path against the running
// NetworkManager and prints the frame, as evidence the topic renders live data.
// Gated so the default `go test` stays deterministic and bus-free.
func TestLiveNetworkFrame(t *testing.T) {
	if os.Getenv("RYOKU_LIVE_DBUS") == "" {
		t.Skip("set RYOKU_LIVE_DBUS=1 to run the live NetworkManager integration")
	}
	conn, err := dbus.ConnectSystemBus()
	if err != nil {
		t.Skipf("no system bus: %v", err)
	}
	defer conn.Close()
	n := &networkState{conn: conn, topic: newStateTopic()}
	ch := n.topic.subscribe()
	n.publish()
	select {
	case frame := <-ch:
		t.Logf("network frame: %s", frame)
		var m map[string]any
		if err := json.Unmarshal(frame, &m); err != nil {
			t.Fatalf("frame is not valid JSON: %v", err)
		}
		for _, k := range []string{"wifi", "wired", "accessPoints", "wireguard", "dns"} {
			if _, ok := m[k]; !ok {
				t.Errorf("frame missing key %q", k)
			}
		}
	case <-time.After(3 * time.Second):
		t.Fatal("no network frame published")
	}
}
