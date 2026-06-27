package main

import (
	"bytes"
	"encoding/hex"
	"testing"
)

// guard the group prime: gcr uses the 1536-bit MODP group, so a transcription
// slip here silently breaks interop.
func TestSecretExchangePrime(t *testing.T) {
	if sxPrime == nil {
		t.Fatal("prime failed to parse")
	}
	if got := sxPrime.BitLen(); got != 1536 {
		t.Fatalf("prime bit length = %d, want 1536", got)
	}
	if (len(sxPrime.Bytes())) != sxPrimeLen {
		t.Fatalf("prime byte length = %d, want %d", len(sxPrime.Bytes()), sxPrimeLen)
	}
}

// drive both halves of the exchange the way gcr does: prompter begins, client
// receives and replies with its public, prompter receives and seals the secret,
// client decrypts. both sides must derive the same key and recover the exact
// bytes.
func TestSecretExchangeRoundTrip(t *testing.T) {
	for _, secret := range [][]byte{
		[]byte("hunter2"),
		[]byte(""),                       // empty password (passwordless keyring)
		[]byte("a"),                      // shorter than a block
		bytes.Repeat([]byte("x"), 16),    // exactly one block (forces a full pad block)
		[]byte("pâsswörd with spaces 🔐"), // multi-byte utf-8
	} {
		prompter := newSecretExchange()
		begin, err := prompter.begin()
		if err != nil {
			t.Fatalf("begin: %v", err)
		}

		client := newSecretExchange()
		if _, err := client.receive(begin); err != nil {
			t.Fatalf("client receive: %v", err)
		}
		clientPub, err := client.send(nil)
		if err != nil {
			t.Fatalf("client send: %v", err)
		}

		if _, err := prompter.receive(clientPub); err != nil {
			t.Fatalf("prompter receive: %v", err)
		}
		if !bytes.Equal(prompter.key, client.key) {
			t.Fatal("derived keys differ between peers")
		}

		sealed, err := prompter.send(secret)
		if err != nil {
			t.Fatalf("prompter send: %v", err)
		}
		got, err := client.receive(sealed)
		if err != nil {
			t.Fatalf("client decrypt: %v", err)
		}
		if !bytes.Equal(got, secret) {
			t.Fatalf("round trip = %q, want %q", got, secret)
		}
	}
}

// HKDF against RFC 5869 test case 1, so the key-derivation half of the exchange
// is verified independently of the DH.
func TestHKDFVector(t *testing.T) {
	ikm := bytes.Repeat([]byte{0x0b}, 22)
	salt, _ := hex.DecodeString("000102030405060708090a0b0c")
	info, _ := hex.DecodeString("f0f1f2f3f4f5f6f7f8f9")
	want, _ := hex.DecodeString("3cb25f25faacd57a90434f64d0362f2a" +
		"2d2d0a90cf1a5a4c5db02d56ecc4c5bf" +
		"34007208d5b887185865")
	got := hkdfSHA256(ikm, salt, info, 42)
	if !bytes.Equal(got, want) {
		t.Fatalf("hkdf = %x, want %x", got, want)
	}
}

func TestPKCS7(t *testing.T) {
	for _, in := range [][]byte{nil, []byte("a"), bytes.Repeat([]byte("z"), 15), bytes.Repeat([]byte("z"), 16)} {
		padded := pkcs7Pad(in, 16)
		if len(padded)%16 != 0 || len(padded) == 0 {
			t.Fatalf("padded length %d not a positive multiple of 16", len(padded))
		}
		if len(padded) <= len(in) {
			t.Fatalf("padding added no bytes for len %d", len(in))
		}
		out, err := pkcs7Unpad(padded, 16)
		if err != nil {
			t.Fatalf("unpad: %v", err)
		}
		if !bytes.Equal(out, in) && !(len(in) == 0 && len(out) == 0) {
			t.Fatalf("pkcs7 round trip = %q, want %q", out, in)
		}
	}
	if _, err := pkcs7Unpad([]byte{1, 2, 3}, 16); err == nil {
		t.Fatal("expected error for non-block-aligned input")
	}
}
