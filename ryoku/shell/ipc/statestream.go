package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"strings"
	"sync"
	"time"
)

// statestream carries typed subsystem state to QML over the same control socket
// the CLI verbs use, so a QML singleton is a view of daemon state rather than an
// independent poller. Two message families ride the socket beside the one-shot
// command lines:
//
//	subscribe <topic>            long-lived: the daemon writes a full-state JSON
//	                             frame at once, then a fresh frame on every
//	                             change. Byte-identical frames are suppressed, so
//	                             an unchanged value never wakes a binding. One
//	                             line per frame.
//	call <topic>.<method> <json> request/response: the daemon runs the method
//	                             and replies with one JSON line; the connection
//	                             stays open for further calls. An "id" in the
//	                             args is echoed back so a multiplexed client can
//	                             correlate replies.
//
// State flows one way (daemon to QML) through subscribe; intent flows the other
// (QML to daemon) through call.

// stateTopic fans a subsystem's current state out to its subscribers. It keeps
// the last frame as the snapshot a fresh subscriber receives immediately, and
// drops a frame identical to the previous one so QML bindings do not churn on a
// no-op update.
type stateTopic struct {
	mu   sync.Mutex
	subs map[chan []byte]struct{}
	last []byte
}

func newStateTopic() *stateTopic {
	return &stateTopic{subs: map[chan []byte]struct{}{}}
}

func (t *stateTopic) subscribe() chan []byte {
	// Depth one: frames are whole-state, so a newer frame supersedes an
	// unread older one (see publish); a single slot is all a consumer needs.
	ch := make(chan []byte, 1)
	t.mu.Lock()
	t.subs[ch] = struct{}{}
	snap := t.last
	t.mu.Unlock()
	if snap != nil {
		ch <- snap
	}
	return ch
}

func (t *stateTopic) unsubscribe(ch chan []byte) {
	t.mu.Lock()
	delete(t.subs, ch)
	t.mu.Unlock()
}

// publish records frame as the new snapshot and delivers it to every subscriber,
// unless it equals the last frame. Because every frame is the complete state, a
// backed-up consumer has its queued frame replaced with the latest rather than
// blocking the publisher: it can miss an intermediate frame but never the newest.
func (t *stateTopic) publish(frame []byte) {
	t.mu.Lock()
	if bytes.Equal(frame, t.last) {
		t.mu.Unlock()
		return
	}
	t.last = frame
	chans := make([]chan []byte, 0, len(t.subs))
	for ch := range t.subs {
		chans = append(chans, ch)
	}
	t.mu.Unlock()
	for _, ch := range chans {
		select {
		case ch <- frame:
		default:
			select {
			case <-ch:
			default:
			}
			select {
			case ch <- frame:
			default:
			}
		}
	}
}

// registerTopic creates a topic subsystems publish to and QML subscribes to.
func (d *daemon) registerTopic(name string) *stateTopic {
	d.topicsMu.Lock()
	defer d.topicsMu.Unlock()
	if d.topics == nil {
		d.topics = map[string]*stateTopic{}
	}
	t := newStateTopic()
	d.topics[name] = t
	return t
}

func (d *daemon) topic(name string) *stateTopic {
	d.topicsMu.Lock()
	defer d.topicsMu.Unlock()
	return d.topics[name]
}

// callFunc handles one control method. args is the raw JSON object from the call
// line (it may carry an "id" the framing echoes back and the handler ignores).
type callFunc func(args json.RawMessage) (any, error)

func (d *daemon) registerCall(method string, fn callFunc) {
	d.callsMu.Lock()
	defer d.callsMu.Unlock()
	if d.calls == nil {
		d.calls = map[string]callFunc{}
	}
	d.calls[method] = fn
}

func (d *daemon) callHandler(method string) callFunc {
	d.callsMu.Lock()
	defer d.callsMu.Unlock()
	return d.calls[method]
}

// serveSubscription streams one topic to a client until it disconnects. The
// control socket's per-command deadline is cleared first: a subscription is
// long-lived, unlike the one-shot verbs handle() otherwise bounds.
func (d *daemon) serveSubscription(conn net.Conn, cmd string) {
	name := strings.TrimSpace(strings.TrimPrefix(cmd, "subscribe"))
	t := d.topic(name)
	if t == nil {
		fmt.Fprintf(conn, "err unknown topic: %s\n", name)
		return
	}
	_ = conn.SetDeadline(time.Time{})
	ch := t.subscribe()
	defer t.unsubscribe(ch)
	done := make(chan struct{})
	go func() {
		// Any further input, or a half-close, ends the stream.
		_, _ = io.Copy(io.Discard, conn)
		close(done)
	}()
	for {
		select {
		case frame := <-ch:
			if _, err := conn.Write(append(frame, '\n')); err != nil {
				return
			}
		case <-done:
			return
		case <-d.quit:
			return
		}
	}
}

// serveCalls runs control methods on one connection until it closes. first is
// the "call ..." line handle() already read.
func (d *daemon) serveCalls(conn net.Conn, r *bufio.Reader, first string) {
	_ = conn.SetDeadline(time.Time{})
	line := first
	for {
		if strings.HasPrefix(line, "call ") {
			if _, err := fmt.Fprintln(conn, d.handleCall(line)); err != nil {
				return
			}
		}
		next, err := r.ReadString('\n')
		if err != nil {
			return
		}
		line = strings.TrimSpace(next)
	}
}

func (d *daemon) handleCall(line string) string {
	rest := strings.TrimSpace(strings.TrimPrefix(line, "call "))
	method := rest
	var raw json.RawMessage
	if sp := strings.IndexByte(rest, ' '); sp >= 0 {
		method = rest[:sp]
		raw = json.RawMessage(strings.TrimSpace(rest[sp+1:]))
	}
	id := callID(raw)
	h := d.callHandler(method)
	if h == nil {
		return callReply(id, nil, fmt.Errorf("unknown method: %s", method))
	}
	result, err := h(raw)
	return callReply(id, result, err)
}

func callID(raw json.RawMessage) json.RawMessage {
	if len(raw) == 0 {
		return nil
	}
	var m map[string]json.RawMessage
	if json.Unmarshal(raw, &m) != nil {
		return nil
	}
	return m["id"]
}

func callReply(id json.RawMessage, result any, err error) string {
	reply := map[string]any{"ok": err == nil}
	if len(id) > 0 {
		reply["id"] = id
	}
	if err != nil {
		reply["error"] = err.Error()
	} else if result != nil {
		reply["result"] = result
	}
	b, e := json.Marshal(reply)
	if e != nil {
		return `{"ok":false,"error":"reply marshal failed"}`
	}
	return string(b)
}
