package securitykey

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"

	"ryoku-cli/internal/sys"
)

type Credential struct {
	ID    string `json:"id"`
	Label string `json:"label"`
}

type Status struct {
	Supported     bool         `json:"supported"`
	DevicePresent bool         `json:"devicePresent"`
	DeviceName    string       `json:"deviceName"`
	Enrolled      bool         `json:"enrolled"`
	Credentials   int          `json:"credentials"`
	CredentialIDs []Credential `json:"credentialIds"`
	Sudo          bool         `json:"sudo"`
	Polkit        bool         `json:"polkit"`
	Login         bool         `json:"login"`
	Lock          bool         `json:"lock"`
	LockSupported bool         `json:"lockSupported"`
}

func gatherStatus() Status {
	a, _ := loadAuthFile()
	present, name := probeDevice()
	st := Status{
		Supported:     sys.Has("pamu2fcfg"),
		DevicePresent: present,
		DeviceName:    name,
		Enrolled:      len(a.creds) > 0,
		Credentials:   len(a.creds),
		Sudo:          pamEnabled(TargetSudo),
		Polkit:        pamEnabled(TargetPolkit),
		Login:         pamEnabled(TargetLogin),
		Lock:          false,
		LockSupported: false,
	}
	for i := range a.creds {
		st.CredentialIDs = append(st.CredentialIDs, Credential{ID: fmt.Sprintf("%d", i+1), Label: fmt.Sprintf("Security key %d", i+1)})
	}
	return st
}

func probeDevice() (bool, string) {
	if !sys.Has("pamu2fcfg") {
		return false, ""
	}
	out, err := exec.Command("pamu2fcfg", "-L").CombinedOutput()
	if err != nil {
		return false, ""
	}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			return true, line
		}
	}
	return false, ""
}

func runStatus(args []string) error {
	jsonOut := false
	for _, a := range args {
		if a == "--json" {
			jsonOut = true
		} else {
			return fmt.Errorf("usage: ryoku security-key status [--json]")
		}
	}
	st := gatherStatus()
	if jsonOut {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		return enc.Encode(st)
	}
	printStatus(st)
	return nil
}

func printStatus(st Status) {
	fmt.Printf("supported:   %s\n", yesno(st.Supported))
	fmt.Printf("device:      %s\n", map[bool]string{true: st.DeviceName, false: "not detected"}[st.DevicePresent])
	fmt.Printf("enrolled:    %s (%d credential%s)\n", yesno(st.Enrolled), st.Credentials, plural(st.Credentials))
	fmt.Printf("sudo:        %s\n", yesno(st.Sudo))
	fmt.Printf("polkit:      %s\n", yesno(st.Polkit))
	fmt.Printf("login:       %s\n", yesno(st.Login))
	fmt.Printf("lockscreen:  unavailable\n")
}

func yesno(b bool) string {
	if b {
		return "yes"
	}
	return "no"
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}
