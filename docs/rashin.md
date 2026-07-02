# Ryoku Rashin

Rashin (羅針, "compass needle") is Ryoku's optional agent OS: a machine-generated
knowledge vault, a local daemon with a web dashboard, and a one-click Hermes
agent setup. It gives any coding agent (Hermes, Claude Code, codex, opencode,
omp/pi) an exact map of the system instead of burning tokens rediscovering it.
Everything is local, off by default, and enabled from Ryoku Settings under
Advanced.

## What it is, and is not

It is:

- **Optional.** The `ryoku-rashin` binary ships with the desktop but stays inert
  until you enable it. Optional means not running, not absent.
- **Local.** The daemon binds `127.0.0.1` only. WebSocket upgrades verify the
  Origin host is localhost. No auth, because the surface is single-user local.
- **Off by default.** Nothing runs, indexes, or wires until you flip the gate.

It is not:

- **An MCP server.** Markdown files are the interface every agent already
  speaks. MCP is a possible v2.
- **Remote.** No listener leaves the loopback interface.
- **A bundled LLM.** Hermes brings its own provider; you pick one during setup.

## The vault

The vault is the knowledge base every agent reads and writes, at
`~/.local/share/ryoku/rashin/` (respects `XDG_DATA_HOME`).

| Path | What it holds |
|---|---|
| `AGENTS.md` | The entry contract, read natively by codex, opencode, and omp |
| `CLAUDE.md` | A symlink to `AGENTS.md` for Claude Code |
| `system.md` | Generated: hardware, kernel, drivers, displays |
| `desktop.md` | Generated: the Ryoku map (configs, owners, reload commands) |
| `packages.md` | Generated: package sets, versions, update state |
| `memory/` | Agent-writable; Hermes `MEMORY.md` and `USER.md` live here |
| `journal/` | Agent-writable dated notes, one file per day |

**Fence markers.** Every generated file is fenced between
`<!-- rashin:generated:begin -->` and `<!-- rashin:generated:end -->`. A reindex
rewrites only the content inside the fence; anything a user or agent adds outside
it survives. `AGENTS.md` is written from a template only when absent, then owned
by the user and agents.

**Write rules for agents.**

- Generated files (`system.md`, `desktop.md`, `packages.md`) are read-only. Do
  not edit inside the fence; a reindex overwrites it.
- Read `desktop.md` before searching the filesystem or guessing paths. It names
  where every config lives, which binary owns it, and how to reload it.
- Write durable notes to `memory/` and dated notes to `journal/YYYY-MM-DD.md`.

Reindex triggers: daemon start, `ryoku-rashin index`, a 6h timer, and the
dashboard's reindex button.

## The daemon: `ryoku-rashin`

One Go program (module `ryoku-rashin`), stdlib plus one dependency
(`github.com/coder/websocket`) for the chat and vitals sockets. It follows
`ryoku-shell` conventions: atomic writes, `RYOKU_*` env overrides, single
instance via a flock. The gate and port live in `~/.config/ryoku/rashin.json`
(respects `XDG_CONFIG_HOME`):

```json
{ "enabled": false, "port": 3600 }
```

Subcommands:

| Command | Job |
|---|---|
| `serve [--if-enabled]` | HTTP and WebSocket on `127.0.0.1:3600`, embedded dashboard. `--if-enabled` exits 0 immediately when the gate is off (the autostart path) |
| `index` | Regenerate `system.md`, `desktop.md`, `packages.md` |
| `setup` | One-click actuator: install Hermes, run its onboarding, wire, enable |
| `wire [agent]` | Apply vault pointers to all detected agents, or one named agent |
| `unwire [agent]` | Remove vault pointers, keeping the file |
| `status [--json]` | Report daemon, vault, hermes, and wiring state |
| `enable` / `disable` | Flip the autostart gate and start or stop the daemon |

The dashboard serves on `http://127.0.0.1:3600`. The HTTP API (all localhost)
covers `GET /api/status`, `GET /api/vitals` (also pushed on `WS /ws/vitals`),
`GET /api/vault` and `GET /api/vault/file?p=`, `POST /api/index`,
`GET /api/agents` with wire and unwire, and `WS /ws/chat` for the Hermes bridge.
Vitals come from `/proc` and `statfs`, with GPU via `nvidia-smi` when present.

## The dashboard

Hand-authored HTML, CSS, and JS embedded in the binary. No node, no build step,
no CDN; fonts and art ship in the repo. It deliberately does not use the desktop
Tokyo Night language: the look is Japanese retro poster and print brutalism, near
black paper with cream ink and a vermillion sun disc.

| Panel | Content |
|---|---|
| Overview | Hero poster header, vitals as poster stat blocks, daemon and hermes state, journal ticker |
| Vault | File tree, rendered markdown, reindex button, generated-fence badges |
| Agents | Detected CLIs, versions, wiring state per agent, wire and unwire actions |
| Chat | Hermes session: streaming text, tool-call cards, permission prompts, session list |

The chat panel talks to Hermes over the daemon's ACP bridge (Agent Client
Protocol over stdio, the interface Zed uses). Streamed message chunks, thought
chunks, tool start and finish events, and permission requests all surface in the
UI. Terminal `hermes` and web chat share the same memory, because both run in the
vault workspace.

## One-click setup

The `setup` verb runs in a floating kitty (the Extras pattern), streaming
progress as JSON to `$XDG_RUNTIME_DIR/ryoku-rashin/setup.json`, which the Hub
page watches live. The flow:

1. **Preflight:** check `curl`, `python3` or `uv`, and disk space; detect an
   existing Hermes.
2. **Install Hermes** via its official installer under `$HOME` (skipped if
   present). Setup never runs with sudo.
3. **Onboard:** run `hermes setup` interactively in that terminal so you pick a
   provider and model right there (skipped if already configured).
4. **Wire:** ensure the vault, reindex, point Hermes's workspace at the vault so
   `MEMORY.md` and sessions live there, and write the vault `AGENTS.md` pointers.
5. **Global pointers:** append a marker-fenced block to each detected agent's
   global instructions file (see below).
6. **Enable** the daemon and open the dashboard.

### Two Hermes safety rules

Hermes is the resident agent, and setup treats an existing install as sacred.

1. **Never clobber an existing Hermes.** If Hermes is already installed and
   configured, setup skips install and onboarding entirely and only wires. Your
   provider and model choices are untouched. Wiring uses the supported interface,
   never a raw edit of `~/.hermes/config.yaml`.
2. **Wiring is re-checked on serve start; drift shows in status.** Hermes's own
   onboarding can rewrite its config, so wiring runs after `hermes setup`
   finishes, and `ryoku-rashin serve` re-checks the wiring on start and re-applies
   it if it was lost. `status` reports drift so the Hub and dashboard can offer a
   re-wire action.

## Agent pointers

Wiring appends one marker-fenced block to each detected agent's global
instructions, telling it the vault exists and to read it first. The block is
idempotent (wire replaces an existing block or appends a fresh one) and reversible
(unwire removes the block and leaves the file):

```markdown
<!-- ryoku-rashin:begin -->
## Ryoku Rashin system vault

This machine runs Ryoku (Arch Linux, Hyprland desktop). A maintained map of the
system lives at `~/.local/share/ryoku/rashin/`. Before exploring the machine or
guessing paths, read `AGENTS.md` there: it says where every config lives, which
binary owns it, and how to reload it. Write durable notes to `memory/` and
dated notes to `journal/YYYY-MM-DD.md`.
<!-- ryoku-rashin:end -->
```

Wire targets, one per detected agent:

| Agent | File |
|---|---|
| Claude Code | `~/.claude/CLAUDE.md` |
| Codex CLI | `~/.codex/AGENTS.md` |
| opencode | `~/.config/opencode/AGENTS.md` |
| Oh My Pi | `~/.omp/agent/AGENTS.md` |
| Hermes | `~/.hermes/memories/MEMORY.md` |

Blocks are additive and only touch agents that are already present; Rashin never
creates an agent's own directory (except opencode's `~/.config/opencode`).

## Testing from a terminal

The vault is plain markdown, so any agent that reads `AGENTS.md` sees the same
map. To confirm the wiring end to end:

```sh
cd ~/.local/share/ryoku/rashin
hermes
```

Ask it something about the machine ("what GPU is in here and how do I switch
graphics modes?"). A wired Hermes reads `AGENTS.md`, follows it to `desktop.md`,
and answers from the vault instead of probing. Then write a note:

```sh
echo '- tried the vault, it works' >> journal/$(date +%F).md
```

Reopen the dashboard's Vault panel and the new journal entry is there, because the
terminal and the web chat share one workspace.
