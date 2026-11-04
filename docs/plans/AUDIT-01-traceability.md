# AUDIT-01: Traceability Audit (PLAN-02 Step 5)

Scope: the 17 in-scope content docs (PLAN-02 `source_docs` minus the
plans/review, which are process, and minus `docs/_rulesHackathon`,
dropped project-wide). Method: every named subsystem, rule, metric,
command, and gate maps to exactly one of: built spec, recorded
deferral/drop, backlog, non-goal, reference-only, or adopted process.
Verdict: **zero orphans** (one tracked backlog: light-gate
imports/format/syntax checks, §1.15).

Disposition key: BUILT (spec + code + tests green) · DROP (recorded,
with reason) · DEFER (recorded, re-entry defined) · BACKLOG
(tracked here, no spec yet) · NON-GOAL (never) · REF (reference
only, not spec material) · PROCESS (adopted way of working).

## 1. Per-doc maps

### 1.1 Architecture.md

- §2.1 SDD engine → PROCESS (specs/TS + EDD loop live).
- §2.2 AST governance → BUILT (14 TS rules + `check`/`grade`).
- §2.3 mutation 3 ops (`>`, `==`, `true`) → BUILT (SYS-MUT-001,
  exact operators).
- §2.4 two-tier visual → BUILT Tier-1 (SYS-VIEW-001) + DEFER
  Tier-2 (SYS-VIEW-002).
- §2.5 resilience/heal/rollback → BUILT (SYS-HEAL-001 dispatcher;
  lib-level, no CLI command — none was ever specced); 8s breaker
  → BUILT (MUT/COV runners, Tier-1 timeouts).
- §3 MCP + `init --mcp` + 4 tools → BUILT (SYS-MCP-001, 5 tools).
- §4 single package → BUILT (kept; `viewport/` rig is the recorded
  non-distributed exception, VIEW-001 §6).
- §5 evidence schema → BUILT (SYS-TELE-001, wins).
- §6 `test_fixtures/` → SUPERSEDED by `fixtures/` (CLI-001b §6,
  MUT-001 §6).
- §7-A git install → BUILT (executables + scripts + foreign-dir
  proof).
- §7-B curl one-liner → REJECTED (supply-chain hygiene; git path
  only).
- §7-C clone for dev → covered-by-existence (README checkout flow).
- `.flutterguard/` scripts/recipe-cache/telemetry → covered-by-design
  (scaffold-only dir; recipes embedded per MCP-001 R3; telemetry
  is `evidence.jsonl`).
- `Process.run(timeout:)` → RESOLVED as Process.start + watchdog
  (MUT-001 §6).

### 1.2 FormalVerificationAlgorithms.md

- 5 provers → SYS-FORMAL-001 table: async-gap/disposal CORE covered
  (ASYNC-002, BLOC-001, LIFE-001, LAY-004, ST-001); BUILD-014 built;
  MEM-011 absorbed+dropped; WASTE-015/RACE-013/FSM-012 dropped;
  interval engine dropped; Row/GridV → TS-07 v2 backlog.
- Gate ladder light/full → BUILT (CLI-001a mapping).
- 40ms claim → measured baselines in CLI-001a (tracked, not
  blocking; startup dominates).

### 1.3 metaai/Readme.md

- Pipeline Spark→Code→SAM+Vision, Llama bus, analyzer-first →
  PROCESS adopted (AGENTS.md Meta AI Stack; tail adjusted by the
  Tier-2 deferral).

### 1.4 metaai/MuseSpark.md

- SDD architect, `*spec` skill, RED stage → PROCESS adopted
  (`fg-spec` skill; specs authored first).

### 1.5 metaai/MuseCode.md

- Dart executor, `*visitor`, `*grade` heal, §2 recipe injection →
  PROCESS adopted (`fg-visitor`, `fg-grade`; HEAL-001 +
  RECIPE-001; injection already points at spec §2).

### 1.6 metaai/SamSegmentAnything.md

- Geometry segmentation, AABB collisions, tap targets → DEFER
  (SYS-VIEW-002, no endpoint); AABB math unbuilt (no boxes);
  PNG feed BUILT (VIEW-001).

### 1.7 metaai/MuseImageVision.md

- Overflow stripes, truncation, contrast, PASS/FAIL JSON → DEFER
  (SYS-VIEW-002); prompt format kept in dossier as re-entry input.

### 1.8 metaai/LlamaStack.md

- Bus, tool calling, memory/RAG, Llama Guard, cloud/local →
  DEFERRED (MCP built instead; future-binding map in MCP-001 §6;
  SYS-LLAMA-001 unminted by decision, recorded here).

### 1.9 ProjectOverview.md

- Problem 1 (controllers/business in build) → BUILT (ST-001,
  BUILD-014; `*Sync` subset open as PERF-010 candidate).
- Problem 2 (state anti-patterns) → BUILT (ST-005, RIV-001,
  BLOC-001, ASYNC-002, LIFE-001); framework-mixing → DEFER
  (needs dependency graph).
- Problem 3 (complacent tests) → BUILT (MUT-001, COV-001).
- Problem 4 (visual blindness) → BUILT (LAY-004, VIEW-001) +
  DEFER (VIEW-002).
- RED-gate / AST inspection → PROCESS + BUILT (rules).
- "1–2 turn" heal → STALE, ForceField 3 wins (HEAL-001 §6).
- Multimodal audit → BUILT/DEFER (VIEW-001/002).
- §3 rows → PROCESS (SDD), ARCH-003, ASYNC-002 + LIFE-001,
  VIEW-001, RECIPE-001.
- Fail-closed → PROCESS adopted (doctrine).
- §5 Portuguese internal docs → SUPERSEDED by AGENTS.md English
  (PLAN-01; old PT kept as-is).

### 1.10 DisruptiveInnovations.md

- Rebuild budget (pillar, Part 2 item, Part 3 §4) → DROP generic
  gate (SPIKE SYS-PROF-001; mechanism verified).
- Mutation 3 ops → BUILT (MUT-001).
- Matrix viewport 4 cases → BUILT (VIEW-001, unioned with PDV
  sizes).
- Missing keys → BUILT rescoped (KEY-001r; dataflow dropped).
- Boolean soup / sealed → DROP (FG-FSM-012 spike).
- RenderFlex stripes → partial (error-based BUILT; visual
  DEFERRED with VIEW-002).
- Keyboard 300px variant → SUPERSEDED by 320px (VIEW-001 §6).
- AST suite incl. named BLOC-001/RIV-001 → BUILT.
- Warden (Zombie Stream, Timer Leak) → BUILT (LIFE-001 table).
- CRAP formula → BUILT exact (COV-001); enforcement HOLD
  (CAL-001).
- Headless harvester PNG→SAM → BUILT PNGs; SAM dispatch DEFERRED.
- Jury pitch → hackathon dropped (not spec material).

### 1.11 ReferencePdvDMais.md

- §1 seven rule files → REF consultation sources (RECIPE-001).
- `uilayout.md` adversarial sizes → BUILT (VIEW-001 cases 5–6).
- §2 future use → REF.
- Tenancy/fiscal → NON-GOAL (never ported).

### 1.12 ClientAgentsTracking.md

- Model table → REF (provider-agnosticism; no code).
- Gate 0 spec-gen / Gate 1 worker → PROCESS (`fg-spec`, EDD).
- Gate 2 `ast_guardian` → SUPERSEDED by `check` (CLI-001a §6).
- Gate 3 `flutter test --concurrency=1` → BUILT (CLI-001a +
  runners).
- Gate 4 visual PNGs → BUILT (VIEW-001).
- Gate 5 commit guard + evidence → BUILT (hook + TELE-001).
- `fg run` → SUPERSEDED (CLI-001a §6).
- §3 independence → architecture property (local-first).

### 1.13 SddEddWorkflow.md

- Chat-skills table → BUILT (4 SKILL.md + MCP mapping).
- `test` + `analyzer` → BUILT (deps).
- `mocktail` → UNNEEDED (condition never met: no mock-needing
  test).
- `args` → BUILT; `json_rpc_2` + `stream_channel` → BUILT (MCP).
- Llama/Meta models → DEFER (see 1.8).
- §7 five MCP commands → BUILT exact match (MCP-001).
- `packages/...` path → STALE, fixed (PLAN-01).
- takeScreenshot-vs-golden_toolkit → RESOLVED manual capture
  (VIEW-001 §6).

### 1.14 SpecDrivenDevelopment.md

- SDD/TDD/EDD/XP pillars → PROCESS adopted (loops live).
- Closed loop → product shape (grade + heal + evidence).
- §3 evidence variant → SUPERSEDED (TELE-001 §6).

### 1.15 ForceFieldHarness.md

- Three principles → PROCESS adopted (doctrine).
- §2 gate ladder → BUILT (CLI-001a mapping with budgets).
- Light-gate imports/format/syntax checks → BACKLOG (attached
  "when specced" per CLI-001a; no spec yet — the audit's one
  tracked backlog, not an orphan) → CLOSED 2026-11-04 (see §6).
- §3 heal budget + snapshot + Attack-the-Premise → BUILT
  (HEAL-001, wins).

### 1.16 CleanCodeDeterministicGates.md

- ub-mode arsenal → REF (ecosystem analysis).
- Gate A CRAP → BUILT (COV-001); `crap` name SUPERSEDED (PLAN-01).
- Gate B dryer → BUILT (DRY-001); `dryer` name SUPERSEDED.
- Gate C Attack-the-Premise → BUILT (HEAL-001).
- §4 beyond-ub-mode → BUILT (VIEW-001) + DROP (PROF-001).
- §5 AGENTS.md section → BUILT condensed (`init --agents` +
  skills; full prose not ported).
- §6 references → REF (not spec material).

### 1.17 CanonicalRecipesCatalog.md

- Rules §1–§5 (ST-001, ASYNC-002, ARCH-003, LAY-004, ST-005) →
  all BUILT.
- Catalog itself → REF frozen (RECIPE-001 §6; live recipes in
  spec §2).

## 2. The six contradictions (all owned, all verified this session)

| # | Conflict | Owner |
|---|---|---|
| 1 | Evidence schema (Arch §5 vs SDD §3) | SYS-TELE-001 §6 |
| 2 | Heal budget + rollback layers | SYS-HEAL-001 §6 |
| 3 | One MCP contract; Llama deferred | SYS-MCP-001 §6 |
| 4 | Recipe source of truth (§2 vs catalog) | SYS-RECIPE-001 §6 |
| 5 | Paths/matrices (fixtures, PNGs, matrix) | CLI-001b §6 + VIEW-001 §6 |
| 6 | Benchmark layout (`vectors/` wins) | This audit, §3 |

Each owning §6 was re-read during this audit; all record their
resolution. Beyond the six, additionally resolved: keyboard
320-vs-300 (VIEW-001), SAM labels invalid (VIEW-002), R3 embedded
specs (MCP-001), TS-07 Row/GridV backlog (FORMAL-001),
`--source path` launcher noise (MCP-001).

## 3. Benchmark layout (owned by this audit)

`benchmark/vectors/` wins as the golden-eval home (28 pairs,
graded). `benchmark/cases/` (corporate real-code benchmark) and
`benchmark/run_benchmark.dart` (comparative scorer) are DEFERRED:
they need donated corporate codes plus a scoring design that does
not exist. Vectors + `grade` + `tool/calibrate.dart` cover eval
and measurement today; re-entry starts here.

## 4. Consolidated non-goals (never)

PDV tenancy/fiscal rules; `uml-viewer`-style viz (deferred, not
never — kept distinct); framework-mixing detection (deferred:
dependency graph); FG-I18N + FG-YAGNI (deferred with reason:
PLAN-01); Llama binding (deferred while MCP suffices);
curl-pipe install (rejected); hackathon submission artifacts
(dropped: deadline missed, PLAN-01); Meta study checklists and
paper/reference lists (not spec material).

## 5. Verdict

60+ named ideas mapped: 14 rule specs + 15 system records (12
approved, 1 deferred, 2 dropped spikes) plus table-recorded drops
(formal provers, MEM/WASTE/RACE/FSM), 1 tracked backlog (§1.15),
0 orphans. Re-audit trigger: any new doc under `docs/_origem/`
(frozen — should not happen) or a deferred item's re-entry
(VIEW-002, PROF-002, TS-07 v2, `*Sync` candidate).

## 6. Re-entry log

- 2026-11-04 — §1.15 light-gate BACKLOG closed: `TS-15`
  (FG-IMP-015 illegal imports), `TS-16` (FG-FMT-016 formatter
  batch), `TS-17` (FG-SYN-017 fail-closed syntax) built with
  vectors, visitors, registry entries, and recipe embeds;
  SYS-CLI-001a §2/§3/§5/§6 amended (gate row live, batch
  placement, fail-closed flip). Tracked backlogs: zero.
- 2026-11-04 — TS-07 v2 (FORMAL-002 axes) closed: Row axis +
  GridView/CustomScrollView coverage amended into TS-07
  (FG-LAY-004, same ID), TC-07 vectors extended (all six
  flex×scrollable cells + shrinkWrap-trap negative), visitor +
  unit tests extended; SYS-FORMAL-001 table flipped
  BACKLOG→COVERED. Re-audit triggers remaining: VIEW-002,
  PROF-002, `*Sync` candidate.
