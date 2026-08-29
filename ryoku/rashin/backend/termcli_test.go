package main

import "testing"

func TestParseTermArgsBufferMode(t *testing.T) {
	o, sub := parseTermArgs([]string{"--buffer", "--", "list files"})
	if !o.buffer || sub != "" || o.query != "list files" {
		t.Fatalf("parseTermArgs buffer = %+v sub=%q", o, sub)
	}
}

func TestParseTermArgsRejectsRetiredFishFlag(t *testing.T) {
	o, _ := parseTermArgs([]string{"--fish", "ask"})
	if o.buffer || o.query != "--fish ask" {
		t.Fatalf("retired --fish flag did not become query text: %+v", o)
	}
}
