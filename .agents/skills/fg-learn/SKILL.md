---
name: fg-learn
description: Distill session learnings into harness updates: versioned rules, FOLLOWUP-01 backlog rows, or local memory. Use when the user asks to /learn, consolidate, or record session lessons; not for ordinary code review.
---

# fg-learn — Session Learning Loop (`*learn`)

Consolidates the session into three types without duplicating rules.
Optional focus argument (`$ARGUMENTS`, e.g. "only the heal loop");
without focus, cover the whole session. Adapted from the
Antigravity / Claude Code `/learn` loop.

## Step 0 — Anchor on what you know, never assume the commit

Long sessions lose fidelity. Prefer the most concrete source, never
guess:

1. If the conversation already showed this session's commit (`git
   log` / `git status` / hash), use `git show <ref> --stat` on that
   ref.
2. Never run `git log -1` as if HEAD were this session's — true
   only right after committing in the same conversation.
3. Without a trustworthy ref, work from conversation context only
   and say so in the output.
4. Even with the right commit, the message may omit files. If it
   does not cite what you are analyzing, treat the match as
   unconfirmed.
5. Grade evidence: `evidence.jsonl` lines appended this session
   corroborate eval claims (canon keys per SYS-TELE-001); quote
   line counts, never contents from memory.

## Type 1 — Versioned harness rule

Promote only what would recur in a similar future session. One-off
detail never becomes a rule. If a nearby rule exists, refine it; if
the learning contradicts the written rule, point and ask — never
overwrite.

Where it lives (one home per learning; adapters only point):

| Learning is... | Goes to |
|---|---|
| Session-wide norm, any file | `AGENTS.md`, one line |
| Rule-spec behavior (grammar, severity, vectors) | Never a direct spec edit — `specs/` is normative and grader-read; file as Type 2, design via `fg-spec` |
| Process-loop step (EDD loop, gates, heal, grade) | The owning skill in `.agents/skills/` |
| Mechanizable check (counts, invariants, gates) | A test, not prose — rules that can be tests must be tests |
| Long explanation or operation | `docs/plans/` or a topical `docs/` page |

Improve where you pass: in the touched section, merge duplicates,
move history out, delete stale pointers.

Do not edit yet. Propose in chat one before/after diff per file
with the session origin. Wait for OK. After applying, run the
matching gate and report PASS/FAIL: docs-only → `check` on the
touched files (links must resolve); skills/process text → focused
`dart test` plus CI-scope `dart analyze`; vectors/visitors → full
`dart test` plus `grade`. On FAIL, revise; never commit red.

## Type 2 — Deferred decision / backlog

Skipped-with-reason findings, out-of-scope items, future ideas.
Canonical home: one Findings row per item in
`docs/plans/FOLLOWUP-01-field-tests.md`, with the disposition
linking the graduating spec/plan amendment; re-entries also append
to `AUDIT-01` §6. Rows are never deleted. Propose the row text
before writing.

## Type 3 — Personal preference (never in the repo)

How the user likes to work: tone, when to ask for OK, tools. Goes
to local memory (project or personal scope, never versioned);
update the `MEMORY.md` index when one exists. Update the existing
fact instead of duplicating; link related topics instead of
repeating the body. Before writing, verify paths cited in memories
still exist on disk; fix moved ones, mark past-only ones
historical, delete dead ones. No gate reads memory. Type 3 writes
directly, no OK needed.

## Auto mode (graded-unit close)

At the close of each graded unit, after `grade` goes green and
before the commit text, `/learn` runs unprompted:

- Type 1: never apply. List proposed diffs in chat with the commit
  text; wait for OK; applied → re-run the matching gate.
- Type 2: write directly to `FOLLOWUP-01` (no OK), report rows.
- Type 3: write directly, as always.

## Expected output

1. Whether you crossed with a commit (which ref) or stayed
   conversation-only.
2. Type 1: proposed diffs per file, awaiting OK (or "no
   rule-worthy learning").
3. Type 2: rows written (auto) or proposed (manual), with
   dispositions.
4. Type 3: written to memory, with locations.
5. Gate result if any Type 1 was applied.
6. If a type had no finding, say so instead of forcing one.
