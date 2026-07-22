package keyring

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// fakeOps stands in for the live daemon: it records the calls the state machine
// makes and materializes the resulting keyring file so a follow-up probe sees
// the new state, exactly as gnome-keyring would.
type fakeOps struct {
	created []string
	changed [][3]string // name, old, new
}

func (f *fakeOps) createBlank(name string) error {
	f.created = append(f.created, name)
	return os.WriteFile(keyringFile(name), []byte("[keyring]\n"), 0o600)
}

func (f *fakeOps) changePassword(name, old, newPw string) error {
	f.changed = append(f.changed, [3]string{name, old, newPw})
	body := []byte("[keyring]\n")
	if newPw != "" {
		body = append(append([]byte{}, encryptedMagic...), 0x00)
	}
	return os.WriteFile(keyringFile(name), body, 0o600)
}

// sandbox wires a fully isolated environment: no real HOME, config, keyrings,
// PAM file, or SDDM config leak in. Returns the PAM fixture path.
func sandbox(t *testing.T, pamBody string) string {
	t.Helper()
	data := t.TempDir()
	cfg := t.TempDir()
	confRoot := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("RYOKU_SDDM_CONF_ROOT", confRoot)
	os.MkdirAll(filepath.Join(data, "keyrings"), 0o700)
	pam := filepath.Join(t.TempDir(), "sddm")
	if err := os.WriteFile(pam, []byte(pamBody), 0o644); err != nil {
		t.Fatal(err)
	}
	t.Setenv("RYOKU_PAM_FILE", pam)
	return pam
}

func useFake(t *testing.T) *fakeOps {
	t.Helper()
	f := &fakeOps{}
	prev := ops
	ops = f
	t.Cleanup(func() { ops = prev })
	return f
}

func setStdin(t *testing.T, lines ...string) {
	t.Helper()
	p := filepath.Join(t.TempDir(), "stdin")
	os.WriteFile(p, []byte(strings.Join(lines, "\n")+"\n"), 0o600)
	f, err := os.Open(p)
	if err != nil {
		t.Fatal(err)
	}
	prev := os.Stdin
	os.Stdin = f
	t.Cleanup(func() { os.Stdin = prev; f.Close() })
}

func seedDefault(t *testing.T, name string) {
	t.Helper()
	os.WriteFile(filepath.Join(keyringsDir(), "default"), []byte(name+"\n"), 0o600)
}

func TestSetAskConfigOnly(t *testing.T) {
	pam := sandbox(t, archSDDM)
	useFake(t)
	// start from a wired stack so ask has something to strip.
	applyPAMFile(pam, ModeUnlockOnLogin)
	if err := runSet([]string{ModeAsk}); err != nil {
		t.Fatalf("set ask: %v", err)
	}
	if m, ok := readConfig(); !ok || m != ModeAsk {
		t.Fatalf("config not recorded as ask (%q, %v)", m, ok)
	}
	got, _ := os.ReadFile(pam)
	if pamPresent(string(got)) {
		t.Fatalf("ask must strip the PAM lines:\n%s", got)
	}
}

func TestSetNeverAskCreatesBlankWhenAbsent(t *testing.T) {
	sandbox(t, archSDDM)
	f := useFake(t)
	if err := runSet([]string{ModeNeverAsk}); err != nil {
		t.Fatalf("set never-ask: %v", err)
	}
	if len(f.created) != 1 || f.created[0] != "login" {
		t.Fatalf("want a blank login keyring created, got %v", f.created)
	}
	if m, _ := readConfig(); m != ModeNeverAsk {
		t.Fatalf("config not never-ask: %q", m)
	}
}

func TestSetNeverAskBlockedWhenEncrypted(t *testing.T) {
	sandbox(t, archSDDM)
	useFake(t)
	seedDefault(t, "Default_Keyring")
	writeKeyringFixtureAt(t, "Default_Keyring", true)
	err := runSet([]string{ModeNeverAsk})
	if err == nil {
		t.Fatal("never-ask on an encrypted keyring must be blocked without --convert/--reset")
	}
	if _, ok := readConfig(); ok {
		t.Fatal("a blocked set must not record the mode")
	}
}

func TestSetNeverAskConvert(t *testing.T) {
	sandbox(t, archSDDM)
	f := useFake(t)
	seedDefault(t, "Default_Keyring")
	writeKeyringFixtureAt(t, "Default_Keyring", true)
	setStdin(t, "oldpw")
	if err := runSet([]string{ModeNeverAsk, "--convert", "--password-stdin"}); err != nil {
		t.Fatalf("convert: %v", err)
	}
	if len(f.changed) != 1 || f.changed[0] != [3]string{"Default_Keyring", "oldpw", ""} {
		t.Fatalf("want a change to blank, got %v", f.changed)
	}
}

func TestSetNeverAskReset(t *testing.T) {
	sandbox(t, archSDDM)
	f := useFake(t)
	seedDefault(t, "Default_Keyring")
	writeKeyringFixtureAt(t, "Default_Keyring", true)
	if err := runSet([]string{ModeNeverAsk, "--reset"}); err != nil {
		t.Fatalf("reset: %v", err)
	}
	// the old encrypted file is moved into a backup dir, a fresh blank created.
	backups, _ := filepath.Glob(filepath.Join(keyringsDir(), "backup-*", "Default_Keyring.keyring"))
	if len(backups) != 1 {
		t.Fatalf("want the old keyring backed up, found %v", backups)
	}
	if len(f.created) != 1 {
		t.Fatalf("want a fresh blank keyring created, got %v", f.created)
	}
	if probeFormat(keyringFile("Default_Keyring")) != fmtPlaintext {
		t.Fatal("the fresh keyring must be blank/plaintext")
	}
}

func TestSetUnlockOnLoginPointsDefaultAndWires(t *testing.T) {
	pam := sandbox(t, archSDDM)
	useFake(t)
	seedDefault(t, "Default_Keyring")
	if err := runSet([]string{ModeUnlockOnLogin}); err != nil {
		t.Fatalf("set unlock-on-login: %v", err)
	}
	if defaultKeyringName() != "login" {
		t.Fatal("unlock-on-login must repoint the default at login")
	}
	bak, _ := os.ReadFile(filepath.Join(keyringsDir(), "default.ryoku-bak"))
	if strings.TrimSpace(string(bak)) != "Default_Keyring" {
		t.Fatalf("previous pointer must be backed up, got %q", bak)
	}
	got, _ := os.ReadFile(pam)
	if !pamHasKeyring(string(got), "auth") || !pamHasKeyring(string(got), "session") {
		t.Fatalf("PAM must be wired:\n%s", got)
	}
}

func TestSetUnlockOnLoginEncryptedNoFlagSucceeds(t *testing.T) {
	sandbox(t, archSDDM)
	f := useFake(t)
	// login keyring already encrypted; without a flag this is a valid choice.
	writeKeyringFixtureAt(t, "login", true)
	if err := runSet([]string{ModeUnlockOnLogin}); err != nil {
		t.Fatalf("set unlock-on-login on an encrypted login keyring should succeed: %v", err)
	}
	if len(f.changed) != 0 || len(f.created) != 0 {
		t.Fatal("no daemon op should run without --convert/--reset")
	}
	if m, _ := readConfig(); m != ModeUnlockOnLogin {
		t.Fatalf("config not unlock-on-login: %q", m)
	}
}

// writeKeyringFixtureAt writes a keyring file in the sandbox's keyrings dir.
func writeKeyringFixtureAt(t *testing.T, name string, encrypted bool) {
	t.Helper()
	var body []byte
	if encrypted {
		body = append(append([]byte{}, encryptedMagic...), 0x00)
	} else {
		body = []byte("[keyring]\n")
	}
	if err := os.WriteFile(keyringFile(name), body, 0o600); err != nil {
		t.Fatal(err)
	}
}
