package keyring

import (
	"os"
	"testing"
)

// A fresh box (no config, no PAM, no keyring) defaults to never-ask and seeds a
// blank passwordless default keyring, so no app ever prompts out of the box.
func TestInitFreshSeedsNeverAsk(t *testing.T) {
	sandbox(t, archSDDM)
	f := useFake(t)
	if err := runInit(nil); err != nil {
		t.Fatalf("init: %v", err)
	}
	if m, ok := readConfig(); !ok || m != ModeNeverAsk {
		t.Fatalf("fresh init must record never-ask, got %q (%v)", m, ok)
	}
	if len(f.created) != 1 || f.created[0] != "login" {
		t.Fatalf("fresh init must seed a blank login keyring, created=%v", f.created)
	}
}

// init respects a user who already chose a mode: a pure no-op, no keyring touch.
func TestInitNoopWhenConfigured(t *testing.T) {
	sandbox(t, archSDDM)
	f := useFake(t)
	if err := writeConfig(ModeAsk); err != nil {
		t.Fatal(err)
	}
	if err := runInit(nil); err != nil {
		t.Fatalf("init: %v", err)
	}
	if m, _ := readConfig(); m != ModeAsk {
		t.Fatalf("init must not change a configured mode, got %q", m)
	}
	if len(f.created) != 0 {
		t.Fatalf("init must not touch keyrings when already configured, created=%v", f.created)
	}
}

// A PAM-wired box means the user chose unlock-on-login; init records that and
// never blanks a keyring.
func TestInitRecordsUnlockOnLoginWhenPamWired(t *testing.T) {
	pam := sandbox(t, archSDDM)
	f := useFake(t)
	applyPAMFile(pam, ModeUnlockOnLogin)
	if err := runInit(nil); err != nil {
		t.Fatalf("init: %v", err)
	}
	if m, _ := readConfig(); m != ModeUnlockOnLogin {
		t.Fatalf("PAM-wired init must record unlock-on-login, got %q", m)
	}
	if len(f.created) != 0 {
		t.Fatalf("unlock-on-login init must not blank a keyring, created=%v", f.created)
	}
}

// A pre-existing password-protected default keyring is never destroyed: init
// records the never-ask policy but leaves the file intact and creates nothing.
func TestInitLeavesEncryptedKeyringIntact(t *testing.T) {
	sandbox(t, archSDDM)
	f := useFake(t)
	enc := append(append([]byte{}, encryptedMagic...), 0x00)
	if err := os.WriteFile(keyringFile("Default_Keyring"), enc, 0o600); err != nil {
		t.Fatal(err)
	}
	seedDefault(t, "Default_Keyring")
	if err := runInit(nil); err != nil {
		t.Fatalf("init: %v", err)
	}
	if m, _ := readConfig(); m != ModeNeverAsk {
		t.Fatalf("init must record never-ask even with an encrypted default, got %q", m)
	}
	if len(f.created) != 0 {
		t.Fatalf("init must not create a keyring when the default is encrypted, created=%v", f.created)
	}
	if probeFormat(keyringFile("Default_Keyring")) != fmtEncrypted {
		t.Fatal("init must leave the encrypted keyring intact")
	}
}
