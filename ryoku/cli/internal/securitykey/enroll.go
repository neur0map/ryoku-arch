package securitykey

import (
	"fmt"
	"os/exec"
	"strings"

	"ryoku-cli/internal/sys"
)

func runEnroll(args []string) error {
	if len(args) != 0 {
		return fmt.Errorf("usage: ryoku security-key enroll")
	}
	if !sys.Has("pamu2fcfg") {
		return fmt.Errorf("pamu2fcfg is not installed; install pam-u2f first")
	}
	origin := defaultOrigin()
	cmd := exec.Command("pamu2fcfg", "-o", origin, "-i", origin)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = nil, nil, nil
	out, err := cmd.CombinedOutput()
	if err != nil {
		msg := strings.TrimSpace(string(out))
		if msg == "" {
			msg = err.Error()
		}
		return fmt.Errorf("pamu2fcfg failed: %s", msg)
	}
	cred, err := parseEnrollment(string(out))
	if err != nil {
		return err
	}
	a, err := loadAuthFile()
	if err != nil {
		return err
	}
	if containsCred(a.creds, cred) {
		fmt.Println("that security key is already enrolled")
		return nil
	}
	a.creds = append(a.creds, cred)
	if err := writeAuthFile(a); err != nil {
		return err
	}
	fmt.Printf("enrolled security key %d for %s\n", len(a.creds), currentUser())
	return nil
}

func parseEnrollment(out string) (string, error) {
	for _, line := range strings.Split(strings.ReplaceAll(out, "\r\n", "\n"), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || !strings.Contains(line, ":") {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		if len(parts) != 2 || strings.TrimSpace(parts[1]) == "" {
			continue
		}
		return strings.TrimSpace(parts[1]), nil
	}
	return "", fmt.Errorf("pamu2fcfg returned no credential line")
}

func runRemove(args []string) error {
	if len(args) != 1 {
		return fmt.Errorf("usage: ryoku security-key remove <id|all>")
	}
	left, err := removeCredential(args[0])
	if err != nil {
		return err
	}
	if args[0] == "all" {
		fmt.Println("removed all enrolled security keys")
		return nil
	}
	fmt.Printf("removed security key %s (%d remaining)\n", args[0], left)
	return nil
}
