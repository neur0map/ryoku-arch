package keyring

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/godbus/dbus/v5"
)

// TestE2EKeyringLifecycle drives create-blank, convert, and reset against a real
// gnome-keyring-daemon, proving the D-Bus half end to end. It is gated and must
// run inside its own session bus with a throwaway XDG_DATA_HOME, so it never
// touches the box owner's real keyrings:
//
//	RYOKU_KEYRING_E2E=1 dbus-run-session -- go test -run E2E ./internal/keyring/
func TestE2EKeyringLifecycle(t *testing.T) {
	if os.Getenv("RYOKU_KEYRING_E2E") != "1" {
		t.Skip("sandbox E2E (set RYOKU_KEYRING_E2E=1 under dbus-run-session)")
	}
	if _, err := exec.LookPath("gnome-keyring-daemon"); err != nil {
		t.Skip("gnome-keyring-daemon not installed")
	}
	if os.Getenv("DBUS_SESSION_BUS_ADDRESS") == "" {
		t.Skip("no session bus; run under dbus-run-session")
	}

	// hard isolation: a fresh XDG_DATA_HOME (the daemon's store) and a fresh
	// XDG_RUNTIME_DIR (its control socket), so it never adopts the real running
	// daemon and never touches the box owner's real keyrings.
	data := t.TempDir()
	t.Setenv("XDG_DATA_HOME", data)
	run := t.TempDir()
	t.Setenv("XDG_RUNTIME_DIR", run)
	os.MkdirAll(filepath.Join(data, "keyrings"), 0o700)

	startDaemon(t)

	c, err := dial()
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer c.close()

	// create-blank: a passwordless keyring is a plaintext file.
	if err := c.createBlank("e2e-blank"); err != nil {
		t.Fatalf("createBlank: %v", err)
	}
	if got := probeFormat(keyringFile("e2e-blank")); got != fmtPlaintext {
		t.Fatalf("blank keyring should be plaintext, got %q", got)
	}

	// convert: a passworded keyring probes encrypted, then rekeying to "" makes
	// it plaintext.
	if err := c.createWithPassword("e2e-conv", "s3cret"); err != nil {
		t.Fatalf("create encrypted: %v", err)
	}
	if got := probeFormat(keyringFile("e2e-conv")); got != fmtEncrypted {
		t.Fatalf("passworded keyring should be encrypted, got %q", got)
	}
	if err := c.changePassword("e2e-conv", "s3cret", ""); err != nil {
		t.Fatalf("convert to blank: %v", err)
	}
	if got := probeFormat(keyringFile("e2e-conv")); got != fmtPlaintext {
		t.Fatalf("converted keyring should be plaintext, got %q", got)
	}

	// reset: an encrypted keyring is moved aside, a fresh blank replaces it.
	if err := c.createWithPassword("e2e-reset", "pw"); err != nil {
		t.Fatalf("create for reset: %v", err)
	}
	if err := resetKeyrings("e2e-reset"); err != nil {
		t.Fatalf("reset: %v", err)
	}
	if probeFormat(keyringFile("e2e-reset")) != fmtAbsent {
		t.Fatal("reset should have moved the keyring file aside")
	}
	backups, _ := filepath.Glob(filepath.Join(keyringsDir(), "backup-*", "e2e-reset.keyring"))
	if len(backups) != 1 {
		t.Fatalf("reset should keep a backup, found %v", backups)
	}
}

// createWithPassword is the encrypted-keyring counterpart of createBlank, used
// only by the E2E to set up convert/reset fixtures against the real daemon.
func (c *secretsClient) createWithPassword(name, pw string) error {
	attrs := map[string]dbus.Variant{
		ifaceColl + ".Label": dbus.MakeVariant(name),
	}
	var coll dbus.ObjectPath
	return c.obj.Call(ifaceInternal+".CreateWithMasterPassword", 0, attrs, c.secret(pw)).Store(&coll)
}

func startDaemon(t *testing.T) {
	t.Helper()
	out, err := exec.Command("gnome-keyring-daemon", "--start", "--components=secrets").Output()
	if err != nil {
		t.Fatalf("start gnome-keyring-daemon: %v", err)
	}
	for _, line := range strings.Split(string(out), "\n") {
		if k, v, ok := strings.Cut(line, "="); ok {
			os.Setenv(k, v)
		}
	}
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if daemonAlive() {
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatal("secrets service never appeared on the bus")
}
