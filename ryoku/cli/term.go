package main

import (
	"os"
	"strconv"
	"strings"
	"syscall"
	"unsafe"
)

// tiny terminal-styling helpers, stdlib only. colour is Ryoku vermilion
// (#F25623) plus a few accents, emitted only on a real terminal and never
// under NO_COLOR, so piped/redirected output (and the report file) stays
// plain text.

var useColor = colorWanted()

func colorWanted() bool {
	if os.Getenv("NO_COLOR") != "" {
		return false
	}
	fi, err := os.Stdout.Stat()
	return err == nil && fi.Mode()&os.ModeCharDevice != 0
}

// stdinIsTTY: is stdin a real terminal? TCGETS succeeds only on a tty.
// unlike an os.ModeCharDevice check it isn't fooled by /dev/null (also a
// character device), so a GUI poller wiring stdin to /dev/null or a pipe
// reads as non-interactive. this is what keeps `ryoku status` from escalating
// to sudo when no human is present.
func stdinIsTTY() bool {
	var t syscall.Termios
	_, _, errno := syscall.Syscall(syscall.SYS_IOCTL, os.Stdin.Fd(),
		uintptr(syscall.TCGETS), uintptr(unsafe.Pointer(&t)))
	return errno == 0
}

func paint(code, s string) string {
	if !useColor || s == "" {
		return s
	}
	return "\033[" + code + "m" + s + "\033[0m"
}

func brand(s string) string { return paint("38;2;242;86;35", s) } // #F25623
func green(s string) string { return paint("38;2;152;195;121", s) }
func amber(s string) string { return paint("38;2;229;181;103", s) }
func red(s string) string   { return paint("38;2;224;108;117", s) }
func dim(s string) string   { return paint("2", s) }
func bold(s string) string  { return paint("1", s) }

// termWidth: terminal column count (COLUMNS, else the TIOCGWINSZ ioctl),
// clamped to a readable range. 80 when stdout isn't a terminal.
func termWidth() int {
	if c := strings.TrimSpace(os.Getenv("COLUMNS")); c != "" {
		if n, err := strconv.Atoi(c); err == nil && n > 0 {
			return clamp(n)
		}
	}
	var ws struct{ row, col, x, y uint16 }
	r, _, _ := syscall.Syscall(syscall.SYS_IOCTL, os.Stdout.Fd(),
		uintptr(syscall.TIOCGWINSZ), uintptr(unsafe.Pointer(&ws)))
	if r == 0 && ws.col > 0 {
		return clamp(int(ws.col))
	}
	return 80
}

func clamp(n int) int {
	switch {
	case n < 40:
		return 40
	case n > 110:
		return 110
	default:
		return n
	}
}

// wrap word-wraps s to width and indents each line. newlines stay as
// paragraph breaks.
func wrap(s string, width int, indent string) string {
	avail := width - len(indent)
	if avail < 8 {
		avail = 8
	}
	var out strings.Builder
	for i, para := range strings.Split(s, "\n") {
		if i > 0 {
			out.WriteByte('\n')
		}
		line := ""
		for _, w := range strings.Fields(para) {
			switch {
			case line == "":
				line = w
			case len(line)+1+len(w) <= avail:
				line += " " + w
			default:
				out.WriteString(indent + line + "\n")
				line = w
			}
		}
		out.WriteString(indent + line)
	}
	return out.String()
}
