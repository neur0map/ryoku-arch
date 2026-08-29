package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// termcli.go is the `rashin <question>` client: it collects terminal context,
// streams the daemon's /api/term markers, renders the answer and the command
// plan with tier badges, and (in --buffer porcelain) prints the chosen command
// to stdout for the shell to drop on the prompt. The daemon does the
// thinking; the CLI is a viewer and the human is the executor.

type termOpts struct {
	query  string
	cont   bool // -c / --continue
	buffer bool // --buffer porcelain: presentation on stderr, buffer on stdout
	plain  bool // --plain: no ANSI (also auto when stdout is not a TTY)
	run    bool // --run: execute here with tiered confirmation
	clip   bool // --copy: copy the one-liner
}

// cmdTerm is the terminal lane entrypoint: `rashin ...` and
// `ryoku-rashin term ...`. Sub-verbs (resume, last, recipe) are local; a bare
// query hits the daemon.
func cmdTerm(args []string) error {
	// Shell post-command hooks report proposed-vs-ran feedback:
	// term --report <proposed> <ran> <status>.
	if len(args) >= 4 && args[0] == "--report" {
		st, _ := strconv.Atoi(args[3])
		reportRan(LoadConfig().Port, args[1], args[2], st)
		return nil
	}
	opts, sub := parseTermArgs(args)
	switch sub {
	case "resume":
		return termResume(opts)
	case "last":
		return termLast(opts)
	case "recipes":
		return termRecipesList(opts)
	case "recipe":
		return termRecipe(opts, args)
	}
	if strings.TrimSpace(opts.query) == "" {
		fmt.Fprintln(os.Stderr, "usage: rashin <what you want>  (also: rashin -c, rashin --resume, rashin recipes)")
		return nil
	}
	cfg := LoadConfig()
	if !pingDaemon(cfg.Port) {
		fmt.Fprintln(os.Stderr, termPaint(opts, redc, "rashin is not running.")+
			" enable it: Ryoku Settings -> Advanced -> Rashin, or `ryoku-rashin enable`.")
		os.Exit(1)
	}
	return runTermAsk(cfg, opts)
}

// parseTermArgs splits flags from the query. Everything after `--`, or the
// first non-flag word, is the query. A leading local sub-verb is returned
// separately.
func parseTermArgs(args []string) (termOpts, string) {
	o := termOpts{}
	var words []string
	sub := ""
	endFlags := false
	for i := 0; i < len(args); i++ {
		a := args[i]
		if endFlags {
			words = append(words, a)
			continue
		}
		switch a {
		case "--":
			endFlags = true
		case "-c", "--continue":
			o.cont = true
		case "--buffer":
			o.buffer = true
		case "--plain":
			o.plain = true
		case "--run":
			o.run = true
		case "--copy":
			o.clip = true
		case "-r", "--resume":
			return o, "resume"
		case "--last":
			return o, "last"
		default:
			if len(words) == 0 && sub == "" && (a == "recipes" || a == "recipe") {
				return o, a
			}
			words = append(words, a)
			endFlags = true // first bare word starts the query
		}
	}
	o.query = strings.Join(words, " ")
	return o, sub
}

// runTermAsk POSTs the question and consumes the marker stream.
func runTermAsk(cfg Config, o termOpts) error {
	body, _ := json.Marshal(termReq{
		Q:          o.query,
		Cwd:        cwd(),
		LastCmd:    os.Getenv("RASHIN_LAST_CMD"),
		LastStatus: lastStatus(),
		Cont:       o.cont,
	})
	req, err := http.NewRequest(http.MethodPost,
		fmt.Sprintf("http://127.0.0.1:%d/api/term", cfg.Port), strings.NewReader(string(body)))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 6 * time.Minute}
	resp, err := client.Do(req)
	if err != nil {
		fmt.Fprintln(os.Stderr, "cannot reach the daemon: "+err.Error())
		os.Exit(1)
	}
	defer resp.Body.Close()

	pres := presenter{o: o, port: cfg.Port}
	// Ctrl+C cancels the daemon-side turn for this id, then exits.
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigs
		pres.clearSpinner()
		if pres.id != "" {
			askPost(cfg.Port, "/api/term/cancel?id="+url.QueryEscape(pres.id))
		}
		os.Exit(130)
	}()

	sc := bufio.NewScanner(resp.Body)
	sc.Buffer(make([]byte, 64*1024), 8<<20)
	for sc.Scan() {
		pres.line(sc.Text())
	}
	pres.clearSpinner()
	return pres.finish()
}

// presenter turns the marker stream into terminal output and, at the end,
// the buffer/copy/run action.
type presenter struct {
	o      termOpts
	port   int
	id     string
	plan   *termPlan
	answer string
	hint   string
	failed bool
	spun   bool
}

func (p *presenter) line(s string) {
	kind, detail, _ := strings.Cut(s, " ")
	switch kind {
	case "@id":
		p.id = detail
	case "@working":
		p.spinner(detail)
	case "@plan":
		var pl termPlan
		if json.Unmarshal([]byte(detail), &pl) == nil {
			p.plan = &pl
		}
	case "@hint":
		p.hint = detail
	case "@perm":
		p.handlePerm(detail)
	case "@answer":
		p.clearSpinner()
		var a askAnswer
		if json.Unmarshal([]byte(detail), &a) == nil {
			p.answer = a.Text
		}
	case "@error":
		p.clearSpinner()
		p.failed = true
		fmt.Fprintln(os.Stderr, termPaint(p.o, redc, "rashin: ")+detail)
	}
}

// finish renders the answer and plan, then performs the terminal action:
// print the buffer payload (--buffer), copy (--copy), run (--run), or just show
// the plan.
func (p *presenter) finish() error {
	if p.failed {
		os.Exit(1)
	}
	w := os.Stderr // presentation channel: stderr under --buffer, else stdout
	if !p.o.buffer {
		w = os.Stdout
	}
	if p.answer != "" && p.answer != "(no answer)" {
		fmt.Fprintln(w, "\n"+wrapText(p.answer, termCols(), "  "))
	}
	if p.plan == nil || len(p.plan.Commands) == 0 {
		p.showHint(w)
		return nil
	}
	fmt.Fprintln(w)
	for i, c := range p.plan.Commands {
		p.renderCommand(w, i, c)
	}
	p.showHint(w)

	chosen := p.pick()
	if chosen == "" {
		return nil
	}
	switch {
	case p.o.clip:
		copyClip(chosen)
		fmt.Fprintln(w, termPaint(p.o, dimc, "copied."))
	case p.o.run:
		return runHere(chosen, p.port)
	case p.o.buffer:
		fmt.Println(chosen)
	default:
		fmt.Println(chosen)
	}
	return nil
}

// renderCommand prints one plan entry: number, tier badge, the command, and
// any validation notes.
func (p *presenter) renderCommand(w *os.File, i int, c termCommand) {
	num := termPaint(p.o, dimc, fmt.Sprintf("%d", i+1))
	fmt.Fprintf(w, "  %s %s %s\n", num, tierBadge(p.o, c.Tier), termPaint(p.o, brandc, c.Run))
	if c.Why != "" {
		fmt.Fprintf(w, "      %s\n", termPaint(p.o, dimc, c.Why))
	}
	for _, n := range c.Notes {
		fmt.Fprintf(w, "      %s %s\n", termPaint(p.o, amberc, "!"), n)
	}
}

func (p *presenter) showHint(w *os.File) {
	if p.hint == "" {
		return
	}
	var h struct {
		Kind string `json:"kind"`
		N    int    `json:"n"`
	}
	if json.Unmarshal([]byte(p.hint), &h) == nil && h.Kind == "repeat" {
		fmt.Fprintln(w, termPaint(p.o, dimc,
			fmt.Sprintf("  (asked %d times, `rashin recipe save <name>` to pin it)", h.N)))
	}
}

// pick returns the command to act on. One command: itself. Several: the user
// chooses on the tty (Enter=first, a=all joined with &&, number=that one,
// q=none). Non-interactive: the one-liner joins, else the first.
func (p *presenter) pick() string {
	cmds := p.plan.Commands
	if len(cmds) == 1 {
		return cmds[0].Run
	}
	joined := joinAnd(cmds)
	tty := openTTY()
	if tty == nil {
		if p.plan.Oneliner {
			return joined
		}
		return cmds[0].Run
	}
	defer tty.Close()
	w := actionChannel(p.o)
	fmt.Fprintf(w, "  %s ", termPaint(p.o, dimc, "[Enter=1  a=all  2-9=step  q=none]"))
	r := bufio.NewReader(tty)
	ans, _ := r.ReadString('\n')
	ans = strings.TrimSpace(ans)
	switch {
	case ans == "" || ans == "1":
		return cmds[0].Run
	case ans == "a":
		return joined
	case ans == "q":
		return ""
	default:
		if n, err := strconv.Atoi(ans); err == nil && n >= 1 && n <= len(cmds) {
			return cmds[n-1].Run
		}
	}
	return cmds[0].Run
}

// handlePerm renders a session-lane permission request and answers it over
// /api/perm from the tty, so an escalated turn never dead-ends outside the
// dashboard.
func (p *presenter) handlePerm(detail string) {
	p.clearSpinner()
	var pr struct {
		ID      string       `json:"id"`
		Title   string       `json:"title"`
		Options []PermOption `json:"options"`
	}
	if json.Unmarshal([]byte(detail), &pr) != nil || len(pr.Options) == 0 {
		return
	}
	w := actionChannel(p.o)
	fmt.Fprintf(w, "\n  %s %s\n", termPaint(p.o, amberc, "needs approval:"), pr.Title)
	for i, o := range pr.Options {
		fmt.Fprintf(w, "    %d %s\n", i+1, o.Name)
	}
	tty := openTTY()
	choice := ""
	if tty != nil {
		fmt.Fprintf(w, "  %s ", termPaint(p.o, dimc, "pick a number (Enter=cancel):"))
		r := bufio.NewReader(tty)
		ans, _ := r.ReadString('\n')
		if n, err := strconv.Atoi(strings.TrimSpace(ans)); err == nil && n >= 1 && n <= len(pr.Options) {
			choice = pr.Options[n-1].ID
		}
		tty.Close()
	}
	pb, _ := json.Marshal(map[string]string{"requestId": pr.ID, "optionId": choice})
	http.Post(fmt.Sprintf("http://127.0.0.1:%d/api/perm", p.port), "application/json", strings.NewReader(string(pb)))
}

// spinner updates a single status line on the presentation channel.
var braille = []rune("⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏")

func (p *presenter) spinner(label string) {
	w := actionChannel(p.o)
	if !isTTY(w) {
		return
	}
	frame := braille[int(time.Now().UnixMilli()/90)%len(braille)]
	fmt.Fprintf(w, "\r\033[K%s %s", termPaint(p.o, brandc, string(frame)), termPaint(p.o, dimc, label))
	p.spun = true
}

func (p *presenter) clearSpinner() {
	if !p.spun {
		return
	}
	w := actionChannel(p.o)
	fmt.Fprint(w, "\r\033[K")
	p.spun = false
}

// termResume lists recent asks and, on a pick, reprints the stored answer and
// plan with no model call.
func termResume(o termOpts) error {
	w := actionChannel(o)
	recs := RecentAsks(12)
	if len(recs) == 0 {
		fmt.Fprintln(w, "no recent asks.")
		return nil
	}
	for i, r := range recs {
		fmt.Fprintf(w, "  %d  %s\n", i+1, oneLine(r.Question, 70))
	}
	tty := openTTY()
	if tty == nil {
		return nil
	}
	defer tty.Close()
	fmt.Fprint(w, "  pick: ")
	ans, _ := bufio.NewReader(tty).ReadString('\n')
	n, err := strconv.Atoi(strings.TrimSpace(ans))
	if err != nil || n < 1 || n > len(recs) {
		return nil
	}
	r := recs[n-1]
	fmt.Fprintln(w, "\n"+wrapText(r.Answer, termCols(), "  "))
	if r.Plan != nil {
		fmt.Fprintln(w)
		p := &presenter{o: o}
		for i, c := range r.Plan.Commands {
			p.renderCommand(w, i, c)
		}
	}
	return nil
}

// termLast reprints the last terminal answer and plan.
func termLast(o termOpts) error {
	w := actionChannel(o)
	last, err := loadLastTerm()
	if err != nil {
		fmt.Fprintln(w, "no last answer.")
		return nil
	}
	if last.Answer != "" {
		fmt.Fprintln(w, wrapText(last.Answer, termCols(), "  "))
	}
	if last.Plan != nil {
		p := &presenter{o: o}
		for i, c := range last.Plan.Commands {
			p.renderCommand(w, i, c)
		}
	}
	return nil
}

func termRecipesList(o termOpts) error {
	w := actionChannel(o)
	rs := LoadRecipes()
	if len(rs) == 0 {
		fmt.Fprintln(w, "no recipes yet. `rashin recipe save <name>` after an ask pins one as `rr-<name>`.")
		return nil
	}
	for _, r := range rs {
		fmt.Fprintf(w, "  rr-%-16s %s\n", r.Name, r.Run)
	}
	return nil
}

// termRecipe handles `recipe save <name>` and `recipe rm <name>`.
func termRecipe(o termOpts, args []string) error {
	w := actionChannel(o)
	var rest []string
	for _, a := range args {
		if a != "recipe" {
			rest = append(rest, a)
		}
	}
	if len(rest) < 2 {
		fmt.Fprintln(w, "usage: rashin recipe save <name> | rashin recipe rm <name>")
		return nil
	}
	action, name := rest[0], rest[1]
	switch action {
	case "save":
		last, err := loadLastTerm()
		if err != nil || last.Plan == nil || len(last.Plan.Commands) == 0 {
			return fmt.Errorf("no last plan to save; run an ask that proposes a command first")
		}
		run := last.Plan.Commands[0].Run
		if len(last.Plan.Commands) > 1 {
			run = joinAnd(last.Plan.Commands)
		}
		if err := SaveRecipe(name, run, last.Plan.Intent); err != nil {
			return err
		}
		fmt.Fprintf(w, "saved rr-%s -> %s\n", name, run)
		return nil
	case "rm":
		if err := RemoveRecipe(name); err != nil {
			return err
		}
		fmt.Fprintf(w, "removed rr-%s\n", name)
		return nil
	}
	return fmt.Errorf("unknown recipe action %q", action)
}

// runHere executes a chosen command with a tiered confirmation, then reports
// what ran so the habits layer learns. Used by --run (scripts, non-fish).
func runHere(cmd string, port int) error {
	tier, reason := classify(cmd)
	tty := openTTY()
	if tty != nil && tier >= tierWrite {
		defer tty.Close()
		prompt := "run this? [y/N] "
		if tier == tierDanger {
			prompt = redc("danger") + " (" + reason + "). type `yes` to run: "
		}
		fmt.Fprint(os.Stderr, prompt)
		ans, _ := bufio.NewReader(tty).ReadString('\n')
		ans = strings.TrimSpace(ans)
		ok := ans == "y" || ans == "Y"
		if tier == tierDanger {
			ok = ans == "yes"
		}
		if !ok {
			fmt.Fprintln(os.Stderr, "skipped.")
			return nil
		}
	}
	sh := os.Getenv("SHELL")
	if sh == "" {
		sh = "/bin/sh"
	}
	c := exec.Command(sh, "-c", cmd)
	c.Stdin, c.Stdout, c.Stderr = os.Stdin, os.Stdout, os.Stderr
	err := c.Run()
	status := 0
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			status = ee.ExitCode()
		} else {
			status = 1
		}
	}
	reportRan(port, cmd, cmd, status)
	return nil
}

// reportRan is the learning feedback: what rashin proposed and what actually
// ran. Fire-and-forget on loopback.
func reportRan(port int, proposed, ran string, status int) {
	b, _ := json.Marshal(runRecord{Proposed: proposed, Ran: ran, Status: status})
	http.Post(fmt.Sprintf("http://127.0.0.1:%d/api/term/ran", port), "application/json", strings.NewReader(string(b)))
}

// --- small helpers ---------------------------------------------------------

func cwd() string {
	d, err := os.Getwd()
	if err != nil {
		return ""
	}
	return d
}

func lastStatus() *int {
	s := os.Getenv("RASHIN_LAST_STATUS")
	if s == "" {
		return nil
	}
	n, err := strconv.Atoi(s)
	if err != nil {
		return nil
	}
	return &n
}

func joinAnd(cmds []termCommand) string {
	var runs []string
	for _, c := range cmds {
		runs = append(runs, c.Run)
	}
	return strings.Join(runs, " && ")
}

func copyClip(s string) {
	if _, err := exec.LookPath("wl-copy"); err == nil {
		c := exec.Command("wl-copy")
		c.Stdin = strings.NewReader(s)
		if c.Run() == nil {
			return
		}
	}
	fmt.Println(s)
}

func openTTY() *os.File {
	f, err := os.OpenFile("/dev/tty", os.O_RDWR, 0)
	if err != nil {
		return nil
	}
	return f
}

// actionChannel: the presentation and prompt channel. stderr under --buffer (so
// stdout stays the clean buffer payload), else stdout.
func actionChannel(o termOpts) *os.File {
	if o.buffer {
		return os.Stderr
	}
	return os.Stdout
}

func oneLine(s string, n int) string {
	s = strings.Join(strings.Fields(s), " ")
	if len(s) > n {
		return s[:n-1] + "…"
	}
	return s
}
