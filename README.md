# FlutterGuard AI

### Autonomous Reactive & Blocking Quality Harness for Flutter / Dart

> **Turning AI from a complacent code generator into a deterministic senior software engineer through Spec-Driven Development (SDD), Reactive AST Analysis, Multimodal Visual Verification, and Blocking Gates.**

*Leia em português: [LEIAME.md](LEIAME.md)*

> **Scope (v0):** 3 AST rules implemented (`FG-BLOC-001`, `FG-RIV-001`, `FG-ST-001`) with
> `grade` + `check` CLI commands. The MCP server, `init`, pre-commit hook,
> mutation gate, visual gates, and auto-heal loop are **[PLANNED]**
> (see `docs/plans/PLAN-01-implementation-to-submission.md` and
> `docs/plans/PLAN-02-functional-scope-to-working-system.md`).
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

2. **[Client Agent Governance and Tracking via MCP](docs/Integrations/ClientAgentsTracking.md)**
   - Once installed in any Flutter project (`flutterguard init --mcp`), FlutterGuard acts as a runtime **Quality Harness and Physical Barrier** for the agents the developer already uses: **Claude Code, Gemini CLI, Cursor, Antigravity, or local models**.
   - Client AIs must respect contracts and validation gates before any commit to the repository.

---

## ⚡ Quick Install & Setup (Option 1: Native Standard via Git)

Install and activate FlutterGuard globally on your machine directly from GitHub with **a single native Dart SDK command** (no need to clone the repository manually):

### What works today (from a repo checkout)

```bash
dart pub get
dart test
dart run bin/flutterguard.dart grade
dart run bin/flutterguard.dart check <path> [--json]
```

### [PLANNED] Global install (does not work yet)

```bash
# 1. Official global activation straight from GitHub (Dart SDK)
dart pub global activate --source git https://github.com/YOUR-USER/flutterguard-ai.git

# 2. Initialization with MCP Server and Git Hook in your Flutter project
cd path/to/your_flutter_project
flutterguard init --mcp
```

### What will happen automatically behind the scenes:

1. **[PLANNED] Native MCP Server:** Registers the `flutterguard_mcp` binary ready to connect with IDEs and agents (Cursor, Claude Code, Gemini CLI, Antigravity).
2. **[PLANNED] Auto-Configuration:** Writes the MCP configuration to `.cursor/mcp.json`, `.agents/mcp_config.json`, or `claude_desktop_config.json`.
3. **[PLANNED] Governance Contract in `AGENTS.md`:** Mandatory instructions so the local AI uses the MCP before committing.
4. **[PLANNED] Git Pre-Commit Hook:** Physical barrier that prevents code with leaks or visual breakage from entering the repository.

---

## 📚 Documentation Map

- 📖 **[Overview and Problem](docs/_origem/ProjectOverview.md):** Market diagnosis, real pain points, and value proposition.
- 🏆 **[Executive Submission Blueprint](docs/_rulesHackathon/HackathonSubmissionBlueprint.md):** Official pitch, Enterprise Bug Benchmark, One-Command CLI, and 2-minute video script.
- 🚀 **[Disruptive Innovations & Out-of-the-Box Engineering](docs/_origem/DisruptiveInnovations.md):** Rebuild Budget, Mutation Testing, Matrix Viewport, and AI's invisible failures.
- 🏛️ **[System Architecture (100% Meta AI)](docs/_origem/Architecture.md):** Reactive flow, AST Engine, feedback loops, and surgical context injection.
- 🔬 **[Formal Verification Algorithms (AST Prover)](docs/_origem/FormalVerificationAlgorithms.md):** Formal methods, Typestate DFA, Cassowary Constraints, Program Slicing, and Causal Analysis for Flutter.
- 🤖 **[Meta AI Stack Dossier](.agents/metaai/Readme.md):** Technical study and integration guide for Muse Spark, Muse Code, SAM 3.1, Muse Image, and Llama Stack.
- 🔌 **[Runtime Client Agent Governance](docs/Integrations/ClientAgentsTracking.md):** Tracking of Claude Code, Cursor, Gemini CLI, and Antigravity via MCP.
- 🛡️ **[Force Field & Gates](docs/_origem/ForceFieldHarness.md):** Deterministic pipeline principles and _fail-closed_ blocking.
- 📐 **[Deterministic Gates & Clean Code Validation (ub-mode)](docs/_origem/CleanCodeDeterministicGates.md):** Adaptation of Robert C. Martin's (Uncle Bob) framework, CRAP Score (< 10), duplication detector, and hallucination breaking.
- 🔄 **[SDD + TDD + EDD + XP Methodology](docs/_origem/SpecDrivenDevelopment.md):** The deterministic lifecycle that eliminates hallucinations and complacent tests.
- ⚙️ **[SDD + EDD Operational Flow](docs/_origem/SddEddWorkflow.md):** Deterministic engineering methodology with OpenSpec AST, Eval Benchmarks, and Llama Stack.
- 💡 **[Canonical Recipes Catalog](docs/_origem/CanonicalRecipesCatalog.md):** Correction pattern library (_Before/After_) for AI self-recovery.
- 🔗 **[ERP PDV D+ Reference Bridge](docs/_origem/ReferencePdvDMais.md):** Mapping and lookup of real rules tested in production on PDV D+.
- 🎯 **[Meta Hackathon Track](docs/_rulesHackathon/MetaHackathonTrack.md):** Event planning and official submission texts.
- 📢 **[Outreach & Build in Public](docs/_rulesHackathon/SelfPromotion/SelfPromotion.md):** Meta compliance guidelines and LinkedIn posting calendar.

---

## ⚡ Core Pillars

1. **Reactive:** Monitors the AST and code mutations the instant they occur.
2. **Blocking (_Fail-Closed_):** Code not approved by 100% of the gates is summarily reverted.
3. **Didactic / Pedagogical:** Not only points out the error but injects the canonical recipe (_Just-in-Time Canonical Recipe_) so the AI fixes it in 1 turn.
4. **Multimodal:** Does not rely only on text and compilers; inspects the rendered screen for layout breakage.
