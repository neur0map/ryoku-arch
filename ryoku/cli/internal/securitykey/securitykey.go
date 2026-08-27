package securitykey

import (
	"fmt"
	"os"
	"path/filepath"

	"ryoku-cli/internal/sys"
)

const (
	TargetSudo   = "sudo"
	TargetPolkit = "polkit"
	TargetLogin  = "login"
)

func authFilePath() string {
	if p := os.Getenv("RYOKU_SECURITY_KEY_AUTHFILE"); p != "" {
		return p
	}
	return filepath.Join(sys.ConfigHome(), "Yubico", "u2f_keys")
}

func Run(args []string) error {
	if len(args) == 0 {
		return usageErr()
	}
	switch args[0] {
	case "status":
		return runStatus(args[1:])
	case "enroll":
		return runEnroll(args[1:])
	case "remove":
		return runRemove(args[1:])
	case "set":
		return runSet(args[1:])
	case "apply-pam":
		return runApplyPAM(args[1:])
	case "-h", "--help", "help":
		fmt.Print(usage)
		return nil
	default:
		return fmt.Errorf("unknown security-key command %q\n\n%s", args[0], usage)
	}
}

const usage = `Usage: ryoku security-key <command>

  status [--json]                 show security-key status and wiring
  enroll                          enroll the inserted FIDO2/U2F key
  remove <id|all>                 remove one enrolled key (1-based) or all
  set <sudo|polkit|login> <on|off>
                                  enable or disable pam_u2f for that target
  apply-pam <sudo|polkit|login> <on|off>
                                  privileged: edit /etc/pam.d for that target
`

func usageErr() error { return fmt.Errorf("%s", usage) }
