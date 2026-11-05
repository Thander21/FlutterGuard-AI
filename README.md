# FlutterGuard AI

### Autonomous Reactive & Blocking Quality Harness for Flutter / Dart

> **Turning AI from a complacent code generator into a deterministic senior software engineer through Spec-Driven Development (SDD), Reactive AST Analysis, Multimodal Visual Verification, and Blocking Gates.**

*Leia em português: [LEIAME.md](LEIAME.md)*

> **Scope:** 17 AST rules implemented (16 blocking + `FG-MET-007`
> advisory) with `grade` + `check` + `init` + `sandbox` CLI commands,
> a pre-commit hook, a heal dispatcher, a mutation runner, a
> Tier-1 viewport runner (with Tier-1-lite AST fallback), a
> coverage/CRAP pipeline, a structural duplication detector, and an
> MCP server (5 typed tools, `init --mcp`, 4 chat-skills).
> The Tier-2 visual gate is **[DEFERRED]** — endpoints unverified,
> Tier-1 standing (see `specs/system/SYS-VIEW-002-tier2-visual.md`).
> `specs/` is normative; `docs/` records direction and intent.

---

## 🎯 What Is This Project?

**FlutterGuard AI** is an autonomous framework and orchestrator (_closed-loop agentic harness_) built specifically for the **Flutter/Dart** ecosystem. It solves the biggest bottleneck in AI-assisted development today: fragile code generation, widget lifecycle pollution, state detachment (_state anti-patterns_), silent concurrency failures, and visual breakage (`RenderFlex overflowed`) that traditional linters cannot detect.

The project works as a physical and pedagogical barrier (_fail-closed_): no AI-generated code is approved before passing a strict specification contract, static AST validation, tests with deterministic telemetry, and automated visual inspection.

---

## 🧠 100% Meta AI Core Architecture + Universal Runtime Governance

**FlutterGuard AI** has its core engine and intelligence powered 100% by the **Meta AI** model and framework ecosystem, while simultaneously acting as a governance harness for any client agent:

1. **[System Architecture & Meta AI Stack](docs/_origem/Architecture.md)**
   - **Meta Muse Spark:** SDD architect that decomposes requirements into contracts and failing tests (RED).
   - **Meta Muse Code / Llama 3:** Minimal-implementation and self-healing agent in Dart guided by AST.
   - **SAM 3.1 & Meta Muse Image:** Multimodal visual audit, bounding-box segmentation, and `RenderFlex overflowed` detection.
   - **Llama Stack:** Unified bus for orchestration, tool calling, and context memory.
   - **Dart SDK Core:** Local deterministic AST inspection engine in microseconds (zero-token).

2. **[Client Agent Governance and Tracking via MCP](docs/_origem/ClientAgentsTracking.md)**
   - Once installed in any Flutter project (`flutterguard init --mcp`), FlutterGuard acts as a runtime **Quality Harness and Physical Barrier** for the agents the developer already uses: **Claude Code, Gemini CLI, Cursor, Antigravity, or local models**.
   - Client AIs must respect contracts and validation gates before any commit to the repository.

---

## ⚡ Quick Install & Setup (Native Standard via Git)

Install and activate FlutterGuard globally on your machine directly from GitHub with **a single native Dart SDK command** (no need to clone the repository manually):

### What works today (from a repo checkout)

```bash
dart pub get
dart test
dart run bin/flutterguard.dart grade
dart run bin/flutterguard.dart check <path> [--json]
```

### Global install

```bash
# 1. Official global install straight from GitHub (Dart SDK).
# Primary path (SDKs shipping `dart install`):
dart install 'flutterguard_ai@{git: {url: https://github.com/Thander21/FlutterGuard-AI.git}}'
# Fallback for older SDKs:
dart pub global activate --source git https://github.com/Thander21/FlutterGuard-AI.git

# 2. Initialization with MCP Server and Git Hook in your Flutter project
cd path/to/your_flutter_project
flutterguard init --mcp
```

### What happens automatically behind the scenes:

1. **Native MCP Server:** the `flutterguard_mcp` stdio binary (JSON-RPC 2.0) with 5 typed tools, ready for IDEs and agents (Cursor, Claude Code, Gemini CLI, Antigravity).
2. **Auto-Configuration:** `init --mcp` writes `mcp_config.json` (plus `.cursor/mcp.json` when `.cursor/` is detected) and prints the global-client snippet for manual install.
3. **Governance Contract:** the agent mandate is printed by default; `init --agents` writes it to `AGENTS.md`.
4. **Git Pre-Commit Hook:** installed by `init`; runs `check` and blocks commits with violations.

### MCP tools and agent usage

`init --mcp` registers the `flutterguard_mcp` stdio server. Cursor is
configured automatically (`.cursor/mcp.json`); other clients need the printed
snippet merged into their MCP config (Claude Code shape):

```json
{
  "mcpServers": {
    "flutterguard": {
      "command": "flutterguard_mcp"
    }
  }
}
```

The 5 typed tools (full contract: `specs/system/SYS-MCP-001-mcp-server.md`):

| Tool | Arguments | Purpose |
|---|---|---|
| `analyze_ast` | `path` | Run all 17 AST rules over a file or directory. `FAILED` = violation caught. |
| `get_canonical_recipe` | `rule_id` | Return the Before/After fix recipe (spec §2). Apply in one turn. |
| `verify_viewport` | `path` | Tier-1-lite layout vocabulary. Degraded: `PASS` never claims rendered-clean. |
| `run_mutation_check` | `source_file`, `test_file` | Judge a test against mutants. `passed=false` = complacent test. |
| `get_telemetry` | `rule_id?`, `status?`, `limit?` | Read newest `evidence.jsonl` lines. A query, never a gate. |

Agent loop: `analyze_ast` → `get_canonical_recipe(rule_id)` → patch →
re-run `analyze_ast` until `PASSED`. Verify the install by connecting a
client: a healthy server answers `initialize` with
`serverInfo flutterguard/0.1.0`.

**Scope note:** mutation, coverage/CRAP, duplication, and heal ship as Dart
API + tests + partial MCP (`run_mutation_check`, lite `verify_viewport`);
the terminal surface is `check`/`grade`/`init`/`sandbox` — fuller CLI
coverage is follow-up.

**Official setup:** install once globally, then `flutterguard init --mcp`
in each project. MCP tools govern the agent loop (advise + verify); the
pre-commit hook enforces the gate — it blocks error-severity commits
without depending on the agent. Drive the daily loop with the `fg-use`
skill (`.agents/skills/fg-use/`, promotable to user scope).

---

## 📚 Documentation Map

- 📖 **[Overview and Problem](docs/_origem/ProjectOverview.md):** Market diagnosis, real pain points, and value proposition.
- 🏆 **[Executive Submission Blueprint](docs/_rulesHackathon/HackathonSubmissionBlueprint.md):** Official pitch, Enterprise Bug Benchmark, One-Command CLI, and 2-minute video script.
- 🚀 **[Disruptive Innovations & Out-of-the-Box Engineering](docs/_origem/DisruptiveInnovations.md):** Rebuild Budget, Mutation Testing, Matrix Viewport, and AI's invisible failures.
- 🏛️ **[System Architecture (100% Meta AI)](docs/_origem/Architecture.md):** Reactive flow, AST Engine, feedback loops, and surgical context injection.
- 🔬 **[Formal Verification Algorithms (AST Prover)](docs/_origem/FormalVerificationAlgorithms.md):** Formal methods, Typestate DFA, Cassowary Constraints, Program Slicing, and Causal Analysis for Flutter.
- 🤖 **[Meta AI Stack Dossier](.agents/metaai/Readme.md):** Technical study and integration guide for Muse Spark, Muse Code, SAM 3.1, Muse Image, and Llama Stack.
- 🔌 **[Runtime Client Agent Governance](docs/_origem/ClientAgentsTracking.md):** Tracking of Claude Code, Cursor, Gemini CLI, and Antigravity via MCP.
- 🛡️ **[Force Field & Gates](docs/_origem/ForceFieldHarness.md):** Deterministic pipeline principles and _fail-closed_ blocking.
- 📐 **[Deterministic Gates & Clean Code Validation (ub-mode)](docs/_origem/CleanCodeDeterministicGates.md):** Adaptation of Robert C. Martin's (Uncle Bob) framework, CRAP Score (< 10), duplication detector, and hallucination breaking.
- 🔄 **[SDD + TDD + EDD + XP Methodology](docs/_origem/SpecDrivenDevelopment.md):** The deterministic lifecycle that eliminates hallucinations and complacent tests.
- ⚙️ **[SDD + EDD Operational Flow](docs/_origem/SddEddWorkflow.md):** Deterministic engineering methodology with OpenSpec AST, Eval Benchmarks, and Llama Stack.
- 💡 **[Canonical Recipes Catalog](docs/_origem/CanonicalRecipesCatalog.md):** Correction pattern library (_Before/After_) for AI self-recovery.
- 🔗 **[ERP PDV D+ Reference Bridge](docs/_origem/ReferencePdvDMais.md):** Mapping and lookup of real rules tested in production on PDV D+.
- 🎯 **[Meta Hackathon Track](docs/_rulesHackathon/MetaHackathonTrack.md):** Event planning and official submission texts.
- 📢 **[Outreach & Build in Public](docs/_rulesHackathon/SelfPromotion/SelfPromotion.md):** Meta compliance guidelines and LinkedIn posting calendar.

_Note: the three hackathon links above are event history, not project requirements._

---

## ⚡ Core Pillars

1. **Reactive:** Monitors the AST and code mutations the instant they occur.
2. **Blocking (_Fail-Closed_):** Code not approved by 100% of the gates is summarily reverted.
3. **Didactic / Pedagogical:** Not only points out the error but injects the canonical recipe (_Just-in-Time Canonical Recipe_) so the AI fixes it in 1 turn.
4. **Multimodal:** Does not rely only on text and compilers; inspects the rendered screen for layout breakage.
