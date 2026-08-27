package securitykey

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"ryoku-cli/internal/sys"
)

const (
	ModeEither = "either"
	ModeMFA    = "mfa"
)

type policy struct {
	Mode             string `json:"mode"`
	TouchRequired    bool   `json:"touchRequired"`
	PinVerification  bool   `json:"pinVerification"`
	UserVerification bool   `json:"userVerification"`
}

func policyPath() string {
	return filepath.Join(sys.ConfigHome(), "ryoku", "security-key.json")
}

func defaultPolicy() policy {
	return policy{Mode: ModeEither, TouchRequired: true}
}

func validMode(mode string) bool {
	return mode == ModeEither || mode == ModeMFA
}

func readPolicy() policy {
	raw, err := os.ReadFile(policyPath())
	if err != nil {
		return defaultPolicy()
	}
	var p policy
	if json.Unmarshal(raw, &p) != nil || !validMode(p.Mode) {
		return defaultPolicy()
	}
	return p
}

func writePolicy(p policy) error {
	if !validMode(p.Mode) {
		return fmt.Errorf("invalid security-key mode %q", p.Mode)
	}
	path := policyPath()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	raw, err := json.Marshal(p)
	if err != nil {
		return err
	}
	tmp := path + ".ryoku-tmp"
	if err := os.WriteFile(tmp, append(raw, '\n'), 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func parseMode(mode string) (string, error) {
	mode = strings.ToLower(strings.TrimSpace(mode))
	if !validMode(mode) {
		return "", fmt.Errorf("expected mode %q or %q, got %q", ModeEither, ModeMFA, mode)
	}
	return mode, nil
}
