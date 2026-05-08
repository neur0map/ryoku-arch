# Listening Ports Hover Design

## Goal

When the three-island topbar shows the ear icon and TCP listener count, hovering that indicator should explain the count by listing the listening TCP ports and the best available service identity for each port without requiring elevated process access.

## UI

Use the existing rich hover popup pattern from `docs/ui-patterns.md`: `StyledPopup` with 16 horizontal and 12 vertical padding. The popup attaches to the existing listening row in `shell/modules/bar/threeIsland/SecPulseIndicator.qml`.

The popup header reads `Listening TCP ports`. Rows show:

- endpoint, for example `127.0.0.1:11434` or `[::1]:631`
- process or service label, for example `ollama (321)` or `systemd-resolved.service`
- purpose hint when known, for example `Ollama API`

If process details are unavailable, the row says `unknown process`. The popup displays at most 12 rows and adds a `+N more` row when the system has more listeners.

## Data Flow

`shell/services/RyokuSecPulse.qml` continues to poll only when `bar.secPulse.showListening` is enabled. The listener command changes from count-only output to:

```bash
ss -lntpeH 2>/dev/null || true
```

The service parses the command output into a `listeningPorts` array and sets `listeningCount` from the parsed row count, keeping the displayed count and hover details aligned. When `ss` exposes cgroup socket metadata, the parser uses it to surface service names such as `tailscaled.service` or `cups.service`.

## Error Handling

If `ss` is unavailable, fails, or returns no output, the count is `0` and the popup shows an empty-state row. If process details are hidden by permissions, endpoint and port still render.

## Testing

Add a focused test for parsing representative `ss -lntpeH` output, including IPv4, IPv6, wildcard bindings, cgroup service metadata, known purpose hints, and hidden process details. Run the new test plus the existing three-island regression test.
