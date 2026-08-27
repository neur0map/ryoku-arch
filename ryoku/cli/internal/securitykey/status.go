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
	if fakeFIDO() {
		return true, "Fake YubiKey 5 NFC"
	}
	for _, probe := range []struct {
		name string
		args []string
	}{
		{name: "systemd-cryptenroll", args: []string{"--fido2-device=list"}},
		{name: "fido2-token", args: []string{"-L"}},
	} {
		if !sys.Has(probe.name) {
			continue
		}
		out, err := exec.Command(probe.name, probe.args...).CombinedOutput()
		if err != nil {
			continue
		}
		for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
			line = strings.TrimSpace(line)
			if line == "" {
				continue
			}
			low := strings.ToLower(line)
			if strings.Contains(low, "no fido2 devices found") || strings.Contains(low, "no fido devices found") || strings.Contains(low, "no devices found") {
				continue
			}
			return true, line
		}
		low := strings.ToLower(strings.TrimSpace(string(out)))
		if strings.Contains(low, "no fido2 devices found") || strings.Contains(low, "no fido devices found") || strings.Contains(low, "no devices found") {
			return false, ""
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
