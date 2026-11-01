# AGENTS.md

## Code Map

- docs/ - project documentation
- docs/_origem/ - archived origin docs (already reconciled into plans; read-only)
- docs/_rulesHackathon/ - hackathon event rules and outreach (out of scope; deadline/disclosure reference only, do not read during implementation)
- benchmark/ - golden eval vectors (.bad/.good pairs)
- lib/ - application source
- test/ - automated tests
- bin/ - executable entry points
- specs/ - OpenSpec rule contracts
- .agents/ - agent config (skills, workflows, Meta AI dossier, layout index)

## Conventions

- Place OpenSpec rule contracts in specs/.
- Place golden eval vectors in benchmark/vectors/.
- Place project skills in .agents/skills/<name>/SKILL.md.
- Place saved workflows in .agents/workflows/<name>.js.
- Keep the Meta AI dossier in .agents/metaai/; map changes there back into the Meta AI Stack section below.

## Commits

- Write commit messages in English: one logical unit per commit, small
  ordered commits stating motive and proof.
- Model-assisted commits carry a trailer naming the acting model:
  `Assisted-by: Muse Spark` (specs/plans) or `Assisted-by: Muse Code`
  (implementation).

## Language

- Chat with the user in Portuguese.
- Write all documentation and code in English.

## Docs Policy

- Treat docs/ as a starting point, not absolute truth: it records initial direction and intent.
- Validate each documented claim against the repository before implementing it.
- Treat docs/_origem/ as a frozen archive: reconciled into plans, never edited in place.
- Treat docs/_rulesHackathon/ as out of scope: hackathon event rules for deadline/disclosure consultation only. Do not read it during implementation tasks, and never treat it as project requirements.

## Meta AI Stack (which model does what, and where to use it)

Pipeline order: Spark (spec) -> Code (implement) -> SAM + Vision (visual audit).
Llama Stack is the bus underneath all of them. The local Dart analyzer
(zero tokens, not a model) always runs before any model call.
Full dossier: [.agents/metaai/Readme.md](.agents/metaai/Readme.md).

- Muse Spark ([MuseSpark.md](.agents/metaai/MuseSpark.md)) - SDD architect.
  Turns natural-language requirements into sealed-class state contracts,
  widget API contracts, and failing RED tests. Never writes lib/.
  Use for: spec authoring, `*spec` skill, RED stage.
- Muse Code ([MuseCode.md](.agents/metaai/MuseCode.md)) - Dart executor.
  Writes the minimal lib/ implementation to turn RED tests GREEN, respects
  layer guardrails, and applies one-turn Before/After refactors from the
  rule spec's §2 canonical recipe when the AST gate reports a violation.
  Use for: implementation, `*visitor` implementation, `*grade` heal dispatch.
- SAM 3.1 ([SamSegmentAnything.md](.agents/metaai/SamSegmentAnything.md)) -
  geometric segmentation. Converts headless screenshots into masks and
  bounding boxes; the harness detects collisions, occlusions, and tap
  targets < 48dp via AABB comparison.
  Use for: visual gate Tier 2 geometry.
- Muse Image / Vision ([MuseImageVision.md](.agents/metaai/MuseImageVision.md)) -
  semantic visual audit. Judges the rendered screen for RenderFlex overflow
  stripes, truncated text, and contrast/accessibility, returning a strict
  PASS/FAIL JSON verdict.
  Use for: visual gate Tier 2 semantics.
- Llama Stack ([LlamaStack.md](.agents/metaai/LlamaStack.md)) - agent bus.
  Standardizes tool calling (`run_flutter_test`, `analyze_dart_ast`,
  `capture_widget_screenshot`), memory/RAG, Llama Guard safety, and
  cloud/local provider switching behind one contract.
  Use for: harness orchestration, MCP tools, `*grade` loop wiring.
