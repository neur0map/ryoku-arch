#!/usr/bin/env python3
"""
aikira-stream  —  QuickShell SSE bridge
========================================
QuickShell's Process type can run this script to consume the SSE stream and
print each token to stdout. QML reads stdout line-by-line via Process.stdout.

Usage (called by QuickShell QML):
    aikira-stream <conversation_id> <message_text> [--proxy <proxy_id>]

Each line printed to stdout is a JSON object:
    {"type": "token",  "content": "..."}
    {"type": "done",   "message_id": "...", "conversation_id": "..."}
    {"type": "error",  "detail": "..."}

Example QML usage:
    Process {
        id: streamProc
        command: ["python3", "/path/to/aikira-stream.py", convId, userText]
        stdout: SplitParser {
            onRead: (line) => {
                const evt = JSON.parse(line)
                if (evt.type === "token") chatModel.appendToken(evt.content)
                else if (evt.type === "done") chatModel.finalize(evt.message_id)
            }
        }
    }
"""

import argparse
import json
import sys
import urllib.request
import urllib.error

BASE_URL = "http://127.0.0.1:7842/api/v1"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("conversation_id")
    parser.add_argument("message", nargs="?", default=None)
    parser.add_argument("--proxy", default=None, dest="proxy_id")
    parser.add_argument("--reroll", action="store_true",
                        help="Delete last AI response and regenerate")
    args = parser.parse_args()

    if args.reroll:
        payload = {"conversation_id": args.conversation_id}
        if args.proxy_id:
            payload["proxy_id"] = args.proxy_id
        endpoint = f"{BASE_URL}/chat/reroll"
    else:
        if not args.message:
            err = {"type": "error", "detail": "message argument is required"}
            print(json.dumps(err), flush=True)
            sys.exit(1)
        payload = {
            "conversation_id": args.conversation_id,
            "content": args.message,
        }
        if args.proxy_id:
            payload["proxy_id"] = args.proxy_id
        endpoint = f"{BASE_URL}/chat/stream"

    body = json.dumps(payload).encode()
    req = urllib.request.Request(
        endpoint,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req) as resp:
            for raw_line in resp:
                line = raw_line.decode("utf-8").rstrip("\n")
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if data == "[DONE]":
                    break
                # Print each event as a single JSON line for QML to parse
                print(data, flush=True)
    except urllib.error.HTTPError as exc:
        err = {"type": "error", "detail": f"HTTP {exc.code}: {exc.read().decode()}"}
        print(json.dumps(err), flush=True)
        sys.exit(1)
    except Exception as exc:
        err = {"type": "error", "detail": str(exc)}
        print(json.dumps(err), flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()