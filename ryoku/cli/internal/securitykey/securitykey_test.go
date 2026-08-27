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
	st := gatherStatus()
	if !st.Enrolled || st.Credentials != 2 || !st.Sudo || !st.Polkit || st.Login {
		t.Fatalf("unexpected status: %#v", st)
	}
	if st.LockSupported || st.Lock {
		t.Fatalf("lockscreen must be unavailable in first version: %#v", st)
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
