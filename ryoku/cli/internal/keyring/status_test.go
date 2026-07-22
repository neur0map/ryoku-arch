package keyring

import (
	"os"
	"path/filepath"
	"testing"
)

func TestAutologinConfigured(t *testing.T) {
	root := t.TempDir()
	if autologinConfigured(root) {
		t.Fatal("empty /etc must report no autologin")
	}
	confd := filepath.Join(root, "sddm.conf.d")
	os.MkdirAll(confd, 0o755)
	os.WriteFile(filepath.Join(confd, "kde_settings.conf"), []byte("[Autologin]\nSession=hyprland\nUser=\n"), 0o644)
	if autologinConfigured(root) {
		t.Fatal("an empty User= is not autologin")
	}
	os.WriteFile(filepath.Join(confd, "autologin.conf"), []byte("[Autologin]\nUser=nero\n"), 0o644)
	if !autologinConfigured(root) {
		t.Fatal("a non-empty User= in a drop-in must count as autologin")
	}
}

func TestAutologinIgnoresOtherSections(t *testing.T) {
	root := t.TempDir()
	os.WriteFile(filepath.Join(root, "sddm.conf"), []byte("[General]\nUser=nero\n"), 0o644)
	if autologinConfigured(root) {
		t.Fatal("User= outside [Autologin] must not count")
	}
}

func TestStatusModeInference(t *testing.T) {
	data := t.TempDir()
	cfg := t.TempDir()
	confRoot := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("RYOKU_SDDM_CONF_ROOT", confRoot)
	os.MkdirAll(filepath.Join(data, "keyrings"), 0o700)

	pam := filepath.Join(t.TempDir(), "sddm")
	t.Setenv("RYOKU_PAM_FILE", pam)

	// no config, no PAM lines -> never-ask (the no-prompt default).
	os.WriteFile(pam, []byte(archSDDM), 0o644)
	st := gatherStatus()
	if st.Mode != ModeNeverAsk || st.ModeSource != "inferred" {
		t.Fatalf("bare stack should infer never-ask, got %q/%q", st.Mode, st.ModeSource)
	}
	if st.PamPresent {
		t.Fatal("stock stack has no keyring lines")
	}

	// PAM lines present -> unlock-on-login.
	wired, _ := applyPAMText(archSDDM, true)
	os.WriteFile(pam, []byte(wired), 0o644)
	st = gatherStatus()
	if st.Mode != ModeUnlockOnLogin || !st.PamPresent {
		t.Fatalf("wired stack should infer unlock-on-login, got %q pam=%v", st.Mode, st.PamPresent)
	}

	// explicit config wins over inference.
	writeConfig(ModeNeverAsk)
	st = gatherStatus()
	if st.Mode != ModeNeverAsk || st.ModeSource != "configured" {
		t.Fatalf("config should win, got %q/%q", st.Mode, st.ModeSource)
	}
}

func TestStatusEncryptedCaveatNotes(t *testing.T) {
	data := t.TempDir()
	cfg := t.TempDir()
	confRoot := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	t.Setenv("XDG_CONFIG_HOME", cfg)
	t.Setenv("RYOKU_SDDM_CONF_ROOT", confRoot)
	os.MkdirAll(filepath.Join(data, "keyrings"), 0o700)
	pam := filepath.Join(t.TempDir(), "sddm")
	os.WriteFile(pam, []byte(archSDDM), 0o644)
	t.Setenv("RYOKU_PAM_FILE", pam)

	// encrypted login keyring under unlock-on-login -> the unknown-match caveat.
	body := append(append([]byte{}, encryptedMagic...), 0x00)
	os.WriteFile(filepath.Join(data, "keyrings", "login.keyring"), body, 0o600)
	writeConfig(ModeUnlockOnLogin)
	st := gatherStatus()
	if len(st.Notes) == 0 {
		t.Fatal("an encrypted default keyring under unlock-on-login must carry the caveat note")
	}
}
