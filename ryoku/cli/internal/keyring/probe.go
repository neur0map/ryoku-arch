package keyring

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"

	"ryoku-cli/internal/sys"
)

const (
	fmtEncrypted = "encrypted"
	fmtPlaintext = "plaintext"
	fmtAbsent    = "absent"
)

// encryptedMagic is the first bytes gnome-keyring writes to a password-protected
// keyring file. A blank (unlocked) keyring is a plaintext "[keyring]" INI file
// with no such magic, so the leading bytes alone tell the two apart.
var encryptedMagic = []byte("GnomeKeyring\n\r\x00\n")

// keyringsDir is $XDG_DATA_HOME/keyrings (default ~/.local/share/keyrings), the
// per-user secret store gnome-keyring reads and writes.
func keyringsDir() string {
	return filepath.Join(sys.Xdg("XDG_DATA_HOME", ".local/share"), "keyrings")
}

// defaultKeyringName is the name the "default" alias resolves to: the content of
// keyrings/default, or "login" when that file is absent (gnome-keyring's own
// fallback). No extension.
func defaultKeyringName() string {
	raw, err := os.ReadFile(filepath.Join(keyringsDir(), "default"))
	if err != nil {
		return "login"
	}
	if n := strings.TrimSpace(string(raw)); n != "" {
		return n
	}
	return "login"
}

// keyringFile is the on-disk path of a named keyring.
func keyringFile(name string) string {
	return filepath.Join(keyringsDir(), name+".keyring")
}

// probeFormat classifies a keyring file by its leading bytes: absent, encrypted
// (passworded, magic present), or plaintext (blank, no magic).
func probeFormat(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return fmtAbsent
	}
	defer f.Close()
	head := make([]byte, len(encryptedMagic))
	n, _ := f.Read(head)
	if bytes.HasPrefix(head[:n], encryptedMagic) {
		return fmtEncrypted
	}
	return fmtPlaintext
}
