package securitykey

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadAuthFileMergesUserEntries(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("USER", "nero")
	path := authFilePath()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	raw := "# keep\nnero:cred-a\nother:else\nnero:cred-b:cred-a\n"
	if err := os.WriteFile(path, []byte(raw), 0o600); err != nil {
		t.Fatal(err)
	}
	a, err := loadAuthFile()
	if err != nil {
		t.Fatal(err)
	}
	if len(a.creds) != 2 || a.creds[0] != "cred-a" || a.creds[1] != "cred-b" {
		t.Fatalf("unexpected creds: %#v", a.creds)
	}
	if err := writeAuthFile(a); err != nil {
		t.Fatal(err)
	}
	out, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	text := string(out)
	if !strings.Contains(text, "nero:cred-a:cred-b\n") {
		t.Fatalf("rewritten authfile missing merged user line: %q", text)
	}
	if !strings.Contains(text, "other:else\n") {
		t.Fatalf("rewritten authfile dropped other user: %q", text)
	}
	if strings.Count(text, "nero:") != 1 {
		t.Fatalf("rewritten authfile must keep one user line: %q", text)
	}
}

func TestRemoveCredentialByID(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("USER", "nero")
	if err := writeAuthFile(authFile{creds: []string{"cred-a", "cred-b", "cred-c"}}); err != nil {
		t.Fatal(err)
	}
	left, err := removeCredential("2")
	if err != nil {
		t.Fatal(err)
	}
	if left != 2 {
		t.Fatalf("remaining creds = %d, want 2", left)
	}
	a, err := loadAuthFile()
	if err != nil {
		t.Fatal(err)
	}
	got := strings.Join(a.creds, ",")
	if got != "cred-a,cred-c" {
		t.Fatalf("creds after remove = %q", got)
	}
}

func TestParseProbeOutputIgnoresHeaderAndNoDevice(t *testing.T) {
	if name, ok := parseProbeOutput("PATH         MANUFACTURER PRODUCT               COMPATIBLE RK CLIENTPIN UP UV ALWAYSUV\nNo FIDO2 devices found.\n"); ok || name != "" {
		t.Fatalf("header-only probe must report no device, got ok=%v name=%q", ok, name)
	}
	if name, ok := parseProbeOutput("PATH         MANUFACTURER PRODUCT               COMPATIBLE RK CLIENTPIN UP UV ALWAYSUV\n/dev/hidraw0 Yubico       YubiKey 5 NFC         yes        yes yes       yes yes no\n"); !ok || name == "" {
		t.Fatalf("device row must be detected, got ok=%v name=%q", ok, name)
	}
}

func TestFakeFIDOStatusAndEnroll(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("USER", "nero")
	t.Setenv("RYOKU_FAKE_FIDO", "1")
	st := gatherStatus()
	if !st.Supported || !st.DevicePresent || st.DeviceName == "" {
		t.Fatalf("fake FIDO status missing device: %#v", st)
	}
	if err := runEnroll(nil); err != nil {
		t.Fatalf("fake enroll: %v", err)
	}
	st = gatherStatus()
	if !st.Enrolled || st.Credentials != 1 {
		t.Fatalf("fake enroll did not persist credential: %#v", st)
	}
}

func TestPolicyDrivesPamLine(t *testing.T) {
	cfg := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	if err := writePolicy(policy{Mode: ModeMFA, TouchRequired: true, PinVerification: true, UserVerification: true}); err != nil {
		t.Fatal(err)
	}
	line := pamLine()
	if !strings.Contains(line, "auth required pam_u2f.so") {
		t.Fatalf("pam line must switch to required for MFA: %q", line)
	}
	if strings.Contains(line, "authfile=%h/.config/Yubico/u2f_keys") {
		t.Fatalf("pam line must not use %%h authfile expansion: %q", line)
	}
	if !strings.Contains(line, "userpresence=1") {
		t.Fatalf("pam line missing userpresence: %q", line)
	}
	if !strings.Contains(line, "pinverification=1") {
		t.Fatalf("pam line missing pinverification: %q", line)
	}
	if !strings.Contains(line, "userverification=1") {
		t.Fatalf("pam line missing userverification: %q", line)
	}
}

func TestStatusJSONReflectsPamAndCredentials(t *testing.T) {
	cfg := t.TempDir()
	pamRoot := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("USER", "nero")
	t.Setenv("RYOKU_SECURITY_KEY_PAM_ROOT", pamRoot)
	for _, name := range []string{"sudo", "polkit-1", "sddm"} {
		if err := os.WriteFile(filepath.Join(pamRoot, name), []byte("auth include system-auth\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := writeAuthFile(authFile{creds: []string{"cred-a", "cred-b"}}); err != nil {
		t.Fatal(err)
	}
	if err := applyPAMFile(filepath.Join(pamRoot, "sudo"), true); err != nil {
		t.Fatal(err)
	}
	if err := applyPAMFile(filepath.Join(pamRoot, "polkit-1"), true); err != nil {
		t.Fatal(err)
	}
	if err := writePolicy(policy{Mode: ModeMFA, TouchRequired: true, PinVerification: true, UserVerification: false}); err != nil {
		t.Fatal(err)
	}
	st := gatherStatus()
	if !st.Enrolled || st.Credentials != 2 || !st.Sudo || !st.Polkit || st.Login {
		t.Fatalf("unexpected status: %#v", st)
	}
	if st.LockSupported || st.Lock {
		t.Fatalf("lockscreen must be unavailable in first version: %#v", st)
	}
	if st.AuthMode != ModeMFA || !st.TouchRequired || !st.PinVerification || st.UserVerification {
		t.Fatalf("unexpected policy in status: %#v", st)
	}
	if len(st.CredentialIDs) != 2 || st.CredentialIDs[0].ID != "1" {
		t.Fatalf("unexpected credential ids: %#v", st.CredentialIDs)
	}
	raw, err := json.Marshal(st)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(raw), "\"credentials\":2") {
		t.Fatalf("json missing credential count: %s", raw)
	}
}

func TestSetPolicyRewritesEnabledTargets(t *testing.T) {
	cfg := t.TempDir()
	root := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("RYOKU_SECURITY_KEY_PAM_ROOT", root)
	t.Setenv("USER", "nero")
	if err := writeAuthFile(authFile{creds: []string{"cred-a"}}); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"sudo", "polkit-1", "sddm"} {
		if err := os.WriteFile(filepath.Join(root, name), []byte("auth include system-auth\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := applyPAMFile(filepath.Join(root, "sudo"), true); err != nil {
		t.Fatal(err)
	}
	if err := runSet([]string{"mode", "mfa"}); err != nil {
		t.Fatalf("set mode: %v", err)
	}
	if err := runSet([]string{"touch-required", "on"}); err != nil {
		t.Fatalf("set touch-required: %v", err)
	}
	if err := runSet([]string{"pin-verification", "on"}); err != nil {
		t.Fatalf("set pin-verification: %v", err)
	}
	raw, err := os.ReadFile(filepath.Join(root, "sudo"))
	if err != nil {
		t.Fatal(err)
	}
	text := string(raw)
	if !strings.Contains(text, "auth required pam_u2f.so") || !strings.Contains(text, "userpresence=1") || !strings.Contains(text, "pinverification=1") {
		t.Fatalf("enabled PAM target not rewritten with policy: %q", text)
	}
}

func TestRunApplyPAMUsesFixtureRoot(t *testing.T) {
	root := t.TempDir()
	t.Setenv("RYOKU_SECURITY_KEY_PAM_ROOT", root)
	path := filepath.Join(root, "sudo")
	if err := os.WriteFile(path, []byte("auth include system-auth\naccount include system-auth\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := runApplyPAM([]string{"sudo", "on"}); err != nil {
		t.Fatalf("apply-pam on: %v", err)
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(raw), "pam_u2f.so") {
		t.Fatalf("pam file missing pam_u2f line: %q", string(raw))
	}
	if err := runApplyPAM([]string{"sudo", "off"}); err != nil {
		t.Fatalf("apply-pam off: %v", err)
	}
	raw, err = os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(raw), "pam_u2f.so") {
		t.Fatalf("pam file still has pam_u2f line: %q", string(raw))
	}
}
