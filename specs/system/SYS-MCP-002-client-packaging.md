---
spec_version: "openspec-1.0"
id: "SYS-MCP-002"
title: "Client packaging: Claude Code plugin + use-skills"
status: "approved"
kind: "system"
---

# 1. Problem

MCP works, but onboarding is manual per client: global install, then
`init --mcp`, then a snippet merge, then a skill promotion — each step
documented, none bundled. Smallest observable misbehavior this must
prevent: a Claude Code user installs the CLI yet never wires
MCP/skills/hooks, so the agent loop runs ungoverned while the user
believes it is governed. This contract scopes the one-install
packaging: a Claude Code plugin bundling the MCP server, the
use-skills, and agent-loop hooks — plus the per-client skill-install
story. Build started 2026-11-05 (Wave 1, SYS-VAL-001 approved);
all §2 fields decided below. Wave-1 build + scratch proof landed
2026-11-05 (FOLLOWUP-01 F-001); status approved.

# 2. Interface / Schema

- Plugin contents (DECIDED 2026-11-05; shapes verified against
  installed marketplace/plugin manifests). Repo root is the
  marketplace (`.claude-plugin/marketplace.json`, one entry, `source`
  `./plugin`); the plugin is self-contained under `plugin/`:
  - Manifest `plugin/.claude-plugin/plugin.json`: `name`
    `flutterguard`, `version` mirrored from `pubspec.yaml`
    (test-enforced), description, author, homepage, repository,
    `license` MIT, and inline `mcpServers: {flutterguard: {command:
    'flutterguard_mcp'}}` (no separate `.mcp.json`).
  - Skills: `plugin/skills/fg-use/SKILL.md`, an embedded copy of
    `.agents/skills/fg-use/SKILL.md` (byte-sync enforced by test —
    the install ships the plugin subdir only, so pointers would
    dangle). v1 bundles `fg-use` only; the dev-loop skills stay
    repo-local (they extend FlutterGuard itself).
  - Hooks `plugin/hooks/hooks.json` (classic command form, matcher
    `Edit|Write`, `${CLAUDE_PLUGIN_ROOT}` script paths):
    - PreToolUse (timeout 10): `dart
      "${CLAUDE_PLUGIN_ROOT}/hooks/check_guard.dart" --presence` —
      fast PATH-presence gate, no gate run.
    - PostToolUse (timeout 60): `dart
      "${CLAUDE_PLUGIN_ROOT}/hooks/check_guard.dart"` — runs
      `flutterguard check --json` on the edited file.
    - Commit-time stays the git pre-commit hook from `init`
      (unchanged; order: agent hook first, git hook last).
  - Hook script `plugin/hooks/check_guard.dart`: standalone Dart
    (`dart:io` + `dart:convert` only, zero `package:` imports —
    install contexts lack package config). Both modes skip non-`.dart`
    paths with exit 0 first; then: CLI missing on PATH → exit 2 +
    install command on stderr; violations → exit 2 + findings +
    recipe pointers on stderr; clean/warnings-only → exit 0. Exit
    semantics are the Claude runtime contract (0 allow, 2
    block/feedback). Requires the Dart SDK on PATH (already
    required by the global install itself).
- Skills-table amendment: the SYS-MCP-001 chat-skills table gains
  `fg-use` (daily loop ↔ `analyze_ast`/`get_canonical_recipe` ↔
  `check`). `fg-use` content ships under REL-001
  (`.agents/skills/fg-use/SKILL.md`); this spec owns its
  distribution, not its content.
- Per-client install matrix (single source of truth, mirrored in
  README/LEIAME): Claude Code → plugin; Cursor → `init --mcp`
  (existing); Gemini CLI / Antigravity → printed snippet (existing);
  Muse → `muse skills install --scope user` for `fg-use`.
- Marketplace vs local-folder distribution (DECIDED per SYS-VAL-001
  owner decision 2026-11-05): BOTH channels in-plan. GitHub
  marketplace first (`Thander21/FlutterGuard-AI` added as the
  `flutterguard` marketplace, install `flutterguard@flutterguard`),
  local folder alongside (clone → `marketplace add <path>` →
  install). The draft's "marketplace on field demand" sequencing is
  superseded.
- Versioning: plugin version tracks the pubspec version; the MCP
  wire stays backward-compatible within a minor.

# 3. File Placement

- `specs/system/SYS-MCP-002-client-packaging.md` (this contract; the
  grader skips `specs/system/` non-recursively and `kind: system`
  explicitly).
- `.claude-plugin/marketplace.json` (repo root IS the marketplace;
  one plugin entry, `source` `./plugin`).
- Plugin root `plugin/` (DECIDED over repo-root co-location — this is
  a Dart package first; the install ships the subdir):
  `.claude-plugin/plugin.json` (manifest + inline `mcpServers`),
  `hooks/hooks.json` + `hooks/check_guard.dart` (standalone hook
  script), `skills/fg-use/SKILL.md` (embedded copy, sync-tested).
  Never vendored copies of `lib/`: the plugin shells out to the
  installed `flutterguard_mcp` / `flutterguard` exes. The skill
  markdown embed is the single exception (a pointer would dangle
  post-install; byte-sync enforced by test, R3 precedent).
- `test/plugin_bundle_test.dart` (manifest/skill/hooks/matrix
  contract tests; hermetic — no global install required).
- `.agents/skills/fg-use/SKILL.md` (content owner: REL-001 turn).
- README/LEIAME install section gains the one-install path.
- SYS-MCP-001 chat-skills-table amendment.

# 4. Evidence Wiring

Emits no `evidence.jsonl`: packaging changes no gate verdict. Hooks
surface findings on stderr only (only `grade` emits evidence lines).
Any new telemetry amends SYS-TELE-001 first (canon rule §4).

# 5. Errors and Edges

- Plugin without a global CLI install: hooks and MCP entries must
  fail with the install command printed — never silent ungoverned.
- Vendor drift: Claude-only packaging must not fork the wire
  contract; SYS-MCP-001 stays the single contract.
- Double-blocking with the git hook is harmless (same verdict);
  document the order: agent hook first, git hook last.
- Skill promotion conflicts at user scope: document precedence,
  never overwrite silently.
- Edited file missing at hook time (concurrent delete): exit 0 —
  nothing to verify; the commit gate re-checks the tree. Blocking
  here would strand the agent with an unfixable error.
- `check` spawn failure (killed shim, broken pipe): exit 2 with the
  reason on stderr — an unknown gate outcome blocks, never a crash
  exit code. The hook resolves the CLI to its full pathed entry
  before spawning (Windows `.bat` shims only spawn with extension).
- `dart` missing on PATH: the hook command fails visibly in the agent
  session (documented prerequisite — the global install itself needs
  the Dart SDK).
- Hooks only see `Edit`/`Write` tool calls: file writes via shell
  commands bypass them. Hooks are a tripwire, not a barrier — the
  pre-commit hook from `init` stays the barrier (gates every commit
  regardless of how files changed), and the `fg-use` loop re-checks
  on demand. Observed live during M5 (agent chose Bash once).
- Noisy `check` stdout (path-activation `dart run` re-resolve lines)
  falls back to raw findings text in the hook report; the verdict
  and exit code are unaffected. Documented-path git installs are
  stdout-silent (SYS-MCP-001 §5).
- Exit bar (MET 2026-11-05, FOLLOWUP-01 F-001): §2 decisions recorded,
  matrix implemented per client (plugin + `init --mcp` + snippet +
  `muse skills install`, each verified live), scratch install proves
  the governed loop end to end (live block + remediation relay).

# 6. Contradictions Resolved

- Plugin root (`plugin/` vs repo-root co-location): `plugin/` wins —
  this is a Dart package first (root hosts `pubspec.yaml`, `lib/`,
  `AGENTS.md` conventions); the marketplace install ships the
  subdir. Subdir `source` follows the installed multi-plugin
  marketplace precedent.
- MCP wiring (`.mcp.json` vs inline `mcpServers`): inline wins —
  follows the installed official Dart/Flutter plugin manifest; one
  less file, same stdio shape as `mcp_config.json`.
- Hook split (draft "PreToolUse running `check`" vs Pre/Post): the
  split wins — gating the pre-edit state would block the very edit
  that fixes a violation. PreToolUse keeps the fast presence gate
  (missing CLI → install command); PostToolUse exit-2 feeds the
  fresh findings back into the loop, which is the §1 fail-closed
  behavior. The draft's single-hook sketch is superseded.
- Skill pointers vs embed: embed wins — the installed plugin
  directory is self-contained, so a pointer to `.agents/skills/`
  would dangle. Byte-sync test follows the R3 recipe-embed
  precedent. The draft's "bundled skill pointers" wording is
  superseded (only `lib/` stays pointer-free, per §3).
- Channels (draft "marketplace on field demand"): both-channels wins
  per SYS-VAL-001 owner decision 2026-11-05.
- This spec otherwise extends SYS-MCP-001 and SYS-REL-001 without
  reversing them.
