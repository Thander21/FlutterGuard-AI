---
spec_version: "openspec-1.0"
id: "SYS-MCP-001"
title: "MCP server (typed tools over stdio)"
status: "approved"
kind: "system"
---

# 1. Problem

Agents (Claude Code, Cursor, Gemini CLI, Antigravity) edit Dart/Flutter
code through chat, but the harness gates live behind shell commands the
agent must remember, spell, and parse. Three docs sketch overlapping
tool contracts (Architecture §3.2, SddEddWorkflow §7, LlamaStack §2)
that disagree on names, arity, and membership. This contract reconciles
them into one wire contract: a native MCP server over stdio
(JSON-RPC 2.0) exposing the gates as typed tools, plus the client
registration (`init --mcp`) and the chat-skills mapping that teach
agents when to call what.

# 2. Interface / Schema

Two new runtime dependencies, named here per the dependency rule:
`json_rpc_2` + `stream_channel` (SddEddWorkflow §6).

## Wire (MCP over stdio, newline-delimited JSON-RPC 2.0)

`bin/flutterguard_mcp.dart` reads one JSON-RPC message per stdin line
and writes responses to stdout (never pretty-printed: one line per
message). Logging, if any, goes to stderr — stdout carries protocol
bytes only.

Methods (minimal compliant subset):

| method | params | result |
|---|---|---|
| `initialize` | `{protocolVersion, capabilities, clientInfo}` (all ignored except echoed version) | `{protocolVersion, capabilities: {tools: {}}, serverInfo: {name: 'flutterguard', version}}` |
| `notifications/initialized` | none (notification, no id) | no response |
| `tools/list` | `{}` | `{tools: [{name, description, inputSchema}]}` (5 tools below) |
| `tools/call` | `{name, arguments}` | `{content: [{type: 'text', text: '<json result>'}]}` |

Errors: `-32601` unknown method/tool, `-32602` invalid params
(missing arg, wrong type, unknown `rule_id`), `-32603` internal
(runner threw unexpectedly). `version` in `serverInfo` is
`mcpServerVersion`, a constant mirrored from `pubspec.yaml` (a test
enforces equality — a global install cannot see the checkout's
pubspec, so runtime reads are out).

## Tools (reconciled membership: 4 + 1)

| # | tool | args | backs onto | returns |
|---|---|---|---|---|
| 1 | `analyze_ast` | `path: string` (file or directory) | `checkPath` registry (SYS-CLI-001a) | `{status: PASSED/FAILED, findings: [{rule_id, spec, file, line, message, severity}], errors: [{file, error}]}` |
| 2 | `get_canonical_recipe` | `rule_id: string` | embedded §2 map (this spec; R3) | `{rule_id, spec, recipe_markdown}` |
| 3 | `verify_viewport` | `path: string` (file or directory) | `runTier1Lite` (SYS-VIEW-001) | `{status: PASSED/FAILED, findings, files_scanned, sdk_available, note}` |
| 4 | `run_mutation_check` | `source_file: string, test_file: string` (BOTH required) | `MutationRunner.run` (SYS-MUT-001) | `{passed, results: [{line, original, replacement, status, exit_code}]}` |
| 5 | `get_telemetry` | `rule_id?: string, status?: string, limit?: int` (default 50, max 500) | `./evidence.jsonl` read | `{lines: [...], count}` |

`status` follows gate semantics (`FAILED` = violation caught).
`verify_viewport` v1 is the lite vocabulary with the degraded-mode
note (honest scope: pumping foreign widgets needs the target's
package context). Full-harness orchestration (v2) is DROPPED as of
Wave 2 (see §6): lite is the orchestration story.
`get_telemetry` on a missing `evidence.jsonl` returns empty `lines`
with a `note` (a query, not a gate — never errors). No server-side
timeout: the runners' own breakers (8s) apply; multi-mutant runs may
take minutes — the client decides its budget.

## Chat-skills reconciliation (skill ↔ MCP tools ↔ CLI)

| chat-skill | MCP tools | CLI fallback | owns |
|---|---|---|---|
| `*spec` (`fg-spec`) | — (authoring, no gate) | — (writes `specs/TS-NN.md`) | rule spec authoring |
| `*vector` (`fg-vector`) | — (authoring, no gate) | — (writes `benchmark/vectors/TC-NN.*`) | golden vectors |
| `*visitor` (`fg-visitor`) | `analyze_ast` (verify on vectors) | `dart test`, `check` | visitor + unit test |
| `*grade` (`fg-grade`) | `analyze_ast`, `get_canonical_recipe`, `get_telemetry` | `grade`, `check` | eval + heal loop |
| `*use` (`fg-use`) | `analyze_ast`, `get_canonical_recipe` (escalate: `verify_viewport`, `run_mutation_check`, `get_telemetry`) | `check` | daily loop |

Skills live at `.agents/skills/fg-<name>/SKILL.md` (AGENTS.md
placement); each states its row's tools, CLI fallback, inputs, and
done criteria.

## `init --mcp` registration

`init --mcp` registers the `flutterguard` server in IDE clients:

- Always writes the portable `<root>/mcp_config.json` (client-agnostic,
  the documented name), merged: existing `mcpServers` entries are
  preserved, `flutterguard: {command: 'flutterguard_mcp'}` is
  set (global exe from the `executables` stanza; PLAN-03 corrected
  snippet).
- When `<root>/.cursor/` exists, merges `<root>/.cursor/mcp.json`
  the same way.
- Prints the global-client snippet (Claude Code
  `claude_desktop_config.json` shape) to stdout for manual install —
  never writes outside the root (pollution budget).
- Warns (stdout, non-fatal) when `flutterguard_mcp` does not resolve
  on PATH: registration is valid once the package is installed
  (`dart pub global activate`); packaging owns the exe, init only
  registers.
- Unparseable existing JSON: error, refuse to overwrite (fail-closed,
  same doctrine as the foreign-hook guard).

`--mcp` composes with `--scaffold`/`--agents` (orthogonal flags).

# 3. File Placement

- `specs/system/SYS-MCP-001-mcp-server.md` (this contract).
- `lib/src/mcp/tools.dart` (5 tool implementations over lib APIs;
  pure dispatch input/output, no stdio).
- `lib/src/mcp/recipes.dart` (embedded §2 map; see R3 below).
- `lib/src/mcp/server.dart` (JSON-RPC method table over
  `json_rpc_2`; stdio-agnostic, driven by a `StreamChannel<String>`).
- `lib/src/mcp/client_config.dart` (config merge + `--mcp` writer;
  pure merge, root-scoped I/O).
- `bin/flutterguard_mcp.dart` (stdio main: stdin lines → server →
  stdout; stderr for crashes only).
- `lib/flutterguard_ai.dart` (re-export `mcp/`).
- `test/mcp_server_test.dart` (per-tool dispatch incl. every error
  code, recipes-sync vs specs §2, client-config merge/write units,
  one stdio smoke test spawning the real server).
- `.agents/skills/fg-spec/SKILL.md`,
  `.agents/skills/fg-vector/SKILL.md`,
  `.agents/skills/fg-visitor/SKILL.md`,
  `.agents/skills/fg-grade/SKILL.md`,
  `.agents/skills/fg-use/SKILL.md` (row added by SYS-MCP-002 Wave 1).
- Runtime-only: `<root>/mcp_config.json`, `<root>/.cursor/mcp.json`
  (written by `init --mcp` in the TARGET project, never here).

# 4. Evidence Wiring

Emits no `evidence.jsonl` in v1: tools return verdict objects, and
`get_telemetry` only reads the log. Any future MCP emission lines
MUST amend SYS-TELE-001 first (canon rule §4).

# 5. Errors and Edges

- Malformed JSON on stdin: `-32700` parse error (json_rpc_2
  default), the server stays up.
- `tools/call` unknown `name`: `-32601`. Missing/wrong-typed arg or
  unknown `rule_id`: `-32602` naming the culprit.
- `analyze_ast` over a missing path: `-32602` (same as `checkPath`
  `ArgumentError`). Per-file analyzer crashes ride `errors`, never
  fail the call (same tolerance as `check`).
- `run_mutation_check` red baseline / non-importing test: `-32602`
  with the runner's message (caller error, not a verdict). Breaker
  timeouts ride `results` as `timeout` (verdict FAIL, not an error).
- `verify_viewport` missing path: `-32602`. Lite PASS never claims
  rendered-clean (carries `sdk_available` + `note`).
- `get_telemetry` `limit <= 0` or `> 500`: `-32602`. Malformed log
  lines are skipped (tolerant read; writer bugs must not break the
  audit tool).
- `run_mutation_check` stages volatile pair sandboxes under
  `fixtures/mutation/` (server cwd; targets should gitignore
  `fixtures/`, and `init` never edits `.gitignore` silently) or
  shadow packages under the system temp dir (SYS-MUT-001 routing;
  shadows fetch their own dependencies, so in-tree staging is no
  longer required for `package:` resolution).
- Launcher silence: `pub global run` re-resolves `--source path`
  activations on every run, printing to stdout (fatal for MCP
  framing) — path activation is dev-only. `--source git` installs
  (the documented path) run stdout-silent; verified by experiment.
- Client disconnect (stdin closes): clean exit 0. Startup crash
  (broken pipe on stdout): stderr + exit 1.
- `init --mcp` outside a project root is fine (writes are
  root-scoped, git-independent — unlike the hook).

# 6. Contradictions Resolved

- Membership (3 contracts → 5 tools): Architecture's 4
  (`analyze_ast`, `verify_viewport`, `run_mutation_check`,
  `get_canonical_recipe`) stand; SddEddWorkflow's 5th
  (`get_telemetry`) is IN (cheap pure read, closes the audit loop);
  LlamaStack's bus names (`run_flutter_test`, `analyze_dart_ast`,
  `capture_widget_screenshot`, `check_ast`) stay OUT of the wire
  contract — Llama is deferred unless MCP proves insufficient
  (PLAN-01/02), and MCP now exists. Future-binding map (not
  implemented): `analyze_dart_ast`→`analyze_ast`,
  `run_flutter_test`→full-harness `verify_viewport` v2,
  `capture_widget_screenshot`→Tier-1 PNG harvest (rig-internal
  today), `check_ast`→`analyze_ast`.
- Arity: `analyze_ast` takes file OR directory (docs said file
  only; `checkPath` already walks both — the narrower doc is
  superseded). `run_mutation_check` takes `source_file` AND
  `test_file` (docs said test only; the runner cannot infer the
  source, and guessing would mint false verdicts — the single-arg
  doc is superseded).
- `verify_viewport` scope: v1 = Tier-1-lite (this decides the
  SYS-VIEW-001 §6 deferred item "target-project consumption" for
  v1: lite over the target path, degraded note attached).
  Full-harness orchestration against foreign package contexts was
  v2 — DROPPED Wave 2 (SYS-VAL-001 F5): pumping foreign widgets
  needs the target's SDK + resolvable deps + knowledge of what to
  pump (constructors/routes/providers are unknowable generically)
  + test-context injection, for no demanding target and no field
  finding; lite (FG-LAY-004) catches the dominant static breakage
  class. The Tier-1 rig stays as FlutterGuard's own fixture gate
  (14/14 green, verified 2026-11-05). Re-entry: a target project
  with widget tests + SDK requesting matrix-wrapped runs, or field
  evidence that lite misses matter — then scope v2 as a
  matrix-wrap of the target's OWN tests (synthetic pumping stays
  infeasible: constructors unknowable).
- R3 (PLAN-03 open question — recipe pointers outside the
  checkout): EMBEDDED SPECS wins. `lib/src/mcp/recipes.dart`
  carries every rule's §2 markdown keyed by rule id (checked in,
  sync-enforced by test: any spec §2 edit without re-embedding
  fails the suite naming the rule). Rejected: `rule` command
  (another surface to distribute), published URLs (network + drift).
  This lifts the SYS-RECIPE-001 §2 bar ("no runtime spec file
  reader") for MCP only — the reader is dev-time (the sync test),
  the runtime ships data, not file I/O.
- `init --mcp` vs pollution budget: in-root writes only
  (`mcp_config.json` always, `.cursor/mcp.json` when `.cursor/`
  detected); the Claude/global config is printed, never written
  (out-of-root writes are barred). "Compila o binário" (Architecture
  §3.1-1) is owned by packaging (`executables` + global activate);
  init registers and warns when the exe is not yet on PATH.
- `fg run`, `bin/ast_guardian.dart` (ClientAgents §2) stay
  superseded (PLAN-01): no such tools exist.
