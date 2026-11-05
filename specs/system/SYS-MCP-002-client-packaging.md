---
spec_version: "openspec-1.0"
id: "SYS-MCP-002"
title: "Client packaging: Claude Code plugin + use-skills"
status: "draft"
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
story. Next feature: design lands here, build starts on owner go.

# 2. Interface / Schema

- Plugin contents (shape recorded here, fields decided at build): the
  MCP server entry (`flutterguard_mcp` stdio), skills (`fg-use`
  mandatory; `fg-spec`/`fg-vector`/`fg-visitor`/`fg-grade` dev-loop
  optional), hooks (PreToolUse/commit running `check` — fail-closed
  inside the agent loop).
- Skills-table amendment: the SYS-MCP-001 chat-skills table gains
  `fg-use` (daily loop ↔ `analyze_ast`/`get_canonical_recipe` ↔
  `check`). `fg-use` content ships under REL-001
  (`.agents/skills/fg-use/SKILL.md`); this spec owns its
  distribution, not its content.
- Per-client install matrix (single source of truth, mirrored in
  README/LEIAME): Claude Code → plugin; Cursor → `init --mcp`
  (existing); Gemini CLI / Antigravity → printed snippet (existing);
  Muse → `muse skills install --scope user` for `fg-use`.
- Marketplace vs local-folder distribution: decided at build;
  local-folder first (no review gate), marketplace on field demand.
- Versioning: plugin version tracks the pubspec version; the MCP
  wire stays backward-compatible within a minor.

# 3. File Placement

- `specs/system/SYS-MCP-002-client-packaging.md` (this contract; the
  grader skips `specs/system/` non-recursively and `kind: system`
  explicitly).
- Plugin root (`plugin/` vs `.claude-plugin/` — decided at build):
  manifest + hooks + bundled skill pointers. Never vendored copies
  of `lib/`: the plugin shells out to the installed
  `flutterguard_mcp` / `flutterguard` exes.
- `.agents/skills/fg-use/SKILL.md` (content owner: REL-001 turn).
- README/LEIAME install section gains the one-install path.
- SYS-MCP-001 chat-skills-table amendment.

# 4. Evidence Wiring

Emits no `evidence.jsonl`: packaging changes no gate verdict. Hooks
report through existing channels (tool results, hook stderr). Any new
telemetry amends SYS-TELE-001 first (canon rule §4).

# 5. Errors and Edges

- Plugin without a global CLI install: hooks and MCP entries must
  fail with the install command printed — never silent ungoverned.
- Vendor drift: Claude-only packaging must not fork the wire
  contract; SYS-MCP-001 stays the single contract.
- Double-blocking with the git hook is harmless (same verdict);
  document the order: agent hook first, git hook last.
- Skill promotion conflicts at user scope: document precedence,
  never overwrite silently.
- Draft exit bar: the §2 build-time decisions are recorded, the
  matrix is implemented per client, and a scratch install proves
  governed-loop behavior end to end.

# 6. Contradictions Resolved

None yet — this spec extends SYS-MCP-001 and SYS-REL-001 without
reversing them. The local-folder-vs-marketplace and manifest-shape
decisions land here at build time.
