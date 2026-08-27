package securitykey

import (
	"fmt"
	"strings"

	"ryoku-cli/internal/sys"
)

func parseOnOff(s string) (bool, error) {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "on", "true", "1", "yes":
		return true, nil
	case "off", "false", "0", "no":
		return false, nil
	default:
		return false, fmt.Errorf("expected on or off, got %q", s)
	}
}

func runSet(args []string) error {
	if len(args) != 2 {
		return fmt.Errorf("usage: ryoku security-key set <sudo|polkit|login> <on|off>")
	}
	target := args[0]
	on, err := parseOnOff(args[1])
	if err != nil {
		return err
	}
	if _, err := targetName(target); err != nil {
		return err
	}
	if on {
		if !sys.Has("pamu2fcfg") {
			return fmt.Errorf("pamu2fcfg is not installed; install pam-u2f first")
		}
		a, err := loadAuthFile()
		if err != nil {
			return err
		}
		if len(a.creds) == 0 {
			return fmt.Errorf("enroll a security key before enabling %s", target)
		}
	}
	if err := applyPAMHalf(target, on); err != nil {
		return fmt.Errorf("wire PAM: %w", err)
	}
	fmt.Printf("security key %s for %s\n", map[bool]string{true: "enabled", false: "disabled"}[on], target)
	return nil
}
