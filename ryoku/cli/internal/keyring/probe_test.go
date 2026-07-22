package keyring

import (
	"os"
	"path/filepath"
	"testing"
)

func writeKeyringFixture(t *testing.T, dir, name string, encrypted bool) {
	t.Helper()
	kd := filepath.Join(dir, "keyrings")
	if err := os.MkdirAll(kd, 0o700); err != nil {
		t.Fatal(err)
	}
	var body []byte
	if encrypted {
		body = append(append([]byte{}, encryptedMagic...), 0x00, 0x01, 0x02)
	} else {
		body = []byte("[keyring]\ndisplay-name=test\n")
	}
	if err := os.WriteFile(filepath.Join(kd, name+".keyring"), body, 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestProbeFormat(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_DATA_HOME", dir)
	writeKeyringFixture(t, dir, "enc", true)
	writeKeyringFixture(t, dir, "blank", false)
	if got := probeFormat(keyringFile("enc")); got != fmtEncrypted {
		t.Fatalf("magic bytes must probe as encrypted, got %q", got)
	}
	if got := probeFormat(keyringFile("blank")); got != fmtPlaintext {
		t.Fatalf("an INI keyring must probe as plaintext, got %q", got)
	}
	if got := probeFormat(keyringFile("nope")); got != fmtAbsent {
		t.Fatalf("a missing file must probe as absent, got %q", got)
	}
}

func TestDefaultKeyringName(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_DATA_HOME", dir)
	if got := defaultKeyringName(); got != "login" {
		t.Fatalf("no default file must fall back to login, got %q", got)
	}
	kd := filepath.Join(dir, "keyrings")
	os.MkdirAll(kd, 0o700)
	os.WriteFile(filepath.Join(kd, "default"), []byte("Default_Keyring\n"), 0o600)
	if got := defaultKeyringName(); got != "Default_Keyring" {
		t.Fatalf("default file content must win, got %q", got)
	}
	os.WriteFile(filepath.Join(kd, "default"), []byte("   \n"), 0o600)
	if got := defaultKeyringName(); got != "login" {
		t.Fatalf("a blank default file must fall back to login, got %q", got)
	}
}
