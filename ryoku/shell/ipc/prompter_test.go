package main

import (
	"bufio"
	"io"
	"net"
	"strings"
	"testing"
)

func TestParseKeyringRespond(t *testing.T) {
	cases := []struct {
		cmd    string
		id     int
		action string
		choice bool
		ok     bool
	}{
		{"keyring-respond 7 continue 1", 7, "continue", true, true},
		{"keyring-respond 0 cancel 0", 0, "cancel", false, true},
		{"keyring-respond 12 continue 0", 12, "continue", false, true},
		{"keyring-respond", 0, "", false, false},
		{"keyring-respond 7 continue", 0, "", false, false},
		{"keyring-respond x continue 1", 0, "", false, false},
	}
	for _, c := range cases {
		id, action, choice, err := parseKeyringRespond(c.cmd)
		if (err == nil) != c.ok {
			t.Fatalf("%q: ok=%v err=%v", c.cmd, c.ok, err)
		}
		if err != nil {
			continue
		}
		if id != c.id || action != c.action || choice != c.choice {
			t.Fatalf("%q => id=%d action=%q choice=%v", c.cmd, id, action, choice)
		}
	}
}

// keyring framing: control socket reads the answer as two lines (command,
// then the raw secret) and hands it to the prompter; ordinary one-line
// commands stay untouched.
func TestHandleKeyringFraming(t *testing.T) {
	d := &daemon{} // prompter nil: keyring branch returns its own error

	// secret line, spaces and all: must be consumed without hanging, and the
	// keyring branch (not dispatch) handles it.
	if got := roundtrip(t, d, "keyring-respond 7 continue 1\nhunter2 with spaces\n"); got != "err keyring prompter not running" {
		t.Fatalf("keyring framing: got %q", got)
	}
	// normal one-line command: keyring branch leaves it alone.
	if got := roundtrip(t, d, "ping\n"); got != "ok" {
		t.Fatalf("ping: got %q", got)
	}
}

func roundtrip(t *testing.T, d *daemon, req string) string {
	t.Helper()
	client, server := net.Pipe()
	go d.handle(server)
	if _, err := io.WriteString(client, req); err != nil {
		t.Fatalf("write: %v", err)
	}
	line, _ := bufio.NewReader(client).ReadString('\n')
	client.Close()
	return strings.TrimSpace(line)
}
