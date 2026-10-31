# Benchmark Vectors

Golden eval pairs for Eval-Driven Development. Each rule owns one pair:

- `TC-NN_slug.bad.dart`: real-world violating code. The gate MUST flag it.
- `TC-NN_slug.good.dart`: the same code after the canonical recipe. The gate
  MUST NOT flag it (zero false positives).

## Naming

`TC-<zero-padded number>_<slug>.{bad,good}.dart`, referenced from the rule
spec in `specs/` via the `golden_vectors` front-matter fields.

## Grader contract (v1: CLI)

From the repository root, after `dart pub get`:

```sh
dart run bin/flutterguard.dart grade
```

The grader scans `specs/*.md`, runs the registered visitor over each
golden pair, appends one JSON line per file to `evidence.jsonl` (see schema
below), and exits non-zero when any eval fails.

Vectors are parsed for AST matching, not compiled, so unresolved package
imports (e.g. `package:bloc`) do not block the v0 loop.

## Audit contract (v1: CLI)

Audit any target with every registered visitor:

```sh
dart run bin/flutterguard.dart check <path> [--json]
```

`<path>` is one `.dart` file or a directory (scanned recursively).
Text output prints one `RULE file:line message` line per violation;
`--json` prints `{"findings": [...], "errors": [...]}` where each finding
carries `rule_id`, `spec`, `recipe` (Before/After pointer, §2 of the spec),
`file`, `line`, and `message`. Exit code is 1 when any violation is
found, 0 when clean, 2 on bad arguments.

## evidence.jsonl schema

One JSON object per line. This is the exact line `grade` appends:

```json
{
  "timestamp": "2026-10-31T12:00:00Z",
  "phase": "DETERMINISTIC_GATE",
  "rule_id": "FG-BLOC-001",
  "file": "benchmark/vectors/TC-01_bloc.bad.dart",
  "status": "FAILED",
  "error_message": "emit() called after async gap without isClosed check",
  "recipe_injected": "",
  "iteration": 1,
  "action": "EVAL_RECORDED"
}
```

`status` is `PASSED` or `FAILED`. A `.bad.dart` vector passes the eval only
when the gate reports `FAILED` for it; a `.good.dart` vector passes only
when the gate reports `PASSED`.

`recipe_injected` is empty on eval lines because `grade` injects nothing;
heal-dispatch lines (future, per `docs/Architecture/Architecture.md` §5)
reuse this schema with `action: AUTO_HEALING_DISPATCHED` and the injected
recipe id.
