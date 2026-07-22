package doctor

import "testing"

// classifyPacnew must auto-resolve only the provably safe cases: bytes identical
// to the live file, or a pacman.conf whose sole difference is the [ryoku] repo
// stanza the installer appends. everything else is a genuine conflict.
func TestClassifyPacnew(t *testing.T) {
	const stockPacman = "[options]\nHoldPkg = pacman glibc\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n"
	liveWithRyoku := stockPacman + "\n[ryoku]\nSigLevel = Required\nServer = https://repo.ryoku.dev/stable/$arch\n"

	cases := []struct {
		name   string
		path   string
		live   string
		pacnew string
		want   pacnewOutcome
	}{
		{"identical bytes", "/etc/foo.conf", "a=1\n", "a=1\n", pacnewIdentical},
		{"pacman.conf only ryoku stanza", "/etc/pacman.conf", liveWithRyoku, stockPacman, pacnewRyokuOnly},
		{"pacman.conf with a real [options] edit", "/etc/pacman.conf", "[options]\nParallelDownloads = 5\nHoldPkg = pacman glibc\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[ryoku]\nSigLevel = Required\nServer = x\n", stockPacman, pacnewConflict},
		{"non-pacman modified file", "/etc/hosts", "127.0.1.1 box\n", "# stock\n", pacnewConflict},
		{"pacman.conf real base change", "/etc/pacman.conf", liveWithRyoku, stockPacman + "[extra]\nInclude = /etc/pacman.d/mirrorlist\n", pacnewConflict},
	}
	for _, c := range cases {
		if got := classifyPacnew(c.path, []byte(c.live), []byte(c.pacnew)); got != c.want {
			t.Errorf("%s: classifyPacnew = %d, want %d", c.name, got, c.want)
		}
	}
}

func TestStripRyokuRepoStanza(t *testing.T) {
	const base = "[options]\nHoldPkg = pacman\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n"
	// appended at EOF (the installer's shape): the whole stanza plus its blank
	// separator must go, leaving the base untouched.
	appended := base + "\n[ryoku]\nSigLevel = Required\nServer = https://repo.ryoku.dev/stable/$arch\n"
	if got := string(trimTrailing(stripRyokuRepoStanza([]byte(appended)))); got != string(trimTrailing([]byte(base))) {
		t.Errorf("appended stanza not stripped cleanly:\n%q", got)
	}
	// a section after [ryoku] survives (only the stanza's own lines are removed).
	withTail := base + "\n[ryoku]\nSigLevel = Required\nServer = x\n[custom]\nServer = y\n"
	wantTail := base + "[custom]\nServer = y\n"
	if got := string(trimTrailing(stripRyokuRepoStanza([]byte(withTail)))); got != string(trimTrailing([]byte(wantTail))) {
		t.Errorf("section after [ryoku] not preserved:\n%q", got)
	}
}
