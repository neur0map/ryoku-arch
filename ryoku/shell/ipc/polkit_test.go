package main

import (
	"os"
	"os/user"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/godbus/dbus/v5"
)

// unescapeGStr must reverse g_strescape so PAM messages carrying escapes render
// as bytes, and must leave plain messages (the common case) untouched.
func TestUnescapeGStr(t *testing.T) {
	cases := map[string]string{
		"Password: ":       "Password: ",
		`line1\nline2`:     "line1\nline2",
		`tab\there`:        "tab\there",
		`back\\slash`:      `back\slash`,
		`quote\"q`:         `quote"q`,
		`octal\101`:        "octalA", // \101 == 'A'
		`plain no escapes`: "plain no escapes",
	}
	for in, want := range cases {
		if got := unescapeGStr(in); got != want {
			t.Errorf("unescapeGStr(%q) = %q, want %q", in, got, want)
		}
	}
}

func fakePolkitHelper(t *testing.T, body string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "polkit-agent-helper-1")
	if err := os.WriteFile(p, []byte("#!/bin/sh\n"+body), 0o755); err != nil {
		t.Fatal(err)
	}
	return p
}

func useFakeHelper(t *testing.T, path string) {
	t.Helper()
	old := polkitHelperPath
	polkitHelperPath = path
	// Point the socket at nothing: a box running polkit 126+ has a live
	// agent-helper socket, and openPolkitHelper prefers it, so without this the
	// fake helper is never reached and the test talks to the real one.
	oldSock := polkitHelperSocket
	polkitHelperSocket = filepath.Join(t.TempDir(), "absent.socket")
	t.Cleanup(func() {
		polkitHelperPath = old
		polkitHelperSocket = oldSock
	})
}

// A non-setuid helper takes --socket-activated and reads username then cookie on
// stdin (the mode this machine ships).
func TestPolkitHelperCommandSocketMode(t *testing.T) {
	p := fakePolkitHelper(t, "true\n")
	useFakeHelper(t, p)
	argv, initial := polkitHelperCommand("alice", "cookie123")
	if len(argv) != 2 || argv[0] != p || argv[1] != "--socket-activated" {
		t.Fatalf("argv = %v, want [%s --socket-activated]", argv, p)
	}
	if initial != "alice\ncookie123\n" {
		t.Errorf("initial stdin = %q, want %q", initial, "alice\ncookie123\n")
	}
}

// A conversation that ends in SUCCESS after one prompt gains authorization, and
// the info/prompt messages reach the published state.
func TestPolkitConverseSuccess(t *testing.T) {
	useFakeHelper(t, fakePolkitHelper(t,
		"read u\nread c\nprintf 'PAM_TEXT_INFO please authenticate\\n'\nprintf 'PAM_PROMPT_ECHO_OFF Password: \\n'\nread pw\n[ \"$pw\" = \"hunter2\" ] && printf 'SUCCESS\\n' || printf 'FAILURE\\n'\n"))
	d := &daemon{}
	a := &polkitAgent{topic: d.registerTopic("polkit")}
	p := &polkitPrompt{cookie: "C", respCh: make(chan string, 1), cancelCh: make(chan struct{})}
	p.respCh <- "hunter2"

	gained, cancelled, err := a.converse("me", "C", p)
	if err != nil {
		t.Fatalf("converse err = %v", err)
	}
	if cancelled {
		t.Fatal("converse reported cancelled")
	}
	if !gained {
		t.Fatal("correct password did not gain authorization")
	}
	if a.state.Info != "please authenticate" {
		t.Errorf("info = %q, want %q", a.state.Info, "please authenticate")
	}
	if a.state.Prompt != "Password: " || a.state.Echo {
		t.Errorf("prompt = %q echo = %v, want %q false", a.state.Prompt, a.state.Echo, "Password: ")
	}
}

// A wrong password ends in FAILURE without gaining authorization or reporting a
// cancel, so BeginAuthentication can retry.
func TestPolkitConverseFailure(t *testing.T) {
	useFakeHelper(t, fakePolkitHelper(t,
		"read u\nread c\nprintf 'PAM_PROMPT_ECHO_OFF Password: \\n'\nread pw\n[ \"$pw\" = \"hunter2\" ] && printf 'SUCCESS\\n' || printf 'FAILURE\\n'\n"))
	d := &daemon{}
	a := &polkitAgent{topic: d.registerTopic("polkit")}
	p := &polkitPrompt{cookie: "C", respCh: make(chan string, 1), cancelCh: make(chan struct{})}
	p.respCh <- "wrong"

	gained, cancelled, err := a.converse("me", "C", p)
	if err != nil || cancelled {
		t.Fatalf("converse err = %v cancelled = %v", err, cancelled)
	}
	if gained {
		t.Fatal("wrong password gained authorization")
	}
}

// A cancel while a prompt is pending unwinds the conversation as cancelled.
func TestPolkitConverseCancel(t *testing.T) {
	useFakeHelper(t, fakePolkitHelper(t,
		"read u\nread c\nprintf 'PAM_PROMPT_ECHO_OFF Password: \\n'\nread pw\nprintf 'SUCCESS\\n'\n"))
	d := &daemon{}
	a := &polkitAgent{topic: d.registerTopic("polkit")}
	p := &polkitPrompt{cookie: "C", respCh: make(chan string, 1), cancelCh: make(chan struct{})}
	p.cancel() // pre-cancel: awaitResponse must pick the cancel

	gained, cancelled, err := a.converse("me", "C", p)
	if err != nil {
		t.Fatalf("converse err = %v", err)
	}
	if gained {
		t.Fatal("cancelled conversation reported gained")
	}
	if !cancelled {
		t.Fatal("cancel was not reported")
	}
}

// polkitPickUser resolves the first unix-user identity's uid to a login name, and
// rejects an identity set with no unix-user (matching the reference error path).
func TestPolkitPickUser(t *testing.T) {
	me, err := user.Current()
	if err != nil {
		t.Skip("no current user")
	}
	uid, err := parseUint32(me.Uid)
	if err != nil {
		t.Skipf("non-numeric uid %q", me.Uid)
	}
	ids := []polkitIdentity{
		{Kind: "unix-group", Details: map[string]dbus.Variant{"gid": dbus.MakeVariant(uint32(0))}},
		{Kind: "unix-user", Details: map[string]dbus.Variant{"uid": dbus.MakeVariant(uid)}},
	}
	if name, ok := polkitPickUser(ids); !ok || name != me.Username {
		t.Errorf("polkitPickUser = %q,%v, want %q,true", name, ok, me.Username)
	}
	if _, ok := polkitPickUser([]polkitIdentity{{Kind: "unix-group"}}); ok {
		t.Error("polkitPickUser accepted a set with no unix-user identity")
	}
}

// submit routes the password to the active prompt; cancelCurrent fires its cancel.
func TestPolkitSubmitCancel(t *testing.T) {
	a := &polkitAgent{}
	p := &polkitPrompt{respCh: make(chan string, 1), cancelCh: make(chan struct{})}
	a.current = p

	a.submit("secret")
	if got := <-p.respCh; got != "secret" {
		t.Errorf("submit delivered %q, want secret", got)
	}
	a.cancelCurrent()
	select {
	case <-p.cancelCh:
	default:
		t.Error("cancelCurrent did not close the cancel channel")
	}

	// submit with no active prompt is a safe no-op.
	a.current = nil
	a.submit("ignored")
}

// startPolkit must register the topic and both control calls even when the agent
// is not enabled, so QML can subscribe and whatever handles polkit today keeps
// working. With the flag unset it must NOT touch the system bus.
func TestStartPolkitRegistersCallsAndTopic(t *testing.T) {
	t.Setenv("RYOKU_POLKIT_AGENT", "")
	d := &daemon{}
	d.startPolkit()
	if d.topic("polkit") == nil {
		t.Error("polkit topic not registered")
	}
	for _, m := range []string{"polkit.submit", "polkit.cancel"} {
		if d.callHandler(m) == nil {
			t.Errorf("%s call not registered", m)
		}
	}
	if d.polkit != nil && d.polkit.conn != nil {
		t.Error("polkit agent connected to the bus while disabled")
	}
}

func parseUint32(s string) (uint32, error) {
	v, err := strconv.ParseUint(s, 10, 32)
	return uint32(v), err
}
