// ryoku-shell = single control plane for the Ryoku desktop shell. as
// `ryoku-shell daemon` it supervises the Quickshell components, brings up the
// clipboard and wallpaper helpers, and owns one Unix socket. as
// `ryoku-shell <command>` it forwards that command to the daemon over the
// socket; Hyprland keybinds use this client form.
package main

import (
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const sockName = "ryoku-shell.sock"

func sockPath() string {
	dir := os.Getenv("XDG_RUNTIME_DIR")
	if dir == "" {
		dir = "/tmp"
	}
	return filepath.Join(dir, sockName)
}

func main() {
	args := os.Args[1:]
	if len(args) == 0 {
		usage()
		os.Exit(2)
	}
	if args[0] == "daemon" {
		if err := runDaemon(); err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-shell:", err)
			os.Exit(1)
		}
		return
	}
	if err := sendCommand(strings.Join(args, " ")); err != nil {
		fmt.Fprintln(os.Stderr, "ryoku-shell:", err)
		os.Exit(1)
	}
}

// sendCommand: forward one command line to the daemon and print any reply that
// isn't a bare "ok".
func sendCommand(line string) error {
	conn, err := net.DialTimeout("unix", sockPath(), 2*time.Second)
	if err != nil {
		return fmt.Errorf("daemon not reachable at %s (is `ryoku-shell daemon` running?)", sockPath())
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(10 * time.Second))
	if _, err := fmt.Fprintln(conn, line); err != nil {
		return err
	}
	buf := make([]byte, 8192)
	n, _ := conn.Read(buf)
	resp := strings.TrimSpace(string(buf[:n]))
	if strings.HasPrefix(resp, "err ") {
		return fmt.Errorf("%s", strings.TrimPrefix(resp, "err "))
	}
	if resp != "" && resp != "ok" {
		fmt.Println(resp)
	}
	return nil
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage:")
	fmt.Fprintln(os.Stderr, "  ryoku-shell daemon")
	fmt.Fprintln(os.Stderr, "  ryoku-shell <launcher|clipboard|link|mixer|calendar|power|battery|peek|hide>")
	fmt.Fprintln(os.Stderr, "  ryoku-shell lock")
	fmt.Fprintln(os.Stderr, "  ryoku-shell wallpaper [next|init|set <path>]")
	fmt.Fprintln(os.Stderr, "  ryoku-shell voice")
	fmt.Fprintln(os.Stderr, "  ryoku-shell <reload|status|ping|quit>")
}
