package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/godbus/dbus/v5"
)

// The daemon is the GNOME keyring "system prompter": it owns
// org.gnome.keyring.SystemPrompter on the session bus and implements
// org.gnome.keyring.internal.Prompter, the interface gnome-keyring-daemon drives
// when it needs the user's keyring password. The default prompter (gcr-prompter)
// draws a centred GTK dialog; by claiming the name first we draw the prompt as a
// pill island instead, while reusing gcr's exact wire protocol so
// gnome-keyring-daemon is unaware of the swap.
//
// gcr's prompter contract (gcr/org.gnome.keyring.Prompter.xml):
//   - BeginPrompting(o callback): the client registers a callback object; we
//     reply, then call PromptReady on it once, seeding the secret exchange.
//   - PerformPrompt(o callback, s type, a{sv} props, s exchange): show one
//     prompt. We return at once; the answer is delivered later via PromptReady.
//   - StopPrompting(o callback): tear the prompt down; we answer PromptDone.
const (
	prompterName  = "org.gnome.keyring.SystemPrompter"
	prompterPath  = "/org/gnome/keyring/Prompter"
	prompterIface = "org.gnome.keyring.internal.Prompter"
	callbackReady = "org.gnome.keyring.internal.Prompter.Callback.PromptReady"
	callbackDone  = "org.gnome.keyring.internal.Prompter.Callback.PromptDone"

	replyYes        = "yes"
	replyNo         = "no"
	errPromptFailed = "org.gnome.keyring.Prompter.Failed"
)

// promptSession is one client's prompt across its lifetime. The secret exchange
// is established once (in BeginPrompting) and reused for every PerformPrompt on
// the same callback; gnome-keyring only sends the properties that changed, so
// props accumulates them.
type promptSession struct {
	callback dbus.ObjectPath
	sender   string
	exchange *secretExchange
	props    map[string]interface{}
	id       int
}

type prompter struct {
	conn    *dbus.Conn
	mu      sync.Mutex
	prompts map[dbus.ObjectPath]*promptSession
	active  *promptSession
	nextID  int
	onShow  func(id int, ptype string, props map[string]interface{})
}

// startKeyringPrompter brings the prompter up on the session bus. It returns nil
// (after logging) when the bus is unavailable or the name is held elsewhere, so
// the shell still starts and gcr's own prompter stays as the fallback.
func startKeyringPrompter() *prompter {
	conn, err := dbus.ConnectSessionBus()
	if err != nil {
		log.Printf("ryoku-shell: keyring prompter disabled: %v", err)
		return nil
	}
	p := &prompter{conn: conn, prompts: map[dbus.ObjectPath]*promptSession{}}
	p.onShow = p.pushPrompt
	if err := conn.Export(p, dbus.ObjectPath(prompterPath), prompterIface); err != nil {
		log.Printf("ryoku-shell: keyring prompter disabled: %v", err)
		_ = conn.Close()
		return nil
	}
	reply, err := conn.RequestName(prompterName, dbus.NameFlagReplaceExisting|dbus.NameFlagDoNotQueue)
	if err != nil {
		log.Printf("ryoku-shell: keyring prompter disabled: %v", err)
		_ = conn.Close()
		return nil
	}
	if reply != dbus.RequestNameReplyPrimaryOwner {
		log.Printf("ryoku-shell: keyring prompter disabled: %s already owned", prompterName)
		_ = conn.Close()
		return nil
	}
	return p
}

// BeginPrompting registers a client callback and seeds the secret exchange. We
// must call PromptReady only after this method's reply reaches the client (it
// completes the client's open on that first ready), so it is deferred briefly:
// the bus preserves message order once the reply is out.
func (p *prompter) BeginPrompting(callback dbus.ObjectPath, sender dbus.Sender) *dbus.Error {
	sess := &promptSession{
		callback: callback,
		sender:   string(sender),
		exchange: newSecretExchange(),
		props:    map[string]interface{}{},
	}
	begin, err := sess.exchange.begin()
	if err != nil {
		return dbus.NewError(errPromptFailed, []interface{}{err.Error()})
	}
	p.mu.Lock()
	p.prompts[callback] = sess
	p.mu.Unlock()

	go func() {
		time.Sleep(60 * time.Millisecond)
		p.callReady(sess, "", nil, begin)
	}()
	return nil
}

// PerformPrompt shows one prompt. It merges the changed properties, takes the
// client's public key to finish key agreement, and raises the island. The user's
// answer arrives later via the control socket and is sent back with PromptReady.
func (p *prompter) PerformPrompt(callback dbus.ObjectPath, ptype string, properties map[string]dbus.Variant, exchange string) *dbus.Error {
	p.mu.Lock()
	sess := p.prompts[callback]
	p.mu.Unlock()
	if sess == nil {
		return dbus.NewError(errPromptFailed, []interface{}{"unknown prompt"})
	}
	if _, err := sess.exchange.receive(exchange); err != nil {
		return dbus.NewError(errPromptFailed, []interface{}{err.Error()})
	}
	for k, v := range properties {
		sess.props[k] = v.Value()
	}

	p.mu.Lock()
	p.nextID++
	sess.id = p.nextID
	p.active = sess
	id, props := sess.id, copyProps(sess.props)
	p.mu.Unlock()

	go p.onShow(id, ptype, props)
	return nil
}

// StopPrompting ends a prompt: dismiss the island and acknowledge with
// PromptDone (best effort; the client has often already dropped its callback).
func (p *prompter) StopPrompting(callback dbus.ObjectPath) *dbus.Error {
	p.mu.Lock()
	sess := p.prompts[callback]
	delete(p.prompts, callback)
	if p.active == sess {
		p.active = nil
	}
	p.mu.Unlock()

	go ipcCall("pill", "pill", "keyringHide", "")
	if sess != nil {
		go p.callDone(sess)
	}
	return nil
}

// respond delivers the island's answer back to gnome-keyring. action is
// "continue" (the user submitted) or anything else (cancel); choice is the
// optional checkbox. A stale id (the prompt was replaced or torn down) is
// ignored. Called from the daemon's control socket so the secret never crosses a
// command line.
func (p *prompter) respond(id int, action string, choice bool, secret string) string {
	p.mu.Lock()
	sess := p.active
	p.mu.Unlock()
	if sess == nil || sess.id != id {
		return "ok"
	}

	reply := replyNo
	var exchange string
	var err error
	if action == "continue" {
		reply = replyYes
		exchange, err = sess.exchange.send([]byte(secret))
	} else {
		exchange, err = sess.exchange.send(nil)
	}
	if err != nil {
		return "err keyring: " + err.Error()
	}

	props := map[string]dbus.Variant{}
	if strProp(sess.props, "choice-label") != "" {
		props["choice-chosen"] = dbus.MakeVariant(choice)
	}
	p.callReady(sess, reply, props, exchange)
	return "ok"
}

// parseKeyringRespond decodes a control-socket "keyring-respond <id> <action>
// <choice>" line. The typed secret travels on the following line, not here.
func parseKeyringRespond(cmd string) (id int, action string, choice bool, err error) {
	fields := strings.Fields(cmd)
	if len(fields) < 4 {
		return 0, "", false, fmt.Errorf("malformed keyring response")
	}
	id, err = strconv.Atoi(fields[1])
	if err != nil {
		return 0, "", false, fmt.Errorf("malformed keyring id")
	}
	return id, fields[2], fields[3] == "1", nil
}

// keyringRespond forwards an island answer to the prompter.
func (d *daemon) keyringRespond(cmd, secret string) string {
	if d.prompter == nil {
		return "err keyring prompter not running"
	}
	id, action, choice, err := parseKeyringRespond(cmd)
	if err != nil {
		return "err " + err.Error()
	}
	return d.prompter.respond(id, action, choice, secret)
}

// pushPrompt sends one prompt's fields to the pill island as JSON.
func (p *prompter) pushPrompt(id int, ptype string, props map[string]interface{}) {
	payload := map[string]interface{}{
		"id":            id,
		"type":          ptype,
		"mon":           activeMonitor(),
		"title":         strProp(props, "title"),
		"message":       strProp(props, "message"),
		"description":   strProp(props, "description"),
		"warning":       strProp(props, "warning"),
		"choiceLabel":   strProp(props, "choice-label"),
		"choiceChosen":  boolProp(props, "choice-chosen"),
		"passwordNew":   boolProp(props, "password-new"),
		"continueLabel": strProp(props, "continue-label"),
		"cancelLabel":   strProp(props, "cancel-label"),
	}
	b, err := json.Marshal(payload)
	if err != nil {
		log.Printf("ryoku-shell: keyring prompt payload: %v", err)
		return
	}
	ipcCall("pill", "pill", "keyringPrompt", string(b))
}

func (p *prompter) callReady(sess *promptSession, reply string, props map[string]dbus.Variant, exchange string) {
	if props == nil {
		props = map[string]dbus.Variant{}
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	obj := p.conn.Object(sess.sender, sess.callback)
	if call := obj.CallWithContext(ctx, callbackReady, 0, reply, props, exchange); call.Err != nil {
		log.Printf("ryoku-shell: keyring PromptReady: %v", call.Err)
	}
}

func (p *prompter) callDone(sess *promptSession) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	obj := p.conn.Object(sess.sender, sess.callback)
	_ = obj.CallWithContext(ctx, callbackDone, 0).Err
}

func copyProps(m map[string]interface{}) map[string]interface{} {
	out := make(map[string]interface{}, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}

func strProp(m map[string]interface{}, k string) string {
	if v, ok := m[k].(string); ok {
		return v
	}
	return ""
}

func boolProp(m map[string]interface{}, k string) bool {
	if v, ok := m[k].(bool); ok {
		return v
	}
	return false
}
